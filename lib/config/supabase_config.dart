import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ouwuirvyzmdutwfkeeoy.supabase.co';
  static const String publishableKey = 'sb_publishable_Q0BBZCvVWRRXKxfCou5dxw_9jo1LgVB';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
