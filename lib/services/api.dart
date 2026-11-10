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

  Future<void> updateFitnessGoals(Map<String, dynamic> fitnessProfile) async {
    final response = await _request(
      () => _client.put(
        Uri.parse('$_baseUrl/users/update-goals'),
        headers: _headers(),
        body: jsonEncode(fitnessProfile),
      ),
      action: 'updating your fitness goals',
    );
    _ensureSuccess(response);
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

  /// Returns this week's completed workouts and the program's weekly total.
  /// [weekStart] should be local midnight on Sunday; it is sent as UTC so the
  /// backend knows the exact moment the user's week begins.
  Future<Map<String, dynamic>> getWeeklyWorkouts(DateTime weekStart) async {
    final startDay = Uri.encodeQueryComponent(weekStart.toUtc().toIso8601String());
    final response = await _request(
      () => _client.get(
        Uri.parse('$_baseUrl/lifting/current-workouts?start_day=$startDay'),
        headers: _headers(),
      ),
      action: 'loading this week\'s workouts',
    );
    return _jsonMap(response);
  }

  /// Returns the user's 3 most recent personal records, newest first.
  /// Each entry has `lift_name`, `weight` and `reps`.
  Future<List<Map<String, dynamic>>> getNewestRecords() async {
    final response = await _request(
      () => _client.get(
        Uri.parse('$_baseUrl/lifting/newest-records'),
        headers: _headers(),
      ),
      action: 'loading your personal records',
    );
    final body = _jsonMap(response);
    return (body['records'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> getNutritionSummary(DateTime day) async {
    final response = await _request(
      () => _client.get(
        Uri.parse('$_baseUrl/nutrition/summary?day=${_dateString(day)}'),
        headers: _headers(),
      ),
      action: 'loading nutrition',
    );
    return _jsonMap(response);
  }

  Future<Map<String, dynamic>> createMeal({
    required String mealName,
    required String mealType,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/nutrition/create-meal'),
        headers: _headers(),
        body: jsonEncode({
          'meal_name': mealName,
          'meal_type': mealType,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        }),
      ),
      action: 'saving your meal',
    );
    return _jsonMap(response);
  }

  /// Looks up a scanned barcode. Returns null when the product isn't in
  /// Open Food Facts (404) so the caller can send the user to manual entry.
  /// The returned map has a `missing` list of fields the user still needs to fill in.
  Future<Map<String, dynamic>?> scanBarcode(String barcode) async {
    final response = await _request(
      () => _client.get(
        Uri.parse('$_baseUrl/nutrition/scan-food/${Uri.encodeComponent(barcode)}'),
        headers: _headers(),
      ),
      action: 'looking up that barcode',
    );
    if (response.statusCode == 404) return null;
    return _jsonMap(response);
  }

  /// Saves food info the user typed in for a barcode. All values are per 100 g.
  /// Returns the full food (name, serving size, macros per 100 g).
  Future<Map<String, dynamic>> saveManualBarcodeFood({
    required String barcode,
    required String name,
    required double servingSizeGrams,
    required double caloriesPer100,
    required double proteinPer100,
    required double carbsPer100,
    required double fatPer100,
  }) async {
    final response = await _request(
      () => _client.put(
        Uri.parse('$_baseUrl/nutrition/manual-barcode/${Uri.encodeComponent(barcode)}'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'serving_size_grams': servingSizeGrams,
          'calories': caloriesPer100,
          'protein': proteinPer100,
          'carbs': carbsPer100,
          'fat': fatPer100,
        }),
      ),
      action: 'saving that food',
    );
    return _jsonMap(response);
  }

  /// Logs a meal from a barcoded food. The backend works out the macros.
  Future<Map<String, dynamic>> logBarcodeMeal({
    required String barcode,
    required double servings,
    required String mealType,
  }) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/nutrition/log-meal/${Uri.encodeComponent(barcode)}'),
        headers: _headers(),
        body: jsonEncode({
          'servings_consumed': servings,
          'meal_type': mealType,
        }),
      ),
      action: 'logging your meal',
    );
    return _jsonMap(response);
  }

  Future<Map<String, dynamic>> saveNutritionGoals({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) async {
    final response = await _request(
      () => _client.put(
        Uri.parse('$_baseUrl/nutrition/goal'),
        headers: _headers(),
        body: jsonEncode({
          'calories_goal': calories,
          'protein_goal': protein,
          'carbs_goal': carbs,
          'fat_goal': fat,
        }),
      ),
      action: 'saving nutrition goals',
    );
    return _jsonMap(response);
  }

  Future<Map<String, dynamic>> logSleep({
    required DateTime wakeDate,
    required String bedTime,
    required String wakeTime,
    required int quality,
    required String notes,
  }) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/sleep/log'),
        headers: _headers(),
        body: jsonEncode({
          'wake_date': _dateString(wakeDate),
          'bed_time': bedTime,
          'wake_time': wakeTime,
          'quality': quality,
          'notes': notes,
        }),
      ),
      action: 'logging your sleep',
    );
    return _jsonMap(response);
  }

  Future<Map<String, dynamic>> startWorkout() async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/lifting/start-workout'),
        headers: _headers(),
      ),
      action: 'starting your workout',
    );
    return _jsonMap(response);
  }

  Future<void> finishExercise({
    required String workoutId,
    required String exerciseId,
    required int sets,
    required int reps,
    required double weight,
  }) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/lifting/$workoutId/finish-exercise'),
        headers: _headers(),
        body: jsonEncode({
          'exercise_id': exerciseId,
          'sets': sets,
          'reps': reps,
          'weight': weight,
        }),
      ),
      action: 'saving your exercise',
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> finishWorkout(String workoutId) async {
    final response = await _request(
      () => _client.post(
        Uri.parse('$_baseUrl/lifting/$workoutId/finish-workout'),
        headers: _headers(),
      ),
      action: 'finishing your workout',
    );
    return _jsonMap(response);
  }

  Future<void> submitWorkout({
    required String workoutId,
    String? notes,
  }) async {
    final response = await _request(
      () => _client.patch(
        Uri.parse('$_baseUrl/lifting/$workoutId/submit-workout'),
        headers: _headers(),
        body: jsonEncode({'notes': notes}),
      ),
      action: 'saving your workout notes',
    );
    _ensureSuccess(response);
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

  Map<String, dynamic> _jsonMap(http.Response response) {
    _ensureSuccess(response);
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const ApiException(502, 'The backend returned an invalid response.');
    }
    return body;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }
  }

  String _dateString(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
