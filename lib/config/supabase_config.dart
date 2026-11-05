import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://googertfgiyanznyazbo.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_LJdVUGg5M3HxWjppgXfg8A_WJyZXhh2',
  );

  static bool get isConfigured => publishableKey.isNotEmpty;

  static Future<void> initialize() {
    return Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }
}
