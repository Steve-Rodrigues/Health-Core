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
