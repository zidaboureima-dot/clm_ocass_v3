import '../config/supabase_config.dart';
import '../models/signalement_model.dart';

class SignalementService {
  static final SignalementService _instance = SignalementService._internal();

  SignalementService._internal();

  factory SignalementService() => _instance;

  Future<String> creerSignalement(Signalement signalement) async {
    try {
      final data = signalement.toJson();
      final response = await SupabaseConfig.client
          .from('signalements')
          .insert(data)
          .select()
          .single();
      return response['id'];
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

  Future<Map<String, dynamic>> obtenirStats() async {
    try {
      final total = await SupabaseConfig.client
          .from('signalements')
          .select()
          .count();
      final traites = await SupabaseConfig.client
          .from('signalements')
          .select()
          .eq('statut', 'traite')
          .count();
      return {'total': total.count, 'traites': traites.count};
    } catch (e) {
      throw Exception('Erreur stats: $e');
    }
  }
}
