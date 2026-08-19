-- =====================================================================
-- Migration : 20260819_configuration_pays_et_rapports.sql
-- Objet     : Couche de configuration par pays, et stockage des rapports
--             périodiques assistés par un modèle de langage.
--
-- POURQUOI CES DEUX TABLES ARRIVENT ENSEMBLE
--   Le rapport périodique ne peut pas exister sans un interrupteur par pays :
--   chaque pays contractant relève d'un cadre juridique distinct, et ce qui
--   est licite dans l'un ne l'est pas nécessairement dans l'autre. Livrer la
--   fonctionnalité sans son interrupteur reviendrait à l'activer partout.
--
--   `configuration_pays` amorce par ailleurs la levée de la DETTE N°1 de
--   DETTES_SAAS.md (FROM_EMAIL codé en dur dans quatre Edge Functions) : la
--   colonne existe ici, les fonctions la liront lors d'une étape ultérieure
--   qui imposera leur redéploiement.
--
-- PRINCIPE DIRECTEUR : ÉTEINT PAR DÉFAUT
--   `rapport_llm_actif` vaut false à la création d'un pays, et aucune policy
--   RLS ne permet de le modifier depuis l'application. L'activation exige un
--   acte délibéré en base, accompagné d'un motif écrit.
--
--   Ce n'est pas de la défiance envers l'administrateur : activer ce
--   traitement engage la conformité du dispositif à la loi du pays concerné
--   (en Guinée, L/2016/037/AN) et suppose que la politique de confidentialité
--   ait été mise à jour AU PRÉALABLE. Une case à cocher dans une interface
--   invite à l'oubli ; une ligne de SQL assortie d'un motif laisse une trace.
--
-- IDEMPOTENT : rejouable sans erreur.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Configuration par pays
-- ---------------------------------------------------------------------
create table if not exists public.configuration_pays (
  pays_code          text primary key,
  libelle_pays       text not null,

  -- Dette n°1 : expéditeur des emails transactionnels, aujourd'hui en dur
  -- dans les Edge Functions. Colonne posée ici, lecture à câbler ensuite.
  from_email         text,

  -- Rapport périodique assisté par un modèle de langage.
  rapport_llm_actif  boolean not null default false,

  -- Pourquoi la fonctionnalité est active, ou pourquoi elle ne l'est pas.
  -- Champ délibérément obligatoire dans les faits : sans motif écrit, la
  -- décision d'activer devient impossible à rejouer ou à auditer six mois
  -- plus tard.
  rapport_llm_motif  text,

  maj_le             timestamptz not null default now()
);

-- Le code pays suit la norme ISO 3166-1 alpha-2, en majuscules.
alter table public.configuration_pays
  drop constraint if exists configuration_pays_code_format;
alter table public.configuration_pays
  add constraint configuration_pays_code_format
  check (pays_code ~ '^[A-Z]{2}$');

-- Amorçage : la Guinée, seul pays déployé à ce jour. Fonctionnalité
-- ÉTEINTE, avec le motif de son extinction.
insert into public.configuration_pays
  (pays_code, libelle_pays, rapport_llm_actif, rapport_llm_motif)
values (
  'GN',
  'Guinée',
  false,
  'Éteint au 19/08/2026. Deux préalables non levés : (1) avis de l''ANSSI '
  'Guinée sur la qualification des données transmises au regard de la loi '
  'L/2016/037/AN, demande envoyée ; (2) mise à jour de la politique de '
  'confidentialité et de la déclaration Data Safety, qui affirment '
  'aujourd''hui l''absence de tout partage avec un tiers. Ne pas activer '
  'avant que les deux ne soient levés.'
)
on conflict (pays_code) do nothing;


-- ---------------------------------------------------------------------
-- 2. Rapports produits
--
--   `statut` encode l'exigence de validation humaine dans le schéma lui-même
--   plutôt que dans une consigne : un rapport naît 'brouillon' et ne peut
--   être diffusé qu'une fois passé à 'valide' par un administrateur. Ce qui
--   est porté par le schéma survit aux changements d'équipe ; ce qui n'est
--   écrit que dans une note, non.
-- ---------------------------------------------------------------------
create table if not exists public.rapports_periodiques (
  id               uuid primary key default gen_random_uuid(),
  pays_code        text not null references public.configuration_pays(pays_code),
  periode_debut    date not null,
  periode_fin      date not null,
  contenu          text not null,
  statut           text not null default 'brouillon',
  modele_utilise   text,

  -- Volumes transmis uniquement — jamais le contenu transmis lui-même.
  -- Journaliser ce contenu reviendrait à créer une seconde copie des données
  -- que l'on cherche précisément à protéger.
  trace            jsonb,

  valide_par       uuid,
  valide_le        timestamptz,
  created_at       timestamptz not null default now()
);

alter table public.rapports_periodiques
  drop constraint if exists rapports_periodiques_statut_check;
alter table public.rapports_periodiques
  add constraint rapports_periodiques_statut_check
  check (statut in ('brouillon', 'valide', 'rejete'));

alter table public.rapports_periodiques
  drop constraint if exists rapports_periodiques_periode_coherente;
alter table public.rapports_periodiques
  add constraint rapports_periodiques_periode_coherente
  check (periode_fin > periode_debut);

create index if not exists idx_rapports_periodiques_pays_periode
  on public.rapports_periodiques (pays_code, periode_debut desc);


-- ---------------------------------------------------------------------
-- 3. RLS
--
--   configuration_pays  : lecture par l'admin (pour connaître l'état),
--                         AUCUNE écriture depuis l'application. Modification
--                         réservée au SQL Editor / service_role.
--   rapports_periodiques: lecture et validation par l'admin seul — le
--                         rapport est national, et l'admin est le seul rôle
--                         au périmètre national (cadrage §2.1).
--
--   Les Edge Functions opèrent en service_role et contournent le RLS : elles
--   lisent la configuration et écrivent les rapports sans policy dédiée.
-- ---------------------------------------------------------------------
alter table public.configuration_pays enable row level security;

drop policy if exists "configuration_pays_select_admin" on public.configuration_pays;
create policy "configuration_pays_select_admin"
  on public.configuration_pays
  for select
  using (role_du_demandeur() = 'admin'::text);

-- Aucune policy INSERT / UPDATE / DELETE : c'est délibéré, voir l'en-tête.

alter table public.rapports_periodiques enable row level security;

drop policy if exists "rapports_select_admin" on public.rapports_periodiques;
create policy "rapports_select_admin"
  on public.rapports_periodiques
  for select
  using (role_du_demandeur() = 'admin'::text);

-- L'admin peut valider ou rejeter un rapport, rien d'autre : le contenu
-- produit reste tel quel. Un rapport que l'on pourrait réécrire à la main
-- avant diffusion ne serait plus le reflet de ce que le traitement a produit,
-- et la trace perdrait son sens.
drop policy if exists "rapports_update_admin" on public.rapports_periodiques;
create policy "rapports_update_admin"
  on public.rapports_periodiques
  for update
  using (role_du_demandeur() = 'admin'::text)
  with check (role_du_demandeur() = 'admin'::text);


-- ---------------------------------------------------------------------
-- 4. Garde-fou en base : un rapport ne peut naître que si le pays l'autorise
--
--   L'Edge Function vérifie déjà le drapeau avant de travailler. Ce trigger
--   est la seconde barrière : si un jour une autre voie d'écriture existe —
--   script d'administration, import, erreur de déploiement —, la base refuse
--   quand même. Même principe que pour les transitions de statut : l'UI est
--   du confort, la base fait foi.
-- ---------------------------------------------------------------------
create or replace function public.verifier_rapport_llm_autorise()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  actif boolean;
begin
  select rapport_llm_actif into actif
    from public.configuration_pays
   where pays_code = new.pays_code;

  if actif is not true then
    raise exception
      'Rapport refusé : la génération assistée par modèle de langage n''est pas activée pour le pays %.', new.pays_code;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_verifier_rapport_llm_autorise on public.rapports_periodiques;

create trigger trg_verifier_rapport_llm_autorise
  before insert on public.rapports_periodiques
  for each row
  execute function verifier_rapport_llm_autorise();


-- =====================================================================
-- VÉRIFICATION APRÈS EXÉCUTION
--
--   select pays_code, libelle_pays, rapport_llm_actif
--     from public.configuration_pays;
--   Attendu : une ligne GN, rapport_llm_actif = false.
--
--   select policyname, cmd from pg_policies
--    where tablename in ('configuration_pays', 'rapports_periodiques')
--    order by tablename, cmd;
--   Attendu : 1 SELECT sur configuration_pays (aucune écriture),
--             1 SELECT + 1 UPDATE sur rapports_periodiques.
--
-- POUR ACTIVER LE JOUR VENU (et pas avant) :
--   update public.configuration_pays
--      set rapport_llm_actif = true,
--          rapport_llm_motif = 'Activé le <date>. Avis ANSSI du <date> : '
--                              '<conclusion>. Politique de confidentialité '
--                              'et déclaration Data Safety mises à jour le '
--                              '<date>.',
--          maj_le = now()
--    where pays_code = 'GN';
-- =====================================================================
