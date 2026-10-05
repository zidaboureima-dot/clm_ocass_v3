-- =====================================================================
-- Migration : 20261005_mode_maintenance.sql
-- Objet     : Interrupteur de maintenance, lisible par l'application.
--
-- POURQUOI CET INTERRUPTEUR EXISTE
--   Tant que l'application est distribuée en APK en téléchargement direct,
--   il n'y a pas de mise à jour automatique : corriger une anomalie suppose
--   de refaire circuler le fichier auprès de points focaux dispersés et
--   d'obtenir qu'ils le réinstallent.
--
--   Cet interrupteur permet de suspendre l'accès des responsables à distance
--   — le temps d'une migration délicate, d'une réparation, ou en cas de
--   découverte d'une faille — sans courir après les téléphones.
--
-- CE QU'IL BLOQUE, ET CE QU'IL NE BLOQUE PAS (décision du 5 octobre 2026)
--   Il bloque l'accès aux TABLEAUX DE BORD des responsables. Leur travail
--   reprend après, rien n'est perdu.
--
--   Il ne bloque PAS le dépôt d'un signalement par un citoyen. Une personne
--   qui a pris le risque de venir signaler un refus de soins et qui tombe sur
--   un écran de maintenance ne reviendra pas forcément : le signalement est
--   perdu, et la confiance avec lui. Les dépôts s'accumulent pendant la
--   fenêtre et seront traités ensuite.
--
-- POURQUOI UNE VUE, ET PAS UNE LECTURE DIRECTE DE LA TABLE
--   configuration_pays n'expose qu'une policy SELECT réservée à l'admin.
--   L'application d'un citoyen — qui n'a aucun compte — ne peut donc rien y
--   lire. Et ouvrir la table entière exposerait from_email et
--   rapport_llm_motif, sans rapport avec le besoin.
--
--   La vue etat_service n'expose que les trois colonnes nécessaires. Même
--   motif que stats_publiques (20260811_securite_rls.sql) : security_invoker
--   à false pour que la vue s'exécute avec les droits de son propriétaire,
--   puis GRANT explicite.
--
-- IDEMPOTENT : rejouable sans erreur.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Les colonnes
-- ---------------------------------------------------------------------
alter table public.configuration_pays
  add column if not exists service_actif boolean not null default true;

-- Message affiché aux responsables pendant la coupure. Facultatif, mais
-- fortement conseillé : « revenez dans deux heures » vaut mieux qu'un écran
-- muet, qui laisse croire à une panne.
alter table public.configuration_pays
  add column if not exists service_message text;


-- ---------------------------------------------------------------------
-- 2. La vue publique
-- ---------------------------------------------------------------------
create or replace view public.etat_service as
  select pays_code, service_actif, service_message
    from public.configuration_pays;

alter view public.etat_service set (security_invoker = false);
grant select on public.etat_service to anon, authenticated;


-- =====================================================================
-- VÉRIFICATION APRÈS EXÉCUTION
--
--   select * from public.etat_service;
--   Attendu : une ligne GN, service_actif = true, service_message null.
--
-- POUR COUPER LE SERVICE
--   update public.configuration_pays
--      set service_actif  = false,
--          service_message = 'Maintenance en cours. Le service sera rétabli '
--                            'vers 14h. Les signalements continuent d''être '
--                            'reçus normalement.',
--          maj_le = now()
--    where pays_code = 'GN';
--
-- POUR LE RÉTABLIR
--   update public.configuration_pays
--      set service_actif = true, service_message = null, maj_le = now()
--    where pays_code = 'GN';
--
-- Comme pour rapport_llm_actif, aucune policy d'écriture n'est posée : la
-- bascule se fait en SQL, délibérément. Une case à cocher dans une interface
-- invite à l'oubli — et un service laissé coupé par distraction est une
-- panne que personne ne diagnostique.
-- =====================================================================
