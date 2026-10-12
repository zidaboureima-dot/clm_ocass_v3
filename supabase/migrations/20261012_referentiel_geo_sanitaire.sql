-- =====================================================================
-- Migration : 20261012_referentiel_geo_sanitaire.sql
-- Objet     : Sortir la géographie du code et donner une existence propre
--             aux FORMATIONS SANITAIRES, aujourd'hui saisies en texte libre.
--
-- POURQUOI CETTE MIGRATION EXISTE
--   Deux manques, de poids très différent.
--
--   1. La géographie est figée dans lib/data/regions_prefectures.dart. Le
--      décret du 20 août 2026 a imposé une recompilation et une
--      republication de l'application pour une décision qui ne touche pas
--      une ligne de logique. C'est la limite du modèle mono-pays, déjà
--      documentée dans ce fichier Dart et dans CADRAGE_SAAS_CONSOLIDE.md.
--
--   2. Plus lourd : `signalements.centre_sante` est un CHAMP DE TEXTE LIBRE,
--      saisi au clavier par le citoyen. « CHU Donka », « chu donka »,
--      « Donka » et « Hôpital Donka » sont donc quatre établissements
--      distincts dans les données. Conséquences :
--
--        - aucun comptage par établissement ;
--        - aucune série temporelle par site ;
--        - et surtout, le CROISEMENT SATISFACTION × SIGNALEMENTS prévu par
--          la réforme est impossible : l'enquête livrera des résultats
--          rattachés à une liste canonique d'établissements, qui n'aurait
--          aucun répondant côté dispositif.
--
--   Le référentiel n'est donc pas la première fonction par commodité de
--   séquencement : c'est la condition d'existence des cinq autres.
--
-- CE QUE CETTE MIGRATION NE TOUCHE PAS — À LIRE AVANT D'Y REVENIR
--   `signalements.region` et `signalements.prefecture` restent des colonnes
--   TEXTE, inchangées. Ce n'est pas un oubli.
--
--   `region` est le PÉRIMÈTRE DE LECTURE appliqué par RLS, via
--   region_du_demandeur() (20260811_securite_rls.sql), qui compare du texte.
--   La remplacer par une clé étrangère reviendrait à réécrire les policies
--   de trois tables — signalements, annotations, actions_menees — dans la
--   même migration que la création du référentiel. Une erreur sur ce
--   chemin n'échoue pas bruyamment : elle ouvre à un superviseur la lecture
--   d'une autre région, sans que rien ne le signale.
--
--   Le référentiel s'ajoute donc À CÔTÉ du cloisonnement existant, sans le
--   traverser. Le passage des policies aux clés étrangères, s'il est un jour
--   souhaité, est une migration à lui seul, avec ses propres tests.
--
-- LE CHOIX DE SAISIE (décision du 12 octobre 2026)
--   Le formulaire citoyen CONSERVE le texte libre. Sur un dispositif de
--   signalement de refus de soins, une liste fermée transforme un
--   établissement absent du référentiel en signalement perdu, et la
--   personne qui a pris le risque de venir ne revient pas.
--
--   Le rapprochement se fait donc APRÈS COUP, côté administration — mais il
--   se fait par ALIAS, pas signalement par signalement : un libellé rattaché
--   une fois rattache automatiquement toutes ses occurrences ultérieures
--   (voir la table alias_formations et le trigger, section 6). La charge est
--   proportionnelle au nombre de graphies distinctes, pas au volume de
--   signalements.
--
--   Corollaire : le rapportage périodique des points focaux, lui, se fera
--   sur LISTE FERMÉE. Un point focal est un acteur identifié et formé ; la
--   mesure routinière a besoin d'un dénominateur, ce que le texte libre
--   ne donne jamais.
--
-- IDEMPOTENT : rejouable sans erreur.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Normalisation des libellés
--
--    unaccent() est déclarée STABLE et non IMMUTABLE par l'extension, ce
--    qui interdit son emploi dans un index ou une colonne générée. On
--    l'enveloppe donc dans une fonction marquée IMMUTABLE explicitement.
--
--    Cette déclaration est sûre ici parce qu'on fige le dictionnaire
--    appelé : extensions.unaccent('unaccent', $1) ne dépend plus du
--    search_path de la session, seule raison pour laquelle unaccent() est
--    STABLE à l'origine.
-- ---------------------------------------------------------------------
create extension if not exists unaccent with schema extensions;

create or replace function public.normaliser_libelle(p_texte text)
returns text
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  -- minuscules, sans accents, ponctuation réduite à l'espace,
  -- espaces multiples repliés, bords rognés.
  select trim(
           regexp_replace(
             regexp_replace(
               lower(extensions.unaccent('extensions.unaccent'::regdictionary, p_texte)),
               '[^a-z0-9]+', ' ', 'g'
             ),
             '\s+', ' ', 'g'
           )
         );
$$;

comment on function public.normaliser_libelle(text) is
  'Forme canonique d''un libellé : « CHU Donka », « chu  donka » et '
  '« CHU, Donka » donnent tous « chu donka ». Sert au rapprochement '
  'des formations sanitaires saisies en texte libre.';

-- CE QUE CETTE NORMALISATION NE FAIT PAS, ET POURQUOI
--   « C.H.U. DONKA » donne « c h u donka », et ne se rapproche donc pas
--   de « chu donka ». C'est volontaire : recoller les lettres isolées
--   ferait aussi fusionner « Centre de Santé N'Zérékoré » avec des
--   libellés sans rapport, et une fusion erronée de deux établissements
--   est bien plus coûteuse qu'un rapprochement manquant — elle additionne
--   silencieusement les signalements de deux sites.
--
--   Ces graphies partent donc dans la file de rapprochement et y sont
--   traitées une fois pour toutes par un alias. C'est précisément le rôle
--   de alias_formations : absorber ce qu'aucune règle ne peut décider
--   sans risque.


-- ---------------------------------------------------------------------
-- 2. Les régions
--
--    `code` est la clé stable, `nom` le libellé affiché. Les deux existent
--    parce qu'un renommage administratif ne doit pas casser les
--    rattachements : on change le nom, le code ne bouge pas.
--
--    `est_zone_speciale` distingue Conakry, gouvernorat dont les 13
--    communes ne comptent pas parmi les 44 préfectures. Sans ce drapeau,
--    tout décompte de contrôle est faux.
--
--    `actif` plutôt qu'une suppression : une région supprimée emporterait
--    ses préfectures et ses établissements, donc le rattachement des
--    signalements historiques. On désactive, on ne détruit pas.
-- ---------------------------------------------------------------------
create table if not exists public.regions (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,
  nom               text not null,
  est_zone_speciale boolean not null default false,
  actif             boolean not null default true,
  ordre             integer not null default 0,
  cree_le           timestamptz not null default now(),
  modifie_le        timestamptz not null default now()
);

create unique index if not exists regions_nom_normalise_uniq
  on public.regions (public.normaliser_libelle(nom));


-- ---------------------------------------------------------------------
-- 3. Les préfectures (et les communes de Conakry)
--
--    Les communes de Conakry figurent ici parce que l'application doit
--    permettre d'y signaler. Elles se distinguent par la région parente,
--    marquée zone spéciale — jamais par une liste codée ailleurs.
-- ---------------------------------------------------------------------
create table if not exists public.prefectures (
  id         uuid primary key default gen_random_uuid(),
  region_id  uuid not null references public.regions(id) on delete restrict,
  code       text not null unique,
  nom        text not null,
  actif      boolean not null default true,
  cree_le    timestamptz not null default now(),
  modifie_le timestamptz not null default now()
);

create index if not exists prefectures_region_idx
  on public.prefectures (region_id);

create unique index if not exists prefectures_nom_normalise_uniq
  on public.prefectures (region_id, public.normaliser_libelle(nom));


-- ---------------------------------------------------------------------
-- 4. Les formations sanitaires
--
--    `code` est destiné à recevoir l'identifiant national — celui du DHIS2
--    quand l'ingestion sera câblée. Il est laissé libre en attendant :
--    imposer dès maintenant un format empêcherait la saisie manuelle.
--
--    `type_etablissement` reste du texte et non une énumération : les
--    nomenclatures varient d'un pays à l'autre, et ce référentiel a
--    vocation à servir au-delà de la Guinée.
-- ---------------------------------------------------------------------
create table if not exists public.formations_sanitaires (
  id                 uuid primary key default gen_random_uuid(),
  prefecture_id      uuid not null references public.prefectures(id) on delete restrict,
  code               text unique,
  nom                text not null,
  type_etablissement text,
  actif              boolean not null default true,
  source             text not null default 'saisie_manuelle',
  cree_le            timestamptz not null default now(),
  modifie_le         timestamptz not null default now(),
  constraint formations_source_connue
    check (source in ('saisie_manuelle', 'import_fichier', 'dhis2'))
);

create index if not exists formations_prefecture_idx
  on public.formations_sanitaires (prefecture_id);

-- Deux établissements de même nom dans la même préfecture sont une erreur
-- de saisie, pas un cas de figure.
create unique index if not exists formations_nom_normalise_uniq
  on public.formations_sanitaires (prefecture_id, public.normaliser_libelle(nom));


-- ---------------------------------------------------------------------
-- 5. Les alias
--
--    C'est la pièce qui rend le texte libre soutenable. Chaque graphie
--    rencontrée est rattachée UNE FOIS à un établissement ; toutes ses
--    occurrences futures se rattachent ensuite d'elles-mêmes.
--
--    Le nom canonique de chaque établissement est inséré comme alias de
--    lui-même (section 7), de sorte qu'une saisie exacte se rattache sans
--    qu'un administrateur ait eu à intervenir.
-- ---------------------------------------------------------------------
create table if not exists public.alias_formations (
  id             uuid primary key default gen_random_uuid(),
  formation_id   uuid not null references public.formations_sanitaires(id) on delete cascade,
  libelle_saisi  text not null,
  libelle_norme  text not null,
  cree_par       uuid references auth.users(id) on delete set null,
  cree_le        timestamptz not null default now()
);

-- Un même libellé normalisé ne peut désigner qu'un seul établissement :
-- sans cette contrainte, le rapprochement serait ambigu et le trigger
-- rattacherait au hasard.
create unique index if not exists alias_libelle_norme_uniq
  on public.alias_formations (libelle_norme);

create index if not exists alias_formation_idx
  on public.alias_formations (formation_id);


-- ---------------------------------------------------------------------
-- 6. Le rattachement des signalements
--
--    Colonne NULLABLE, et qui doit le rester : un signalement dont
--    l'établissement n'est pas encore rapproché doit être déposé,
--    acheminé et traité normalement. Le rapprochement est une amélioration
--    de la donnée, jamais une condition de recevabilité.
-- ---------------------------------------------------------------------
alter table public.signalements
  add column if not exists formation_sanitaire_id uuid
    references public.formations_sanitaires(id) on delete set null;

create index if not exists signalements_formation_idx
  on public.signalements (formation_sanitaire_id)
  where formation_sanitaire_id is not null;

create or replace function public.rapprocher_formation_sanitaire()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_formation uuid;
begin
  -- Un rattachement déjà posé n'est jamais écrasé : s'il vient d'un
  -- arbitrage d'administrateur, le trigger n'a pas à le défaire.
  if new.formation_sanitaire_id is not null then
    return new;
  end if;

  if new.centre_sante is null or trim(new.centre_sante) = '' then
    return new;
  end if;

  select a.formation_id
    into v_formation
    from public.alias_formations a
   where a.libelle_norme = public.normaliser_libelle(new.centre_sante)
   limit 1;

  if v_formation is not null then
    new.formation_sanitaire_id := v_formation;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_rapprocher_formation on public.signalements;
create trigger trg_rapprocher_formation
  before insert or update of centre_sante on public.signalements
  for each row execute function public.rapprocher_formation_sanitaire();


-- ---------------------------------------------------------------------
-- 7. Alias automatique du nom canonique
--
--    Tout établissement créé ou renommé devient alias de lui-même. Sans
--    cela, un nom saisi exactement comme au référentiel ne se rattacherait
--    pas, ce qui serait absurde.
--
--    on conflict do nothing : si la graphie est déjà prise par un autre
--    établissement, c'est un conflit de référentiel à arbitrer par un
--    humain. Le signaler par une erreur empêcherait la création de
--    l'établissement, ce qui est pire que de laisser l'alias manquant.
-- ---------------------------------------------------------------------
create or replace function public.alias_du_nom_canonique()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.alias_formations (formation_id, libelle_saisi, libelle_norme)
  values (new.id, new.nom, public.normaliser_libelle(new.nom))
  on conflict (libelle_norme) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_alias_nom_canonique on public.formations_sanitaires;
create trigger trg_alias_nom_canonique
  after insert or update of nom on public.formations_sanitaires
  for each row execute function public.alias_du_nom_canonique();


-- ---------------------------------------------------------------------
-- 8. Horodatage des modifications
-- ---------------------------------------------------------------------
create or replace function public.toucher_modifie_le()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.modifie_le := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_regions on public.regions;
create trigger trg_touch_regions before update on public.regions
  for each row execute function public.toucher_modifie_le();

drop trigger if exists trg_touch_prefectures on public.prefectures;
create trigger trg_touch_prefectures before update on public.prefectures
  for each row execute function public.toucher_modifie_le();

drop trigger if exists trg_touch_formations on public.formations_sanitaires;
create trigger trg_touch_formations before update on public.formations_sanitaires
  for each row execute function public.toucher_modifie_le();


-- ---------------------------------------------------------------------
-- 9. RLS
--
--    LECTURE OUVERTE, y compris à anon. Le formulaire citoyen doit pouvoir
--    peupler ses listes déroulantes sans compte, comme il le fait déjà
--    pour les catégories. Un référentiel géographique et sanitaire est une
--    donnée publique : il ne dit rien de ce qui a été signalé.
--
--    ÉCRITURE RÉSERVÉE À L'ADMINISTRATEUR. Le référentiel détermine le
--    périmètre de la mesure ; laisser un superviseur créer un
--    établissement reviendrait à lui laisser créer son propre
--    dénominateur.
-- ---------------------------------------------------------------------
alter table public.regions               enable row level security;
alter table public.prefectures           enable row level security;
alter table public.formations_sanitaires enable row level security;
alter table public.alias_formations      enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['regions', 'prefectures', 'formations_sanitaires'] loop
    execute format('drop policy if exists %I on public.%I', t || '_lecture_tous', t);
    execute format(
      'create policy %I on public.%I for select to anon, authenticated using (true)',
      t || '_lecture_tous', t);

    execute format('drop policy if exists %I on public.%I', t || '_ecriture_admin', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (public.role_du_demandeur() = ''admin'') '
      'with check (public.role_du_demandeur() = ''admin'')',
      t || '_ecriture_admin', t);
  end loop;
end $$;

-- Les alias ne sont lisibles que des comptes authentifiés : un citoyen n'en
-- a pas l'usage, et la liste des graphies erronées rencontrées n'a pas à
-- être publique.
drop policy if exists alias_lecture_authentifies on public.alias_formations;
create policy alias_lecture_authentifies on public.alias_formations
  for select to authenticated using (true);

drop policy if exists alias_ecriture_admin on public.alias_formations;
create policy alias_ecriture_admin on public.alias_formations
  for all to authenticated
  using (public.role_du_demandeur() = 'admin')
  with check (public.role_du_demandeur() = 'admin');


-- ---------------------------------------------------------------------
-- 10. Amorçage depuis la liste codée en dur
--
--     Reprise fidèle de lib/data/regions_prefectures.dart au 12 octobre
--     2026 : 9 régions administratives, Conakry en zone spéciale,
--     44 préfectures et 13 communes.
--
--     Les codes sont dérivés du nom normalisé, sans accent ni espace. Ils
--     ne sont donc pas « officiels » — ils seront remplacés par les codes
--     nationaux à l'ingestion DHIS2, l'unicité du nom servant de pivot.
--
--     on conflict (code) do update : rejouer la migration corrige un
--     libellé sans dupliquer la ligne ni rompre les rattachements.
-- ---------------------------------------------------------------------
with donnees(region, est_speciale, ordre, prefectures) as (
  values
    ('Beyla',     false, 1,  array['Beyla','Karala','Kouankan','Sinko']),
    ('Boké',      false, 2,  array['Boké','Boffa','Fria','Gaoual','Kamsar','Koundara']),
    ('Conakry',   true,  3,  array['Dixinn','Gbessia','Kagbelen','Kaloum','Kassa','Lambanyi',
                                   'Manéah','Matam','Matoto','Ratoma','Sanoyah','Sonfonia','Tombolia']),
    ('Faranah',   false, 4,  array['Faranah','Dabola','Dinguiraye','Kissidougou']),
    ('Kankan',    false, 5,  array['Kankan','Dialakoro','Kérouané','Kouroussa','Mandiana',
                                   'Sabadou-Baranama','Tokounou']),
    ('Kindia',    false, 6,  array['Kindia','Coyah','Dubréka','Forécariah','Télimélé']),
    ('Labé',      false, 7,  array['Labé','Koubia','Lélouma','Mali','Tougué']),
    ('Mamou',     false, 8,  array['Mamou','Dalaba','Pita','Timbo']),
    ('Nzérékoré', false, 9,  array['Nzérékoré','Guéckédou','Lola','Macenta','Yomou']),
    ('Siguiri',   false, 10, array['Siguiri','Doko','Kintinian','Siguirini'])
),
regions_insérées as (
  insert into public.regions (code, nom, est_zone_speciale, ordre)
  select replace(public.normaliser_libelle(region), ' ', '-'), region, est_speciale, ordre
    from donnees
  on conflict (code) do update
    set nom               = excluded.nom,
        est_zone_speciale = excluded.est_zone_speciale,
        ordre             = excluded.ordre
  returning id, nom
)
insert into public.prefectures (region_id, code, nom)
select r.id,
       replace(public.normaliser_libelle(d.region), ' ', '-') || '-' ||
       replace(public.normaliser_libelle(p), ' ', '-'),
       p
  from donnees d
  join regions_insérées r on r.nom = d.region
  cross join lateral unnest(d.prefectures) as p
on conflict (code) do update set nom = excluded.nom;


-- ---------------------------------------------------------------------
-- 11. Contrôle de cohérence
--
--     Même rôle que nombrePrefectures et nombreRegionsAdministratives côté
--     Dart : si l'amorçage fait varier ces nombres sans qu'un texte l'ait
--     décidé, c'est une erreur de saisie. La migration échoue plutôt que
--     d'installer un découpage faux.
-- ---------------------------------------------------------------------
do $$
declare
  v_regions      integer;
  v_prefectures  integer;
  v_communes     integer;
begin
  select count(*) into v_regions
    from public.regions where not est_zone_speciale;

  select count(*) into v_prefectures
    from public.prefectures p
    join public.regions r on r.id = p.region_id
   where not r.est_zone_speciale;

  select count(*) into v_communes
    from public.prefectures p
    join public.regions r on r.id = p.region_id
   where r.est_zone_speciale;

  if v_regions <> 9 or v_prefectures <> 44 or v_communes <> 13 then
    raise exception
      'Découpage territorial incohérent : % régions administratives (attendu 9), '
      '% préfectures (attendu 44), % communes de Conakry (attendu 13). '
      'Décret du 20 août 2026 — voir lib/data/regions_prefectures.dart.',
      v_regions, v_prefectures, v_communes;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 12. Vue de la file de rapprochement
--
--     Ce que l'administrateur a à traiter : les graphies rencontrées qui
--     ne correspondent à aucun alias connu, les plus fréquentes d'abord.
--     Une ligne traitée en fait disparaître autant qu'il y avait
--     d'occurrences.
--
--     security_invoker à true, contrairement à etat_service : la vue ne
--     doit être lisible que de qui peut déjà lire les signalements, et le
--     RLS existant s'en charge. Ne pas inverser ce réglage — ce serait
--     exposer l'activité de signalement région par région.
-- ---------------------------------------------------------------------
create or replace view public.rapprochements_en_attente
with (security_invoker = true) as
  select public.normaliser_libelle(s.centre_sante) as libelle_norme,
         min(s.centre_sante)                       as exemple_saisi,
         s.region,
         s.prefecture,
         count(*)                                  as occurrences,
         max(s.soumis_le)                          as derniere_occurrence
    from public.signalements s
   where s.formation_sanitaire_id is null
     and s.centre_sante is not null
     and trim(s.centre_sante) <> ''
   group by 1, 3, 4
   order by count(*) desc;

grant select on public.rapprochements_en_attente to authenticated;


-- ---------------------------------------------------------------------
-- 13. L'acte de rapprochement
--
--     POURQUOI UNE FONCTION, ET PAS UN SIMPLE INSERT D'ALIAS
--       La vue ci-dessus annonce un nombre d'occurrences. Elle promet donc
--       implicitement que traiter une ligne rattache aussi les signalements
--       DÉJÀ déposés sous cette graphie. Le trigger, lui, ne s'applique
--       qu'aux insertions : poser l'alias seul laisserait les anciens
--       signalements non rattachés et la ligne dans la file, avec un
--       décompte qui ne baisse pas.
--
--       Les deux écritures — créer l'alias, reprendre l'historique — sont
--       donc réunies dans une seule fonction, qui est l'acte unitaire
--       d'administration. Les séparer, c'est accepter qu'elles divergent.
--
--     SECURITY DEFINER, mais contrôle de rôle explicite en première ligne :
--     la fonction écrit sur les signalements de toutes les régions, ce
--     qu'aucun superviseur ne doit pouvoir déclencher.
-- ---------------------------------------------------------------------
create or replace function public.rapprocher_libelle(
  p_libelle      text,
  p_formation_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_norme   text;
  v_reprise integer;
begin
  if public.role_du_demandeur() is distinct from 'admin' then
    raise exception 'Seul un administrateur peut rapprocher un libellé.'
      using errcode = '42501';
  end if;

  v_norme := public.normaliser_libelle(p_libelle);

  if v_norme is null or v_norme = '' then
    raise exception 'Libellé vide après normalisation : rien à rapprocher.';
  end if;

  if not exists (select 1 from public.formations_sanitaires
                  where id = p_formation_id and actif) then
    raise exception 'Formation sanitaire inconnue ou désactivée.';
  end if;

  -- L'alias, pour toutes les occurrences à venir.
  insert into public.alias_formations
         (formation_id, libelle_saisi, libelle_norme, cree_par)
  values (p_formation_id, p_libelle, v_norme, auth.uid())
  on conflict (libelle_norme) do update
    set formation_id = excluded.formation_id,
        libelle_saisi = excluded.libelle_saisi,
        cree_par      = excluded.cree_par,
        cree_le       = now();

  -- L'historique, pour toutes les occurrences déjà déposées.
  update public.signalements
     set formation_sanitaire_id = p_formation_id
   where formation_sanitaire_id is null
     and centre_sante is not null
     and public.normaliser_libelle(centre_sante) = v_norme;

  get diagnostics v_reprise = row_count;
  return v_reprise;
end;
$$;

revoke all on function public.rapprocher_libelle(text, uuid) from public;
grant execute on function public.rapprocher_libelle(text, uuid) to authenticated;

comment on function public.rapprocher_libelle(text, uuid) is
  'Rattache une graphie à une formation sanitaire : crée l''alias pour '
  'l''avenir et reprend les signalements déjà déposés. Renvoie le nombre '
  'de signalements repris. Réservée à l''administrateur.';


-- =====================================================================
-- APRÈS EXÉCUTION — vérifications à lancer dans le SQL Editor
-- =====================================================================
--
--   -- Le découpage
--   select count(*) filter (where not est_zone_speciale) as regions_adm,
--          count(*) filter (where est_zone_speciale)     as zones_speciales
--     from public.regions;                                 -- attendu : 9, 1
--
--   -- La normalisation
--   select public.normaliser_libelle('C.H.U.  DONKA');      -- attendu : chu donka
--   select public.normaliser_libelle('Hôpital Préfectoral de Kindia');
--                                       -- attendu : hopital prefectoral de kindia
--
--   -- Le rapprochement, une fois un établissement créé
--   insert into public.formations_sanitaires (prefecture_id, nom, type_etablissement)
--   select id, 'CHU Donka', 'Hôpital national' from public.prefectures
--    where nom = 'Dixinn';
--   select libelle_norme from public.alias_formations;      -- attendu : chu donka
--
--   -- La file d'attente
--   select * from public.rapprochements_en_attente limit 20;
--
-- =====================================================================
