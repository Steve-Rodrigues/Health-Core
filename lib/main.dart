import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/fitness_dashboard_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await SupabaseConfig.initialize();
  }
  runApp(const HealthCoreApp());
}

class HealthCoreApp extends StatelessWidget {
  const HealthCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HealthCore',
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return const WelcomeScreen();
    }

    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;

        if (session == null) {
          return const WelcomeScreen();
        }

        return const FitnessDashboardScreen();
      },
    );
  }
}
