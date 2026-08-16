import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Nettoyage des métadonnées sensibles (EXIF, GPS) des photos avant upload.
///
/// Confidentialité (principe fondateur du dispositif) : AUCUNE géolocalisation.
/// Une photo prise par un téléphone embarque, dans ses métadonnées EXIF, les
/// coordonnées GPS du lieu de prise de vue et des informations d'appareil.
/// Dans un dispositif de signalement, ces métadonnées peuvent désanonymiser
/// la personne qui signale (révéler où elle était, voire son domicile). Elles
/// DOIVENT être retirées avant tout enregistrement.
///
/// Méthode : on décode l'image en pixels bruts (le décodage ne conserve pas
/// l'EXIF), puis on ré-encode en JPEG. L'image ré-encodée ne contient plus
/// aucune métadonnée EXIF/GPS d'origine.
class ImageSanitizer {
  /// Retourne un nouveau File JPEG débarrassé de ses métadonnées EXIF/GPS.
  ///
  /// FAIL-SAFE STRICT : si l'image ne peut pas être décodée / ré-encodée,
  /// on lève une exception plutôt que de risquer d'uploader l'original avec
  /// ses métadonnées. Pour un outil de lanceur d'alerte, mieux vaut un dépôt
  /// qui échoue (l'usager réessaie) qu'une photo qui fuite sa localisation.
  static Future<File> nettoyer(File source) async {
    final bytes = await source.readAsBytes();

    final decodee = img.decodeImage(bytes);
    if (decodee == null) {
      throw Exception(
        "Image illisible : nettoyage des métadonnées impossible, "
        "upload refusé par sécurité.",
      );
    }

    // decodeImage conserve l'EXIF attaché à l'objet image ; encodeJpg le
    // réécrirait tel quel (y compris le GPS). On remplace donc l'EXIF par
    // un bloc VIDE avant ré-encodage, pour garantir qu'aucune métadonnée
    // de localisation ou d'appareil ne subsiste dans le fichier produit.
    decodee.exif = img.ExifData();

    // Ré-encodage JPEG sans métadonnées EXIF/GPS. La qualité 90 conserve
    // une bonne lisibilité tout en réduisant le poids.
    final jpgSansExif = img.encodeJpg(decodee, quality: 90);

    // Écriture dans un fichier temporaire dédié.
    final dir = await getTemporaryDirectory();
    final cible = File(
      '${dir.path}/clean_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await cible.writeAsBytes(jpgSansExif, flush: true);
    return cible;
  }
}