import 'package:flutter/material.dart';

import 'program_survey_screen.dart';
import '../services/api.dart';

/// Shows every day of the user's current program as swipeable cards,
/// with a tab row on top to jump straight to a day.
class ProgramOverviewScreen extends StatefulWidget {
  const ProgramOverviewScreen({super.key});

  @override
  State<ProgramOverviewScreen> createState() => _ProgramOverviewScreenState();
}

class _ProgramOverviewScreenState extends State<ProgramOverviewScreen> {
  static const Color navy = Color(0xFF062D63);
  static const Color blue = Color(0xFF086AC7);
  static const Color lightBlue = Color(0xFFC2DFF2);
  static const Color paleBlue = Color(0xFFE5F4FF);
  static const Color doneGreen = Color(0xFF2E9E5B);
  static const Color mutedText = Color(0xFF657B9A);

  // viewportFraction < 1 lets the next card peek in from the right.
  final PageController _pageController = PageController(viewportFraction: 0.9);

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _program; // from /lifting/get-program/days
  List<Map<String, dynamic>> _days = [];
  int _nextDay = 1; // from /lifting/my-program
  double? _estimatedMinutes; // only known for the next day
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      final results = await Future.wait([api.getProgramDays(), api.getMyProgram()]);
      final program = results[0];
      final myProgram = results[1];
      if (!mounted) return;

      final days = (program?['days'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final nextDay = (myProgram?['next_day'] as num?)?.toInt() ?? 1;
      // Open on today's day so the user sees what's next first.
      final startIndex = (nextDay - 1).clamp(0, days.isEmpty ? 0 : days.length - 1);

      setState(() {
        _program = program;
        _days = days;
        _nextDay = nextDay;
        _estimatedMinutes = (myProgram?['estimated_completion_time'] as num?)?.toDouble();
        _selectedIndex = startIndex;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) _pageController.jumpToPage(startIndex);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  void _goToDay(int index) {
    if (index < 0 || index >= _days.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openBuilder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProgramSurveyScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = _days.length;
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: _program == null
            ? const Text('Your Program')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _program!['name'] as String? ?? 'Your Program',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$days days a week · repeats weekly',
                    style: const TextStyle(fontSize: 13, color: lightBlue),
                  ),
                ],
              ),
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return _buildMessage(_error!, buttonLabel: 'Try again', onPressed: _load);
    }
    if (_program == null || _days.isEmpty) {
      return _buildMessage(
        "You don't have a program yet.",
        buttonLabel: 'Open the builder',
        onPressed: _openBuilder,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _buildDayTabs(),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _days.length,
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildDayCard(_days[index]),
            ),
          ),
        ),
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildMessage(String text, {required String buttonLabel, required VoidCallback onPressed}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: blue),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Day tabs ----------

  Widget _buildDayTabs() {
    return Row(
      children: [
        for (var i = 0; i < _days.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _buildDayTab(i)),
        ],
      ],
    );
  }

  Widget _buildDayTab(int index) {
    final dayNumber = (_days[index]['day'] as num?)?.toInt() ?? index + 1;
    final selected = index == _selectedIndex;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _goToDay(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Colors.white : lightBlue.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(
                'Day $dayNumber',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? navy : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              _buildStatusDot(dayNumber, selected),
            ],
          ),
        ),
      ),
    );
  }

  /// Green = already done this cycle, filled blue = today, hollow = coming up.
  Widget _buildStatusDot(int dayNumber, bool selected) {
    final hollowColor = selected ? mutedText : lightBlue;
    if (dayNumber < _nextDay) {
      return _dot(fill: doneGreen);
    }
    if (dayNumber == _nextDay) {
      return _dot(fill: blue);
    }
    return _dot(border: hollowColor);
  }

  Widget _dot({Color? fill, Color? border}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border == null ? null : Border.all(color: border, width: 1.4),
      ),
    );
  }

  // ---------- Day card ----------

  Widget _buildDayCard(Map<String, dynamic> day) {
    final dayNumber = (day['day'] as num?)?.toInt() ?? 0;
    final isToday = dayNumber == _nextDay;
    final exercises = (day['exercises'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    final numExercises = (day['number_exercises'] as num?)?.toInt() ?? exercises.length;
    final numSets = (day['number_sets'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: isToday ? blue : const Color(0xFF3E6A9C),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isToday) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'Day $dayNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    _headerStat('$numExercises exercises'),
                    _headerStat('$numSets sets'),
                    // The backend only estimates time for the next day.
                    if (isToday && _estimatedMinutes != null) _headerStat(_formatMinutes(_estimatedMinutes!)),
                  ],
                ),
              ],
            ),
          ),
          // Exercise list
          Expanded(
            child: exercises.isEmpty
                ? const Center(
                    child: Text('Rest day', style: TextStyle(color: mutedText, fontSize: 16)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    itemCount: exercises.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: paleBlue),
                    itemBuilder: (_, i) => _buildExerciseRow(i + 1, exercises[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildExerciseRow(int number, Map<String, dynamic> exercise) {
    final sets = (exercise['sets'] as num?)?.toInt() ?? 0;
    final reps = (exercise['reps'] as num?)?.toInt() ?? 0;
    // Not sent by the backend yet; shows automatically once it is.
    final weight = (exercise['recommended_weight'] as num?)?.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$number', style: const TextStyle(color: blue, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'] as String? ?? 'Exercise',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text('$sets sets × $reps', style: const TextStyle(fontSize: 12, color: mutedText)),
              ],
            ),
          ),
          if (weight != null)
            Text(
              '${weight % 1 == 0 ? weight.toInt() : weight} lb',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
        ],
      ),
    );
  }

  // ---------- Bottom arrows ----------

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _arrowButton(Icons.chevron_left, _selectedIndex > 0 ? () => _goToDay(_selectedIndex - 1) : null),
          const Expanded(
            child: Text(
              'Swipe or tap to see each day',
              textAlign: TextAlign.center,
              style: TextStyle(color: lightBlue, fontSize: 13),
            ),
          ),
          _arrowButton(
            Icons.chevron_right,
            _selectedIndex < _days.length - 1 ? () => _goToDay(_selectedIndex + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      disabledColor: Colors.white24,
      style: IconButton.styleFrom(
        side: BorderSide(color: onPressed == null ? Colors.white24 : lightBlue),
      ),
    );
  }

  //turns minutes into "~45 min" or "~1 hr 10 min"
  String _formatMinutes(double minutes) {
    final total = minutes.round().clamp(1, 1 << 30);
    final hours = total ~/ 60;
    final mins = total % 60;
    if (hours == 0) return '~$mins min';
    if (mins == 0) return '~$hours hr';
    return '~$hours hr $mins min';
  }
}
