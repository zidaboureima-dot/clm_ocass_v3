# Audit — Retrait des métadonnées EXIF/GPS des photos

**Date de l'audit :** 16 août 2026
**Projet :** CLM-OCASS (ref Supabase `ouwuirvyzmdutwfkeeoy`)
**Exigence traitée :** Livre blanc §3.3 (principes de confidentialité) —
« Aucune géolocalisation » et « Les métadonnées de localisation et d'appareil
(EXIF, GPS) sont retirées automatiquement des photos avant enregistrement ».

**Gravité :** élevée. Dans un dispositif de signalement anonyme, une photo
portant les coordonnées GPS de sa prise de vue peut désanonymiser la personne
qui signale (révéler le lieu, voire le domicile). C'est précisément le risque
de représailles que le dispositif s'attache à écarter.

---

## Faille découverte

À la vérification, l'affirmation du livre blanc était **fausse** : aucun code
ne retirait les métadonnées EXIF/GPS. Les deux canaux d'upload de photo
envoyaient le fichier **brut**, EXIF et GPS inclus :

- `PhotoService.uploaderPhoto` (photo jointe à un signalement)
- `PhotoBruteService.uploaderPhotoBrute` (photo brute déposée seule)

Confirmé par inspection binaire d'un fichier réellement uploadé dans le bucket
`photos-signalements` : présence du segment `ff e1 ... 45 78 69 66 (Exif)
4d 4d (MM)`, c.-à-d. un bloc EXIF complet.

---

## Correction

Ajout d'un utilitaire `ImageSanitizer` (`lib/services/image_sanitizer.dart`)
appelé avant chaque upload dans les deux services. Il décode l'image, **vide
explicitement l'EXIF**, puis ré-encode en JPEG sans métadonnées.

Point technique important (package `image` 4.9.1) : `decodeImage` conserve
l'EXIF attaché à l'objet image, et `encodeJpg` le **réécrit** tel quel. Décoder
et ré-encoder ne suffit donc PAS à retirer l'EXIF. Il faut le vider
explicitement avant l'encodage :

```dart
final decodee = img.decodeImage(bytes);
decodee.exif = img.ExifData();   // <-- vidage explicite, sinon EXIF réécrit
final jpgSansExif = img.encodeJpg(decodee, quality: 90);
```

**Fail-safe strict** : si l'image ne peut pas être décodée/ré-encodée,
`ImageSanitizer.nettoyer` lève une exception et l'upload est refusé, plutôt que
de risquer d'envoyer l'original avec ses métadonnées. Mieux vaut un dépôt qui
échoue (l'usager réessaie) qu'une photo qui fuite sa localisation.

---

## Preuve de test (avant / après)

Photo prise avec géolocalisation active, déposée via l'app, puis fichier
récupéré depuis le bucket `photos-signalements` et inspecté (inspecteur de
métadonnées binaire).

**Avant correction** (fichier du bucket) :
- Taille : 683.33 KB
- En-tête : `ff d8 ff e0 ... JFIF ... ff e1 03 00 45 78 69 66 (Exif) 4d 4d (MM)`
- → bloc EXIF présent (GPS potentiel).

**Après correction** (nouveau fichier du bucket, même scène) :
- Taille : 763.21 KB (ré-encodage effectif — taille différente, preuve que le
  sanitizer a bien tourné)
- En-tête : `ff d8 ff e0 ... JFIF ... ff e2 ... 49 43 43 (ICC_PROFILE)`
- → plus aucun segment `ff e1`/EXIF. Seul subsiste un profil colorimétrique
  ICC (APP2), sans donnée personnelle.

Le bloc EXIF (et donc toute coordonnée GPS) a disparu du fichier produit. La
correction s'applique aux **deux** canaux (photo jointe et photo brute).

---

## Conclusion

L'affirmation du livre blanc « aucune géolocalisation / métadonnées EXIF-GPS
retirées » est désormais **vraie et vérifiable** sur les fichiers réellement
enregistrés. Correction couvrant l'intégralité des points d'upload de photo.

## Note de non-régression pour les évolutions futures

Tout nouveau point d'upload de photo devra passer par `ImageSanitizer.nettoyer`
avant `storage.upload`. Ne jamais uploader un `File` image brut directement.
