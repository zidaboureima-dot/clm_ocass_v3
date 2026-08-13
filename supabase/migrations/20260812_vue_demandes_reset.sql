-- Vue enrichie des demandes de réinitialisation en attente.
-- Jointure demandes_reset × users pour afficher, côté admin,
-- l'email, le nom, le rôle et la zone du compte concerné.
-- Lecture seule ; ne modifie aucune table.
-- Le filtre en_attente garantit que l'onglet ne voit jamais
-- les demandes déjà traitées (la ligne disparaît après traitement).

CREATE OR REPLACE VIEW demandes_reset_enrichies AS
SELECT
  d.id,
  d.email,
  d.statut,
  d.demande_le,
  u.nom,
  u.role,
  u.region,
  u.prefecture
FROM demandes_reset d
JOIN users u ON u.email = d.email
WHERE d.statut = 'en_attente';
