import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  /// Makes sure the signed-in Supabase user has a row in the backend users
  /// table, creating it through /users/signup when /users/me returns 404.
  Future<void> ensureUser() async {
    final me = await _request(
      () => _client.get(Uri.parse('$_baseUrl/users/me'), headers: _headers()),
      action: 'loading your account',
    );
    if (me.statusCode >= 200 && me.statusCode < 300) return;
    if (me.statusCode != 404) {
      throw ApiException(me.statusCode, _errorMessage(me));
    }

    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/users/signup'),
        headers: _headers(),
        body: jsonEncode({'username': _usernameForCurrentUser()}),
      ),
      action: 'creating your account',
    );

    // 409 means another request already created the user.
    if (response.statusCode != 409 &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }
  }

  String _usernameForCurrentUser() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadataName = user?.userMetadata?['username'];
    if (metadataName is String && metadataName.trim().length >= 3) {
      return metadataName.trim();
    }

    // Fall back to the email prefix for users created outside the app.
    var name = (user?.email ?? 'user').split('@').first;
    name = name.replaceAll(RegExp(r'[^A-Za-z0-9_.]'), '');
    if (name.length < 3) name = name.padRight(3, '0');
    return name.length > 20 ? name.substring(0, 20) : name;
  }

  Future<void> saveFitnessProfile(Map<String, dynamic> fitnessProfile) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/users/welcome-survey'),
        headers: _headers(),
        body: jsonEncode(fitnessProfile),
      ),
      action: 'saving your fitness goals',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }
  }

  /// Sends the program survey answers and returns the top 3 matching programs.
  Future<List<Map<String, dynamic>>> generatePrograms(
    Map<String, dynamic> surveyResults,
  ) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/lifting/generate-program'),
        headers: _headers(),
        body: jsonEncode(surveyResults),
      ),
      action: 'finding programs for you',
    );

    if (response.statusCode == 404) {
      throw const ApiException(
        404,
        'No programs match those answers. Try more days or equipment.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['programs'] is! List) {
      throw const ApiException(
        502,
        'The backend returned an invalid program list.',
      );
    }

    return (body['programs'] as List).cast<Map<String, dynamic>>();
  }

  /// Returns the user's current program, or null if they have not chosen one.
  Future<Map<String, dynamic>?> getMyProgram() async {
    final response = await _request(
      () => _client.get(
        Uri.parse('$_baseUrl/lifting/my-program'),
        headers: _headers(),
      ),
      action: 'loading your program',
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const ApiException(502, 'The backend returned an invalid program.');
    }
    return body;
  }

  /// Saves the program the user picked as their current program.
  Future<void> chooseProgram(String programId) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/lifting/$programId/choose-program'),
        headers: _headers(),
      ),
      action: 'saving your program',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await _request(
      () => _client.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: _headers(),
      ),
      action: 'loading your fitness goals',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const ApiException(
        502,
        'The backend returned an invalid user profile.',
      );
    }

    return body;
  }

  Map<String, String> _headers() {
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(
        401,
        'You must be signed in before using fitness goals.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Future<http.Response> _request(
    Future<http.Response> Function() request, {
    required String action,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw const ApiException(
        500,
        'Supabase is not configured. Launch with '
        'SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    try {
      return await request();
    } on http.ClientException catch (error) {
      throw ApiException(0, 'Could not connect to the backend while $action: $error');
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] is String) {
        return body['detail'] as String;
      }
    } on FormatException {
      // Fall back to the status code when the backend did not return JSON.
    }

    return 'Unable to complete the request (HTTP ${response.statusCode}).';
  }
}
