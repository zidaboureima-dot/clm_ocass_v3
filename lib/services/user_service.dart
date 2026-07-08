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
