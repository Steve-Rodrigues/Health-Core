
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';

class FitnessSurveyScreen extends StatefulWidget {
  const FitnessSurveyScreen({super.key});

  @override
  State<FitnessSurveyScreen> createState() =>
      _FitnessSurveyScreenState();
}

class _FitnessSurveyScreenState extends State<FitnessSurveyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  String _weightUnit = 'kg';
  double _sleepGoal = 8;
  int _workoutsPerWeek = 3;
  bool _isSubmitting = false;

  static const Color primaryColor = Color(0xFF0756A8);
  static const Color backgroundColor = Color(0xFFF5F7F2);
  static const Color textColor = Color(0xFF001D4B);

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  // Convert a weight value when changing units.
  double _convertWeight(double value, String newUnit) {
    if (_weightUnit == newUnit) return value;

    if (newUnit == 'lbs') {
      return value * 2.2046226218;
    }

    return value / 2.2046226218;
  }

  // Convert both weight fields without losing their meaning.
  void _changeWeightUnit(String newUnit) {
    if (_weightUnit == newUnit) return;

    final currentWeight = double.tryParse(
      _weightController.text.trim(),
    );
    final targetWeight = double.tryParse(
      _targetWeightController.text.trim(),
    );

    setState(() {
      if (currentWeight != null && currentWeight.isFinite) {
        _weightController.text =
            _formatWeight(_convertWeight(currentWeight, newUnit));
      }

      if (targetWeight != null && targetWeight.isFinite) {
        _targetWeightController.text =
            _formatWeight(_convertWeight(targetWeight, newUnit));
      }

      _weightUnit = newUnit;
    });

    // Revalidate the fields using the new unit's range.
    _formKey.currentState?.validate();
  }

  // Display up to two decimal places without unnecessary trailing zeros.
  String _formatWeight(double value) {
    return value.toStringAsFixed(2).replaceFirst(
          RegExp(r'\.?0+$'),
          '',
        );
  }

  String? _validateNumber(
    String? value, {
    required String field,
    required double min,
    required double max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $field';
    }

    final number = double.tryParse(value.trim());

    if (number == null || !number.isFinite) {
      return 'Enter a valid number';
    }

    if (number < min || number > max) {
      return 'Enter a value between '
          '${_formatWeight(min)} and ${_formatWeight(max)}';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String hint,
    required String unit,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixText: unit,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8DE),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8DE),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required String hint,
    required String unit,
    required TextEditingController controller,
    required String field,
    required double min,
    required double max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d*\.?\d*'),
            ),
          ],
          decoration: _inputDecoration(
            hint: hint,
            unit: unit,
          ),
          validator: (value) => _validateNumber(
            value,
            field: field,
            min: min,
            max: max,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9EDE5),
        ),
      ),
      child: child,
    );
  }

  Widget _buildWeightUnitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weight unit',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'kg',
                label: Text('Kilograms (kg)'),
              ),
              ButtonSegment<String>(
                value: 'lbs',
                label: Text('Pounds (lbs)'),
              ),
            ],
            selected: {_weightUnit},
            onSelectionChanged: (selection) {
              _changeWeightUnit(selection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: primaryColor,
              selectedForegroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your current and target weights convert automatically.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSleepSelector() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.nightlight_round,
                color: primaryColor,
              ),
              SizedBox(width: 10),
              Text(
                'Sleep goal',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'How many hours would you like to sleep each night?',
            style: TextStyle(
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _sleepGoal.toStringAsFixed(
                  _sleepGoal.truncateToDouble() == _sleepGoal
                      ? 0
                      : 1,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'hours per night',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
          Slider(
            value: _sleepGoal,
            min: 4,
            max: 12,
            divisions: 16,
            activeColor: primaryColor,
            inactiveColor: const Color(0xFFE2E8DE),
            label: '${_sleepGoal.toStringAsFixed(1)} hours',
            onChanged: (value) {
              setState(() {
                _sleepGoal = value;
              });
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '4 hours',
                style: TextStyle(color: Colors.black45),
              ),
              Text(
                '12 hours',
                style: TextStyle(color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSelector() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fitness_center,
                color: primaryColor,
              ),
              SizedBox(width: 10),
              Text(
                'Weekly workouts',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'How many days per week can you work out?',
            style: TextStyle(
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(7, (index) {
              final days = index + 1;
              final selected = _workoutsPerWeek == days;

              return ChoiceChip(
                label: Text('$days'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _workoutsPerWeek = days;
                  });
                },
                selectedColor: primaryColor,
                backgroundColor: backgroundColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : textColor,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected
                        ? primaryColor
                        : const Color(0xFFE2E8DE),
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            '$_workoutsPerWeek '
            '${_workoutsPerWeek == 1 ? 'day' : 'days'} per week',
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSurvey() async {
    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fitnessProfile = <String, dynamic>{
      'current_weight': double.parse(_weightController.text),
      'height': double.parse(_heightController.text),
      'goal_weight': double.parse(
        _targetWeightController.text,
      ),
      'sleep_goal': _sleepGoal,
      'workouts_per_week_goal': _workoutsPerWeek,
    };

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiClient().saveFitnessProfile(fitnessProfile);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitness goals saved successfully!'),
        backgroundColor: primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Fitness setup',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'YOUR FITNESS PROFILE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    'Step 1 of 3',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  value: 1 / 3,
                  minHeight: 5,
                  backgroundColor: Color(0xFFE2E8DE),
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                "Let's get to know you.",
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.7,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tell us about your body and routine so we can '
                'help personalize your fitness journey.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 28),

              // Body measurements and weight units
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Body measurements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 22),

                    _buildWeightUnitSelector(),
                    const SizedBox(height: 22),

                    _buildNumberField(
                      label: 'Current weight',
                      hint: _weightUnit == 'kg'
                          ? 'e.g. 70'
                          : 'e.g. 154',
                      unit: _weightUnit,
                      controller: _weightController,
                      field: 'current weight',
                      min: _weightUnit == 'kg' ? 1 : 2.2,
                      max: _weightUnit == 'kg' ? 500 : 1102.3,
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      label: 'Height',
                      hint: 'e.g. 175',
                      unit: 'cm',
                      controller: _heightController,
                      field: 'height',
                      min: 30,
                      max: 300,
                    ),
                    const SizedBox(height: 20),

                    _buildNumberField(
                      label: 'Target weight',
                      hint: _weightUnit == 'kg'
                          ? 'e.g. 65'
                          : 'e.g. 143',
                      unit: _weightUnit,
                      controller: _targetWeightController,
                      field: 'target weight',
                      min: _weightUnit == 'kg' ? 1 : 2.2,
                      max: _weightUnit == 'kg' ? 500 : 1102.3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _buildSleepSelector(),
              const SizedBox(height: 18),

              _buildWorkoutSelector(),
              const SizedBox(height: 28),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Save my fitness goals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'You can update your goals at any time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
