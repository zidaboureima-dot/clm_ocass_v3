# Fiche du store — Google Play

**Dernière mise à jour :** 18 août 2026

Contenu prêt à copier-coller dans la Play Console (Présence sur le store →
Fiche Store principale). Ce qui ne peut pas être produit depuis cette session
(captures d'écran réelles, visuel graphique) est listé en fin de document
avec ce qu'il reste à fournir.

---

## 1. Nom de l'app

**CLM-OCASS Guinée**

## 2. Description courte (80 caractères max)

```
Signalez un dysfonctionnement de santé, en toute confidentialité, en Guinée.
```
*(76 caractères)*

## 3. Description complète (4000 caractères max)

```
CLM-OCASS Guinée permet à toute personne de signaler, en toute confidentialité, un dysfonctionnement observé dans un service de santé — rupture de médicaments, absence de personnel, mauvais accueil, ou tout autre problème affectant l'accès aux soins.

SIGNALER SANS CRAINDRE POUR SA VIE PRIVÉE
• Aucun compte n'est nécessaire pour signaler.
• Aucune identité n'est demandée : ni nom, ni numéro de téléphone.
• Aucune géolocalisation : les données de localisation (GPS) sont automatiquement retirées de toute photo jointe, avant même son enregistrement.
• Vous pouvez décrire le problème par écrit, joindre une photo, ou enregistrer un message vocal si vous préférez parler plutôt qu'écrire.

UN SUIVI RÉEL PAR LES RESPONSABLES COMPÉTENTS
Chaque signalement est transmis au responsable de la zone concernée (superviseur, point focal), qui peut le consulter, le traiter et suivre sa résolution. Les statistiques agrégées (nombre de signalements, répartition par statut) sont publiques, sans jamais exposer un signalement individuel.

UNE CONFIDENTIALITÉ VÉRIFIÉE, PAS SEULEMENT PROMISE
Les principes de confidentialité de CLM-OCASS ne sont pas de simples engagements : ils sont vérifiés techniquement, jusque dans le contenu réel des fichiers stockés. Les messages vocaux déposés seuls sont détruits dès leur transformation en signalement, une suppression que le système lui-même refuse de contourner.

UN CADRE LÉGAL NATIONAL
CLM-OCASS Guinée s'inscrit dans le cadre de la loi guinéenne L/2016/037/AN du 28 juillet 2016 relative à la cybersécurité et à la protection des données à caractère personnel.

CLM-OCASS est un dispositif de suivi dirigé par les communautés (« community-led monitoring ») : la valeur du système dépend de la participation de chacun. Un dysfonctionnement observé, signalé, c'est un service de santé qui peut s'améliorer.
```
*(1844 caractères)*

## 4. Catégorie

**Recommandée : Médical.**

Justification : l'app porte sur le suivi de dysfonctionnements dans des
services de santé, à destination du grand public comme des responsables du
secteur — c'est le positionnement le plus proche de la catégorie « Médical »
de Google Play. Alternative possible : « Réseaux sociaux » (angle
signalement communautaire), moins précise sur le domaine.

## 5. Coordonnées

- **Email de contact / support :** info@sapsapservices.com
- **Email dédié aux questions de données personnelles :** info@sapsapservices.com
  *(identique au contact support — cohérent avec `POLITIQUE_CONFIDENTIALITE.md`)*
- **Site web / politique de confidentialité :**
  https://sapsapservices.com/clm-ocass/confidentialite *(contenu revérifié
  conforme le 18 août 2026 — voir §7)*
- **Téléphone :** +224 61 42 67 911 *(confirmé le 18 août 2026 — la valeur
  +226 76 41 09 90 précédemment retenue dans cette fiche était erronée)*

## 6. Classification du contenu (questionnaire Play Console)

Ce questionnaire (IARC) se remplit directement dans la Play Console, pas ici
— mais à titre indicatif, rien dans l'app ne relève de contenu violent,
sexuel, de jeu d'argent ou de contenu généré par d'autres utilisateurs visible
publiquement (les signalements ne sont jamais publics individuellement,
seules des statistiques agrégées le sont). La classification attendue est la
plus basse (tout public).

---

## 7. Ce qu'il reste à fournir de ton côté

- ~~**Captures d'écran réelles**~~ *(FAIT — 18 août 2026)* : 5 captures
  téléphone prises sur appareil réel (ICL LX9, Android 12) depuis le build
  release signé, via `adb exec-out screencap`, puis recadrées en 1080×2160 et
  converties en JPEG (`sips`) pour respecter les deux contraintes Play
  vérifiées : ratio maximum 2:1 (l'écran natif 1080×2440 = 2,26:1 aurait été
  refusé) et absence de canal alpha. Elles se trouvent sur le poste local dans
  `~/captures-clm-ocass/play/` (originaux PNG non recadrés conservés dans le
  dossier parent) — non versionnées ici pour ne pas alourdir le dépôt.
  Écrans retenus : accueil, formulaire (localisation), formulaire (détails),
  récapitulatif avec la mention d'anonymat, statistiques publiques.
  *Point de vigilance appliqué :* la capture du récapitulatif a été refaite
  avec un cas d'exemple neutre (panne d'équipement) après qu'une première
  version montrait un signalement mettant en cause le personnel d'un centre
  de santé nommé — publier cela aurait été en tension avec l'engagement
  « aucun signalement n'est rendu public individuellement ».
  Tablettes 7"/10" : non fournies, facultatif tant que le format téléphone
  est couvert.
- **Visuel graphique (feature graphic)** *(FAIT)* : `store_feature_graphic_1024x500.png`,
  1024×500, généré à partir de l'icône livrée et des couleurs de marque déjà
  utilisées. À valider ou faire ajuster.
- ~~**URL publique de la politique de confidentialité**~~ *(FAIT — contenu
  corrigé et revérifié)* : https://sapsapservices.com/clm-ocass/confidentialite
  affichait initialement un contenu divergent du comportement réel de l'app
  (détecté le 18 août 2026 via les captures d'écran fournies — voir historique
  Git pour le détail). La page a été remplacée par le contenu vérifié et
  revérifiée section par section le 18 août 2026 : §2 ne mentionne plus de
  nom/téléphone pour la personne qui signale, §4 liste bien nom + téléphone
  pour les comptes responsables, §6 cite la loi L/2016/037/AN. Reste un détail
  cosmétique, non bloquant : dans l'encadré « Contact » en bas de page, la
  ligne à côté de l'icône téléphone affiche du texte au lieu du numéro
  +224 61 42 67 911 — à corriger quand l'occasion se présente, mais sans
  impact sur la conformité déclaré = réel.
- ~~**Téléphone** *(à vérifier)*~~ *(FAIT — confirmé le 18 août 2026, après
  correction)* : +224 61 42 67 911.

---

## 8. Points cosmétiques repérés, non bloquants

Relevés le 18 août 2026 en examinant les captures d'écran réelles. Aucun
n'empêche la soumission ; à traiter quand l'occasion se présente.

- **Nom affiché dans l'app : « CLM/OCASS Guinée » (barre oblique)** alors que
  le nom de l'app (`android:label`), le bundle iOS et cette fiche store
  utilisent le tiret : « CLM-OCASS Guinée ». Harmonisation à prévoir, de
  préférence côté app pour s'aligner sur le nom store.
- **Titre tronqué dans la barre d'app du formulaire** : « Signaler un
  dysfoncti… ». Comportement normal de l'AppBar, mais un libellé plus court
  (ex. « Nouveau signalement ») rendrait mieux à l'écran comme en capture.
