import 'package:flutter/material.dart';

import '../services/api.dart';

class ProgramSurveyScreen extends StatefulWidget {
  const ProgramSurveyScreen({super.key});

  @override
  State<ProgramSurveyScreen> createState() => _ProgramSurveyScreenState();
}

class _ProgramSurveyScreenState extends State<ProgramSurveyScreen> {
  static const Color primaryColor = Color(0xFF0756A8);
  static const Color backgroundColor = Color(0xFFF5F7F2);
  static const Color textColor = Color(0xFF001D4B);
  static const Color borderColor = Color(0xFFE2E8DE);

  // Values match Survey_Results_In on the backend.
  static const _goals = {
    'build_muscle': ('Build muscle', Icons.fitness_center),
    'get_stronger': ('Get stronger', Icons.trending_up),
    'lose_fat': ('Lose fat', Icons.local_fire_department_outlined),
    'general_fitness': ('General fitness', Icons.favorite_border),
  };
  static const _experienceLevels = {
    'beginner': ('New to lifting', 'Less than 6 months of training'),
    'intermediate': ('Some experience', 'Comfortable with the main lifts'),
    'expert': ('Experienced', 'Years of consistent training'),
  };
  static const _equipment = {
    'dumbbell': 'Dumbbells',
    'kettlebells': 'Kettlebells',
    'bands': 'Resistance bands',
    'medicine ball': 'Medicine ball',
    'exercise ball': 'Exercise ball',
    'foam roll': 'Foam roller',
    'barbell': 'Barbell',
    'e-z curl bar': 'E-Z curl bar',
    'cable': 'Cable machine',
    'machine': 'Weight machines',
  };

  int _step = 0;
  String? _goal;
  String? _experience;
  int _daysAvailable = 3;
  final Set<String> _selectedEquipment = {};

  bool _isLoading = false;
  String? _choosingProgramId;
  List<Map<String, dynamic>> _programs = [];

  bool get _canContinue => _goal != null && _experience != null;

  Future<void> _findPrograms() async {
    setState(() => _isLoading = true);
    try {
      final programs = await ApiClient().generatePrograms({
        'goal': _goal,
        'experience': _experience,
        'days_available': _daysAvailable,
        'equipment': _selectedEquipment.toList(),
      });
      if (!mounted) return;
      setState(() {
        _programs = programs;
        _step = 2;
      });
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _chooseProgram(Map<String, dynamic> program) async {
    final programId = program['program_id'] as String;
    setState(() => _choosingProgramId = programId);
    try {
      await ApiClient().chooseProgram(programId);
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
      return;
    } finally {
      if (mounted) setState(() => _choosingProgramId = null);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${program['name']} is now your program!'),
        backgroundColor: primaryColor,
      ),
    );
    Navigator.pop(context);
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.maybePop(context);
    } else {
      setState(() => _step -= 1);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _goBack,
        ),
        title: const Text(
          'Find a program',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _buildProgress(),
                  const SizedBox(height: 28),
                  ...switch (_step) {
                    0 => _buildAboutYouStep(),
                    1 => _buildEquipmentStep(),
                    _ => _buildResultsStep(),
                  },
                ],
              ),
            ),
            if (_step < 2) _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    const labels = ['ABOUT YOU', 'YOUR EQUIPMENT', 'YOUR MATCHES'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              labels[_step],
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.3,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            Text(
              'Step ${_step + 1} of 3',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            minHeight: 5,
            backgroundColor: borderColor,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.7,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required bool selected,
    required String title,
    String? subtitle,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFE5F0FB) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? primaryColor : borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: primaryColor),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? primaryColor : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAboutYouStep() {
    return [
      _buildTitle(
        "Let's build your plan.",
        'Answer a few questions and we will match you with a program.',
      ),
      _buildSectionLabel("What's your main goal?"),
      for (final entry in _goals.entries)
        _buildOptionTile(
          selected: _goal == entry.key,
          title: entry.value.$1,
          icon: entry.value.$2,
          onTap: () => setState(() => _goal = entry.key),
        ),
      const SizedBox(height: 16),
      _buildSectionLabel('How much lifting experience do you have?'),
      for (final entry in _experienceLevels.entries)
        _buildOptionTile(
          selected: _experience == entry.key,
          title: entry.value.$1,
          subtitle: entry.value.$2,
          onTap: () => setState(() => _experience = entry.key),
        ),
      const SizedBox(height: 16),
      _buildSectionLabel('How many days a week can you train?'),
      Wrap(
        spacing: 10,
        children: [
          for (var days = 2; days <= 6; days++)
            ChoiceChip(
              label: Text('$days'),
              selected: _daysAvailable == days,
              showCheckmark: false,
              selectedColor: primaryColor,
              backgroundColor: Colors.white,
              side: const BorderSide(color: borderColor),
              labelStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _daysAvailable == days ? Colors.white : textColor,
              ),
              onSelected: (_) => setState(() => _daysAvailable = days),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildEquipmentStep() {
    return [
      _buildTitle(
        'What equipment do you have?',
        'Check everything you can use. Leave it empty for bodyweight-only '
            'programs.',
      ),
      for (final entry in _equipment.entries)
        _buildOptionTile(
          selected: _selectedEquipment.contains(entry.key),
          title: entry.value,
          onTap: () => setState(() {
            if (!_selectedEquipment.remove(entry.key)) {
              _selectedEquipment.add(entry.key);
            }
          }),
        ),
    ];
  }

  List<Widget> _buildResultsStep() {
    return [
      _buildTitle(
        'Your top matches',
        'Pick the program you want to follow. You can change it later.',
      ),
      for (final program in _programs) _buildProgramCard(program),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() => _step = 0),
        child: const Text('Change my answers'),
      ),
    ];
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final programId = program['program_id'] as String;
    final isChoosing = _choosingProgramId == programId;
    final length = program['program_length'];
    final details = [
      '${program['number_of_days']} days/week',
      _titleCase(program['split'] as String),
      _titleCase(program['difficulty'] as String),
      _titleCase(program['equipment_level'] as String),
      if (length != null) '$length weeks',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  program['name'] as String,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F0FB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(program['score'] as num).round()}% match',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            program['description'] as String,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final detail in details)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    detail,
                    style: const TextStyle(fontSize: 12, color: textColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed:
                  _choosingProgramId == null ? () => _chooseProgram(program) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isChoosing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Choose this program',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final isLastQuestion = _step == 1;
    final enabled = !_isLoading && (isLastQuestion || _canContinue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: enabled
              ? () {
                  if (isLastQuestion) {
                    _findPrograms();
                  } else {
                    setState(() => _step = 1);
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isLastQuestion ? 'Find my programs' : 'Continue',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  String _titleCase(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
