-- =====================================================================
-- Migration : 20260816_durcir_insert_bruts.sql
-- Objet     : Durcir les policies INSERT publiques des deux canaux de
--             dépôt brut anonyme (photos_brutes, messages_vocaux_bruts).
--
-- CONTEXTE (faille corrigée)
--   Le dépôt d'une photo ou d'un vocal brut est un acte CITOYEN ANONYME
--   (pas de compte), donc l'INSERT public est légitime dans le principe.
--   MAIS les policies existantes utilisaient with_check = true, c.-à-d.
--   AUCUNE contrainte sur les valeurs insérées. Comme la clé anon est
--   publique dans une app distribuée, un appelant malveillant pouvait
--   insérer une ligne avec un statut arbitraire (ex. 'traite') et un
--   signalement_id pointant vers n'importe quel signalement, contournant
--   le tri admin (qui est la seule voie normale pour lier un brut à un
--   signalement, via la policy UPDATE admin).
--
-- CIBLE
--   Un dépôt anonyme ne peut insérer QUE :
--     - statut = 'nouveau'        (un brut neuf, non trié)
--     - signalement_id IS NULL    (non lié : la liaison est un acte admin)
--   L'app fait déjà exactement cela (photo_brute_service / message_vocal_
--   service insèrent statut='nouveau' sans signalement_id). Le durcissement
--   ne casse donc pas le flux légitime ; il bloque l'injection de lignes
--   malformées. Principe projet : ne jamais faire confiance au client sur
--   les champs sensibles.
--
--   La lecture (SELECT admin) et la modification (UPDATE admin) restent
--   inchangées : elles sont déjà correctement restreintes à l'admin.
--
-- NOTE : le rate-limit de ces deux canaux de dépôt anonyme n'est PAS
--   traité ici (pas de limitation de débit sur l'INSERT direct). À traiter
--   dans un chantier dédié, idéalement en passant par une RPC SECURITY
--   DEFINER (comme soumettre_signalement_anonyme) couvrant les deux canaux.
--
-- SÉQUENCEMENT (règle projet : CREATE avant DROP)
--   Les INSERT d'un même cmd sont en OR : tant que l'ancienne policy
--   permissive existe, elle l'emporte. On crée donc la policy restrictive
--   sous un NOUVEAU nom, on vérifie, PUIS on supprime l'ancienne. On ne
--   laisse jamais la table sans policy INSERT (sinon dépôts citoyens
--   bloqués). Ce fichier documente l'état cible ; exécuter par blocs.
-- =====================================================================


-- ---------------------------------------------------------------------
-- BLOC 1 — CREATE les nouvelles policies INSERT restrictives.
-- ---------------------------------------------------------------------

-- 1.a photos_brutes
DROP POLICY IF EXISTS "photos_brutes_insert_anonyme" ON public.photos_brutes;
CREATE POLICY "photos_brutes_insert_anonyme"
  ON public.photos_brutes
  FOR INSERT
  WITH CHECK (
    statut = 'nouveau'
    AND signalement_id IS NULL
  );

-- 1.b messages_vocaux_bruts
DROP POLICY IF EXISTS "messages_vocaux_bruts_insert_anonyme" ON public.messages_vocaux_bruts;
CREATE POLICY "messages_vocaux_bruts_insert_anonyme"
  ON public.messages_vocaux_bruts
  FOR INSERT
  WITH CHECK (
    statut = 'nouveau'
    AND signalement_id IS NULL
  );


-- ---------------------------------------------------------------------
-- BLOC 2 — Vérification (exécuter et lire AVANT le bloc 3).
--   Attendu par table : la nouvelle policy _insert_anonyme présente,
--   à côté de l'ancienne _insert_public (coexistence temporaire voulue).
-- ---------------------------------------------------------------------
-- SELECT tablename, policyname, cmd, with_check FROM pg_policies
-- WHERE tablename IN ('photos_brutes','messages_vocaux_bruts') AND cmd = 'INSERT'
-- ORDER BY tablename, policyname;


-- ---------------------------------------------------------------------
-- BLOC 3 — DROP les anciennes policies permissives (APRÈS vérif bloc 2).
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "photos_brutes_insert_public" ON public.photos_brutes;
DROP POLICY IF EXISTS "messages_vocaux_bruts_insert_public" ON public.messages_vocaux_bruts;


-- =====================================================================
-- ÉTAT ATTENDU APRÈS EXÉCUTION COMPLÈTE (par table)
--   photos_brutes / messages_vocaux_bruts : 3 policies chacune
--     - *_insert_anonyme  (INSERT, with_check: statut='nouveau' AND signalement_id IS NULL)
--     - Admin sees all *  (SELECT, role admin)
--     - Admin updates *   (UPDATE, role admin)
--   Plus aucune policy INSERT permissive (with_check: true).
--   Un dépôt anonyme ne peut insérer qu'un brut neuf non lié.
-- =====================================================================
