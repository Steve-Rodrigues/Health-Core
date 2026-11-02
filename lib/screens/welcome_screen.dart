import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'create_account_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0756A8),
              Color(0xFF003A80),
              Color(0xFF001D4B),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 25,
            ),
            child: Column(
              children: [
                const SizedBox(height: 35),

                // Welcome heading with HealthCore logo
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 45,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F7FC),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: Colors.black,
                          width: 6,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'Welcome to\nHealthCore',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: Colors.black,
                            ),
                          ),

                          SizedBox(height: 15),

                          Text(
                            'Get Started Today',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: -15,
                      right: -10,
                      child: Image.asset(
                        'web/icons/Logo.webp',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 85),

                // LOGIN BUTTON
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F7FC),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(250, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(
                        color: Colors.black,
                        width: 5,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Already have a login?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 80),

                // CREATE ACCOUNT BUTTON
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CreateAccountScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F7FC),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(280, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(
                        color: Colors.black,
                        width: 5,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Create a New Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'If not, click here to create a new account!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}