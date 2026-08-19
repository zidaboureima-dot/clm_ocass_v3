-- =====================================================================
-- Migration : 20260819_actions_menees.sql
-- Objet     : Table des ACTIONS MENÉES sur un signalement, et exigence de
--             documentation aux deux transitions de statut qui comptent.
--
-- POURQUOI CETTE TABLE EXISTE (à lire avant d'y toucher)
--   Elle est volontairement DISTINCTE de public.annotations, alors que les
--   deux portent du texte écrit par un acteur sur un cas. La distinction
--   n'est pas cosmétique : c'est le garde-fou central du rapport périodique
--   (voir CADRAGE_RAPPORT_LLM.md).
--
--     - annotations    : espace de TRAVAIL INTERNE. Peut contenir des
--                        appréciations professionnelles, y compris sur des
--                        collègues ou des hiérarchies locales. N'est JAMAIS
--                        transmis à un modèle de langage ni à un tiers.
--     - actions_menees : ce qui a été ENTREPRIS, écrit par son auteur en
--                        sachant que cela pourra figurer dans un rapport
--                        transmis aux autorités. Seule source exploitée par
--                        le rapport périodique.
--
--   La minimisation s'opère ainsi À LA SOURCE : le modèle ne reçoit que ce
--   qui a été écrit en connaissance de cause. Un filtrage appliqué en aval,
--   sur un corpus non trié, finit toujours par laisser passer quelque chose.
--
--   COROLLAIRE POUR TOUTE ÉVOLUTION FUTURE : n'ajoutez jamais les
--   annotations à la source du rapport « parce qu'elles sont plus riches ».
--   Si le rapport manque de matière, la réponse est d'améliorer la saisie
--   des actions, pas d'élargir la collecte.
--
-- QUAND LA SAISIE A LIEU (décision du 19 août 2026)
--   Plutôt qu'un champ disponible en permanence — qu'en pratique personne
--   ne remplit —, la saisie est ancrée sur deux moments qui existent déjà
--   dans le workflow :
--     - le SUPERVISEUR documente l'action menée avant de marquer « traité » ;
--     - l'ADMIN rédige une note de synthèse avant de « clôturer ».
--   Aucune nouvelle habitude à créer, et une garantie : tout cas traité a
--   une action documentée, tout cas clôturé a une synthèse.
--
--   Le SCHÉMA autorise néanmoins PLUSIEURS actions par signalement, même si
--   l'interface n'en propose qu'une à chacun de ces deux moments. Ouvrir la
--   saisie plus largement plus tard ne coûtera alors aucune migration.
--
-- CE QUE L'ON PERD, ET POURQUOI C'EST ACCEPTABLE
--   L'action n'étant consignée qu'en fin de traitement, le délai avant
--   PREMIÈRE action n'est pas mesurable. Mais les cas bloqués — ceux qui
--   n'atteignent jamais « traité » — restent visibles par leur absence
--   même : « N cas sans aucune action depuis plus de X jours » se calcule à
--   partir du statut et des dates. Ce sont précisément les cas qui
--   intéressent le plaidoyer.
--
-- SÉCURITÉ
--   RLS calquée sur celle de public.annotations
--   (20260815_securite_annotations.sql) : même périmètre, mêmes rôles,
--   public exclu, append-only (aucune policy UPDATE ni DELETE).
--
-- IDEMPOTENT : rejouable sans erreur.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------
create table if not exists public.actions_menees (
  id              uuid primary key default gen_random_uuid(),
  signalement_id  uuid not null references public.signalements(id) on delete cascade,
  auteur_uid      uuid not null,
  role_auteur     text not null,
  type_action     text not null,
  description     text not null,
  resultat        text not null default 'en_attente',
  created_at      timestamptz not null default now()
);

-- Vocabulaire contrôlé. Volontairement court : une liste longue n'est pas
-- renseignée sérieusement sur le terrain et rend les agrégats illisibles.
--   saisine    : cas porté au responsable de la structure concernée
--   plaidoyer  : démarche auprès d'une autorité (district, région, ministère)
--   correction : correction obtenue ou constatée sur le terrain
--   relance    : nouvelle sollicitation après absence de réponse
--   autre      : à préciser dans la description
--   synthese   : note de synthèse rédigée par l'admin à la clôture. Type à
--                part : il ne décrit pas une démarche mais conclut le cas.
alter table public.actions_menees
  drop constraint if exists actions_menees_type_action_check;
alter table public.actions_menees
  add constraint actions_menees_type_action_check
  check (type_action in ('saisine', 'plaidoyer', 'correction', 'relance', 'autre', 'synthese'));

alter table public.actions_menees
  drop constraint if exists actions_menees_resultat_check;
alter table public.actions_menees
  add constraint actions_menees_resultat_check
  check (resultat in ('obtenu', 'en_attente', 'sans_suite'));

alter table public.actions_menees
  drop constraint if exists actions_menees_role_auteur_check;
alter table public.actions_menees
  add constraint actions_menees_role_auteur_check
  check (role_auteur in ('point_focal', 'superviseur', 'admin'));

-- Une description vide n'a aucune valeur dans un rapport : on la refuse au
-- niveau de la base plutôt que de compter sur la seule validation côté app.
alter table public.actions_menees
  drop constraint if exists actions_menees_description_non_vide;
alter table public.actions_menees
  add constraint actions_menees_description_non_vide
  check (length(btrim(description)) >= 10);


-- ---------------------------------------------------------------------
-- 2. Index
--   - lecture des actions d'un cas (écran de détail) ;
--   - extraction par période (rapport périodique).
-- ---------------------------------------------------------------------
create index if not exists idx_actions_menees_signalement
  on public.actions_menees (signalement_id, created_at);

create index if not exists idx_actions_menees_created_at
  on public.actions_menees (created_at);


-- ---------------------------------------------------------------------
-- 3. RLS — miroir exact de public.annotations
--   admin        : toutes les actions
--   superviseur  : actions des signalements de SA région
--   point focal  : actions des signalements où il est l'assigné
--   public/anon  : RIEN
--   INSERT       : auteur_uid = auth.uid() ET signalement dans le périmètre
--   Pas de policy UPDATE ni DELETE (trace append-only).
-- ---------------------------------------------------------------------
alter table public.actions_menees enable row level security;

-- 3.a SELECT admin
drop policy if exists "actions_menees_select_admin" on public.actions_menees;
create policy "actions_menees_select_admin"
  on public.actions_menees
  for select
  using (role_du_demandeur() = 'admin'::text);

-- 3.b SELECT superviseur : sa région
drop policy if exists "actions_menees_select_superviseur" on public.actions_menees;
create policy "actions_menees_select_superviseur"
  on public.actions_menees
  for select
  using (
    role_du_demandeur() = 'superviseur'::text
    and exists (
      select 1 from public.signalements s
      where s.id = actions_menees.signalement_id
        and s.region = region_du_demandeur()
    )
  );

-- 3.c SELECT point focal : ses cas assignés
drop policy if exists "actions_menees_select_point_focal" on public.actions_menees;
create policy "actions_menees_select_point_focal"
  on public.actions_menees
  for select
  using (
    role_du_demandeur() = 'point_focal'::text
    and exists (
      select 1 from public.signalements s
      where s.id = actions_menees.signalement_id
        and s.assignee_uid = auth.uid()
    )
  );

-- 3.d INSERT : auteur = soi-même ET signalement dans le périmètre
drop policy if exists "actions_menees_insert_acteurs" on public.actions_menees;
create policy "actions_menees_insert_acteurs"
  on public.actions_menees
  for insert
  with check (
    auteur_uid = auth.uid()
    and (
      role_du_demandeur() = 'admin'::text
      or (
        role_du_demandeur() = 'superviseur'::text
        and exists (
          select 1 from public.signalements s
          where s.id = actions_menees.signalement_id
            and s.region = region_du_demandeur()
        )
      )
      or (
        role_du_demandeur() = 'point_focal'::text
        and exists (
          select 1 from public.signalements s
          where s.id = actions_menees.signalement_id
            and s.assignee_uid = auth.uid()
        )
      )
    )
  );


-- ---------------------------------------------------------------------
-- 4. Exigence de documentation aux transitions
--
--   TRIGGER DISTINCT de trg_valider_transition_statut, volontairement.
--   Ce dernier répond à « qui a le droit de faire quoi » ; celui-ci répond
--   à « le cas est-il documenté ». Deux préoccupations séparées, deux
--   triggers séparés, chacun modifiable sans toucher l'autre.
--
--   Règle :
--     - vers 'traite'  : au moins une action menée (hors synthèse)
--     - vers 'cloture' : au moins une note de synthèse
--
--   S'applique à TOUS les rôles, y compris l'admin. Ce n'est pas une
--   restriction de permission mais une exigence de qualité de donnée — et
--   la migration 20260814 posait déjà le principe pour la reprise par
--   l'admin : « avec documentation obligatoire ».
--
--   ORDRE D'ÉCRITURE CÔTÉ APPLICATION : insérer l'action D'ABORD, changer
--   le statut ENSUITE. L'inverse est refusé par ce trigger.
--
--   Les signalements déjà en 'traite' ou 'cloture' avant cette migration
--   ne sont pas affectés : le trigger ne se déclenche que sur une
--   transition nouvelle.
-- ---------------------------------------------------------------------
create or replace function public.exiger_documentation_statut()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  -- Statut inchangé : rien à exiger.
  if new.statut is not distinct from old.statut then
    return new;
  end if;

  if new.statut = 'traite' then
    if not exists (
      select 1 from public.actions_menees a
      where a.signalement_id = new.id
        and a.type_action <> 'synthese'
    ) then
      raise exception
        'Impossible de marquer ce signalement traité : aucune action menée n''a été documentée.';
    end if;
  end if;

  if new.statut = 'cloture' then
    if not exists (
      select 1 from public.actions_menees a
      where a.signalement_id = new.id
        and a.type_action = 'synthese'
    ) then
      raise exception
        'Impossible de clôturer ce signalement : aucune note de synthèse n''a été rédigée.';
    end if;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_exiger_documentation_statut on public.signalements;

create trigger trg_exiger_documentation_statut
  before update on public.signalements
  for each row
  execute function exiger_documentation_statut();


-- =====================================================================
-- VÉRIFICATION APRÈS EXÉCUTION
--   select policyname, cmd from pg_policies
--   where tablename = 'actions_menees' order by cmd, policyname;
--   Attendu : 4 policies (3 SELECT + 1 INSERT), aucune UPDATE/DELETE.
--
--   select relname, relrowsecurity from pg_class
--   where relname = 'actions_menees';
--   Attendu : relrowsecurity = true.
--
--   select tgname from pg_trigger
--   where tgrelid = 'public.signalements'::regclass and not tgisinternal;
--   Attendu : trg_valider_transition_statut ET
--             trg_exiger_documentation_statut.
-- =====================================================================
