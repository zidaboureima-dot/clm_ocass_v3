-- =====================================================================
-- Migration : 20260814_workflow_statuts.sql
-- Objet     : Machine à états du statut des signalements (workflow rôle).
--
-- NATURE DE CE FICHIER
--   Fichier de REJEU / DOCUMENTATION. La fonction, le trigger et les
--   policies décrits ici ont été créés directement dans le SQL Editor
--   du dashboard Supabase (projet ouwuirvyzmdutwfkeeoy) et sont DÉJÀ
--   ACTIFS en production Guinée. Ce script capture l'état réel afin de
--   pouvoir le rejouer à l'identique sur un environnement neuf
--   (ex. futur locataire multi-pays) sans reconstruire de mémoire.
--   Il est idempotent : réexécutable sans casser l'existant.
--
-- MODÈLE DE WORKFLOW (rappel)
--   (1) nouveau   : signalement reçu, chez le superviseur de la région
--   (2) en_cours  : superviseur assigne à un point focal  (nouveau  -> en_cours)
--   (3) point focal documente le cas mais NE CHANGE PAS le statut
--   (4) traite    : superviseur marque traité             (en_cours -> traite)
--   (5) cloture   : SEUL l'admin clôture                  (traite   -> cloture)
--   (6) continuité (superviseur absent) : l'admin peut réassigner /
--       reprendre, avec documentation obligatoire.
--
-- FRONTIÈRE DE SÉCURITÉ
--   La validation des transitions est garantie CÔTÉ BASE par le trigger
--   ci-dessous (BEFORE UPDATE). L'UI Flutter ne fait que filtrer
--   l'affichage des boutons : même si un bouton fuyait, la base refuse
--   la transition illégale. L'UI est du confort, la base fait foi.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Fonction de validation des transitions de statut
--    SECURITY DEFINER : s'exécute avec les droits du propriétaire pour
--    pouvoir appeler role_du_demandeur() sans dépendre des droits de
--    l'appelant. search_path fixé à 'public' (bonne pratique sécurité :
--    évite le détournement de résolution de noms).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.valider_transition_statut()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  role_demandeur text := role_du_demandeur();
BEGIN
  -- Si le statut ne change pas, on laisse passer (l'UPDATE ne touche
  -- peut-être que assignee_uid, superviseur_uid, etc.). Les autres
  -- contrôles (périmètre) restent gérés par les policies RLS.
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN
    RETURN NEW;
  END IF;

  -- L'admin peut faire TOUTES les transitions (clôture, réouverture,
  -- continuité). Aucun blocage.
  IF role_demandeur = 'admin' THEN
    RETURN NEW;
  END IF;

  -- Le superviseur peut faire deux transitions seulement :
  --   nouveau  -> en_cours  (via l'assignation)
  --   en_cours -> traite    (marquer traité)
  IF role_demandeur = 'superviseur' THEN
    IF (OLD.statut = 'nouveau'  AND NEW.statut = 'en_cours')
    OR (OLD.statut = 'en_cours' AND NEW.statut = 'traite') THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Transition de statut non autorisée pour un superviseur : % -> %', OLD.statut, NEW.statut;
  END IF;

  -- Le point focal ne change JAMAIS le statut (il n'écrit que des annotations).
  IF role_demandeur = 'point_focal' THEN
    RAISE EXCEPTION 'Un point focal ne peut pas modifier le statut d''un signalement.';
  END IF;

  -- Tout autre rôle (ou rôle inconnu) : refus par défaut.
  RAISE EXCEPTION 'Changement de statut non autorisé pour ce rôle.';
END;
$function$;


-- ---------------------------------------------------------------------
-- 2. Trigger BEFORE UPDATE qui appelle la validation
--    DROP IF EXISTS d'abord pour rendre le rejeu idempotent, puis CREATE.
--    (Un trigger ne peut pas se CREATE OR REPLACE ; on DROP/CREATE.)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_valider_transition_statut ON public.signalements;

CREATE TRIGGER trg_valider_transition_statut
  BEFORE UPDATE ON public.signalements
  FOR EACH ROW
  EXECUTE FUNCTION valider_transition_statut();


-- ---------------------------------------------------------------------
-- 3. Policies UPDATE sur signalements
--    Principe de séquencement du projet : CREATE les nouvelles policies
--    AVANT de DROP l'ancienne, pour ne jamais ouvrir de fenêtre sans
--    contrôle d'accès. Sur un rejeu neuf, l'ancienne policy mixte
--    n'existe pas : le DROP en fin de script est protégé par IF EXISTS.
--
--    Le contrôle de PÉRIMÈTRE (qui peut toucher quelle ligne) est ici.
--    Le contrôle de TRANSITION (quel statut -> quel statut) est dans le
--    trigger ci-dessus. Les deux sont complémentaires.
-- ---------------------------------------------------------------------

-- 3.a Admin : peut modifier tous les signalements (périmètre national).
--     Le trigger l'autorise par ailleurs à toutes les transitions.
DROP POLICY IF EXISTS "Admin modifie tous signalements" ON public.signalements;
CREATE POLICY "Admin modifie tous signalements"
  ON public.signalements
  FOR UPDATE
  USING (role_du_demandeur() = 'admin'::text)
  WITH CHECK (role_du_demandeur() = 'admin'::text);

-- 3.b Superviseur : peut modifier les signalements de SA région uniquement.
--     Le trigger restreint par ailleurs ses transitions à
--     nouveau->en_cours et en_cours->traite.
DROP POLICY IF EXISTS "Superviseur modifie signalements de sa region" ON public.signalements;
CREATE POLICY "Superviseur modifie signalements de sa region"
  ON public.signalements
  FOR UPDATE
  USING (
    (role_du_demandeur() = 'superviseur'::text)
    AND (region = region_du_demandeur())
  )
  WITH CHECK (
    (role_du_demandeur() = 'superviseur'::text)
    AND (region = region_du_demandeur())
  );

-- 3.c Suppression de l'ancienne policy mixte (déjà retirée en base).
--     Elle mélangeait superviseur-région OU point_focal-assigné dans une
--     seule policy UPDATE et ne contrôlait PAS le statut, laissant le
--     point focal et le superviseur écrire 'cloture'. Remplacée par les
--     deux policies ci-dessus + le trigger. Le point focal n'a plus
--     AUCUNE policy UPDATE : il ne peut plus modifier la ligne
--     signalement (il n'écrit que dans annotations).
DROP POLICY IF EXISTS "Acteurs modifient signalements de leur périmètre" ON public.signalements;


-- =====================================================================
-- ÉTAT ATTENDU APRÈS EXÉCUTION
--   pg_policies sur signalements : 4 policies au total
--     - 2 SELECT (existantes, hors périmètre de cette migration)
--     - 2 UPDATE (admin, superviseur) créées ci-dessus
--   Le point focal n'a aucune policy UPDATE.
--   Trigger trg_valider_transition_statut actif (BEFORE UPDATE).
-- =====================================================================
