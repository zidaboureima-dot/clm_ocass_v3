# Cadrage — Rapport périodique assisté par un modèle de langage

**Statut :** cadrage, aucune ligne de code écrite à ce jour.
**Dernière mise à jour :** 19 août 2026.

Ce document cadre l'ajout d'une fonctionnalité de **synthèse périodique
automatique** des signalements, produite par un modèle de langage (LLM), et
destinée à l'administrateur, puis aux autorités sanitaires et partenaires.

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
  traitement. Elles permettent des comptages, mais rien de plus.
- **Les actions entreprises sur les cas** : ce qui a été tenté, obtenu, ou
  resté sans réponse.

Un rapport ne mobilisant que le premier gisement dit : *« 47 signalements,
dont 12 ruptures de médicaments »*. Un rapport mobilisant les deux peut
dire : *« les ruptures signalées en Haute-Guinée ont donné lieu à sept
saisines du district, dont une seule suivie d'effet »*. C'est cette seconde
qualité d'information qui intéresse les autorités sanitaires, et qu'aucun
tableau de bord ne produit.

---

## 2. Décisions structurantes prises le 19 août 2026

### 2.1 Le rapport est réservé à l'administrateur

**Problème résolu.** Les policies RLS garantissent qu'un superviseur ne lit
que les données de **sa** région, et un point focal que celles des cas qui
lui sont **assignés**. Un rapport national diffusé à tous les responsables
aurait restitué à chacun ce que le RLS lui interdit — une régression
silencieuse, invisible dans les tests fonctionnels.

**Décision.** La génération est réservée au seul rôle disposant d'un
périmètre national : l'**administrateur**. Un rapport national produit pour
lui ne lui révèle rien qu'il ne puisse déjà consulter. Le cloisonnement n'est
pas contourné, il devient sans objet.

La diffusion aux autorités sanitaires et partenaires se fait ensuite depuis
ce rapport administrateur, sous forme **agrégée** et après validation
humaine (voir §5).

### 2.2 Le rapport se nourrit d'« actions menées », non des annotations

**Constat.** Ce que le rapport doit restituer, ce ne sont pas les
délibérations internes, mais **les actions entreprises**. Les annotations
sont un espace de travail : elles contiennent des appréciations
professionnelles, parfois sur des collègues ou des hiérarchies locales, qui
n'ont pas vocation à sortir — sans être pour autant des secrets.

**Décision.** Un objet distinct est introduit : l'**action menée**. Le point
focal ou le superviseur la renseigne au moment où il entreprend quelque
chose. Les annotations restent ce qu'elles sont — un espace d'échange
interne — et **ne sont jamais transmises au modèle**.

**Pourquoi c'est supérieur aux deux alternatives écartées :**

| Option | Défaut |
| --- | --- |
| Transmettre toutes les annotations | Envoie à un tiers des délibérations internes non destinées à sortir |
| Ne rien transmettre, retransmission manuelle par les superviseurs | Corvée supplémentaire, faite irrégulièrement en pratique — le rapport devient bancal là où il devait être fort |
| **Champ « action menée » dédié** | Aucun des deux : même effort de saisie que la retransmission manuelle, mais capté au moment de l'action |

La minimisation s'opère **à la source** : le modèle ne reçoit que ce qui a
été explicitement déclaré comme destiné à être rapporté. Un filtrage à la
source ne fuit pas ; un filtrage appliqué en aval finit toujours par fuir.

**Bénéfice au-delà du rapport.** Les actions deviennent interrogeables :
délai entre signalement et première action, part des cas sans aucune action,
efficacité comparée du plaidoyer par région. Aujourd'hui, tout cela est
enfoui dans du texte libre. C'est aussi ce que la méthode CLM demande — le
suivi dirigé par les communautés ne vaut que si la boucle
problème → plaidoyer → résolution est tracée.

---

## 3. L'objet « action menée » — conception proposée

Nouvelle table `actions_menees`, distincte de `annotations`, en append-only
comme elle.

| Champ | Type | Rôle |
| --- | --- | --- |
| `id` | uuid | Identifiant |
| `signalement_id` | uuid | Cas concerné |
| `auteur_uid` | uuid | Auteur (jamais transmis au modèle) |
| `role_auteur` | text | `point_focal`, `superviseur`, `admin` |
| `type_action` | text | Vocabulaire contrôlé (ci-dessous) |
| `description` | text | Formulation libre et courte, **explicitement destinée au rapport** |
| `resultat` | text | `obtenu`, `en_attente`, `sans_suite` |
| `created_at` | timestamptz | Horodatage |

**Vocabulaire de `type_action` (à valider côté métier) :**

- `saisine` — signalement porté au responsable de la structure concernée
- `plaidoyer` — démarche auprès d'une autorité (district, région, ministère)
- `correction` — correction obtenue ou constatée sur le terrain
- `relance` — nouvelle sollicitation après absence de réponse
- `autre` — à préciser dans la description

**Point d'interface déterminant :** le champ doit indiquer clairement à son
auteur que **ce qu'il écrit là pourra figurer dans un rapport transmis aux
autorités**, contrairement à l'annotation. Sans cette mention, la distinction
entre les deux espaces ne tiendra pas à l'usage.

### 3.1 Quand la saisie a lieu (décision du 19 août 2026)

Un champ disponible en permanence, à remplir quand on veut, n'est en pratique
pas rempli : on obtient un champ élégant et vide. La saisie est donc **ancrée
sur deux moments qui existent déjà dans le workflow** :

| Moment | Auteur | Contenu attendu |
| --- | --- | --- |
| Avant de marquer « traité » | Superviseur | L'action menée : type de démarche, ce qui a été fait, résultat à ce jour |
| Avant de « clôturer » | Administrateur | Une note de synthèse concluant le cas (`type_action = 'synthese'`) |

Aucune nouvelle habitude à créer, et une garantie de complétude : tout cas
traité a une action documentée, tout cas clôturé a une synthèse.

**Exigence portée par la base**, via un trigger distinct de celui des
permissions (`trg_exiger_documentation_statut`). Les deux préoccupations —
« qui a le droit de faire quoi » et « le cas est-il documenté » — restent
séparées et modifiables indépendamment. L'interface ne fait qu'anticiper le
refus pour offrir un parcours fluide : la base reste l'autorité finale,
conformément au principe posé en `20260814_workflow_statuts.sql`.

**Le schéma autorise plusieurs actions par signalement**, même si l'interface
n'en propose qu'une à chacun de ces deux moments. Ouvrir la saisie plus
largement plus tard ne coûtera aucune migration.

**Limite assumée.** L'action n'étant consignée qu'en fin de traitement, le
délai avant *première* action n'est pas mesurable. Mais les cas bloqués —
ceux qui n'atteignent jamais « traité » — restent visibles par leur absence
même : « N cas sans aucune action depuis plus de X jours » se calcule à
partir du statut et des dates. Ce sont précisément les cas qui intéressent
le plaidoyer.

**RLS :** mêmes règles de périmètre que `annotations` — admin national,
superviseur régional, point focal sur ses cas assignés, public exclu. Pas de
policy UPDATE ni DELETE.

---

## 4. Contrainte — Le transfert vers un tiers (bloquante)

Faire traiter des contenus par un modèle exploité par un prestataire
constitue un **transfert de données à un tiers**.

Or, en l'état :

- `POLITIQUE_CONFIDENTIALITE.md` n'annonce aucun partage de ce type ;
- `DECLARATION_SURETE_DONNEES_PLAY_STORE.md` répond **« Non »** à la question
  « Partagé avec un tiers ? » pour toutes les catégories de données.

Déployer la fonctionnalité sans mettre ces deux documents à jour **au
préalable** constituerait exactement l'écart *déclaré ≠ réel* que le projet
identifie comme motif de rejet puis de suspension.

### Décision prise le 19 août 2026 : les descriptions citoyennes

Le périmètre initialement envisagé incluait les **descriptions rédigées par
les citoyens**. La décision du §2.2 invite à réexaminer ce point, car le même
raisonnement s'y applique : le citoyen a rédigé sa description à l'intention
des responsables chargés de traiter son cas, **pas à destination d'un rapport
ni d'un prestataire tiers**. Rien n'empêche par ailleurs quelqu'un d'écrire
« l'infirmière de garde mardi soir m'a renvoyée » — texte qui n'identifie pas
son auteur mais identifie indirectement un tiers.

**Décision : les descriptions restent dans le périmètre**, la richesse
analytique étant jugée nécessaire, **mais l'étage de minimisation du §5
devient obligatoire et bloquant** — il n'est pas une option d'implémentation
mais la condition de cette décision. Aucun appel au modèle ne doit être écrit
avant que cet étage n'existe et ne soit testé.

---

## 5. Garde-fous à implémenter

- ~~**Minimisation avant envoi.**~~ *(FAIT — 19 août 2026)* :
  `supabase/functions/_shared/minimisation.ts`, testé
  (`minimisation.test.ts`, 23 assertions).

  Deux minimisations distinctes y sont implémentées :

  1. **Textuelle** — retrait des numéros de téléphone (formats guinéens,
     burkinabè, internationaux et locaux), adresses email, liens et longues
     suites de chiffres. Les motifs sont remplacés par un marqueur explicite
     (`[numéro retiré]`) plutôt que supprimés : le modèle voit qu'une
     information a été ôtée, et la relecture humaine peut le vérifier.
  2. **Structurelle** — seuls les champs utiles au rapport sont recopiés.
     Ni `auteur_uid` (seul le **rôle** est transmis), ni l'identifiant du
     signalement ne sortent de la base. C'est la plus efficace des deux :
     ce qui n'est pas recopié ne peut pas fuir.

  *Point d'attention consigné dans le code :* les dates échappent au
  nettoyage grâce à un contrôle dédié — « réunion du 15 08 2026 » a huit
  chiffres en quatre groupes, indiscernable d'un numéro par la seule forme.
  Sans ce contrôle, le rapport perdrait sa dimension temporelle.

  **Limite structurelle, à ne jamais perdre de vue :** cet étage retire des
  identifiants de *forme* reconnaissable. Il ne peut rien contre une
  identification par le *contexte* — « l'infirmière de garde mardi soir m'a
  renvoyée » passera intact. Aucune expression régulière ne couvrira jamais
  ce cas. C'est pourquoi les deux garde-fous suivants (sortie agrégée,
  validation humaine) ne sont pas des options : ils compensent cette limite,
  et en retirer un rouvre le risque en entier.
- **Prestataire sous contrat.** Fournisseur offrant contractuellement la
  **non-réutilisation des données pour l'entraînement** et une **rétention
  nulle ou minimale**, avec accord de traitement des données signé. À défaut,
  réduire le périmètre aux seules données structurées.
- **Sortie agrégée pour la diffusion externe.** Le rapport transmis aux
  autorités ne reproduit jamais une description ni une action *verbatim* : il
  en produit la synthèse. Consigne à inscrire dans l'invite **et** à vérifier
  par relecture humaine.
- **Validation humaine avant diffusion externe.** Aucun rapport généré n'est
  transmis à une autorité ou à un partenaire sans relecture et validation
  explicite par l'administrateur. Un modèle peut sur-interpréter un cas isolé
  ou formuler une causalité que les données ne soutiennent pas. L'engagement
  de crédibilité du dispositif ne se délègue pas.
- **Traçabilité.** Journaliser pour chaque génération : période, périmètre,
  volume transmis, horodatage, destinataire — sans recopier le contenu
  transmis. C'est ce qui rendra la fonctionnalité auditable, au même titre
  que les audits EXIF et suppression des audios.
- **Mention explicite dans le rapport.** Tout rapport porte une mention
  indiquant qu'il a été produit avec l'assistance d'un modèle de langage et
  validé par un responsable. Ne pas le dire serait une seconde forme d'écart
  entre le déclaré et le réel.

---

## 5.1 Qualification des données transmises (analyse du 19 août 2026)

Après implémentation de l'étage de minimisation, **le payload transmis ne
contient aucune donnée identifiante** :

| Personne concernée | Ce qui est transmis |
| --- | --- |
| Citoyen qui signale | Rien. Aucun compte, aucune identité collectée en amont — c'est la conception même du dispositif |
| Agent traitant (point focal, superviseur, admin) | Son **rôle** seulement. `auteur_uid` est retiré à la construction du payload |

**Le seul risque résiduel ne porte sur aucune de ces deux catégories.** Il
porte sur une **tierce personne évoquée dans un texte libre** : un agent de
santé décrit dans une description citoyenne ou dans une action menée. Dans
une petite structure, « le seul médecin du centre » identifie une personne
sans la nommer. C'est la limite structurelle de l'étage de minimisation (§5),
et elle est irréductible par des moyens techniques.

### Décision : le centre de santé reste dans le périmètre

`centre_sante` est conservé dans le payload. Un rapport incapable de pointer
un établissement précis ne remplit pas sa fonction de plaidoyer : le suivi
communautaire consiste justement à dire *où* les dysfonctionnements se
concentrent.

**Contrepartie obligatoire, à inscrire dans l'invite du modèle :** interdire
explicitement toute mention d'une fonction ou d'un rôle individuel dans le
rapport produit (« le médecin-chef », « l'infirmière de garde », « le
gestionnaire du stock »). Le rapport parle d'établissements et de
dysfonctionnements, jamais de personnes.

**Portée réelle de cette contrepartie — à ne pas surestimer.** Une consigne
donnée à un modèle n'est pas une garantie technique : elle est respectée la
plupart du temps, pas systématiquement. Ce qui rend cette protection
effective, c'est la **relecture humaine avant diffusion externe** (§5). La
consigne réduit la fréquence du problème ; la relecture est ce qui l'arrête.
Supprimer la relecture au motif que la consigne existe serait une erreur de
raisonnement aux conséquences directes sur des personnes.

---

## 6. Cadre légal national (à instruire)

La loi guinéenne **L/2016/037/AN du 28 juillet 2016**, socle juridique
revendiqué par le projet, encadre le traitement des données à caractère
personnel. Ses dispositions relatives aux **transferts hors du territoire
national** doivent être instruites avant tout engagement : selon leur
contenu, elles peuvent imposer des conditions (autorisation préalable,
garanties contractuelles, localisation) qui orientent le choix du
prestataire.

**Ce point n'est pas tranché ici et ne doit pas l'être par supposition.** Il
appelle une lecture du texte, et le cas échéant un avis juridique.

### La question à poser en premier

L'analyse du §5.1 change l'ordre d'instruction. Plutôt que de demander
« à quelles conditions peut-on transférer ces données ? », la question
préalable est :

> **Après minimisation, ce qui est transmis constitue-t-il encore des données
> à caractère personnel au sens de la loi L/2016/037/AN ?**

Si la réponse est **non** — aucune personne concernée n'étant identifiable —
les dispositions sur le transfert transfrontalier ne s'appliquent pas, et le
choix du prestataire redevient une décision purement technique. Si la réponse
est **oui**, au motif qu'une description peut identifier indirectement un
agent de santé (§5.1), alors les conditions du texte s'appliquent et
orientent le choix du prestataire.

Cette question décide de tout le reste : elle doit être instruite avant
toute autre.

**Interlocuteurs identifiés :** l'ANSSI Guinée et l'ARPT publient toutes deux
le texte. L'ANSSI, qui porte la loi, est le destinataire naturel d'une
demande écrite. La Guinée figure par ailleurs parmi les pays référencés par
l'AFAPDP (association francophone des autorités de protection des données),
ce qui constitue une piste pour identifier l'autorité compétente.

*Réserve : ce document n'est pas un avis juridique et son auteur n'a pas
qualité pour en rendre un. Il pose la question dans les termes utiles, il ne
la tranche pas.*

---

## 7. Architecture envisagée

1. **Déclencheur périodique** — planification côté Supabase (`pg_cron`
   appelant la fonction, ou planificateur d'Edge Function). Périodicité à
   décider : mensuelle pour l'usage interne, trimestrielle pour
   l'institutionnel.
2. **Edge Function `rapport-periodique`** — sur le modèle des cinq fonctions
   existantes (`clever-service`, `quick-endpoint`, `rapid-action`,
   `quick-task`, `super-worker`) :
   - extraction : signalements structurés + `actions_menees` de la période ;
   - passage par l'étage de minimisation (§5) ;
   - appel au modèle ;
   - stockage du rapport en base, avec période, périmètre et statut de
     validation ;
   - diffusion par email via Resend, déjà en place, **après validation**.
3. **Consultation dans l'app** — rapports lisibles depuis le tableau de bord
   administrateur, avec l'action de validation avant diffusion externe.

---

## 8. Séquencement recommandé

L'objet « action menée » a une valeur propre, indépendamment du rapport : il
instrumente la boucle CLM et rend les actions mesurables. Il peut donc être
livré et éprouvé **avant** toute décision sur le LLM.

1. **Étape 1 — l'objet « action menée »** : migration, RLS, modèle, service,
   interface de saisie. Aucun transfert à un tiers, aucune mise à jour
   documentaire requise. Utile même si le rapport LLM n'est jamais fait.
2. **Étape 2 — le rapport, version interne** : génération pour
   l'administrateur seul, non diffusée à l'extérieur, pour juger sur pièces
   de la qualité réelle des synthèses. Impose la mise à jour préalable de la
   politique de confidentialité et de la déclaration Data Safety.
3. **Étape 3 — la diffusion institutionnelle** : sortie agrégée, validation
   humaine, mention explicite. À n'engager que si l'étape 2 est concluante.

### État au 19 août 2026 — construit, éteint

L'étape 2 est **écrite et livrée, mais désactivée**. Cette dissociation est
volontaire : construire n'est pas déployer, et rien n'interdisait d'écrire le
code pendant que les préalables juridiques et documentaires s'instruisent. Ce
qui aurait été fautif, c'est de transmettre des données réelles avant leur
levée — ce que le dispositif rend maintenant impossible par construction.

Livré :

- `configuration_pays` — un interrupteur **par pays**, `rapport_llm_actif`,
  **faux par défaut**, assorti d'un champ `rapport_llm_motif` où la raison de
  l'état est écrite. Aucune policy RLS ne permet de le modifier depuis
  l'application : l'activation exige un acte délibéré en base. Une case à
  cocher dans une interface invite à l'oubli ; une ligne de SQL motivée laisse
  une trace.
- `rapports_periodiques` — le statut `brouillon` par défaut encode
  l'exigence de validation humaine **dans le schéma** plutôt que dans une
  consigne. Ce qui est porté par le schéma survit aux changements d'équipe.
- `trg_verifier_rapport_llm_autorise` — seconde barrière en base : même si
  la fonction était contournée, l'insertion d'un rapport reste refusée tant
  que le pays ne l'autorise pas.
- Edge Function `rapport-periodique` (Mistral) — vérifie le drapeau **avant**
  toute extraction, minimise **avant** tout appel au prestataire, enregistre
  en brouillon et **n'envoie rien à personne**.

Vérifié par simulation de la chaîne complète : ni identifiant de cas, ni
identifiant d'agent, ni numéro, ni adresse email n'apparaissent dans l'invite
réellement transmise ; le nom de l'établissement, le rôle de l'auteur et les
dates y sont bien conservés.

**Pour activer, le jour venu :** la commande figure en fin de
`20260819_configuration_pays_et_rapports.sql`. Elle exige d'écrire le motif —
donc de nommer l'avis reçu et la date de mise à jour de la politique de
confidentialité.

---

## 9. À mettre à jour AVANT l'étape 2

Ordre impératif — la documentation précède la mise en production, jamais
l'inverse :

1. `POLITIQUE_CONFIDENTIALITE.md` et sa version hébergée
   (`politique-confidentialite.html`) : section décrivant le traitement
   automatisé, le prestataire, la finalité, et ce qui n'est pas transmis.
2. `DECLARATION_SURETE_DONNEES_PLAY_STORE.md` : la réponse « Partagé avec un
   tiers ? » devient **Oui** pour les catégories concernées.
3. `CADRAGE_SAAS_CONSOLIDE.md` : chaque pays contractant pouvant relever d'un
   cadre légal différent, la fonctionnalité doit être **activable ou
   désactivable par pays**.

---

## 10. Décisions restant à prendre

- Validation du vocabulaire de `type_action` par le métier (§3).
- Périodicité retenue.
- Choix du prestataire de modèle, au regard des garanties du §5 et des
  exigences légales du §6.
- Instruction du §6 — préalable à toute décision de mise en œuvre.
