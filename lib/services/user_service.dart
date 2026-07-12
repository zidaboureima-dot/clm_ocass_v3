import '../config/supabase_config.dart';
import '../models/user_profile_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();

  UserService._internal();

  factory UserService() => _instance;

  Future<List<UserProfile>> obtenirPointsFocauxParPrefecture(String prefecture) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('role', 'point_focal')
          .eq('prefecture', prefecture)
          .eq('actif', true);
      return (response as List).map((j) => UserProfile.fromJson(j)).toList();
    } catch (e) {
      throw Exception('Erreur chargement points focaux: $e');
    }
  }

  Stream<List<UserProfile>> streamComptesGeres() {
    return SupabaseConfig.client
        .from('users')
        .stream(primaryKey: ['id'])
        .order('nom', ascending: true)
        .map((rows) => rows
            .where((r) => r['role'] == 'superviseur' || r['role'] == 'point_focal')
            .map((r) => UserProfile.fromJson(r))
            .toList());
  }

  Future<void> basculerActifCompte(String id, bool actif) async {
    try {
      await SupabaseConfig.client.from('users').update({'actif': actif}).eq('id', id);
    } catch (e) {
      throw Exception('Erreur mise à jour compte: $e');
    }
  }

  Future<void> creerCompte({
    required String email,
    required String role,
    required String nom,
    String? region,
    String? prefecture,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'quick-endpoint',
        body: {
          'email': email,
          'role': role,
          'nom': nom,
          'region': region,
          'prefecture': prefecture,
        },
      );
      final data = response.data;
      if (data is Map && data['ok'] != true) {
        throw Exception(data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      throw Exception('Erreur création du compte: $e');
    }
  }

  Future<UserProfile?> obtenirUtilisateur(String uid) async {
    try {
      final response = await SupabaseConfig.client.from('users').select().eq('id', uid).maybeSingle();
      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
