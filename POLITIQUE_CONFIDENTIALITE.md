# Politique de confidentialité — CLM-OCASS Guinée

**Dernière mise à jour :** 18 août 2026

Cette page décrit précisément quelles données CLM-OCASS traite, dans quel but,
combien de temps elles sont conservées, et ce qui n'est jamais collecté. Elle
correspond au fonctionnement réel et vérifié de l'application — pas à une
promesse. Chaque affirmation ci-dessous a fait l'objet d'une vérification
technique documentée (voir `AUDIT_EXIF_PHOTOS.md` et
`AUDIT_SUPPRESSION_AUDIOS.md` dans le dépôt du projet).

---

## 1. Qui traite les données

CLM-OCASS Guinée est un dispositif de suivi dirigé par les communautés,
permettant à toute personne de signaler un dysfonctionnement (dans le domaine
sanitaire) auprès des responsables compétents, de manière anonyme.

**Responsable du traitement :** le porteur du projet CLM-OCASS Guinée. Pour
toute question relative aux données personnelles, contact :
**info@sapsapservices.com**.

---

## 2. Ce que fait une personne qui signale (citoyen)

Aucun compte n'est nécessaire pour signaler. La personne peut :

- remplir un formulaire structuré (zone géographique réelle — région et
  préfecture —, catégorie de dysfonctionnement, niveau de gravité,
  description) ;
- joindre une photo et/ou un enregistrement audio à ce formulaire ;
- déposer un message vocal seul, sans formulaire, pour les personnes qui
  préfèrent parler plutôt qu'écrire ;
- déposer une photo seule, comme preuve d'un dysfonctionnement observé ;
- consulter les statistiques publiques agrégées (nombre de signalements,
  répartition par statut), qui ne contiennent aucune donnée individuelle.

### Ce qui N'EST PAS collecté sur cette personne

- **Aucune identité** : ni nom, ni numéro de téléphone, ni identifiant. Le
  signalement vaut par son contenu, pas par son auteur.
- **Aucune géolocalisation précise.** Les métadonnées de localisation et
  d'appareil (EXIF, GPS) contenues dans une photo sont retirées
  automatiquement, avant l'enregistrement, par un traitement qui vide
  explicitement ces métadonnées. Si ce nettoyage échoue pour une raison
  technique, l'envoi de la photo est refusé plutôt que d'être accepté avec ses
  métadonnées — la fiabilité de cette suppression a été vérifiée sur les
  fichiers réellement stockés, pas seulement en théorie.

---

## 3. Traitement des enregistrements vocaux

Deux cas, avec deux règles de conservation différentes :

- **Message vocal joint à un signalement structuré** : il fait partie du
  dossier de traitement, au même titre que la description ou la photo. Il est
  **conservé tant que le signalement existe**, pour permettre au responsable
  compétent de le réécouter et de traiter le cas. Il est traité de façon
  centralisée, jamais écouté au niveau local, pour écarter tout risque de
  reconnaissance de la voix par un acteur de proximité.
- **Message vocal déposé seul, sans signalement** : la voix étant une donnée
  potentiellement identifiante, ce fichier brut n'est pas conservé. Un
  responsable l'écoute une fois, le transforme en signalement structuré et
  anonymisé, puis le fichier audio brut est **supprimé immédiatement du
  stockage**. Cette suppression est vérifiée par le système lui-même : le
  message n'est marqué comme traité que si la suppression du fichier a
  effectivement réussi.

*Point de vigilance transparent : la durée de conservation des audios joints
après la **clôture** d'un signalement n'est pas encore définie. C'est un
chantier de gouvernance des données en cours, qui visera à limiter cette
conservation au strict nécessaire.*

---

## 4. Comptes des responsables (administrateurs, superviseurs, points focaux)

Contrairement au citoyen qui signale, les personnes chargées de traiter les
signalements (administrateur, superviseur, point focal) disposent d'un compte.
Pour ces personnes, sont traités : un nom, une adresse email, un numéro de
téléphone, un mot de passe (géré de façon sécurisée, jamais stocké en clair),
un rôle et une zone géographique de responsabilité. Le compte est créé par un
administrateur, avec un mot de passe temporaire envoyé par email et un
changement de mot de passe obligatoire à la première connexion.

Ces adresses email sont utilisées uniquement pour les notifications liées au
fonctionnement du dispositif (création de compte, réinitialisation de mot de
passe, notification d'étape de traitement d'un signalement), via un
prestataire d'envoi d'emails transactionnels. Elles ne sont ni partagées avec
des tiers, ni utilisées à des fins commerciales.

---

## 5. Qui a accès aux signalements

Un signalement est visible uniquement par les responsables habilités de la
zone géographique concernée (superviseur, point focal) et par
l'administrateur. Aucune donnée d'un signalement n'est rendue publique
individuellement : seules des statistiques agrégées (comptages) sont visibles
publiquement.

---

## 6. Base légale et cadre applicable

Le traitement des données par CLM-OCASS Guinée s'inscrit dans le cadre de la
loi guinéenne **L/2016/037/AN du 28 juillet 2016** relative à la
cybersécurité et à la protection des données à caractère personnel.

---

## 7. Vos droits

- **Personne qui signale (citoyen)** : aucune donnée identifiante n'étant
  collectée, il n'existe pas de moyen technique de relier un signalement
  déposé à une personne précise pour exercer un droit d'accès ou de
  suppression individuel a posteriori — c'est une conséquence directe de
  l'anonymat garanti dès la conception.
- **Titulaire d'un compte (administrateur, superviseur, point focal)** : vous
  pouvez demander l'accès, la correction ou la suppression des données de
  votre compte en contactant le responsable du traitement (coordonnées en
  section 1).

---

## 8. Évolutions de cette politique

Cette politique sera mise à jour si le fonctionnement réel de l'application
évolue (nouvelles fonctionnalités, nouveaux pays de déploiement avec leurs
propres règles). La date de dernière mise à jour figure en haut de cette page.
