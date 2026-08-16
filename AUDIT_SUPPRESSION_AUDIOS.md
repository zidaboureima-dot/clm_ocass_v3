# Audit — Effectivité de la suppression des audios

**Date de l'audit :** 16 août 2026
**Projet :** CLM-OCASS (ref Supabase `ouwuirvyzmdutwfkeeoy`)
**Exigence traitée :** Livre blanc §3.3 et §9, Plan technique §4 (ligne 5) et §7 —
« la suppression de l'audio après écoute doit être effective et vérifiable au
niveau du stockage, non un simple masquage d'affichage ».

---

## Deux natures d'audio, deux règles de conservation

Le dispositif manipule **deux types d'audio distincts**, qui ne suivent pas la
même politique de conservation. La distinction est structurelle, pas accidentelle.

### Type 1 — Audio joint à un signalement (CONSERVÉ)
- Service : `AudioService` (`lib/services/audio_service.dart`)
- Table : `audios` · Bucket : `audios-signalements`
- Chemin : `{signalementId}/audio.m4a`
- Nature : pièce jointe **volontaire** d'un signalement structuré, au même titre
  que la photo ou la description. Fait partie du dossier de traitement ; le
  superviseur et le point focal doivent pouvoir la réécouter pour traiter le cas.
- Politique : **conservé** tant que le signalement existe. `AudioService` n'a
  donc pas de méthode de suppression — c'est volontaire, pas un manque.
- Piste future (gouvernance, non implémentée) : définir une durée de conservation
  après **clôture** du signalement, pour minimiser la rétention de données
  vocales, en alignement avec la loi nationale (Guinée : L/2016/037/AN).

### Type 2 — Message vocal brut seul (DÉTRUIT après traitement)
- Service : `MessageVocalService` (`lib/services/message_vocal_service.dart`)
- Table : `messages_vocaux_bruts` · Bucket : `audios-signalements` (préfixe `bruts/`)
- Chemin : `bruts/{timestamp}/audio.m4a`
- Nature : vocal déposé **sans** signalement. La voix est une donnée biométrique
  identifiante ; le brut n'a pas vocation à être conservé. L'admin l'écoute, le
  transforme en signalement structuré et anonymisé, puis le brut est détruit.
- Politique : **détruit** dès transformation en signalement (« Modèle A » de
  confidentialité cité dans le code).

---

## Mécanisme de suppression vérifiée (Type 2)

La méthode `marquerTraite()` de `MessageVocalService` applique une suppression
**effective et vérifiée**, dans cet ordre strict :

1. **Supprimer le fichier du bucket en premier** (`storage.from(bucket).remove([chemin])`).
2. **Vérifier que la suppression a réellement eu lieu.** Point critique :
   `storage.remove()` de Supabase **ne lève pas d'exception** si le fichier est
   introuvable — il renvoie une liste (vide si rien supprimé). Le code vérifie
   donc explicitement `supprimes.any((obj) => obj.name == cheminStockage)` et
   **lève une exception qui annule tout le traitement** si la suppression n'est
   pas confirmée (« Traitement annulé pour ne pas laisser croire à une
   suppression non effectuée »).
3. **Seulement si la suppression est confirmée** : marquer le message `traite`,
   le lier au `signalement_id`, et **vider `chemin_stockage` (mis à `null`)**
   pour ne plus pointer vers un fichier inexistant.

Conséquence : il est **impossible** qu'un message soit marqué `traite` sans que
son fichier audio ait été réellement détruit du stockage.

---

## Vérification sur les données de production (16/08/2026)

### Requête 1 — État des messages vocaux bruts vs leur fichier
```sql
SELECT id, chemin_stockage, statut, signalement_id, created_at
FROM messages_vocaux_bruts
ORDER BY created_at;
```

Résultat : 8 lignes.
- **6 messages `traite`** (juillet–août) : tous avec `chemin_stockage = null` et
  un `signalement_id` renseigné. → fichier détruit, chemin vidé, lié au
  signalement. Conforme.
- **2 messages `nouveau`** (13 et 14 août) : `chemin_stockage` renseigné
  (`bruts/...`), `signalement_id = null`. → vocaux **en attente de traitement**,
  présence légitime, seront détruits à la transformation.

### Requête 2 — Contenu réel du bucket
```sql
SELECT name, created_at FROM storage.objects
WHERE bucket_id = 'audios-signalements'
ORDER BY created_at;
```

Résultat : 6 objets, tous justifiés :
- 3 × `{uuid}/audio.m4a` → audios Type 1 (joints à signalements, conservés).
- 2 × `bruts/{timestamp}/audio.m4a` → vocaux Type 2 `nouveau` en attente.
- 1 × `bruts/.emptyFolderPlaceholder` → marqueur de dossier vide (inoffensif).

### Recoupement
Les 2 fichiers `bruts/` du bucket correspondent **exactement** aux 2 lignes
`statut = 'nouveau'`. Aucun message `traite` n'a de fichier résiduel. Aucun
fichier orphelin (sans ligne correspondante). Aucune contradiction.

---

## Conclusion

L'effectivité de la suppression des audios bruts est **confirmée** :
- garantie **par le code** (`marquerTraite` refuse de marquer traité si la
  suppression du stockage n'est pas vérifiée) ;
- confirmée **par les données** (tous les messages traités ont `chemin_stockage
  = null` et plus aucun fichier dans le bucket ; seuls les vocaux non traités
  conservent leur fichier, en attente légitime).

L'exigence du livre blanc est satisfaite. Aucune correction de code n'est
requise.

## Amélioration recommandée pour le chantier SaaS multi-tenant

En production mono-pays, l'audit manuel ci-dessus suffit. En multi-tenant, où
l'audit à la main de chaque pays n'est plus praticable, prévoir un **contrôle
d'intégrité récurrent** détectant tout futur résidu, par exemple :
- un message `statut = 'traite'` avec `chemin_stockage` non `null` (anomalie) ;
- un fichier `bruts/` du bucket sans ligne `messages_vocaux_bruts` correspondante
  (orphelin de stockage).
