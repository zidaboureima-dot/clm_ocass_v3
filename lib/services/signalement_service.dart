import '../config/supabase_config.dart';
import '../models/signalement_model.dart';

class SignalementService {
  static final SignalementService _instance = SignalementService._internal();

  SignalementService._internal();

  factory SignalementService() => _instance;

  Future<void> creerSignalement(Signalement signalement) async {
    try {
      final data = signalement.toJson();
      await SupabaseConfig.client.from('signalements').insert(data);
    } catch (e) {
      throw Exception('Erreur creation: $e');
    }
  }

  Future<List<Signalement>> obtenirSignalements() async {
    try {
      final response = await SupabaseConfig.client
          .from('signalements')
          .select()
          .order('soumis_le', ascending: false);
      return (response as List).map((json) => Signalement.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur recuperation: $e');
    }
  }

  /// Flux temps réel de tous les signalements. Se met à jour automatiquement
  /// à chaque insertion/modification côté Supabase (nécessite que la
  /// réplication Realtime soit activée sur la table `signalements`).
  Stream<List<Map<String, dynamic>>> streamSignalements() {
    return SupabaseConfig.client.from('signalements').stream(primaryKey: ['id']);
  }

  /// Calcule les compteurs affichés sur la page d'accueil à partir d'une
  /// liste brute de signalements (utilisé avec [streamSignalements]).
  Map<String, int> calculerStats(List<Map<String, dynamic>> lignes) {
    return {
      'total': lignes.length,
      'en_cours': lignes.where((l) => l['statut'] == 'en_cours').length,
      'traites': lignes.where((l) => l['statut'] == 'traite').length,
      'clotures': lignes.where((l) => l['statut'] == 'cloture').length,
    };
  }
}
