-- =====================================================================
-- Migration : 20260816_index_bridge_rate_limit.sql
-- Objet     : Index de performance sur la table de rate-limit de la
--             passerelle du site vitrine (Edge Function super-worker).
--
-- CONTEXTE
--   La fonction super-worker applique un rate-limit par IP sur les dépôts
--   anonymes du formulaire vitrine (max 8 soumissions / fenêtre glissante
--   de 5 min). À chaque soumission, verifierDebit() exécute :
--       SELECT count(*) FROM bridge_rate_limit
--       WHERE ip = $1 AND created_at >= now() - interval '5 minutes'
--   Avant cette migration, le seul index existant était la clé primaire
--   (bridge_rate_limit_pkey sur id). Le filtre (ip, created_at) n'était
--   donc PAS indexé : PostgreSQL faisait un scan séquentiel de toute la
--   table à chaque appel. Comme la table grossit à chaque dépôt, ce scan
--   ralentissait avec le volume — au point d'affaiblir la protection
--   anti-inondation qu'il est censé servir.
--
--   Une purge opportuniste (lignes > 1 h) a été ajoutée côté fonction
--   super-worker pour borner la taille de la table. Cet index complète
--   la mesure côté base.
--
-- IDEMPOTENT : CREATE INDEX IF NOT EXISTS, rejouable sans erreur.
-- =====================================================================

-- Index composite couvrant exactement le filtre de verifierDebit.
-- L'ordre des colonnes (ip d'abord, created_at ensuite) correspond à
-- l'égalité sur ip suivie de la borne temporelle sur created_at.
CREATE INDEX IF NOT EXISTS idx_bridge_rate_limit_ip_created_at
  ON public.bridge_rate_limit (ip, created_at);


-- =====================================================================
-- ÉTAT ATTENDU APRÈS EXÉCUTION
--   pg_indexes sur bridge_rate_limit : 2 index
--     - bridge_rate_limit_pkey               (clé primaire sur id)
--     - idx_bridge_rate_limit_ip_created_at  (créé ci-dessus)
--   verifierDebit() utilise désormais un index scan au lieu d'un seq scan.
-- =====================================================================
