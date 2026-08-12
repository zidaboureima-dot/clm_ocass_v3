-- 20260812_reset_password.sql
-- Vulnérabilité n°4 : réinitialisation de mot de passe (Modèle 2 — admin déclenche)
-- + changement forcé au premier accès (posé à true par les Edge Functions).

-- 1. Changement forcé : marqueur sur users (default false ; les Edge Functions
--    poseront true sur les temporaires — reset et création).
alter table public.users
  add column if not exists doit_changer_mdp boolean not null default false;

-- 2. Table des demandes de réinitialisation (minimale ; nom/rôle/région
--    viennent de users par jointure à l'affichage).
create table if not exists public.demandes_reset (
  id           uuid primary key default gen_random_uuid(),
  email        text not null,
  statut       text not null default 'en_attente',
  demande_le   timestamptz not null default now(),
  traitee_le   timestamptz
);

-- Anti-doublon : une seule demande en attente par email.
create unique index if not exists uq_demande_reset_en_attente
  on public.demandes_reset (email)
  where statut = 'en_attente';

-- 3. RLS : seul un admin actif LIT les demandes. Écriture réservée aux
--    Edge Functions en service_role (aucune policy insert/update publique).
alter table public.demandes_reset enable row level security;

create policy "Admin actif lit les demandes de reset"
  on public.demandes_reset for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'
        and u.actif = true
    )
  );
