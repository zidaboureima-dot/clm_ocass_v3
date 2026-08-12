import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Marqueur d'appareil anonyme, utilisé UNIQUEMENT pour le rate-limit des
/// dépôts. UUID aléatoire généré au premier lancement, stocké localement.
/// Non-identifiant : aucun lien avec l'identité, le numéro ou la localisation.
/// Ne doit jamais être stocké avec un signalement ni servir à tracer.
Future<String> obtenirMarqueurAppareil() async {
  final prefs = await SharedPreferences.getInstance();
  var marqueur = prefs.getString('marqueur_appareil');
  if (marqueur == null) {
    marqueur = const Uuid().v4();
    await prefs.setString('marqueur_appareil', marqueur);
  }
  return marqueur;
}