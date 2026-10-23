import 'package:flutter/material.dart';

import 'config/supabase_config.dart';
import 'screens/fitness_survey_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/fitness_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await SupabaseConfig.initialize();
  }
  runApp(const HealthCoreApp());
}

class HealthCoreApp extends StatelessWidget{
  const HealthCoreApp({super.key});

  @override
  Widget build(BuildContext context){
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HealthCore',
      // You can change the home to what you want to test,
      // I might add a seperate tester main later on.
      home: WelcomeScreen(),
    );
  }
}
