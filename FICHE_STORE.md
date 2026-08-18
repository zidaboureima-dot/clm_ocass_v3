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
  https://sapsapservices.com/clm-ocass/confidentialite — ⚠️ *voir §7 : le
  contenu actuellement en ligne à cette adresse ne correspond pas au document
  vérifié et ne doit pas être soumis tel quel.*
- **Téléphone :** +226 76 41 09 90 *(confirmé côté fiche store — à
  réconcilier avec le +224 61 42 67 911 affiché sur la page hébergée, voir §7)*

## 6. Classification du contenu (questionnaire Play Console)

Ce questionnaire (IARC) se remplit directement dans la Play Console, pas ici
— mais à titre indicatif, rien dans l'app ne relève de contenu violent,
sexuel, de jeu d'argent ou de contenu généré par d'autres utilisateurs visible
publiquement (les signalements ne sont jamais publics individuellement,
seules des statistiques agrégées le sont). La classification attendue est la
plus basse (tout public).

---

## 7. Ce qu'il reste à fournir de ton côté

- **Captures d'écran réelles** : minimum 2 par format (téléphone au minimum,
  idéalement aussi tablette 7" et 10" si l'app les supporte). À prendre
  depuis un appareil ou un émulateur, une fois l'app compilée en local — cette
  session cloud n'a pas d'émulateur Android/iOS disponible pour les produire.
- **Visuel graphique (feature graphic)** *(FAIT)* : `store_feature_graphic_1024x500.png`,
  1024×500, généré à partir de l'icône livrée et des couleurs de marque déjà
  utilisées. À valider ou faire ajuster.
- **URL publique de la politique de confidentialité** *(BLOQUANT — contenu
  non conforme constaté)* : https://sapsapservices.com/clm-ocass/confidentialite
  est bien hébergée, mais d'après les captures d'écran fournies le 18 août
  2026, la page qui y est réellement affichée n'est **pas**
  `politique-confidentialite.html` (celle produite et vérifiée dans cette
  session) — c'est un document différent, dont au moins une affirmation
  contredit le code vérifié de l'app : il indique que le formulaire de
  signalement anonyme collecte un nom/prénom et un numéro de téléphone, ce
  qui est faux (vérifié dans `lib/models/signalement_model.dart`,
  `lib/screens/signalement_form_screen.dart` et
  `lib/services/signalement_service.dart` — aucun champ nom/téléphone n'existe
  dans ce flux). Il omet aussi la référence à la loi L/2016/037/AN et affiche
  un numéro de téléphone différent (+224 61 42 67 911) de celui confirmé
  ci-dessous. **Cette URL ne doit pas être utilisée comme lien de politique de
  confidentialité dans la Play Console tant que ce contenu n'est pas
  remplacé** par `politique-confidentialite.html` (ou corrigé pour y
  correspondre) — un décalage entre la politique publiée et le comportement
  réel de l'app est exactement le type de non-conformité qui motive un rejet
  Play Store.
- ~~**Téléphone** *(à vérifier)*~~ *(FAIT — confirmé)* : +226 76 41 09 90.
