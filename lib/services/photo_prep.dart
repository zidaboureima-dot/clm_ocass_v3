import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

Future<File> preparerPhoto(File original) async {
  final bytes = await original.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return original;

  final redimensionnee = decoded.width > 1600 ? img.copyResize(decoded, width: 1600) : decoded;
  final jpg = img.encodeJpg(redimensionnee, quality: 82);

  final dossier = await getTemporaryDirectory();
  final chemin = '${dossier.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final fichier = File(chemin);
  await fichier.writeAsBytes(jpg);
  return fichier;
}
