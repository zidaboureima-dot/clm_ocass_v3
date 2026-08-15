-- =====================================================================
-- Migration : 20260815_securite_annotations.sql
-- Objet     : Sécurisation des policies RLS de la table annotations.
--
-- CONTEXTE (faille corrigée)
--   Avant cette migration, la table annotations exposait :
--     - annotations_select_public  : SELECT qual=true  -> lecture PUBLIQUE
--       de tous les échanges de traitement des cas (fuite de confidentialité).
--     - annotations_insert_authenticated : INSERT with_check=auth.role()=
--       'authenticated' -> tout authentifié insère, sans contrôle de
--       l'auteur ni du périmètre. Cette policy permissive ANNULAIT
--       "Can insert own annotations" (les INSERT d'un même cmd sont en OR).
--
-- CIBLE (périmètre du cas + admin, public exclu)
--   Une annotation appartient à un signalement (annotations.signalement_id
--   -> signalements.id). L'accès suit le périmètre du signalement :
--     - admin        : toutes les annotations
--     - superviseur  : annotations des signalements de SA région
--     - point focal  : annotations des signalements où il est l'assigné
--                      (signalements.assignee_uid = auth.uid())
--     - public/anon  : RIEN
--   INSERT : auteur_uid = auth.uid() ET signalement dans le périmètre.
--
-- NOTE : pas de policy UPDATE ni DELETE (trace append-only conservée).
--
-- SÉQUENCEMENT (règle projet : CREATE avant DROP)
--   Sur la base de production, exécuter par blocs dans cet ordre :
--     Bloc 0 : vérifier que RLS est actif (relrowsecurity = true).
--     Bloc 1 : CREATE les nouvelles policies.
--     Bloc 2 : vérifier leur présence (relire pg_policies).
--     Bloc 3 : DROP les anciennes policies permissives.
--   Ce fichier documente l'état cible et sert de rejeu idempotent.
-- =====================================================================


-- ---------------------------------------------------------------------
-- BLOC 0 — Prérequis : RLS doit être actif sur annotations.
--   Si relrowsecurity = false, les policies sont ignorées. Activer
--   SEULEMENT après avoir créé les policies (bloc 1), jamais avant,
--   pour ne pas bloquer les acteurs légitimes entre-temps.
-- ---------------------------------------------------------------------
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'annotations';
-- (Si false, décommenter la ligne suivante APRÈS le bloc 1 :)
-- ALTER TABLE public.annotations ENABLE ROW LEVEL SECURITY;


-- ---------------------------------------------------------------------
-- BLOC 1 — CREATE les nouvelles policies (avant tout DROP).
-- ---------------------------------------------------------------------

-- 1.a SELECT admin : toutes les annotations.
DROP POLICY IF EXISTS "annotations_select_admin" ON public.annotations;
CREATE POLICY "annotations_select_admin"
  ON public.annotations
  FOR SELECT
  USING (role_du_demandeur() = 'admin'::text);

-- 1.b SELECT superviseur : annotations des signalements de sa région.
DROP POLICY IF EXISTS "annotations_select_superviseur" ON public.annotations;
CREATE POLICY "annotations_select_superviseur"
  ON public.annotations
  FOR SELECT
  USING (
    role_du_demandeur() = 'superviseur'::text
    AND EXISTS (
      SELECT 1 FROM public.signalements s
      WHERE s.id = annotations.signalement_id
        AND s.region = region_du_demandeur()
    )
  );

-- 1.c SELECT point focal : annotations des signalements où il est assigné.
DROP POLICY IF EXISTS "annotations_select_point_focal" ON public.annotations;
CREATE POLICY "annotations_select_point_focal"
  ON public.annotations
  FOR SELECT
  USING (
    role_du_demandeur() = 'point_focal'::text
    AND EXISTS (
      SELECT 1 FROM public.signalements s
      WHERE s.id = annotations.signalement_id
        AND s.assignee_uid = auth.uid()
    )
  );

-- 1.d INSERT unifié : auteur = soi-même ET signalement dans le périmètre.
--     Remplace "Can insert own annotations" (qui ne contrôlait pas le
--     périmètre) et "annotations_insert_authenticated" (permissive).
DROP POLICY IF EXISTS "annotations_insert_acteurs" ON public.annotations;
CREATE POLICY "annotations_insert_acteurs"
  ON public.annotations
  FOR INSERT
  WITH CHECK (
    auteur_uid = auth.uid()
    AND (
      role_du_demandeur() = 'admin'::text
      OR (
        role_du_demandeur() = 'superviseur'::text
        AND EXISTS (
          SELECT 1 FROM public.signalements s
          WHERE s.id = annotations.signalement_id
            AND s.region = region_du_demandeur()
        )
      )
      OR (
        role_du_demandeur() = 'point_focal'::text
        AND EXISTS (
          SELECT 1 FROM public.signalements s
          WHERE s.id = annotations.signalement_id
            AND s.assignee_uid = auth.uid()
        )
      )
    )
  );


-- ---------------------------------------------------------------------
-- BLOC 2 — Vérification (à exécuter et lire AVANT le bloc 3).
--   Attendu : 4 nouvelles policies présentes (3 SELECT + 1 INSERT).
-- ---------------------------------------------------------------------
-- SELECT policyname, cmd FROM pg_policies
-- WHERE tablename = 'annotations' ORDER BY cmd, policyname;


-- ---------------------------------------------------------------------
-- BLOC 3 — DROP les anciennes policies permissives (APRÈS vérif bloc 2).
--   Ne PAS exécuter avant d'avoir confirmé le bloc 2.
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "annotations_select_public" ON public.annotations;
DROP POLICY IF EXISTS "annotations_insert_authenticated" ON public.annotations;
DROP POLICY IF EXISTS "Can insert own annotations" ON public.annotations;


-- =====================================================================
-- ÉTAT ATTENDU APRÈS EXÉCUTION COMPLÈTE
--   pg_policies sur annotations : 4 policies
--     - annotations_select_admin        (SELECT)
--     - annotations_select_superviseur  (SELECT)
--     - annotations_select_point_focal  (SELECT)
--     - annotations_insert_acteurs      (INSERT)
--   Aucune lecture publique. Aucun INSERT sans auteur+périmètre.
--   Pas de policy UPDATE/DELETE (annotations append-only).
--   RLS actif sur la table (relrowsecurity = true).
-- =====================================================================
