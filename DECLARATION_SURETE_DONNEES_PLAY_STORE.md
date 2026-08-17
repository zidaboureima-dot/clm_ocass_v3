# Déclaration de sûreté des données — Google Play (Data safety)

**Dernière mise à jour :** 17 août 2026

Ce document sert de brouillon prêt à recopier dans le formulaire « Data
safety » de la Play Console (Play Console → Contenu de l'app → Sûreté des
données). Il suit exactement la structure de ce formulaire (catégories,
sous-types, questions par type de donnée), pour que le remplissage soit un
copier-coller plutôt qu'une reformulation.

**Méthode.** Chaque ligne est déduite des dépendances réellement présentes
dans `pubspec.yaml` et du code vérifié (`AUDIT_EXIF_PHOTOS.md`,
`AUDIT_SUPPRESSION_AUDIOS.md`), pas d'une estimation. Aucun SDK d'analytics,
de publicité ou de crash-reporting tiers n'est présent dans le projet — c'est
la raison structurelle pour laquelle la quasi-totalité des cases restent à
« Non collecté ».

---

## 1. L'app collecte-t-elle ou partage-t-elle des données utilisateur ?

**Oui** — signalements (contenu), comptes des responsables.

## 2. Toutes les données collectées sont-elles chiffrées en transit ?

**Oui.** Le backend (Supabase) sert exclusivement en HTTPS/TLS ; aucun appel
en clair.

## 3. Proposez-vous un moyen de demander la suppression des données ?

**Partiellement — à formuler avec précision dans le formulaire :**
- Pour un **titulaire de compte** (administrateur, superviseur, point focal) :
  oui, sur demande auprès du responsable du traitement (contact dans la
  politique de confidentialité).
- Pour la **personne qui signale** (citoyen, anonyme) : aucune identité
  n'étant collectée, il n'existe pas de mécanisme technique pour relier une
  demande à un signalement précis déposé. Cette limite est assumée et
  documentée dans la politique de confidentialité (§7), pas cachée.

---

## 4. Détail par type de donnée

### Localisation — **Non collecté**
- Approximative : non
- Précise : non

Vérifié à deux niveaux : aucune permission de localisation dans le manifeste
Android, et les métadonnées EXIF/GPS des photos sont retirées automatiquement
avant l'enregistrement (`AUDIT_EXIF_PHOTOS.md`).

### Informations personnelles

| Sous-type | Collecté ? | Détail |
| --- | --- | --- |
| Nom | Non | — |
| Adresse email | **Oui** | Uniquement pour les comptes des responsables (admin, superviseur, point focal). Jamais pour la personne qui signale. |
| Identifiants utilisateur | **Oui** | Identifiant de compte (responsables uniquement), généré par le backend. |
| Adresse postale | Non | — |
| Numéro de téléphone | Non | — |
| Origine ethnique, opinions religieuses/politiques, orientation sexuelle | Non | — |
| Autres informations | Non | — |

- **Facultatif ou obligatoire :** obligatoire pour créer un compte de
  responsable (pas de compte sans email) ; sans objet pour la personne qui
  signale (aucun compte requis).
- **Finalité (collecte) :** fonctionnement de l'app, gestion du compte,
  communications du développeur (notifications de création de compte, de
  réinitialisation de mot de passe, d'étape de traitement).
- **Partagé avec un tiers ?** Non. L'envoi des emails transactionnels passe
  par un prestataire technique (service d'emailing) agissant uniquement pour
  le compte de l'app — ce type de sous-traitance n'est pas considéré comme un
  « partage » au sens du formulaire Play tant que le prestataire ne traite les
  données que sur instruction et pour le fonctionnement de l'app.

### Informations financières — **Non collecté**

Aucun paiement, aucun historique d'achat dans l'app.

### Santé et bien-être — **Non collecté**

*Point de vigilance :* le contenu d'un signalement peut, selon les cas,
décrire une situation à caractère sanitaire (ex. rupture de médicaments dans
un centre de santé). Il s'agit d'un signalement sur le **fonctionnement d'un
service**, pas d'une donnée de santé individuelle sur la personne qui
signale — aucun champ du formulaire ne demande d'information médicale
personnelle. À confirmer néanmoins avec le contenu réel des catégories de
signalement avant soumission finale.

### Messages — **Non collecté**

Pas de messagerie entre utilisateurs. Les emails envoyés sont des
notifications système (couvertes ci-dessus, « Informations personnelles »),
pas une fonctionnalité de messagerie.

### Photos et vidéos

| Sous-type | Collecté ? |
| --- | --- |
| Photos | **Oui** |
| Vidéos | Non |

- **Détail :** photo-preuve jointe à un signalement, ou déposée seule
  (« photo brute »). Métadonnées EXIF/GPS retirées automatiquement avant
  stockage (`AUDIT_EXIF_PHOTOS.md`).
- **Facultatif ou obligatoire :** facultatif (la personne peut signaler sans
  joindre de photo).
- **Finalité :** fonctionnement de l'app (constitution du dossier de
  signalement).
- **Partagé avec un tiers ?** Non.

### Fichiers audio

| Sous-type | Collecté ? |
| --- | --- |
| Voix / enregistrements sonores | **Oui** |
| Fichiers musicaux | Non |
| Autres fichiers audio | Non |

- **Détail :** message vocal joint à un signalement (conservé tant que le
  signalement existe) ou déposé seul (détruit immédiatement après
  transformation en signalement structuré, suppression vérifiée au niveau du
  stockage — `AUDIT_SUPPRESSION_AUDIOS.md`).
- **Facultatif ou obligatoire :** facultatif.
- **Finalité :** fonctionnement de l'app.
- **Partagé avec un tiers ?** Non. Traitement centralisé, jamais d'écoute au
  niveau local.

### Fichiers et documents — **Non collecté**

### Agenda — **Non collecté**

### Contacts — **Non collecté**

### Activité dans l'app

| Sous-type | Collecté ? |
| --- | --- |
| Interactions dans l'app | Non |
| Historique de recherche dans l'app | Non |
| Applications installées | Non |
| **Autre contenu généré par l'utilisateur** | **Oui** |
| Autres actions | Non |

- **Détail :** le texte structuré du signalement (zone géographique réelle —
  région/préfecture —, catégorie de dysfonctionnement, niveau de gravité,
  description libre). C'est le cœur du contenu déposé par la personne qui
  signale.
- **Facultatif ou obligatoire :** obligatoire pour déposer un signalement
  structuré (les champs zone/catégorie/description sont le signalement
  lui-même).
- **Finalité :** fonctionnement de l'app.
- **Partagé avec un tiers ?** Non.

### Navigation web — **Non collecté**

### Infos et performances de l'app — **Non collecté**

Aucun SDK de crash-reporting ou de diagnostic tiers dans le projet (vérifié
dans `pubspec.yaml`).

### Identifiants d'appareil ou autres — **Non collecté**

Aucun SDK de publicité ou d'identifiant publicitaire dans le projet (vérifié
dans `pubspec.yaml`).

---

## 5. Pratiques de sécurité (questions complémentaires du formulaire)

- **Chiffrement en transit :** oui, pour toutes les données collectées.
- **Suppression des données sur demande :** oui pour les comptes de
  responsables ; sans objet pour les signalements anonymes (voir §3).
- **Conformité à la politique Familles de Google Play :** l'app ne cible pas
  spécifiquement les enfants — audience générale.
- **Revue de sécurité indépendante :** non réalisée à ce jour.

---

## 6. Cohérence à vérifier avant soumission

Le principe directeur du projet (déclaré = réel) s'applique intégralement
ici : toute divergence entre cette déclaration et le comportement réel de
l'app est un motif de rejet, puis de suspension. Avant de soumettre ce
formulaire dans la Play Console :

- Relire cette page en parallèle de `POLITIQUE_CONFIDENTIALITE.md` — les deux
  documents doivent raconter exactement la même histoire.
- Si une fonctionnalité change (ajout d'un SDK d'analytics, d'une
  notification push, d'un paiement…), cette déclaration doit être mise à jour
  **avant** la publication de la nouvelle version, pas après.
