-- Restriction des tables médias à l'admin uniquement.
-- Les superviseurs et points focaux ne consultent JAMAIS les médias :
-- ils travaillent sur le signalement structuré préparé par l'admin.
--
-- Faille corrigée : des policies *_select_authenticated / *_update_authenticated
-- ouvraient audios, photos et files brutes à tout utilisateur connecté. Comme
-- les policies SELECT se combinent en OR, ces policies larges annulaient la
-- restriction admin (même schéma que la faille authenticated_read_users).
--
-- Séquencement appliqué : CREATE des policies admin manquantes d'abord,
-- puis DROP des policies larges. Jamais l'inverse, pour ne pas couper
-- l'accès admin entre les deux étapes.

-- ÉTAPE 1 : policies admin (audios avait déjà "Admin sees all audios")
CREATE POLICY "Admin sees all messages vocaux bruts"
  ON messages_vocaux_bruts FOR SELECT USING (role_du_demandeur() = 'admin');
CREATE POLICY "Admin updates messages vocaux bruts"
  ON messages_vocaux_bruts FOR UPDATE USING (role_du_demandeur() = 'admin');
CREATE POLICY "Admin sees all photos"
  ON photos FOR SELECT USING (role_du_demandeur() = 'admin');
CREATE POLICY "Admin sees all photos brutes"
  ON photos_brutes FOR SELECT USING (role_du_demandeur() = 'admin');
CREATE POLICY "Admin updates photos brutes"
  ON photos_brutes FOR UPDATE USING (role_du_demandeur() = 'admin');

-- ÉTAPE 2 : suppression des policies larges _authenticated
DROP POLICY "audios_select_authenticated" ON audios;
DROP POLICY "messages_vocaux_bruts_select_authenticated" ON messages_vocaux_bruts;
DROP POLICY "messages_vocaux_bruts_update_authenticated" ON messages_vocaux_bruts;
DROP POLICY "photos_select_authenticated" ON photos;
DROP POLICY "photos_brutes_select_authenticated" ON photos_brutes;
DROP POLICY "photos_brutes_update_authenticated" ON photos_brutes;
