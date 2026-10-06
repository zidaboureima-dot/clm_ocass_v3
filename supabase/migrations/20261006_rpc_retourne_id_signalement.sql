-- =====================================================================
-- Migration : 20261006_rpc_retourne_id_signalement.sql
-- Objet     : `soumettre_signalement_anonyme` renvoie l'identifiant du
--             signalement créé, au lieu de ne rien renvoyer.
--
-- LE DÉFAUT CORRIGÉ
--   Depuis le 11 août 2026, le dépôt citoyen passe par cette RPC. Sa liste
--   de colonnes commence à `anonyme` : `id` n'y figure pas, donc la base
--   génère le sien.
--
--   Or l'application génère de son côté un UUID AVANT l'appel, et s'en sert
--   pour rattacher la photo et le message vocal :
--
--       final idSignalement = const Uuid().v4();
--       await SignalementService().creerSignalement(signalement);
--       await PhotoService().uploaderPhoto(signalementId: idSignalement, ...);
--
--   Les deux identifiants ne coïncident jamais. Depuis cette date, AUCUNE
--   pièce jointe ne peut se rattacher à son signalement — sur les trois
--   chemins : formulaire citoyen, traitement d'un vocal brut, traitement
--   d'une photo brute.
--
--   Conséquence la plus grave : quelqu'un photographie une preuve, l'envoie,
--   reçoit une confirmation, et la preuve n'atteint aucun responsable.
--
-- POURQUOI CE CORRECTIF PLUTÔT QUE L'AUTRE
--   On aurait pu insérer `(p_contenu->>'id')::uuid` : une seule migration,
--   aucun changement applicatif. Écarté délibérément — cela laisserait un
--   appelant ANONYME choisir la clé primaire d'un signalement, donc rendre
--   les identifiants prévisibles sur le flux le plus exposé du dispositif.
--
--   La fonction renvoie donc l'identifiant que la base a généré, et
--   l'application attend ce retour avant d'envoyer le moindre média. Cela
--   corrige la cause : l'application cessait d'avoir à présumer qu'elle
--   connaît l'id.
--
-- POURQUOI UN `drop` PRÉALABLE
--   PostgreSQL refuse de changer le type de retour d'une fonction existante
--   par `create or replace`. Le `drop` est donc obligatoire, et il emporte le
--   GRANT — qui est réappliqué en fin de fichier. L'oublier couperait le
--   dépôt citoyen.
--
-- CE QUI NE CHANGE PAS
--   Le compteur de rate-limit, le seuil, la fenêtre, le message `RATE_LIMIT`,
--   et le fait que `anon` n'a aucun droit direct sur `signalements`.
--
-- ORDRE DE DÉPLOIEMENT — IMPORTANT
--   1. CETTE MIGRATION D'ABORD, puis le binaire.
--   2. Jamais l'inverse.
--
--   L'ordre migration → application est sans risque : l'ancienne application
--   ignore simplement la valeur renvoyée. L'ordre inverse ne l'est pas — la
--   nouvelle application attend un identifiant que l'ancienne fonction ne
--   renvoie pas, et afficherait une erreur d'envoi alors que le signalement
--   a bien été enregistré. Dire à quelqu'un que son signalement a échoué
--   alors qu'il est passé est exactement ce qu'il ne faut pas faire ici.
--
-- IDEMPOTENT : rejouable sans erreur.
-- =====================================================================

drop function if exists public.soumettre_signalement_anonyme(jsonb, uuid, int, int);

create function public.soumettre_signalement_anonyme(
  p_contenu          jsonb,
  p_marqueur         uuid,
  p_seuil            int default 50,
  p_fenetre_minutes  int default 15
)
returns uuid
language plpgsql
security definer
set search_path = public
as $FN$
declare
  debut_fenetre timestamptz := date_trunc('minute', now())
    - make_interval(mins => (extract(minute from now())::int % p_fenetre_minutes));
  n int;
  v_id uuid;
begin
  insert into public.rate_limit_depots (marqueur, fenetre, compteur)
    values (p_marqueur, debut_fenetre, 1)
  on conflict (marqueur, fenetre)
    do update set compteur = public.rate_limit_depots.compteur + 1
  returning public.rate_limit_depots.compteur into n;

  if n > p_seuil then
    raise exception 'RATE_LIMIT'
      using hint = 'Trop de dépôts depuis cet appareil. Réessayez dans quelques minutes.';
  end if;

  insert into public.signalements (
    anonyme, region, prefecture, centre_sante,
    nature, groupe, categorie_id, categorie_libelle,
    description, date_incident,
    soumis_le, statut,
    assignee_uid, superviseur_uid, admin_uid
  ) values (
    coalesce((p_contenu->>'anonyme')::boolean, true),
    p_contenu->>'region',
    p_contenu->>'prefecture',
    p_contenu->>'centre_sante',
    p_contenu->>'nature',
    p_contenu->>'groupe',
    nullif(p_contenu->>'categorie_id','')::uuid,
    p_contenu->>'categorie_libelle',
    p_contenu->>'description',
    nullif(p_contenu->>'date_incident','')::date,
    now(),
    'nouveau',
    null, null, null
  )
  -- LE SEUL AJOUT DE FOND : récupérer l'identifiant réellement attribué.
  returning public.signalements.id into v_id;

  return v_id;
end;
$FN$;

grant execute on function public.soumettre_signalement_anonyme(jsonb, uuid, int, int) to anon;


-- =====================================================================
-- VÉRIFICATION APRÈS EXÉCUTION
--
--   select pg_get_function_result(p.oid)
--     from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and p.proname = 'soumettre_signalement_anonyme';
--
--   Attendu : uuid  (et non void).
--
--   Puis, après redéploiement de l'application, un dépôt de test avec photo
--   doit faire apparaître une ligne dans `photos` dont `signalement_id`
--   existe bien dans `signalements` :
--
--   select count(*) from public.photos p
--    where not exists (select 1 from public.signalements s
--                       where s.id = p.signalement_id);
--   Attendu : 0.
-- =====================================================================
