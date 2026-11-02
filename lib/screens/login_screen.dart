import 'package:flutter/material.dart';
import 'create_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // HealthCore blue background
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
              horizontal: 16,
              vertical: 16,
            ),

            child: Column(
              children: [

                // Header and HealthCore logo
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 115,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F7FC),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.black,
                            width: 6,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Log in Here',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 35,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    Image.asset(
                      'web/icons/Logo.webp',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),

                const SizedBox(height: 65),

                // Username / Email label
                const Text(
                  'Enter Username/Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                // Username / Email input
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FC),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.black,
                      width: 6,
                    ),
                  ),
                  child: TextField(
                    controller: usernameController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 65),

                // Password label
                const Text(
                  'Enter Password',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                // Password input
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FC),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.black,
                      width: 6,
                    ),
                  ),
                  child: TextField(
                    controller: passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 75),

                // Bottom buttons
                Row(
                  children: [

                    // Sign up navigation
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              
                                  builder: (context) => const CreateAccountScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFCDD6DF),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 75),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(25),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 6,
                            ),
                          ),
                        ),
                        child: const Text(
                          "Don't have an account?\nSign up",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Login button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final username =
                              usernameController.text.trim();
                          final password =
                              passwordController.text;

                          if (username.isEmpty ||
                              password.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter your username/email and password.',
                                ),
                              ),
                            );
                            return;
                          }

                          // Backend login integration goes here
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Login backend not connected yet.',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFCDD6DF),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 75),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(25),
                            side: const BorderSide(
                              color: Colors.black,
                              width: 6,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}