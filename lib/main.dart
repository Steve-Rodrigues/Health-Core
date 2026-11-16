import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/fitness/fitness_screen.dart';
import 'screens/auth/welcome_screen.dart';

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
    const fitnessBlue = Color(0xFF086AC7);
    const fitnessNavy = Color(0xFF062D63);
    const fitnessPaleBlue = Color(0xFFE5F4FF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HealthCore',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: fitnessBlue,
          primary: fitnessBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: fitnessPaleBlue,
        appBarTheme: const AppBarTheme(
          backgroundColor: fitnessNavy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: fitnessBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
        ),
      ),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured || !SupabaseConfig.isInitialized) {
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

        return const FitnessScreen();
      },
    );
  }
}
