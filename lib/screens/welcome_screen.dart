import 'package:flutter/material.dart';
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Background gradient
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Welcome heading with HealthCore logo
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Welcome heading container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 35,
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
                            SizedBox(height: 15),
                            Text(
                              'Welcome to\nHealthCore',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 36,
                                color: Colors.black,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            SizedBox(height: 20),
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
                      // HealthCore logo in top-right corner
                      Positioned(
                        top: -10,
                        right: -10,
                        child: Image.asset(
                          'web/icons/Logo.webp',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  // Login button
                  ElevatedButton(
                    onPressed: () {
                      // Login navigation will go here
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F7FC),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(250, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(
                          color: Colors.black,
                          width: 5,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Already have a login?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Create Account button
                  ElevatedButton(
                    onPressed: () {
                      // Sign up navigation will go here
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F7FC),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(280, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(
                          color: Colors.black,
                          width: 5,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Create a new Account',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If not, click here to create a new account!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
