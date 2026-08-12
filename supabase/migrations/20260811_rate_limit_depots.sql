-- 20260811_rate_limit_depots.sql
-- Vulnérabilité n°2 : rate-limit des dépôts anonymes.
-- Passe l'insert citoyen par une RPC SECURITY DEFINER porteuse d'un compteur
-- par marqueur d'appareil anonyme (UUID non-identifiant). Révoque tout droit
-- d'écriture/lecture directe de `anon`. Seuil paramétrable (défaut 50 / 15 min).

create table if not exists public.rate_limit_depots (
  marqueur   uuid        not null,
  fenetre    timestamptz not null,
  compteur   int         not null default 0,
  primary key (marqueur, fenetre)
);

alter table public.rate_limit_depots enable row level security;

drop function if exists public.soumettre_signalement_anonyme(jsonb, uuid, int, int);

create function public.soumettre_signalement_anonyme(
  p_contenu          jsonb,
  p_marqueur         uuid,
  p_seuil            int default 50,
  p_fenetre_minutes  int default 15
)
returns void
language plpgsql
security definer
set search_path = public
as $FN$
declare
  debut_fenetre timestamptz := date_trunc('minute', now())
    - make_interval(mins => (extract(minute from now())::int % p_fenetre_minutes));
  n int;
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
  );
end;
$FN$;

revoke insert, update, delete, truncate, select on public.signalements from anon;
revoke all on public.rate_limit_depots from anon;
drop policy if exists "Citizen can insert signalement" on public.signalements;
grant execute on function public.soumettre_signalement_anonyme(jsonb, uuid, int, int) to anon;
