# CLM-OCASS — Cadrage consolidé : de l'application Guinée au SaaS multi-tenant

**Nature du document.** Base de travail unique consolidant l'état d'avancement,
le chantier restant, et les directives d'architecture pour le passage au
service universel multi-pays. Il fusionne le suivi de sécurisation, l'inventaire
des dettes SaaS (`DETTES_SAAS.md`) et les audits de confidentialité
(`AUDIT_SUPPRESSION_AUDIOS.md`, `AUDIT_EXIF_PHOTOS.md`).

**Convention.** *Fait* = livré et vérifié en production Guinée. *À faire* =
planifié, non livré. *Directive* = règle d'architecture à respecter pour le SaaS.

**Dernière mise à jour :** 16 août 2026.

---

## 1. Séquence stratégique (rappel)

Le déploiement est séquencé, chaque étape conditionnant la suivante :

1. **Phase i — Sécurisation** *(TERMINÉE)* : fermeture des vulnérabilités,
   prérequis de tout le reste.
2. **Phase ii — Publication mobile** *(À ENGAGER)* : mise sur le magasin
   d'applications.
3. **Phase iii — SaaS universel** *(CIBLE)* : architecture multi-tenant,
   configuration par pays, intégration DHIS2.

On ne publie pas avant d'avoir sécurisé ; on n'industrialise pas en SaaS avant
d'avoir publié et éprouvé le modèle sur la vitrine guinéenne.

---

## 2. État d'avancement — Phase i (sécurisation) : TERMINÉE

Vulnérabilités et points fermés, vérifiés et versionnés :

- **Workflow des statuts** : machine à états au niveau base (trigger
  `trg_valider_transition_statut`) + policies UPDATE scopées + UI filtrée par
  rôle. Testé sur les 3 rôles. *(migrations `20260814`)*
- **Table `annotations`** : lecture publique fermée, INSERT scopé aux acteurs
  du cas + admin. *(migration `20260815`)*
- **Passerelle vitrine (`super-worker`)** : fuite de la clé de passerelle dans
  les logs fermée, rate-limit avec purge opportuniste, index `(ip, created_at)`
  sur `bridge_rate_limit`. *(migration `20260816_index`)*
- **Canaux de dépôt brut** (`photos_brutes`, `messages_vocaux_bruts`) : INSERT
  anonyme durci (`statut='nouveau'` + `signalement_id IS NULL`), blocage de
  l'injection. *(migration `20260816_durcir`)*
- **Suppression des audios bruts** : vérifiée effective au niveau du stockage
  (`marquerTraite` refuse de marquer traité si la suppression échoue) et
  documentée. *(`AUDIT_SUPPRESSION_AUDIOS.md`)*
- **Retrait EXIF/GPS des photos** : faille de géolocalisation découverte puis
  fermée (`ImageSanitizer`, vidage explicite de l'EXIF + fail-safe strict),
  appliquée aux deux canaux, vérifiée avant/après. *(`AUDIT_EXIF_PHOTOS.md`)*
- **Cohérence des comptes** `auth.users` / `public.users` : vérifiée alignée
  (rollback de `quick-endpoint` en cas d'échec d'insertion).
- **Edge Functions email** : revues (auth admin, aucun secret loggé,
  `doit_changer_mdp` sur création et reset), et versionnées dans le repo.

**Mécanismes de sécurité en place (à répliquer par tenant au SaaS) :**
- `role_du_demandeur()` / `region_du_demandeur()` (SECURITY DEFINER) comme
  source de vérité du rôle et du périmètre, jamais le JWT brut.
- Rate-limit des dépôts anonymes (app : `rate_limit_depots` ; vitrine :
  `bridge_rate_limit`).
- Suppression vérifiée des médias bruts après traitement.
- `doit_changer_mdp` sur création et réinitialisation de compte.
- Absence de permission de localisation dans le manifeste Android + strip EXIF :
  chaîne de non-géolocalisation complète et vérifiée.

---

## 3. Chantier restant — Phase ii (publication mobile) : À ENGAGER

Nature différente de la phase i : moins de code, plus de préparation
documentaire et administrative. La cohérence déclaré/réel est la contrainte
majeure — une divergence est un motif de rejet, puis de suspension.

### 3.1 Documents à produire
- **Politique de confidentialité** (page publique) : données traitées, finalité,
  durée de conservation, absence de données personnelles et de géolocalisation.
  À rédiger sur la base du comportement réel désormais vérifié (pas d'EXIF, pas
  de permission de localisation, suppression des vocaux bruts).
- **Déclaration de sûreté des données** (Data Safety Play Store) : déclarer la
  collecte de contenu de signalement (photo, audio, texte), et l'ABSENCE de
  collecte d'identité et de localisation.
- **Justification des permissions sensibles** :
  - Micro (`RECORD_AUDIO`) : dépôt de signalement vocal.
  - Caméra (`CAMERA`) : photo-preuve, métadonnées de localisation retirées
    automatiquement.
  Aucune autre permission n'est demandée (manifeste minimal vérifié).

### 3.2 Actions techniques préalables
- **Renommer `android:label`** : actuellement `clm_ocass_v3` (nom technique).
  Remplacer par un nom présentable (ex. « CLM-OCASS Guinée ») avant soumission.
- **Fiche du store** : descriptif, captures d'écran, catégorie, coordonnées de
  support et de responsable des données.
- **Tests fermés** : campagne à accès restreint avant ouverture au public.

### 3.3 Point de vigilance transverse
La déclaration de sûreté et la politique de confidentialité doivent dire
EXACTEMENT ce que fait l'app. Tout le travail de sécurisation de la phase i rend
cette exactitude possible : on sait désormais précisément ce que l'app fait.

---

## 4. Directives d'architecture — Phase iii (SaaS multi-tenant) : CIBLE

Objectif : un service unique, mutualisé, que l'on **paramètre par pays** plutôt
que de le redévelopper. La Guinée devient le premier locataire et sert de
gabarit. Trois chantiers techniques, plus des directives transverses.

### Principe directeur du passage au SaaS
Ne PAS coder d'abstraction multi-tenant de façon anticipée et partielle : tant
que la couche de configuration par pays n'existe pas, une demi-abstraction crée
une dette pire (à défaire) que la valeur en dur localisée. La bonne préparation
consiste à rendre chaque point d'externalisation **explicite, localisé et
inventorié** (marqueurs `// TODO SaaS`, ce document), pas à l'implémenter à
moitié.

### 4.1 Directive — Architecture multi-locataire (cloisonnement)
- Ajouter une dimension tenant (`pays_code` / `tenant_id`, ISO 3166-1 alpha-3
  aligné Fonds mondial/DHIS2 : GIN, BFA, TGO, TCD, COG) sur les tables de
  données et de médias.
- Réécrire les policies « admin » sur contenu et médias en « admin **de ce
  tenant** ».
- **Garantir le cloisonnement au niveau BASE (RLS), pas seulement applicatif** :
  une faille applicative ne doit jamais suffire à traverser la frontière entre
  pays. Aucun pays ne doit lire les signalements d'un autre.

### 4.2 Directive — Rôle super-admin et frontière de souveraineté
- Introduire un rôle super-admin (au-dessus des admins pays) : crée les tenants
  et les admins pays, gère abonnements et structure.
- **Frontière absolue** : le super-admin ne doit JAMAIS accéder au contenu d'un
  pays (signalements, audios, photos, médias bruts). Exclusion **enforced au
  niveau RLS**, pas par simple convention d'interface. Argument de souveraineté
  central du dispositif.

### 4.3 Directive — Couche de configuration par pays
Externaliser hors du code, par tenant :
- hiérarchie géographique (régions, préfectures, districts), idéalement ingérée
  depuis le DHIS2 national pour éviter la ressaisie ;
- catalogue de catégories de dysfonctionnements ;
- langue de l'interface ;
- mentions légales calées sur la loi nationale applicable (modèle Guinée : loi
  L/2016/037/AN du 28 juillet 2016). Citer la loi nationale, jamais un standard
  importé.

### 4.4 Directive — Emailing par tenant
- **FROM_EMAIL** : ne doit jamais rester codé en dur. À lire depuis la config du
  tenant. Points marqués `// TODO SaaS` dans `clever-service`, `quick-endpoint`,
  `rapid-action` ; `quick-task` à marquer lors de sa prochaine revue.
- **Vérification de domaine Resend par pays** (SPF/DKIM DNS) : étape
  OBLIGATOIRE et documentée de l'onboarding pays. La propagation DNS est une
  dépendance bloquante, pas un détail (découvert via un HTTP 403 « domain not
  verified »).

### 4.5 Directive — Intégration DHIS2 (restitution des agrégats)
- S'appuyer sur l'API Web DHIS2 : ingestion des `organisationUnits`, mapping
  configurable des `dataElements`, envoi périodique des `dataValueSets`,
  authentification par compte de service à droits limités, file de rejeu
  tolérante aux coupures.
- **Frontière stricte** : seuls des **agrégats anonymes** circulent vers le
  DHIS2 national ; jamais la donnée brute (signalements nominatifs — qui
  n'existent pas —, audios, photos). Restituer la donnée brute recréerait le
  risque que le dispositif écarte.
- Le mapping est une **configuration versionnée par pays et par programme**,
  validée par pilote avec le programme national, jamais codée en dur.

### 4.6 Directives — Durcissements et gouvernance à finir
- **Rate-limit des dépôts bruts** : passer `photos_brutes` et
  `messages_vocaux_bruts` par une RPC SECURITY DEFINER (modèle
  `soumettre_signalement_anonyme`) contrôlant les champs ET appliquant un
  rate-limit, puis révoquer l'INSERT direct. Traiter les deux canaux ensemble.
- **Conservation des audios joints après clôture** : définir une durée de
  conservation / purge des audios joints (conservés tant que le signalement
  existe) une fois le signalement clôturé, pour minimiser la rétention de
  données vocales identifiantes. Décision de gouvernance, à aligner sur la loi
  nationale.
- **Contrôle d'intégrité récurrent des suppressions média** : en multi-tenant,
  l'audit manuel n'est plus praticable. Mettre en place une détection
  automatique des résidus (média `traite` avec `chemin_stockage` non nul ;
  fichier de stockage sans ligne correspondante).

### 4.7 Directive — Non-régression photo (déjà acquise, à préserver)
Tout nouveau point d'upload de photo DOIT passer par `ImageSanitizer.nettoyer`
avant `storage.upload`. Ne jamais uploader un fichier image brut : cela
réintroduirait la fuite EXIF/GPS fermée en phase i.

---

## 5. Modèle économique (rappel de cadrage)

Deux leviers, à activer une fois le service stable, sécurisé et conforme :
- **Paramétrage initial par pays** (prestation ponctuelle) : ingestion de la
  hiérarchie, adaptation du catalogue, création des rôles, calage des mentions
  légales, cadrage du mapping DHIS2. Coût allégé par le gabarit guinéen.
- **Abonnement annuel** (récurrent) : paliers sur critères objectifs (étendue de
  couverture, volume d'usage, option DHIS2, niveau de service). Pas de grille
  tarifaire figée avant validation avec les premiers clients réels.

Un abonnement institutionnel n'est solvable que sur une base sécurisée et
conforme : la séquence (sécuriser → publier → industrialiser) n'est pas
négociable.

---

## 6. Périmètre de déploiement (honnêteté du cadrage)

- **Guinée** : vitrine réelle, application en production, environnement de test
  du service universel.
- **Burkina Faso, République du Congo, Togo** : déploiements envisagés
  (projection), non engagés.

Seule la Guinée est décrite au présent. Les autres pays illustrent le potentiel
de réplication sans laisser entendre des déploiements qui n'existent pas.

---

## 7. Prochaines étapes immédiates

1. **Phase ii** : rédiger la politique de confidentialité, la déclaration de
   sûreté des données et les justifications de permissions (base désormais
   honnête) ; renommer `android:label` ; préparer la fiche et les tests fermés.
2. **En parallèle** : le cadrage du mapping DHIS2 d'un premier programme
   national peut démarrer indépendamment (il n'attend pas le multi-tenant).
3. **Puis phase iii** : engager le chantier multi-tenant en suivant les
   directives de la section 4, dans l'ordre cloisonnement → configuration →
   intégration DHIS2 validée par pilote.
