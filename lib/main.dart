import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
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

        return const LoggedInPlaceholderScreen();
      },
    );
  }
}

class LoggedInPlaceholderScreen extends StatelessWidget {
  const LoggedInPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = SupabaseConfig.isConfigured
        ? Supabase.instance.client.auth.currentUser?.email
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthCore'),
        backgroundColor: const Color(0xFF0756A8),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.health_and_safety,
                size: 88,
                color: Color(0xFF0756A8),
              ),
              const SizedBox(height: 20),
              const Text(
                'You are logged in',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF001D4B),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (email != null) ...[
                const SizedBox(height: 8),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              const SizedBox(height: 28),
              const Text(
                'This is the starting screen for authenticated users. '
                'The full dashboard can be connected here as the app grows.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0756A8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
