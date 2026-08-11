-- =====================================================================
-- CLM-OCASS : Securite RLS et vue d'agregats publique
-- Consigne l'etat de securite pose les 10-11 aout 2026.
-- A rejouer sur toute base neuve (nouveau deploiement pays SaaS).
-- Ordre important : fonctions avant policies, vue avant grant.
-- =====================================================================

-- 1. Colonnes de contact sur les acteurs (public.users)
alter table public.users
  add column if not exists telephone text,
  add column if not exists whatsapp text;

alter table public.users
  drop constraint if exists telephone_format;
alter table public.users
  add constraint telephone_format
  check (telephone is null or telephone ~ '^\+[0-9 ]{8,20}$');

-- 2. Fonctions SECURITY DEFINER : region et role du demandeur
create or replace function public.region_du_demandeur()
returns text language sql security definer stable set search_path = public
as $$ select region from public.users where id = auth.uid(); $$;

create or replace function public.role_du_demandeur()
returns text language sql security definer stable set search_path = public
as $$ select role from public.users where id = auth.uid(); $$;

-- 3. RLS sur public.users
alter table public.users enable row level security;
drop policy if exists authenticated_read_users on public.users;
drop policy if exists users_select_self on public.users;
drop policy if exists "Acteurs voient leur region" on public.users;
create policy "Acteurs voient leur region"
on public.users for select to authenticated
using (region is not null and region = public.region_du_demandeur());

-- 4. Vue d'agregats publique (comptes uniquement)
create or replace view public.stats_publiques as
  select 'statut'::text as dimension, statut as valeur, count(*)::int as nombre
  from public.signalements group by statut
  union all
  select 'nature'::text, nature, count(*)::int
  from public.signalements group by nature
  union all
  select 'categorie'::text, coalesce(nullif(categorie_libelle, ''), groupe), count(*)::int
  from public.signalements
  where coalesce(nullif(categorie_libelle, ''), groupe) is not null
    and coalesce(nullif(categorie_libelle, ''), groupe) <> ''
  group by coalesce(nullif(categorie_libelle, ''), groupe)
  union all
  select 'region'::text, region, count(*)::int
  from public.signalements group by region;

alter view public.stats_publiques set (security_invoker = false);
grant select on public.stats_publiques to anon, authenticated;

-- 5. RLS sur public.signalements : cloisonnement par role et perimetre
alter table public.signalements enable row level security;
drop policy if exists public_read_signalements_stats on public.signalements;
drop policy if exists authenticated_update_signalements on public.signalements;

drop policy if exists "Acteurs voient signalements de leur perimetre" on public.signalements;
create policy "Acteurs voient signalements de leur perimetre"
on public.signalements for select to authenticated
using (
  (public.role_du_demandeur() = 'superviseur' and region = public.region_du_demandeur())
  or (public.role_du_demandeur() = 'point_focal' and assignee_uid = auth.uid())
);

drop policy if exists "Acteurs modifient signalements de leur perimetre" on public.signalements;
create policy "Acteurs modifient signalements de leur perimetre"
on public.signalements for update to authenticated
using (
  (public.role_du_demandeur() = 'superviseur' and region = public.region_du_demandeur())
  or (public.role_du_demandeur() = 'point_focal' and assignee_uid = auth.uid())
)
with check (
  (public.role_du_demandeur() = 'superviseur' and region = public.region_du_demandeur())
  or (public.role_du_demandeur() = 'point_focal' and assignee_uid = auth.uid())
);

-- Policies preexistantes conservees (non recreees ici) :
--   users : "Admin see all users", "Users see themselves", "admin_update_users"
--   signalements : "Admin sees all signalements", "Citizen can insert signalement"
