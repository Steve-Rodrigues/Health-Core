
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/fitness_profile_service.dart';

class FitnessGoalsScreen extends StatefulWidget {
  const FitnessGoalsScreen({super.key});

  @override
  State<FitnessGoalsScreen> createState() =>
      _FitnessGoalsScreenState();
}

class _FitnessGoalsScreenState extends State<FitnessGoalsScreen> {
  static const Color navy = Color(0xFF062D63);
  static const Color primaryBlue = Color(0xFF086AC7);
  static const Color lightBlue = Color(0xFFC2DFF2);
  static const Color background = Color(0xFFF2F7FC);
  static const Color textColor = Color(0xFF203626);

  final _formKey = GlobalKey<FormState>();
  final _profileService = FitnessProfileService();

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  String _weightUnit = 'kg';
  double _sleepGoal = 8;
  int _workoutsPerWeek = 3;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2).replaceFirst(
          RegExp(r'\.?0+$'),
          '',
        );
  }

  double _convertWeight(double value, String newUnit) {
    if (_weightUnit == newUnit) return value;

    return newUnit == 'lbs'
        ? value * 2.2046226218
        : value / 2.2046226218;
  }

  void _changeWeightUnit(String newUnit) {
    if (_weightUnit == newUnit) return;

    final weight = double.tryParse(_weightController.text);
    final target = double.tryParse(_targetWeightController.text);

    setState(() {
      if (weight != null && weight.isFinite) {
        _weightController.text =
            _formatNumber(_convertWeight(weight, newUnit));
      }

      if (target != null && target.isFinite) {
        _targetWeightController.text =
            _formatNumber(_convertWeight(target, newUnit));
      }

      _weightUnit = newUnit;
    });

    _formKey.currentState?.validate();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();

      if (!mounted) return;

      if (profile != null) {
        setState(() {
          _hasProfile = true;
          _weightController.text =
              _formatNumber((profile['weight'] as num).toDouble());
          _heightController.text =
              _formatNumber((profile['height_cm'] as num).toDouble());
          _targetWeightController.text =
              _formatNumber(
                (profile['target_weight'] as num).toDouble(),
              );
          _weightUnit = profile['weight_unit'] as String;
          _sleepGoal =
              (profile['sleep_goal_hours'] as num).toDouble();
          _workoutsPerWeek =
              (profile['workouts_per_week'] as num).toInt();
        });
      }
    } catch (error) {
      debugPrint('Could not load fitness profile: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load your saved goals. Please try again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateNumber(
    String? value, {
    required String label,
    required double min,
    required double max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $label';
    }

    final number = double.tryParse(value.trim());

    if (number == null || !number.isFinite) {
      return 'Enter a valid number';
    }

    if (number < min || number > max) {
      return 'Enter a value between '
          '${_formatNumber(min)} and ${_formatNumber(max)}';
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
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lightBlue),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lightBlue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryBlue,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _numberField({
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
            color: navy,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
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
            label: field,
            min: min,
            max: max,
          ),
        ),
      ],
    );
  }

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EAF2)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryBlue, size: 23),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurements() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Body measurements',
            Icons.monitor_weight_outlined,
          ),
          const SizedBox(height: 22),

          const Text(
            'Weight unit',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'kg',
                  label: Text('Kilograms (kg)'),
                ),
                ButtonSegment(
                  value: 'lbs',
                  label: Text('Pounds (lbs)'),
                ),
              ],
              selected: {_weightUnit},
              onSelectionChanged: (selection) {
                _changeWeightUnit(selection.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: primaryBlue,
                selectedForegroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Switching units automatically converts both weights.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),

          _numberField(
            label: 'Current weight',
            hint: _weightUnit == 'kg' ? 'e.g. 70' : 'e.g. 154',
            unit: _weightUnit,
            controller: _weightController,
            field: 'current weight',
            min: _weightUnit == 'kg' ? 1 : 2.2,
            max: _weightUnit == 'kg' ? 500 : 1102.3,
          ),
          const SizedBox(height: 20),

          _numberField(
            label: 'Height',
            hint: 'e.g. 175',
            unit: 'cm',
            controller: _heightController,
            field: 'height',
            min: 30,
            max: 300,
          ),
          const SizedBox(height: 20),

          _numberField(
            label: 'Target weight',
            hint: _weightUnit == 'kg' ? 'e.g. 65' : 'e.g. 143',
            unit: _weightUnit,
            controller: _targetWeightController,
            field: 'target weight',
            min: _weightUnit == 'kg' ? 1 : 2.2,
            max: _weightUnit == 'kg' ? 500 : 1102.3,
          ),
        ],
      ),
    );
  }

  Widget _buildSleepGoal() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Sleep goal', Icons.nightlight_round),
          const SizedBox(height: 10),
          const Text(
            'Set your preferred hours of sleep per night.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _sleepGoal.toStringAsFixed(
                  _sleepGoal % 1 == 0 ? 0 : 1,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
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
            activeColor: primaryBlue,
            label: '${_sleepGoal.toStringAsFixed(1)} hours',
            onChanged: (value) {
              setState(() => _sleepGoal = value);
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('4 hours', style: TextStyle(color: Colors.black45)),
              Text('12 hours', style: TextStyle(color: Colors.black45)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutGoal() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Weekly workouts',
            Icons.fitness_center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose how many days you want to train each week.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(7, (index) {
              final days = index + 1;
              final selected = days == _workoutsPerWeek;

              return ChoiceChip(
                label: Text('$days'),
                selected: selected,
                selectedColor: primaryBlue,
                backgroundColor: background,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : navy,
                  fontWeight: FontWeight.bold,
                ),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _workoutsPerWeek = days);
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            '$_workoutsPerWeek '
            '${_workoutsPerWeek == 1 ? 'day' : 'days'} per week',
            style: const TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGoals() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _profileService.saveProfile(
        weight: double.parse(_weightController.text),
        heightCm: double.parse(_heightController.text),
        targetWeight: double.parse(_targetWeightController.text),
        weightUnit: _weightUnit,
        sleepGoalHours: _sleepGoal,
        workoutsPerWeek: _workoutsPerWeek,
      );

      if (!mounted) return;

      setState(() => _hasProfile = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your fitness goals have been saved!'),
          backgroundColor: Color(0xFF527D56),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Could not save fitness goals: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your goals. Check your connection and try again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
        title: const Text(
          'My Fitness Goals',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryBlue,
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Text(
                    _hasProfile
                        ? 'Update your goals.'
                        : 'Set your goals.',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 29,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Adjust your profile whenever your routine or '
                    'fitness goals change. Your saved preferences '
                    'can help personalize future workout plans.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildMeasurements(),
                  const SizedBox(height: 18),

                  _buildSleepGoal(),
                  const SizedBox(height: 18),

                  _buildWorkoutGoal(),
                  const SizedBox(height: 26),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveGoals,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            primaryBlue.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined),
                                SizedBox(width: 10),
                                Text(
                                  'Save goals & preferences',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your preferences are saved to your fitness profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
