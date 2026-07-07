import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String publishableKey = 'YOUR_ANON_KEY';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
