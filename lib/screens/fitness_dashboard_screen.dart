import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fitness_goals_screen.dart';
import 'health_screen.dart';
import 'nutrition_screen.dart';
import 'program_survey_screen.dart';
import 'settings_screen.dart';
import 'workout_flow_screens.dart';
import '../services/api.dart';

class FitnessDashboardScreen extends StatefulWidget {
  const FitnessDashboardScreen({super.key, this.onTabSelected});

  final ValueChanged<int>? onTabSelected;

  @override
  State<FitnessDashboardScreen> createState() => _FitnessDashboardScreenState();
}

class _FitnessDashboardScreenState extends State<FitnessDashboardScreen> {
  static const Color navy = Color(0xFF062D63);
  static const Color blue = Color(0xFF086AC7);
  static const Color lightBlue = Color(0xFFC2DFF2);
  static const Color paleBlue = Color(0xFFE5F4FF);
  static const Color white = Colors.white;
  static const TextStyle _smallActionLabelStyle = TextStyle(
    color: white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle _prHeaderStyle = TextStyle(
    color: navy,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.4,
  );
  static const TextStyle _prCellStyle = TextStyle(
    color: Colors.black,
    fontSize: 16,
  );

  int _selectedTab = 0;
  Map<String, dynamic>? _program;
  bool _isLoadingProgram = true;

  // This week's progress from /lifting/current-workouts.
  bool _isLoadingWeek = true;
  int _weekCompleted = 0;
  int _weekTotal = 0;
  Set<int> _completedDays = {}; // 0 = Sunday ... 6 = Saturday

  // Newest personal records from /lifting/newest-records.
  bool _isLoadingRecords = true;
  List<Map<String, dynamic>> _records = [];

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    widget.onTabSelected?.call(index);
    if (index == 3) {
      _openSettings();
    } else if (index == 1) {
      _openPage(const NutritionScreen());
    } else if (index == 2) {
      _openPage(const HealthScreen());
    }
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) setState(() => _selectedTab = 0);
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) {
      setState(() => _selectedTab = 0);
    }
  }

  Future<void> _openGoals() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FitnessGoalsScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProgram();
    _loadWeek();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoadingRecords = true);
    var records = <Map<String, dynamic>>[];
    try {
      records = await ApiClient().getNewestRecords();
    } on ApiException {
      // Show the empty state if the backend is unreachable.
    }
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoadingRecords = false;
    });
  }

  /// Local midnight on the most recent Sunday (today if today is Sunday).
  DateTime _startOfWeek() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - now.weekday % 7);
  }

  Future<void> _loadWeek() async {
    setState(() => _isLoadingWeek = true);
    var completed = 0;
    var total = 0;
    final days = <int>{};
    try {
      final week = await ApiClient().getWeeklyWorkouts(_startOfWeek());
      completed = (week['completed_lifts'] as num?)?.toInt() ?? 0;
      total = (week['total_lifts'] as num?)?.toInt() ?? 0;
      for (final lift in (week['completed_lift_array'] as List? ?? [])) {
        final raw = lift is Map ? lift['day_completed'] : null;
        final parsed = raw is String ? DateTime.tryParse(raw) : null;
        // Backend sends UTC; convert so the dot lands on the user's local day.
        if (parsed != null) days.add(parsed.toLocal().weekday % 7);
      }
    } on ApiException {
      // Show an empty week if the backend is unreachable.
    }
    if (!mounted) return;
    setState(() {
      _weekCompleted = completed;
      _weekTotal = total;
      _completedDays = days;
      _isLoadingWeek = false;
    });
  }

  Future<void> _loadProgram() async {
    setState(() => _isLoadingProgram = true);
    Map<String, dynamic>? program;
    try {
      program = await ApiClient().getMyProgram();
    } on ApiException {
      // Leave the card in its "no program" state if the backend is unreachable.
      program = null;
    }
    if (!mounted) return;
    setState(() {
      _program = program;
      _isLoadingProgram = false;
    });
  }

  Future<void> _openProgramSurvey() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProgramSurveyScreen()),
    );
    // Picking a program in the survey changes what these cards should show.
    await Future.wait([_loadProgram(), _loadWeek()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeader(),
                          const SizedBox(height: 28),
                          _buildPlannedWorkout(),
                          const SizedBox(height: 24),
                          _buildConsistency(),
                          const SizedBox(height: 24),
                          _buildPersonalBests(),
                          const SizedBox(height: 20),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _headingStyle(double size) {
    return TextStyle(
      fontFamily: 'Georgia',
      fontSize: size,
      fontWeight: FontWeight.bold,
      color: white,
      height: 1.04,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's movement",
          style: TextStyle(
            color: Color(0xFF36B9FF),
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text('Fitness Dashboard', style: _headingStyle(32)),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildHeaderAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0C61B9),
              ),
              child: Icon(icon, color: white, size: 30),
            ),
            const SizedBox(height: 7),
            Text(label, style: _smallActionLabelStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedWorkout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Planned Workout',
          textAlign: TextAlign.center,
          style: _headingStyle(29),
        ),
        const SizedBox(height: 6),
        _buildProgramSummary(),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    _buildStartWorkoutButton(),
                    const SizedBox(height: 16),
                    _buildWorkoutActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgramSummary() {
    if (_isLoadingProgram) {
      return const SizedBox(
        height: 38,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: white),
          ),
        ),
      );
    }

    final program = _program;
    if (program == null) {
      return const Text(
        'No program yet. Find one to get started.',
        textAlign: TextAlign.center,
        style: TextStyle(color: lightBlue, fontSize: 14),
      );
    }

    return Column(
      children: [
        Text(
          program['name'] as String,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Next up: Day ${program['next_day']} of ${program['number_of_days']}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: lightBlue, fontSize: 14),
        ),
        //only shows once the user has finished this day at least once
        if (program['estimated_completion_time'] != null) ...[
          const SizedBox(height: 2),
          Text(
            'Est. time: ${_formatMinutes((program['estimated_completion_time'] as num).toDouble())}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: lightBlue, fontSize: 13),
          ),
        ],
      ],
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

  Widget _buildStartWorkoutButton() {
    final hasProgram = _program != null;

    return Expanded(
      child: Material(
        color: const Color(0xFFF4F9FD),
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: hasProgram ? _startWorkout : _openProgramSurvey,
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.black54),
            ),
            child: Text(
              hasProgram || _isLoadingProgram
                  ? 'Start Workout!'
                  : 'Find a program',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startWorkout() async {
    try {
      final workout = await ApiClient().startWorkout();
      final lifts = (workout['lift_data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(
            (lift) => WorkoutExercise(
              exerciseId: lift['exercise_id'] as String?,
              name: lift['exercise'] as String? ?? 'Exercise',
              sets: (lift['sets'] as num?)?.toInt() ?? 0,
              reps: (lift['reps'] as num?)?.toInt() ?? 0,
              recommendedWeight: (lift['recommended_weight'] as num?)?.toDouble(),
            ),
          )
          .toList();

      if (!mounted) return;
      if (lifts.isEmpty) {
        throw const ApiException(502, 'The backend returned no exercises.');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSessionScreen(
            workoutId: workout['workout_id'] as String?,
            plan: WorkoutPlan(
              title: workout['name'] as String? ?? 'Workout',
              dayNumber: (_program?['next_day'] as num?)?.toInt() ?? 1,
              totalDays: (_program?['number_of_days'] as num?)?.toInt() ?? 1,
              nextWorkout: 'Keep building your consistency.',
              exercises: lifts,
            ),
            weightUnit: 'lb',
            onWorkoutSaved: (summary) {
              final id = summary.workoutId;
              if (id == null) return Future.value();
              return ApiClient().submitWorkout(
                workoutId: id,
                notes: summary.notes,
              );
            },
          ),
        ),
      );
      // Finishing a workout can set new PRs, so refresh those too.
      await Future.wait([_loadProgram(), _loadWeek(), _loadRecords()]);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildWorkoutActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildHeaderAction(
          label: 'Exercises',
          icon: Icons.fitness_center,
          onTap: _showExerciseLibraryMessage,
        ),
        _buildHeaderAction(
          label: 'Programs',
          icon: Icons.list_alt_rounded,
          onTap: _openProgramSurvey,
        ),
        _buildHeaderAction(
          label: 'Goals',
          icon: Icons.flag_rounded,
          onTap: _openGoals,
        ),
      ],
    );
  }

  void _showExerciseLibraryMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connect this button to your exercise library.'),
      ),
    );
  }

  Widget _buildConsistency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Consistency', 30),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: paleBlue,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'This week',
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLoadingWeek)
                    Text(
                      _weekTotal > 0
                          ? '$_weekCompleted of $_weekTotal done'
                          : 'No program yet',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, _buildWeekDay),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const Color _doneGreen = Color(0xFF16A34A);
  static const Color _emptyGrey = Color(0xFFE3E8EC);

  /// One day in the strip: green = lifted, dark ring = today,
  /// dashed = still ahead this week, grey = past day with no lift.
  Widget _buildWeekDay(int index) {
    final todayIndex = DateTime.now().weekday % 7;
    final done = _completedDays.contains(index);
    final isToday = index == todayIndex;
    final isFuture = index > todayIndex;
    const size = 30.0;

    Widget dot;
    if (done) {
      dot = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _doneGreen,
          border: isToday ? Border.all(color: navy, width: 2.5) : null,
        ),
      );
    } else if (isToday) {
      dot = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: white,
          border: Border.all(color: navy, width: 2.5),
        ),
      );
    } else if (isFuture) {
      dot = CustomPaint(
        size: const Size(size, size),
        painter: DashedCirclePainter(color: Colors.black38),
      );
    } else {
      dot = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _emptyGrey,
        ),
      );
    }

    return Column(
      children: [
        Text(
          _dayLetters[index],
          style: TextStyle(
            color: isToday ? navy : Colors.black54,
            fontSize: 12,
            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        dot,
      ],
    );
  }

  Widget _buildPersonalBests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Bests', 29, color: navy),
          const SizedBox(height: 4),
          const Text(
            'Your newest records',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(22),
            ),
            child: _buildRecordsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTable() {
    if (_isLoadingRecords) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: navy),
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 14),
        child: Text(
          'No records yet. Finish a workout to set your first PR.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      );
    }

    const divider = BorderSide(color: lightBlue, width: 1);

    TableRow row(List<String> cells, TextStyle style, {bool lastRow = false}) {
      return TableRow(
        decoration: BoxDecoration(
          border: lastRow ? null : const Border(bottom: divider),
        ),
        children: [
          for (var i = 0; i < cells.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                cells[i],
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
        ],
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(0.8),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        row(const ['LIFT', 'WEIGHT', 'REPS'], _prHeaderStyle),
        for (var i = 0; i < _records.length; i++)
          row(
            [
              _records[i]['lift_name'] as String? ?? 'Exercise',
              '${_formatWeight(_records[i]['weight'])} lb',
              '${(_records[i]['reps'] as num?)?.toInt() ?? 0}',
            ],
            _prCellStyle,
            lastRow: i == _records.length - 1,
          ),
      ],
    );
  }

  /// Drops the trailing ".0" so 225.0 shows as "225" but 102.5 stays "102.5".
  String _formatWeight(Object? raw) {
    final weight = (raw as num?)?.toDouble() ?? 0;
    return weight == weight.roundToDouble()
        ? weight.toInt().toString()
        : weight.toString();
  }

  Widget _buildSectionTitle(String title, double size, {Color color = white}) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: color,
        height: 1.04,
      ),
    );
  }

  Widget _buildBottomNavigation() {
    const labels = ['Fitness', 'Nutrition', 'Health', 'Settings'];

    const icons = [
      Icons.fitness_center,
      Icons.restaurant,
      Icons.favorite_outline,
      Icons.settings_outlined,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF052858),
        border: Border(top: BorderSide(color: Color(0xFF104783), width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        12,
        10,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: List.generate(4, (index) {
          final selected = _selectedTab == index;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _selectTab(index),
                borderRadius: BorderRadius.circular(28),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minHeight: 58),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected ? blue : lightBlue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icons[index], size: 16, color: navy),
                          const SizedBox(width: 4),
                          Text(
                            labels[index],
                            style: const TextStyle(
                              color: navy,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Draws a dashed circle outline for days that haven't happened yet.
class DashedCirclePainter extends CustomPainter {
  DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const dashCount = 12;
    const sweep = 2 * math.pi / dashCount;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
