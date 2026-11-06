import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/api.dart';
import 'fitness_survey_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    if (!SupabaseConfig.isConfigured) {
      _showError(
        'Supabase is not configured. Launch with SUPABASE_PUBLISHABLE_KEY.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    AuthResponse response;
    try {
      response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        // Kept in Supabase metadata so the backend user can be created on
        // first login when email confirmation delays the session.
        data: {'username': _usernameController.text.trim()},
      );
      if (response.session != null) await ApiClient().ensureUser();
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
      return;
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
      return;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    if (response.session == null) {
      _showMessage(
        'Account created. Check your email to confirm your account, then log in.',
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const FitnessSurveyScreen()),
      (_) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF0756A8),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    required VoidCallback onToggle,
    required bool obscureText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      appBar: AppBar(
        title: const Text('Create an account'),
        backgroundColor: const Color(0xFFF5F7F2),
        foregroundColor: const Color(0xFF001D4B),
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const Text(
                'Start your journey',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF001D4B),
                  fontFamily: 'serif',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your HealthCore account to set goals and track progress.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.length < 3 || name.length > 20) {
                    return 'Use 3 to 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _decoration(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Use at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _register(),
                decoration: _decoration(
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirmation,
                  onToggle: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0756A8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
