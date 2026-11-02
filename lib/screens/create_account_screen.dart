import 'package:flutter/material.dart';


class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final emailController = TextEditingController();

  bool hidePassword = true;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void createAccount() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Backend registration will be connected later.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Account registration backend not connected yet.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // HealthCore blue gradient background
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
              horizontal: 20,
              vertical: 16,
            ),

            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // Create Account heading and logo
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 110,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
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
                              'Create Account',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Image.asset(
                        'web/icons/Logo.webp',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // Username
                  const Text(
                    'Enter Username',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  buildInputBox(
                    controller: usernameController,
                    hint: 'Username',
                    action: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 30),

                  // Password
                  const Text(
                    'Enter Password',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  buildInputBox(
                    controller: passwordController,
                    hint: 'Password',
                    obscure: hidePassword,
                    action: TextInputAction.next,
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Use at least 8 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 30),

                  // Email
                  const Text(
                    'Enter Email',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 10),

                  buildInputBox(
                    controller: emailController,
                    hint: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    action: TextInputAction.done,
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Please enter an email';
                      }

                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Please enter a valid email';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 40),

                  // Create Account button
                  ElevatedButton(
                    onPressed: createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDD6DF),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(270, 65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                        side: const BorderSide(
                          color: Colors.black,
                          width: 6,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Return to Login
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Already have an account? Go back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
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
   // Reusable input box for username, password, and email
  Widget buildInputBox({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 20,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF2F7FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        suffixIcon: suffixIcon,
        errorStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(
            color: Colors.black,
            width: 6,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(
            color: Colors.black,
            width: 6,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(
            color: Colors.black,
            width: 6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 4,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 4,
          ),
        ),
      ),
    );
  }
}