# Cadrage — Robustesse avant distribution

**Statut :** points 1 (mode maintenance), 2 (états d'erreur) et 3
(pagination) **mis en œuvre** le 5 octobre 2026. Restent les points 4
(tolérance réseau) et 5 (vérification des états vides).
**Date :** 5 octobre 2026. Constat établi au commit `5e70f46`.

Ce document cadre cinq points de robustesse soulevés avant la distribution de
l'application : mode maintenance, états d'erreur, états vides, pagination
côté serveur, et tolérance aux coupures réseau.

---

## 1. Pourquoi ces points comptent plus que d'habitude

Tant que l'application est distribuée en APK en téléchargement direct, **il
n'y a pas de mise à jour automatique**. Chaque correctif suppose de refaire
circuler le fichier auprès de points focaux dispersés et d'obtenir qu'ils le
réinstallent.

Cela inverse l'arbitrage habituel. Ailleurs on livre et on itère ; ici, ce qui
n'est pas dans le binaire au moment de la distribution coûtera dix fois plus
cher à corriger. Deux familles de problèmes méritent donc une attention
disproportionnée :

- ce qui **se dégrade tout seul** sans rien casser (la pagination) ;
- ce qui **ne peut être réparé qu'à distance** (le mode maintenance).

---

## 2. Constat vérifié

| Point | État |
| --- | --- |
| Mode maintenance | ~~**Absent.** Aucun interrupteur, aucun drapeau~~ → **fait** le 5 octobre 2026 (§3.5) |
| États d'erreur | ~~**Partiel.**~~ → **fait** le 5 octobre 2026 (§5). Le constat initial était optimiste : voir ci-dessous |
| États vides | **Fait.** 16 messages couvrant les listes qui comptent |
| Pagination serveur | ~~**Absente.**~~ → **fait** le 5 octobre 2026 (§4.4) |
| Tolérance réseau | **Absente.** Ni détection de coupure, ni réessai |

**Détail sur les états d'erreur — le constat initial était trop optimiste.**

Le dénombrement du 5 octobre au matin comptait « 8 `hasError` sur 16
builders ». Le décompte exact est **12 builders**, et surtout : parmi les sept
qui testaient `hasError`, **cinq ne l'atteignaient jamais.**

Deux schémas défaillants, pas un seul :

*Schéma A — aucune branche d'erreur* (5 builders : `admin_accounts_tab`,
`admin_messages_vocaux_tab`, `admin_photos_tab`, `signalement_detail_screen`
×2) :

```dart
if (!snapshot.hasData) {
  return const Center(child: CircularProgressIndicator());
}
```

*Schéma B — branche d'erreur inatteignable* (5 builders :
`admin_dashboard_screen`, `superviseur_dashboard_screen`,
`point_focal_dashboard_screen`, `admin_categories_tab`,
`admin_demandes_reset_tab`) :

```dart
if (!snapshot.hasData) {
  return const Center(child: CircularProgressIndicator());   // ← sort ici
}
if (snapshot.hasError) {
  return Center(child: Text('Erreur : ${snapshot.error}'));  // ← jamais atteint
}
```

**En erreur, `hasData` est faux.** Le premier test sort donc avec le chargeur,
et la branche d'erreur est du code mort. Elle existe, elle se relit comme une
protection lors d'une revue, et elle ne s'affiche jamais. C'est pire que son
absence : elle rassure.

Résultat identique dans les deux cas : **l'indicateur de chargement tourne
indéfiniment.** En contexte de connexion instable, c'est le pire retour
possible — un chargement perpétuel est indiscernable d'une lenteur, donc
l'utilisateur attend au lieu de réessayer.

Deux builders étaient corrects : `stats_body.dart` et `stats_body_public.dart`
— les deux écrans citoyens, testés en premier, et les seuls où l'ordre avait
été écrit dans le bon sens.

---

## 3. Mode maintenance

### 3.1 Le problème que ça résout

Sans mise à jour automatique, une anomalie découverte après distribution n'a
aucun remède rapide. Un interrupteur lisible à distance permet de suspendre le
service le temps d'une migration délicate, d'une réparation, ou en cas de
découverte d'une faille — sans courir après les téléphones.

### 3.2 Obstacle identifié : la configuration n'est pas lisible publiquement

`configuration_pays` n'expose qu'une policy `SELECT` réservée à
`role_du_demandeur() = 'admin'`. L'application d'un citoyen, qui n'a aucun
compte, ne peut donc rien y lire.

**Solution retenue : une vue publique**, sur le modèle de `stats_publiques`
qui joue déjà exactement ce rôle pour les statistiques. Elle n'expose que ce
qui doit l'être :

```sql
create or replace view public.etat_service as
  select pays_code, service_actif, service_message
    from public.configuration_pays;
```

Lire la table entière exposerait `from_email` et `rapport_llm_motif`, sans
rapport avec le besoin. La vue est la frontière.

### 3.3 Principe directeur : échouer en position ouverte

**Si la lecture du drapeau échoue, l'application considère le service comme
actif.** C'est contre-intuitif pour un interrupteur de sécurité, et c'est
pourtant le seul choix défendable : dans le cas inverse, une simple coupure
réseau verrouillerait l'application pour tout le monde, y compris pour des
gens qui n'ont qu'une fenêtre de connexion par jour.

Un interrupteur de maintenance protège d'un incident connu. Il ne doit pas en
créer un nouveau.

### 3.4 Décision prise le 5 octobre 2026 : le citoyen n'est jamais bloqué

Bloquer les tableaux de bord des responsables pendant une maintenance est sans
conséquence : le travail reprend après.

Bloquer le dépôt d'un signalement n'est pas équivalent. Une personne qui a pris
le risque de venir signaler un refus de soins, et qui tombe sur un écran de
maintenance, ne reviendra pas forcément. **Le signalement est perdu, et avec
lui la confiance.**

**Décision retenue : l'interrupteur bloque les tableaux de bord, et eux
seuls.** Le dépôt citoyen n'écrit que dans `signalements` via une fonction
dédiée ; c'est justement le chemin le plus simple et le moins susceptible
d'être en cause lors d'une maintenance. Les dépôts s'accumulent pendant la
fenêtre et sont traités à la reprise.

### 3.5 Mise en œuvre — faite le 5 octobre 2026

- Migration `20261005_mode_maintenance.sql` : colonnes
  `service_actif boolean not null default true` et `service_message text`
  dans `configuration_pays`, vue `etat_service` lisible par `anon` et
  `authenticated`.
- **Aucune policy d'écriture** : bascule par commande SQL délibérée, comme
  `rapport_llm_actif`. Une case à cocher dans une interface invite à l'oubli —
  et un service laissé coupé par distraction est une panne que personne ne
  diagnostique. Les deux commandes `update` figurent en commentaire dans la
  migration.
- `lib/services/etat_service_service.dart` : lecture avec délai de 5 secondes,
  **échec en position ouverte**.
- `lib/screens/maintenance_screen.dart` : écran sobre affichant
  `service_message` quand il est renseigné, et rappelant que les signalements
  citoyens continuent d'arriver.
- Branchement dans `login_screen.dart`, après la vérification de
  `profil.actif`.

Deux points de mise en œuvre méritent d'être consignés, parce qu'ils ne se
devinent pas à la lecture du code :

**L'administrateur est exempté.** C'est lui qui conduit la maintenance ; le
bloquer l'obligerait à rouvrir le service sans avoir pu vérifier que tout est
rentré dans l'ordre.

**La vérification a lieu à la connexion, pas en continu.** Un responsable déjà
dans son tableau de bord au moment de la bascule n'en est pas éjecté. C'est
assumé : l'interrupteur sert à empêcher d'entrer pendant une fenêtre
annoncée, pas à arracher un écran des mains de quelqu'un. Si un incident
impose de couper l'accès immédiatement, c'est le rôle des policies RLS, pas
celui de cet interrupteur.

---

## 4. Pagination côté serveur

### 4.1 Le problème

Chaque tableau de bord ouvre un flux temps réel sur la table entière :
`streamToutesSignalements()`, `streamSignalementsParRegion()`,
`streamSignalementsParPrefecture()`, `streamSignalementsAssignes()`, et la
liste des comptes.

À 59 signalements, tout va bien. À 2 000, un superviseur sur un téléphone
modeste en 3G attend. À 10 000, l'écran administrateur devient inutilisable.
**Rien n'alertera entre-temps** : ça ne casse pas, ça ralentit — et le profil
d'appareil et de connexion visé par le projet est précisément celui qui
encaisse le moins bien.

### 4.2 Arbitrage tranché le 5 octobre 2026 : les deux, séparés

Les deux ne se cumulent pas simplement. Le flux temps réel de Supabase pousse
chaque ligne correspondant au filtre ; une pagination par `.range()` suppose
une lecture ponctuelle, sans abonnement.

| Option | Ce qu'on gagne | Ce qu'on perd |
| --- | --- | --- |
| Flux borné par `.limit(n)` | Correction minimale, temps réel conservé | On ne voit que les n plus récents, jamais l'historique |
| Pagination `.select().range()` | Historique accessible, charge maîtrisée | Plus de mise à jour automatique : il faut rafraîchir |
| Les deux, séparés | Temps réel sur les cas actifs, historique paginé à côté | Deux chemins de code à maintenir |

*Recommandation : la troisième.* Le travail quotidien d'un superviseur porte
sur les cas ouverts — peu nombreux par nature, et c'est là que le temps réel a
de la valeur. L'historique se consulte, il n'a pas besoin de se mettre à jour
sous les yeux. Cette séparation reflète d'ailleurs l'usage réel mieux qu'une
liste unique.

### 4.3 Périmètre

Tableaux de bord administrateur, superviseur, point focal, et liste des
comptes. Les annotations et actions menées d'un cas ne sont pas concernées :
leur volume est borné par le cas lui-même.

### 4.4 Mise en œuvre — faite le 5 octobre 2026

**Ce que `limit()` fait réellement, vérifié.** Dans
`supabase_stream_builder.dart` du paquet `supabase` 2.14.0 — la version que
verrouille `pubspec.lock` — la limite est appliquée **côté serveur** sur la
requête initiale, puis ré-appliquée côté client à chaque émission. Borner un
flux réduit donc réellement la charge réseau ; ce n'est pas un rognage
d'affichage. Ce point conditionnait tout le reste, il ne pouvait pas rester une
supposition.

**La contrainte qui a changé la forme retenue.** Un flux Supabase n'accepte
**qu'un seul filtre serveur**, déjà pris par `region` chez le superviseur et
`assignee_uid` chez le point focal. Le statut ne peut donc pas y être filtré
côté serveur — le cadrage du matin supposait à tort qu'on pourrait borner sur
« cas ouverts ». Les filtres de statut des tableaux de bord restent donc
**côté client**, à l'intérieur de la fenêtre des 100 plus récents.

**Conséquence, et la seule réponse honnête.** Une liste tronquée qui ne le dit
pas est un mensonge d'interface : filtrer sur « Clôturé » peut afficher trois
cas alors qu'il en existe quatre cents, et l'utilisateur ne compte pas les
lignes, il fait confiance à ce qu'il voit. D'où `BandeauHistorique`, affiché en
permanence sous les filtres — **pas seulement quand la troncature mord**, pour
que personne n'ait à se demander dans quel régime il se trouve.

**L'historique.** `HistoriqueSignalementsScreen` interroge le serveur par
pages de 25, avec tous les filtres appliqués côté serveur, et sans temps réel.
Le périmètre y suit le rôle, mais ces filtres servent le confort de lecture :
**le périmètre opposable reste celui des policies RLS.** Un filtre oublié
n'ouvre rien ; une policy manquante ouvrirait tout.

### 4.5 L'effet de bord qu'il ne fallait pas laisser passer

`streamSignalementsParRegion` et `streamSignalementsParPrefecture`
n'alimentaient pas que les tableaux de bord : **les écrans de statistiques
consommaient les mêmes méthodes.** Les borner aurait fait afficher
« 12 clôturés » au lieu de 400, sans rien signaler.

Trois flux explicitement non bornés ont donc été isolés —
`streamToutesSignalementsPourStats`, `…ParRegionPourStats`,
`…ParPrefecturePourStats` — et le suffixe dit pourquoi ils échappent à la
règle. Mieux vaut un écran lent qu'un écran qui ment.

Ils restent le chemin le plus lourd du dispositif. La vraie réponse est une
agrégation côté serveur, inscrite en **dette n°9** dans `DETTES_SAAS.md` plutôt
que laissée implicite.

---

## 5. États d'erreur — fait le 5 octobre 2026

`lib/widgets/etat_erreur.dart` : un widget partagé plutôt que dix variantes.
Il distingue trois situations que l'utilisateur ne doit pas confondre :

- **chargement** — en cours, patienter ;
- **vide** — tout va bien, il n'y a rien à afficher ;
- **erreur** — quelque chose a échoué, voici quoi faire.

Avant, la troisième était absorbée par la première — le pire des mélanges.

### 5.1 L'ordre des tests est la correction de fond

`hasError` se teste **avant** `hasData`, dans les douze builders. C'est la
part la plus importante du changement, et la moins visible : cinq branches
d'erreur existaient déjà et n'étaient jamais atteintes (§2).

### 5.2 Le texte de l'exception n'est plus affiché

Les écrans montraient `Erreur : ${snapshot.error}`. Deux raisons d'arrêter :

1. Le destinataire est un point focal ou un superviseur, pas un développeur.
   « PostgrestException(message: JWT expired…) » ne lui dit pas quoi faire.
2. Le texte d'une exception Postgrest cite des noms de tables, de colonnes et
   de policies. C'est de l'information sur l'architecture, affichée sur un
   appareil qui peut être consulté par un tiers.

Le diagnostic appartient aux journaux du serveur, pas à l'écran.

### 5.3 Le réessai reconstruit le flux

Un flux Supabase interrompu ne reprend pas de lui-même. Chaque écran concerné
expose donc un `_recharger()` qui **réaffecte** `_stream` dans un `setState`,
plutôt qu'un simple rafraîchissement d'affichage qui ne rouvrirait rien.

Sur `signalement_detail_screen`, les flux sont construits dans `build()` : un
`setState(() {})` suffit, et l'erreur s'affiche en version compacte — le reste
de l'écran s'est affiché correctement, seule une section a échoué.

### 5.4 Ce qui n'a pas été touché

`stats_body.dart` et `stats_body_public.dart`, déjà corrects, gardent leur
formulation (« Statistiques momentanément indisponibles ») et leur propre
bouton de réessai. Ce sont les écrans citoyens : les uniformiser pour la seule
cohérence aurait ajouté du risque sans rien apporter.

---

## 6. États vides

**Rien à faire.** Les seize messages existants couvrent les listes qui
comptent, et certains vont au-delà du strict minimum — celui du point focal
explique *pourquoi* la liste est vide et *ce qui va se passer* : « Le
superviseur vous assignera les signalements de votre préfecture. » C'est le
bon niveau.

Une vérification suffira après la pagination, pour s'assurer qu'un état vide
ne se confond pas avec une page suivante inexistante.

---

## 7. Tolérance aux coupures réseau — et son conflit avec l'anonymat

### 7.1 Le problème

Aucune détection de perte de connexion, aucun réessai. Si l'envoi d'un
signalement échoue depuis un centre de santé mal couvert, le signalement est
perdu — et la personne qui a pris un risque pour venir le déposer repart sans
rien.

C'est, des cinq points, celui qui détruit de la donnée.

### 7.2 Pourquoi la solution évidente ne convient pas

Le réflexe serait une file d'attente locale : stocker le signalement sur
l'appareil, le renvoyer à la reconnexion. `shared_preferences` est déjà une
dépendance du projet.

**Mais cela crée exactement la trace que tout le dispositif s'emploie à ne pas
produire.** Un signalement en attente sur le téléphone, c'est le contenu d'une
dénonciation stocké sur l'appareil de la personne qui dénonce. Si ce téléphone
est consulté — par un employeur, un proche, une autorité — le lien est fait.

Le projet est déjà conscient de ce risque : le commentaire de
`marqueur_appareil.dart` précise que le marqueur « ne doit jamais être stocké
avec un signalement ni servir à tracer ». Une file d'attente locale
franchirait précisément cette ligne.

### 7.3 Pistes compatibles avec le modèle de confidentialité

- **Réessai en mémoire seulement**, le temps que l'écran reste ouvert : ne
  survit pas à la fermeture de l'application, donc ne laisse aucune trace.
  Couvre la coupure brève, pas l'absence prolongée de réseau.
- **Détection et message explicite** : dire clairement que l'envoi a échoué et
  que le signalement n'a pas été enregistré, plutôt que d'échouer en silence.
  Ne sauve pas la donnée, mais évite de laisser croire qu'elle est partie.
- **File chiffrée et purgée agressivement** — effacée après envoi, et au bout
  d'un délai court même sans envoi. Réduit la fenêtre d'exposition sans la
  supprimer. À n'envisager que si le terrain montre que les pertes sont
  fréquentes.

*Recommandation : les deux premières d'abord.* Elles n'ont aucun coût en
confidentialité. La troisième est un arbitrage entre perdre des signalements
et exposer leurs auteurs — il ne se tranche pas sans données de terrain.

---

## 8. Séquencement proposé

1. ~~**Mode maintenance**~~ — **fait le 5 octobre 2026.** Peu de code,
   infrastructure déjà présente, et c'est le filet de sécurité qui rend tout
   le reste moins risqué.
2. ~~**États d'erreur**~~ — **fait le 5 octobre 2026.** Widget partagé, dix
   branchements, et surtout l'ordre des tests corrigé dans les douze builders.
3. ~~**Pagination**~~ — **fait le 5 octobre 2026.** Le plus de travail, et le
   seul qui se dégradait tout seul sans jamais rien casser.
4. **Tolérance réseau**, niveaux 1 et 2 — réessai en mémoire et message franc.
5. **États vides** — vérification après la pagination.

---

## 9. Décisions

**Tranchées le 5 octobre 2026 :**

- **Maintenance** (§3.4) — bloque les tableaux de bord des responsables
  seulement. Le dépôt citoyen n'est jamais interrompu.
- **Pagination** (§4.2) — les deux chemins séparés : temps réel borné sur les
  cas ouverts, historique paginé à côté.
- **File d'attente locale** (§7.3) — **exclue.** Stocker une dénonciation en
  attente sur le téléphone de la personne qui dénonce crée exactement la
  trace que le dispositif s'emploie à ne pas produire. Retenus : réessai en
  mémoire et message d'échec explicite.

Aucune décision n'est en attente. Prochaine étape : les états d'erreur (§5).
