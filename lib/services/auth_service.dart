import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  AuthService._internal();

  factory AuthService() => _instance;

  Future<UserProfile?> login(String email, String password) async {
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) return await getUserProfile(response.user!.id);
      return null;
    } catch (e) {
      throw Exception('Erreur login: $e');
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final response = await SupabaseConfig.client.from('users').select().eq('id', uid).single();
      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  bool isLoggedIn() => SupabaseConfig.client.auth.currentUser != null;

  Future<void> logout() async {
    await SupabaseConfig.client.auth.signOut();
  }
}
