import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static bool _initialized = false;

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://googertfgiyanznyazbo.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_LJdVUGg5M3HxWjppgXfg8A_WJyZXhh2',
  );

  static bool get isConfigured => publishableKey.isNotEmpty;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    _initialized = true;
  }
}
