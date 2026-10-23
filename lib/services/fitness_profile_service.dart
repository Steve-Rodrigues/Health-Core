import 'api.dart';

class FitnessProfileService {
  FitnessProfileService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  static const _poundsPerKilogram = 2.2046226218;

  final ApiClient _apiClient;

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final profile = await _apiClient.getUserProfile();
      final currentWeight = _numberOrNull(profile['current_weight']);
      final height = _numberOrNull(profile['height']);
      final goalWeight = _numberOrNull(profile['goal_weight']);
      final sleepGoal = _numberOrNull(profile['sleep_goal']);
      final workoutsPerWeek = _intOrNull(profile['workouts_per_week_goal']);

      if (currentWeight == null &&
          height == null &&
          goalWeight == null &&
          sleepGoal == null &&
          workoutsPerWeek == null) {
        return null;
      }

      return {
        'weight': currentWeight ?? 0,
        'height_cm': height ?? 0,
        'target_weight': goalWeight ?? 0,
        'weight_unit': 'kg',
        'sleep_goal_hours': sleepGoal ?? 8,
        'workouts_per_week': workoutsPerWeek ?? 3,
      };
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> saveProfile({
    required double weight,
    required double heightCm,
    required double targetWeight,
    required String weightUnit,
    required double sleepGoalHours,
    required int workoutsPerWeek,
  }) {
    return _apiClient.saveFitnessProfile({
      'current_weight': _toKilograms(weight, weightUnit),
      'height': heightCm,
      'goal_weight': _toKilograms(targetWeight, weightUnit),
      'sleep_goal': sleepGoalHours,
      'workouts_per_week_goal': workoutsPerWeek,
    });
  }

  double _toKilograms(double value, String unit) {
    if (unit == 'kg') return value;
    if (unit == 'lbs') return value / _poundsPerKilogram;
    throw ArgumentError.value(unit, 'weightUnit', 'Use kg or lbs.');
  }

  double? _numberOrNull(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  int? _intOrNull(Object? value) {
    return value is num ? value.toInt() : null;
  }
}
