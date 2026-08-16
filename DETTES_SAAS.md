# Dettes SaaS multi-tenant — inventaire

**Objet.** Ce fichier recense les points de l'application actuelle (Guinée
mono-pays) qui devront être traités lors du chantier d'industrialisation
multi-tenant (SaaS universel). L'objectif n'est pas de les corriger de façon
anticipée et partielle — ce qui créerait une fausse abstraction à défaire — mais
de les rendre **explicites, localisés et impossibles à oublier** le jour où la
couche de configuration par pays existera.

**Principe directeur.** Tant que la couche de configuration par pays (table
`tenants` / `pays_config`, colonnes `pays_code` sur les tables, résolution du
tenant) n'existe pas, on garde les valeurs en dur — mais **toujours localisées
en un seul point par fonction**, marquées d'un `// TODO SaaS`, et référencées
ici.

**Date de dernière mise à jour :** 16 août 2026

---

## 1. FROM_EMAIL codé en dur dans les fonctions d'email

**Dette.** L'expéditeur des courriels transactionnels est en dur :
`'CLM/OCASS Guinée <notifications@clm-ocass-guinee.org>'`. En multi-tenant,
chaque pays a son propre domaine vérifié et son propre expéditeur ; la valeur
doit être lue depuis la config du tenant concerné.

**Localisation** (4 Edge Functions d'email, toutes marquées `// TODO SaaS`) :
- `supabase/functions/clever-service/index.ts` (notifications)
- `supabase/functions/quick-endpoint/index.ts` (création de compte)
- `supabase/functions/rapid-action/index.ts` (process reset)
- `quick-task` (reset request) — à marquer lors de sa prochaine revue.

**Cible.** Lire `FROM_EMAIL` depuis la config par pays, résolue à partir du
tenant du destinataire / du signalement concerné.

---

## 2. Vérification de domaine Resend par pays

**Dette.** L'envoi d'email repose sur un domaine vérifié côté Resend
(SPF/DKIM). Aujourd'hui un seul domaine (`clm-ocass-guinee.org`). Chaque
nouveau pays devra faire vérifier son propre domaine AVANT de pouvoir envoyer.

**Cible.** Faire de la vérification de domaine Resend (SPF/DKIM DNS) une étape
**obligatoire et documentée** de l'onboarding pays. Découvert en production via
un HTTP 403 « domain not verified ». La propagation DNS est une dépendance
bloquante, à traiter comme prérequis, pas comme un détail.

---

## 3. Cloisonnement multi-tenant des données (RLS par tenant)

**Dette.** Les policies RLS actuelles isolent par rôle et par région, mais pas
par pays (il n'y a qu'un pays). En multi-tenant, aucune donnée d'un pays ne doit
être visible depuis un autre.

**Cible.**
- Ajouter une dimension tenant (`pays_code` / `tenant_id`) sur les tables de
  données et de médias.
- Réécrire les policies « admin » sur les tables de contenu et de médias en
  « admin **de ce tenant** », et **exclure explicitement le super-admin** de
  l'accès au contenu des pays.
- Garantir le cloisonnement au niveau **base** (RLS), pas seulement applicatif :
  une faille applicative ne doit jamais suffire à traverser la frontière entre
  pays.

---

## 4. Rôle super-admin (au-dessus des admins pays)

**Dette.** Pas encore de rôle super-admin. En multi-tenant, il crée les tenants
et les admins pays, gère les abonnements et la structure.

**Cible — frontière de souveraineté à tenir.** Le super-admin ne doit **JAMAIS**
accéder au contenu d'un pays (signalements, audios, photos, médias bruts). Cette
exclusion doit être **enforced au niveau RLS**, pas seulement par convention
d'interface. C'est un argument de souveraineté central du dispositif.

---

## 5. Couche de configuration par pays (géographie, catégories, langue, loi)

**Dette.** La hiérarchie géographique (régions, préfectures, districts), le
catalogue de catégories, la langue et les mentions légales sont propres à la
Guinée et non externalisés.

**Cible.** Externaliser hors du code, par tenant :
- hiérarchie géographique (idéalement ingérée depuis le DHIS2 national) ;
- catalogue de catégories de dysfonctionnements ;
- langue de l'interface ;
- mentions légales calées sur la loi nationale applicable (Guinée : loi
  L/2016/037/AN du 28 juillet 2016).
- **Codes pays** : ISO 3166-1 alpha-3 alignés sur les conventions Fonds
  mondial / DHIS2 (GIN, BFA, TGO, TCD, COG).

---

## 6. Rate-limit des dépôts bruts anonymes (durcissement à finir)

**Dette (sécurité, notée lors du durcissement des INSERT bruts).** Les canaux de
dépôt brut anonyme (`photos_brutes`, `messages_vocaux_bruts`) ont vu leur INSERT
durci (contrainte `statut='nouveau'` + `signalement_id IS NULL`), mais **n'ont
pas de limitation de débit** sur l'INSERT direct depuis l'app. Vecteur
d'inondation possible.

**Cible.** Passer les deux canaux par une RPC `SECURITY DEFINER` (sur le modèle
de `soumettre_signalement_anonyme`) qui contrôle les champs ET applique un
rate-limit, puis révoquer l'INSERT direct. À traiter pour les deux canaux
ensemble. Pertinent aussi hors SaaS, mais regroupé ici comme durcissement.

---

## 7. Conservation des audios joints après clôture (gouvernance)

**Dette (gouvernance des données).** Les audios **joints à un signalement**
(type 1, conservés à dessein tant que le signalement existe) n'ont pas de durée
de conservation définie après **clôture** du signalement.

**Cible.** Définir une politique de conservation / purge des audios joints après
clôture, pour minimiser la rétention de données vocales identifiantes, en
alignement avec la loi nationale de protection des données applicable. Décision
de gouvernance à valider avec le porteur du projet, pas un simple choix
technique. Voir aussi `AUDIT_SUPPRESSION_AUDIOS.md`.

---

## 8. Contrôle d'intégrité récurrent des suppressions média

**Dette (robustesse, notée lors de l'audit de suppression des audios).** En
mono-pays, l'audit manuel de l'effectivité des suppressions média suffit. En
multi-tenant, l'audit à la main de chaque pays n'est plus praticable.

**Cible.** Mettre en place un contrôle d'intégrité récurrent détectant :
- un message/photo `statut = 'traite'` avec `chemin_stockage` non `null`
  (suppression stockage non effectuée) ;
- un fichier de stockage sans ligne correspondante en base (orphelin).

---

## Rappel des mécanismes déjà en place (à répliquer par tenant)

Ces éléments sont déjà sécurisés en mono-pays et devront être **répliqués /
paramétrés par tenant** au moment du multi-tenant, sans régression :
- workflow des statuts (trigger `trg_valider_transition_statut` + policies) ;
- policies média scopées (audios, photos, annotations, bruts) ;
- rate-limit de la passerelle vitrine (`bridge_rate_limit` + index) ;
- suppression vérifiée des vocaux bruts (`marquerTraite`) ;
- `doit_changer_mdp` sur création et reset de compte.
