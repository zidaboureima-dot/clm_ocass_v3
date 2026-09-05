# CLM-OCASS Guinée — instructions pour Claude Code

Application mobile de **suivi dirigé par les communautés** (*community-led
monitoring*) : toute personne peut signaler anonymement un dysfonctionnement
observé dans un service de santé, et une chaîne de responsables traite le
signalement jusqu'à sa clôture.

En production en Guinée. Premier locataire d'un futur service multi-pays.

- Dépôt : `github.com/zidaboureima-dot/clm_ocass_v3`, branche `main`
- Supabase : projet `ouwuirvyzmdutwfkeeoy`
- Version applicative : `1.0.0+1`
- Porteur : Zida Boureima — SAP SAP Services

---

## 1. Méthode de travail — à respecter sans exception

Ces règles ont été posées par le porteur du projet et ont, à plusieurs
reprises, évité des régressions sérieuses.

- **Diagnostic à froid avant d'agir.** Lire le code concerné, comprendre
  l'existant, *puis* proposer. Ne jamais modifier sur hypothèse.
- **Une étape à la fois.** Livrer, faire valider, puis passer à la suivante.
  Pas de refonte en bloc.
- **`flutter analyze` après toute modification Dart.** Référence :
  **exactement 6 issues préexistantes** (5 imports `supabase_flutter`
  inutilisés, 1 `anonKey` déprécié). Plus de 6 = régression introduite.
- **`git status` avant chaque commit.**
- **Tout est versionné** : code, migrations SQL, et les décisions elles-mêmes
  (documents de cadrage à la racine).
- **Messages de commit explicatifs.** La convention du projet est d'écrire
  *pourquoi*, pas seulement *quoi* — y compris ce qui a été écarté et pour
  quelle raison. Les commits servent de mémoire au projet.

### Le principe directeur : déclaré = réel

Tout écart entre ce que le projet **déclare** (politique de confidentialité
publiée, déclaration Data Safety, livre blanc) et ce que l'application **fait
réellement** est un motif de rejet sur les stores, puis de suspension de
compte. Ce principe prime sur la vitesse de livraison.

Conséquence pratique : **la documentation précède la mise en production,
jamais l'inverse.** Une fonctionnalité qui change le traitement des données
n'est pas déployée avant que les documents publiés ne soient à jour.

---

## 2. Architecture

**Flutter** (Dart) → **Supabase** (PostgreSQL, Auth, Storage, Edge Functions
Deno) → **Resend** pour les emails transactionnels.

### Les rôles et leur périmètre

| Rôle | Voit | Peut |
|---|---|---|
| Citoyen | Statistiques agrégées publiques | Signaler sans compte, sans identité |
| Point focal | Ses cas assignés | Documenter, annoter — ne change **jamais** le statut |
| Superviseur | Sa **région** | Assigner à un point focal, marquer « traité » |
| Administrateur | National | Tout, dont clôturer, gérer comptes et catégories |

### Le workflow des statuts

`nouveau` → `en_cours` (superviseur assigne) → `traite` (superviseur) →
`cloture` (admin seul).

Deux triggers distincts gardent ce workflow, et ils sont **séparés
volontairement** :

- `trg_valider_transition_statut` — *qui a le droit de faire quoi*
- `trg_exiger_documentation_statut` — *le cas est-il documenté* : refuse
  `traite` sans action menée, `cloture` sans note de synthèse

L'interface Flutter ne fait que filtrer l'affichage des boutons. **La base
fait foi.**

---

## 3. Invariants de sécurité — ne jamais casser

### 3.1 L'anonymat du citoyen

Aucune donnée personnelle n'est collectée sur la personne qui signale : ni
nom, ni téléphone, ni identifiant, ni compte. Vérifié dans
`lib/models/signalement_model.dart` et `lib/screens/signalement_form_screen.dart`.

**N'ajoute jamais de champ identifiant à ce flux**, même « optionnel », même
« pour le suivi ». C'est la promesse centrale du dispositif et l'argument qui
permet aux gens de signaler sans craindre de représailles.

### 3.2 Le cloisonnement par région

`region` n'est pas un libellé d'affichage : c'est le **périmètre de lecture**
appliqué par RLS sur `signalements`, `annotations` et `actions_menees`, via
`region_du_demandeur()`.

Toute fonctionnalité qui agrège ou diffuse des données doit respecter ce
cloisonnement. Un rapport national diffusé aux superviseurs restituerait à
chacun ce que le RLS lui interdit — c'est pourquoi le rapport périodique est
réservé à l'administrateur, seul rôle au périmètre national.

Corollaire opérationnel : **créer une région ne suffit pas, il faut lui
affecter un superviseur**, sinon ses signalements ne sont visibles que de
l'administrateur.

### 3.3 Photos et audios

- Les métadonnées EXIF/GPS des photos sont retirées **avant** enregistrement
  (`lib/services/image_sanitizer.dart`). Si le nettoyage échoue, l'envoi est
  refusé plutôt qu'accepté. Audit : `AUDIT_EXIF_PHOTOS.md`.
- Un message vocal déposé **seul** est détruit après transformation en
  signalement structuré, et le système ne marque le message traité que si la
  suppression a effectivement réussi. Audit : `AUDIT_SUPPRESSION_AUDIOS.md`.

### 3.4 Annotations ≠ actions menées

Deux tables distinctes, et la distinction est un garde-fou, pas un détail de
modélisation :

- **`annotations`** — espace de travail **interne**. Peut contenir des
  appréciations sur des personnes. **N'est jamais transmis à un tiers.**
- **`actions_menees`** — ce qui a été entrepris, écrit par son auteur *en
  sachant* que cela pourra figurer dans un rapport transmis aux autorités.
  Seule source exploitée par le rapport périodique.

**N'ajoute jamais les annotations à la source du rapport**, même si elles sont
« plus riches ». Si le rapport manque de matière, la réponse est d'améliorer
la saisie des actions, pas d'élargir la collecte.

---

## 4. Carte du dépôt

```
lib/
  data/regions_prefectures.dart     géographie (voir §5)
  models/                            signalement, annotation, action_menee, user_profile…
  services/                          supabase, image_sanitizer, photo, audio, action_menee…
  screens/                           formulaire citoyen, détail, tableaux de bord par rôle
supabase/
  migrations/                        12 migrations, documentées et idempotentes
  functions/
    _shared/minimisation.ts          étage de minimisation + calcul des agrégats
    _shared/config_pays.ts           lecture de la configuration par pays
    rapport-periodique/              rapport LLM (Mistral) — voir §7
    clever-service, quick-endpoint,  emails transactionnels (Resend)
    quick-task, rapid-action
    super-worker                     passerelle du site vitrine
```

**Documents de cadrage à la racine — les lire avant de toucher aux sujets
concernés :**

| Fichier | Contenu |
|---|---|
| `CADRAGE_SAAS_CONSOLIDE.md` | Trajectoire multi-pays, directives d'architecture |
| `CADRAGE_RAPPORT_LLM.md` | Rapport périodique : décisions, garde-fous, séquencement |
| `DETTES_SAAS.md` | Dettes techniques identifiées et leur cible |
| `EDGE_FUNCTIONS.md` | Registre des fonctions : les noms déployés ne disent pas leur rôle |
| `AUDIT_EXIF_PHOTOS.md`, `AUDIT_SUPPRESSION_AUDIOS.md` | Preuves des engagements de confidentialité |
| `FICHE_STORE.md` | Contenu de la fiche Play Store |
| `POLITIQUE_CONFIDENTIALITE.md` + `.html` | Version publiée sur sapsapservices.com |
| `DECLARATION_SURETE_DONNEES_PLAY_STORE.md` | Formulaire Data Safety |

⚠️ **Les Edge Functions portent des noms générés par le dashboard Supabase,
sans rapport avec leur rôle.** Toujours consulter `EDGE_FUNCTIONS.md` avant
d'en modifier une.

---

## 5. Découpage territorial — à jour au 21 août 2026

Décret du 20 août 2026 : Beyla et Siguiri, jusque-là préfectures, sont
érigées en **régions administratives** ; 11 préfectures nouvelles sont créées.

**Décompte officiel : 9 régions administratives et 44 préfectures**, plus
Conakry — gouvernorat, « zone spéciale », dont les 13 communes ne comptent pas
parmi les préfectures.

`lib/data/regions_prefectures.dart` expose `nombrePrefectures` (doit valoir
**44**) et `nombreRegionsAdministratives` (doit valoir **9**). Si une
modification fait varier ces nombres sans qu'un texte l'ait décidé, c'est une
erreur de saisie.

*Cet épisode illustre la limite du modèle mono-pays : une décision
administrative impose une recompilation et une republication. Dans
l'architecture visée, la hiérarchie sanitaire relève de la configuration par
pays, idéalement ingérée depuis le DHIS2 national.*

---

## 6. État au 21 août 2026 — ce qui bloque en priorité

### ⚠️ Le binaire est en retard sur la base

L'APK et le bundle datent du **18 août**. Depuis, trois commits ont modifié le
code Dart (nom affiché, objet « action menée », découpage territorial).

**Conséquence immédiate :** le trigger `trg_exiger_documentation_statut` est
actif en production, mais l'application installée n'a pas le dialogue qui
crée l'action. **Marquer un cas « traité » échoue avec l'APK actuel.**

```bash
flutter build apk --release
flutter build appbundle --release
```

### Publication sur les stores

Tout est prêt côté technique : `applicationId` `com.clmocass.app`, icônes
Android et iOS, clé de signature câblée (`android/key.properties`, non
versionné), politique de confidentialité hébergée et vérifiée, déclaration
Data Safety, fiche store, visuel 1024×500, captures d'écran conformes
(Play impose un ratio maximum de 2:1 et interdit le canal alpha).

**Seul blocage : la validation d'identité du compte développeur Google Play.**
Compte personnel, profil de paiement au Burkina Faso. Cause identifiée : le
profil comportait une **boîte postale** alors que les justificatifs de
domicile portent une adresse physique — la comparaison automatique ne pouvait
aboutir. Adresse corrigée, tentatives épuisées : un recours au support Play a
été rédigé et reste à envoyer.

**Distribution directe en parallèle** : APK universel (59,5 Mo) et
`installation-android.html` produits, à héberger côte à côte sur
`sapsapservices.com`.

---

## 7. Rapport périodique assisté par un LLM

Cadrage complet dans `CADRAGE_RAPPORT_LLM.md`. **Le lire avant toute
intervention sur ce sujet.**

### État : écrit, déployé, et volontairement éteint

La chaîne fonctionne — vérifiée sur données fabriquées via Mistral — et trois
barrières indépendantes garantissent qu'elle ne traite **aucune donnée
réelle** :

1. `configuration_pays.rapport_llm_actif` = `false` pour `GN`, **sans policy
   RLS d'écriture** : l'activation exige une commande SQL délibérée, assortie
   d'un motif écrit.
2. `trg_verifier_rapport_llm_autorise` refuse l'insertion d'un rapport si le
   pays ne l'autorise pas.
3. L'Edge Function vérifie le drapeau **avant** toute extraction.

Mode démonstration accessible sur données fabriquées :

```bash
curl -H "x-cron-key: <RAPPORT_CRON_KEY>" \
  "https://ouwuirvyzmdutwfkeeoy.supabase.co/functions/v1/rapport-periodique?demo=1"
```

### Règle de conception dégagée à l'usage

> **Ce qui *doit* être vrai se code. Ce qui *peut* varier se demande au
> modèle.**

Éprouvé en conditions réelles :

- **Les comptages sont calculés** (`calculerAgregats`), pas rédigés par le
  modèle. Sur le même jeu de données, deux exécutions avaient produit deux
  répartitions différentes, toutes deux fausses. Un modèle rédige bien et
  compte mal.
- **La mention de provenance est apposée en code** (`apposerMention`), pas
  demandée dans l'invite : elle avait disparu entre deux essais.
- **Le statut `brouillon`** est le défaut du schéma : la validation humaine
  est encodée dans la base, pas dans une consigne.

Restent des consignes d'invite ce qui porte sur la formulation — ne pas citer
de fonction individuelle, ne pas écrire « le centre X a signalé ». Ces
consignes sont suivies *la plupart du temps*, pas systématiquement. **C'est
pourquoi la relecture humaine avant diffusion externe n'est pas
négociable.**

### Limite structurelle de la minimisation

`_shared/minimisation.ts` retire des identifiants de **forme** (téléphones,
emails, liens, suites de chiffres) et opère une minimisation **structurelle**
(ni `auteur_uid` ni identifiant de cas ne sortent — seul le rôle).

Il ne peut rien contre une identification par le **contexte** :
« l'infirmière de garde mardi soir » passera intact. Aucune expression
régulière ne couvrira ce cas. C'est compensé par la sortie agrégée et la
relecture humaine — **retirer l'une rouvre le risque en entier.**

### Ce qui reste avant activation, dans cet ordre

1. **Avis de l'ANSSI Guinée** sur la qualification des données au regard de la
   loi **L/2016/037/AN du 28 juillet 2016**. Lettre rédigée, à envoyer.
   Question déterminante : *après minimisation, ce qui est transmis
   constitue-t-il encore des données à caractère personnel ?*
2. **Mise à jour de `POLITIQUE_CONFIDENTIALITE.md`, de sa version hébergée et
   de `DECLARATION_SURETE_DONNEES_PLAY_STORE.md`** — qui affirment aujourd'hui
   l'absence de tout partage avec un tiers.
3. Puis seulement, activer le drapeau : la commande figure en fin de
   `supabase/migrations/20260819_configuration_pays_et_rapports.sql`.

---

## 8. Ce qui reste à faire

**Bloquant pour la mise en service**

- Recompiler l'APK et le bundle (§6).
- Créer un superviseur pour **Beyla** et un pour **Siguiri**.
- **Purger les données de test** avant l'ouverture au public.
- Envoyer le recours au support Play et la demande d'avis à l'ANSSI.

**Ensuite**

- Héberger l'APK et `installation-android.html` sur `sapsapservices.com`.
- Éprouver l'objet « action menée » sur le terrain avec un superviseur réel.
- Faire valider le vocabulaire de `type_action` par le métier.
- Refaire les captures d'écran après recompilation (elles montrent encore
  « CLM/OCASS » avec une barre oblique et l'ancien découpage).

**Dettes techniques** (voir `DETTES_SAAS.md`)

- Dette n°1 : `FROM_EMAIL` codé en dur dans 4 Edge Functions. La colonne
  `configuration_pays.from_email` existe déjà, il reste à les y câbler — à
  grouper avec la correction de la barre oblique « CLM/OCASS » qu'elles
  contiennent également, les deux imposant le même redéploiement.
- Edge Functions historiques non versionnées : `clever-service`,
  `quick-endpoint`, `super-worker` à récupérer depuis le dashboard.

---

## 9. Pièges éprouvés

- **Les migrations ne s'exécutent pas toutes seules.** Elles vivent dans
  `supabase/migrations/` mais doivent être **collées et exécutées dans le SQL
  Editor** du dashboard. À deux reprises, la requête de vérification a été
  lancée avant la migration elle-même. Toutes sont idempotentes et rejouables.
- **Déployer une Edge Function ne déploie pas la migration**, et inversement.
  Vérifier les deux côtés après tout changement touchant la base.
- **`--no-verify-jwt` est nécessaire** pour `rapport-periodique` et
  `super-worker` : elles se protègent par clé partagée, pas par jeton
  Supabase.

```bash
npx supabase functions deploy rapport-periodique --no-verify-jwt
```

- **Ordre d'écriture imposé** dans `rapport-periodique` : vérifier le drapeau
  → extraire → minimiser → appeler le modèle → enregistrer en brouillon.
  Chaque étape est le préalable de la suivante ; les réorganiser revient à
  supprimer le garde-fou correspondant. C'est commenté dans le fichier.
- **Secrets** : `android/key.properties` et `.env` sont dans `.gitignore`.
  Ne jamais les committer, ne jamais écrire de clé en dur.

---

## 10. Conventions Zida

- **Interfaces en français**, mobile-first et légères : connexions lentes et
  appareils modestes fréquents en Afrique de l'Ouest.
- **Supabase** est le backend de données unique. **Resend** pour l'email.
- Téléphones au format international : Guinée `+224`, Burkina `+226`.
- Secrets en variables d'environnement, jamais dans le code.
- Une branche par fonctionnalité ; code et CI/CD sur GitHub.

Contacts publics du dispositif : `info@sapsapservices.com` ·
`+224 61 42 67 911` · politique de confidentialité sur
`sapsapservices.com/clm-ocass/confidentialite`.
