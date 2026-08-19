# Cadrage — Rapport périodique assisté par un modèle de langage

**Statut :** cadrage, aucune ligne de code écrite à ce jour.
**Dernière mise à jour :** 19 août 2026.

Ce document cadre l'ajout d'une fonctionnalité de **synthèse périodique
automatique** des signalements, produite par un modèle de langage (LLM), et
destinée à l'administrateur, aux superviseurs, ainsi qu'aux autorités
sanitaires et partenaires.

Il est écrit **avant** toute implémentation, parce que la fonctionnalité
touche directement au principe fondateur du projet — *déclaré = réel* — et
au cloisonnement des données durement acquis (voir
`20260815_securite_annotations.sql`).

---

## 1. Valeur attendue

Le dispositif dispose de deux gisements de matière, et c'est leur croisement
qui fait l'intérêt de la fonctionnalité :

- **Les caractéristiques structurées des cas** : région, préfecture, centre
  de santé, groupe, catégorie, gravité, statut, dates de dépôt et de
  traitement. Elles permettent déjà des comptages, mais rien de plus.
- **Le dialogue autour des cas** : la table `annotations` (auteur, rôle,
  contenu, date), où points focaux, superviseurs et administrateurs
  consignent ce qui a été tenté, ce qui a bloqué, ce qui a été obtenu.

Un rapport ne mobilisant que le premier gisement dit : *« 47 signalements,
dont 12 ruptures de médicaments »*. Un rapport mobilisant les deux peut
dire : *« les ruptures signalées en Haute-Guinée restent non résolues faute
d'interlocuteur identifié au niveau régional, selon les échanges répétés des
points focaux »*. C'est cette seconde qualité d'information qui intéresse les
autorités sanitaires, et qu'aucun tableau de bord ne produit.

---

## 2. Contrainte n°1 — Le cloisonnement par périmètre (bloquante)

**C'est la contrainte la plus facile à violer sans s'en apercevoir.**

Les policies RLS garantissent aujourd'hui qu'un superviseur ne lit que les
annotations des signalements de **sa** région, et un point focal que celles
des cas qui lui sont **assignés**. Un rapport unique, construit sur
l'ensemble des données puis diffusé à tous les responsables, restituerait à
chacun des informations que le RLS lui interdit — une régression silencieuse,
invisible dans les tests fonctionnels, et contraire à l'engagement pris
auprès des acteurs.

**Règle à respecter :** le périmètre du rapport ne peut jamais excéder le
périmètre de lecture de son destinataire.

Conséquence sur la conception : il ne peut pas exister *un* rapport, mais
**trois familles de rapports** :

| Destinataire | Périmètre des données | Niveau de détail permis |
| --- | --- | --- |
| Point focal | Ses cas assignés | Cas par cas |
| Superviseur | Sa région | Cas par cas dans sa région |
| Administrateur | National | Tout |
| Autorités sanitaires, partenaires | National | **Agrégé uniquement** — aucun cas individuel reconstituable |

La génération doit donc être **paramétrée par périmètre**, et la requête
d'extraction filtrée en amont — pas le texte du rapport filtré en aval. Un
filtrage effectué après la génération est un filtrage qui finira par fuir.

---

## 3. Contrainte n°2 — Le transfert vers un tiers (bloquante)

Faire traiter des descriptions et des annotations par un modèle exploité par
un prestataire constitue un **transfert de données à un tiers**.

Or, en l'état :

- `POLITIQUE_CONFIDENTIALITE.md` n'annonce aucun partage de ce type ;
- `DECLARATION_SURETE_DONNEES_PLAY_STORE.md` répond **« Non »** à la question
  « Partagé avec un tiers ? » pour toutes les catégories de données.

Déployer la fonctionnalité sans mettre ces deux documents à jour **au
préalable** constituerait exactement l'écart *déclaré ≠ réel* que le projet
identifie comme motif de rejet puis de suspension.

Deux risques de fond, au-delà de la conformité formelle :

1. **Les descriptions sont écrites par des citoyens anonymes**, sans contrôle
   éditorial. Rien n'empêche quelqu'un d'écrire « l'infirmière de garde mardi
   soir m'a renvoyée » — texte qui n'identifie pas son auteur mais identifie
   indirectement un tiers. Ce contenu partirait chez le prestataire.
2. **Les annotations sont écrites par des agents identifiés** et contiennent
   leurs appréciations professionnelles sur des situations sensibles, parfois
   sur des collègues ou des hiérarchies locales.

---

## 4. Contrainte n°3 — Cadre légal national (à instruire)

La loi guinéenne **L/2016/037/AN du 28 juillet 2016**, socle juridique
revendiqué par le projet, encadre le traitement des données à caractère
personnel. Ses dispositions relatives aux **transferts hors du territoire
national** doivent être instruites avant tout engagement : selon leur
contenu, elles peuvent imposer des conditions (autorisation préalable,
garanties contractuelles, localisation) qui orientent le choix du
prestataire.

**Ce point n'est pas tranché ici et ne doit pas l'être par supposition.** Il
appelle une lecture du texte, et le cas échéant un avis juridique. Le fait
que la fonctionnalité soit techniquement simple ne dispense pas de cette
étape — c'est même l'inverse.

---

## 5. Architecture envisagée

Elle s'inscrit dans l'existant sans rien bouleverser :

1. **Déclencheur périodique** — planification côté Supabase (`pg_cron`
   appelant la fonction, ou planificateur d'Edge Function). Périodicité à
   décider : mensuelle probablement, trimestrielle pour l'institutionnel.
2. **Edge Function `rapport-periodique`** — sur le modèle des cinq fonctions
   existantes (`clever-service`, `quick-endpoint`, `rapid-action`,
   `quick-task`, `super-worker`) :
   - extraction filtrée **par périmètre** (voir §2) ;
   - passage par l'étage de minimisation (§6) ;
   - appel au modèle ;
   - stockage du rapport en base, dans une table dédiée, avec sa période, son
     périmètre et son destinataire ;
   - diffusion par email via Resend, déjà en place.
3. **Consultation dans l'app** — les rapports produits sont lisibles depuis
   les tableaux de bord existants, selon le rôle.

Rien n'impose de tout livrer d'un coup : une première version limitée au
rapport administrateur, non diffusé à l'extérieur, permettrait d'évaluer la
qualité réelle des synthèses avant d'ouvrir la diffusion institutionnelle.

---

## 6. Garde-fous à implémenter

Ces garde-fous ne sont pas des options : ils conditionnent la possibilité
même de retenir le périmètre le plus large (descriptions comprises).

- **Minimisation avant envoi.** Un étage de nettoyage précède tout appel au
  modèle : suppression des numéros de téléphone, adresses email, et de toute
  séquence ressemblant à un identifiant, dans les descriptions comme dans les
  annotations. Les auteurs d'annotations sont réduits à leur **rôle**
  (« un point focal »), jamais à leur identité.
- **Prestataire sous contrat.** Choisir un fournisseur offrant
  contractuellement la **non-réutilisation des données pour l'entraînement**
  et une **rétention nulle ou minimale**, avec un accord de traitement des
  données signé. À défaut de ces garanties, le périmètre doit être réduit aux
  seules données structurées.
- **Sortie agrégée pour la diffusion externe.** Le rapport destiné aux
  autorités et partenaires ne reproduit jamais une description ni une
  annotation *verbatim* : il en produit la synthèse. Consigne à inscrire dans
  l'invite, **et** à vérifier par relecture humaine.
- **Validation humaine avant diffusion externe.** Aucun rapport généré n'est
  transmis à une autorité ou à un partenaire sans relecture et validation
  explicite par l'administrateur. Un modèle peut se tromper, sur-interpréter
  un cas isolé, ou formuler une causalité que les données ne soutiennent pas.
  L'engagement de crédibilité du dispositif ne se délègue pas.
- **Traçabilité.** Journaliser, pour chaque génération : la période, le
  périmètre, le volume de données transmis, l'horodatage et le destinataire —
  sans recopier le contenu transmis. Cette trace est ce qui rendra la
  fonctionnalité auditable, au même titre que les audits EXIF et suppression
  des audios.
- **Mention explicite dans le rapport.** Tout rapport porte une mention
  indiquant qu'il a été produit avec l'assistance d'un modèle de langage et
  validé par un responsable. Ne pas le dire serait une seconde forme d'écart
  entre le déclaré et le réel.

---

## 7. À mettre à jour AVANT tout déploiement

Ordre impératif — la documentation précède la mise en production, jamais
l'inverse :

1. `POLITIQUE_CONFIDENTIALITE.md` et sa version hébergée
   (`politique-confidentialite.html`) : nouvelle section décrivant le
   traitement automatisé, le prestataire concerné, la finalité, et ce qui
   n'est pas transmis.
2. `DECLARATION_SURETE_DONNEES_PLAY_STORE.md` : la réponse « Partagé avec un
   tiers ? » devient **Oui** pour les catégories concernées, avec la finalité
   correspondante.
3. `CADRAGE_SAAS_CONSOLIDE.md` : inscription de la fonctionnalité et de son
   périmètre par tenant — chaque pays contractant pouvant relever d'un cadre
   légal différent, la fonctionnalité doit être **activable ou désactivable
   par pays**.

---

## 8. Décisions restant à prendre

- Périodicité retenue (mensuelle, trimestrielle, les deux selon le
  destinataire).
- Choix du prestataire de modèle, au regard des garanties contractuelles
  du §6 et des exigences légales du §4.
- Périmètre de la première version : administrateur seul, ou d'emblée les
  trois familles de rapports.
- Instruction du §4 (transferts hors territoire) — préalable à toute
  décision de mise en œuvre.
