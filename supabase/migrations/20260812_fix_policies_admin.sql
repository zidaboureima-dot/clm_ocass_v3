-- 20260812_fix_policies_admin.sql
-- Correctif régression accès admin.
-- Les policies admin reposaient sur (auth.jwt() ->> 'role') = 'admin', un claim
-- absent du JWT Supabase (qui porte role='authenticated'). Elles ne matchaient
-- que via l'ancienne faille authenticated_read_users (fermée le 2026-08-11).
-- Correctif : baser les policies admin sur role_du_demandeur() (SECURITY DEFINER,
-- lit public.users.role sans récursion). Cohérent avec les policies superviseur/
-- point focal et avec admin_update_users.

-- users
drop policy if exists "Admin see all users" on public.users;
create policy "Admin see all users"
  on public.users for select
  using ( role_du_demandeur() = 'admin' );

-- signalements
drop policy if exists "Admin sees all signalements" on public.signalements;
create policy "Admin sees all signalements"
  on public.signalements for select
  using ( role_du_demandeur() = 'admin' );

-- audios
drop policy if exists "Admin sees all audios" on public.audios;
create policy "Admin sees all audios"
  on public.audios for select
  using ( role_du_demandeur() = 'admin' );
