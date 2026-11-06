
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';

const Color workoutNavy = Color(0xFF092F62);
const Color workoutBlue = Color(0xFF125BA7);
const Color workoutLightBlue = Color(0xFFE8F1FC);
const Color workoutWhite = Colors.white;
const Color workoutText = Color(0xFF193452);

// ---------------------------------------------------------
// WORKOUT DATA MODELS
// ---------------------------------------------------------

class WorkoutExercise {
  final String? exerciseId;
  final String name;
  final int sets;
  final int reps;
  final double recommendedWeight;

  const WorkoutExercise({
    this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.recommendedWeight,
  });
}

class WorkoutPlan {
  final String title;
  final int dayNumber;
  final int totalDays;
  final String nextWorkout;
  final List<WorkoutExercise> exercises;

  const WorkoutPlan({
    required this.title,
    required this.dayNumber,
    required this.totalDays,
    required this.nextWorkout,
    required this.exercises,
  });
}

class CompletedExercise {
  final WorkoutExercise exercise;
  final double workingWeight;

  const CompletedExercise({
    required this.exercise,
    required this.workingWeight,
  });

  double get volume =>
      exercise.sets * exercise.reps * workingWeight;
}

class WorkoutSummary {
  final String? workoutId;
  final String workoutTitle;
  final int durationMinutes;
  final List<CompletedExercise> completedExercises;
  final String notes;
  final int dayNumber;
  final int totalDays;

  const WorkoutSummary({
    this.workoutId,
    required this.workoutTitle,
    required this.durationMinutes,
    required this.completedExercises,
    required this.notes,
    required this.dayNumber,
    required this.totalDays,
  });

  int get totalSets => completedExercises.fold(
        0,
        (sum, item) => sum + item.exercise.sets,
      );

  double get totalVolume => completedExercises.fold(
        0,
        (sum, item) => sum + item.volume,
      );
}

// ---------------------------------------------------------
// SAMPLE WORKOUT PLAN
// ---------------------------------------------------------

const WorkoutPlan sampleWorkout = WorkoutPlan(
  title: 'Full Body Strength',
  dayNumber: 1,
  totalDays: 3,
  nextWorkout: 'Day 2 · Upper Body Push',
  exercises: [
    WorkoutExercise(
      name: 'Goblet Squat',
      sets: 3,
      reps: 10,
      recommendedWeight: 35,
    ),
    WorkoutExercise(
      name: 'Dumbbell Bench Press',
      sets: 3,
      reps: 8,
      recommendedWeight: 40,
    ),
    WorkoutExercise(
      name: 'Bent-Over Row',
      sets: 3,
      reps: 10,
      recommendedWeight: 30,
    ),
  ],
);

// ---------------------------------------------------------
// WORKOUT SESSION SCREEN
// ---------------------------------------------------------

class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutPlan plan;
  final String weightUnit;
  final Future<void> Function(WorkoutSummary summary)? onWorkoutSaved;
  final String? workoutId;

  const WorkoutSessionScreen({
    super.key,
    this.plan = sampleWorkout,
    this.weightUnit = 'lb',
    this.onWorkoutSaved,
    this.workoutId,
  });

  @override
  State<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState
    extends State<WorkoutSessionScreen> {
  late final Stopwatch _stopwatch;
  late final TextEditingController _weightController;

  int _currentExerciseIndex = 0;
  final List<CompletedExercise> _completedExercises = [];

  bool _isFinishing = false;

  WorkoutExercise get _currentExercise =>
      widget.plan.exercises[_currentExerciseIndex];

  @override
  void initState() {
    super.initState();

    _stopwatch = Stopwatch()..start();

    _weightController = TextEditingController(
      text: _formatWeight(
        widget.plan.exercises.first.recommendedWeight,
      ),
    );
  }

  String _formatWeight(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _completeExercise() async {
    final weight = double.tryParse(_weightController.text);

    if (weight == null || !weight.isFinite || weight < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid working weight.'),
        ),
      );
      return;
    }

    if (widget.workoutId != null && _currentExercise.exerciseId != null) {
      try {
        await ApiClient().finishExercise(
          workoutId: widget.workoutId!,
          exerciseId: _currentExercise.exerciseId!,
          sets: _currentExercise.sets,
          reps: _currentExercise.reps,
          weight: weight,
        );
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _completedExercises.add(
        CompletedExercise(
          exercise: _currentExercise,
          workingWeight: weight,
        ),
      );
    });

    if (_currentExerciseIndex < widget.plan.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;

        _weightController.text = _formatWeight(
          _currentExercise.recommendedWeight,
        );
      });
    } else {
      _finishWorkout();
    }
  }

  Future<void> _finishWorkout() async {
    if (_isFinishing) return;

    setState(() => _isFinishing = true);

    _stopwatch.stop();

    final backendSummary = widget.workoutId == null
        ? null
        : await _finishBackendWorkout(widget.workoutId!);
    final summary = WorkoutSummary(
      workoutId: widget.workoutId,
      workoutTitle: widget.plan.title,
      durationMinutes: (backendSummary?['duration'] as num?)?.round() ??
          _stopwatch.elapsed.inMinutes,
      completedExercises: List.unmodifiable(_completedExercises),
      notes: '',
      dayNumber: widget.plan.dayNumber,
      totalDays: widget.plan.totalDays,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          summary: summary,
          nextWorkout: widget.plan.nextWorkout,
          onWorkoutSaved: widget.onWorkoutSaved,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _finishBackendWorkout(String workoutId) async {
    try {
      return await ApiClient().finishWorkout(workoutId);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _exitWorkout() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit workout?'),
        content: const Text(
          'Your unfinished workout will not be marked as complete. '
          'Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Continue workout'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text(
              'Exit workout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exerciseNumber = _currentExerciseIndex + 1;
    final totalExercises = widget.plan.exercises.length;

    return Scaffold(
      backgroundColor: workoutNavy,
      appBar: AppBar(
        backgroundColor: workoutNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Workout Session',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                children: [
                  _buildTargetCard(),
                  const SizedBox(height: 26),
                  _buildProgress(exerciseNumber, totalExercises),
                  const SizedBox(height: 26),
                  _buildExerciseCard(),
                  const SizedBox(height: 24),
                  _buildCompleteButton(),
                  const SizedBox(height: 14),
                  _buildExitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: workoutLightBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eyebrow('YOUR TARGET FOR TODAY'),
                const SizedBox(height: 10),
                Text(
                  widget.plan.title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: workoutText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Build total-body strength with controlled, confident lifts.',
                  style: TextStyle(
                    color: Color(0xFF607B99),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: workoutBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(int exerciseNumber, int totalExercises) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('WORKOUT FLOW', color: const Color(0xFF7BCBFF)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Session progress',
              style: TextStyle(
                fontFamily: 'Georgia',
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Exercise $exerciseNumber of $totalExercises',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: _completedExercises.length / totalExercises,
            minHeight: 12,
            backgroundColor: workoutLightBlue,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF55B7FF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('CURRENT EXERCISE'),
                    const SizedBox(height: 8),
                    Text(
                      _currentExercise.name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: workoutText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F2FC),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.repeat_rounded,
                  color: workoutBlue,
                  size: 25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _statBox('SETS', '${_currentExercise.sets}'),
              const SizedBox(width: 12),
              _statBox('REPS', '${_currentExercise.reps}'),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Working weight',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: workoutText,
                  fontSize: 15,
                ),
              ),
              Text(
                'Recommended: '
                '${_formatWeight(_currentExercise.recommendedWeight)} '
                '${widget.weightUnit}',
                style: const TextStyle(
                  color: Color(0xFF71869C),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d*'),
              ),
            ],
            decoration: InputDecoration(
              suffixText: widget.weightUnit,
              filled: true,
              fillColor: const Color(0xFFF9FCFF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 17,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFFD5E5F1),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: workoutBlue,
                  width: 2,
                ),
              ),
            ),
            style: const TextStyle(
              color: workoutText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Adjust the recommendation to match today's readiness.",
            style: TextStyle(
              color: Color(0xFF71869C),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: workoutLightBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(label),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: workoutText,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    final isLast =
        _currentExerciseIndex == widget.plan.exercises.length - 1;

    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: _isFinishing ? null : _completeExercise,
        style: ElevatedButton.styleFrom(
          backgroundColor: workoutBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: Text(
          isLast ? 'Finish Workout' : 'Complete Exercise',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    return SizedBox(
      height: 55,
      child: OutlinedButton(
        onPressed: _exitWorkout,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Exit workout early',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// WORKOUT COMPLETE SCREEN
// ---------------------------------------------------------

class WorkoutCompleteScreen extends StatefulWidget {
  final WorkoutSummary summary;
  final String nextWorkout;
  final Future<void> Function(WorkoutSummary summary)? onWorkoutSaved;

  const WorkoutCompleteScreen({
    super.key,
    required this.summary,
    required this.nextWorkout,
    this.onWorkoutSaved,
  });

  @override
  State<WorkoutCompleteScreen> createState() =>
      _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState
    extends State<WorkoutCompleteScreen> {
  final TextEditingController _notesController =
      TextEditingController();

  bool _isSaving = false;
  bool _saved = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  WorkoutSummary get _summary => WorkoutSummary(
        workoutId: widget.summary.workoutId,
        workoutTitle: widget.summary.workoutTitle,
        durationMinutes: widget.summary.durationMinutes,
        completedExercises: widget.summary.completedExercises,
        notes: _notesController.text.trim(),
        dayNumber: widget.summary.dayNumber,
        totalDays: widget.summary.totalDays,
      );

  Future<void> _saveAndReturn() async {
    if (_isSaving || _saved) return;

    setState(() => _isSaving = true);

    try {
      await widget.onWorkoutSaved?.call(_summary);

      if (!mounted) return;

      setState(() {
        _saved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout summary saved!'),
          backgroundColor: Color(0xFF397C61),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      debugPrint('Could not save workout: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save workout. Please try again.'),
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
      backgroundColor: workoutNavy,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              "Today's movement",
              style: TextStyle(
                color: Color(0xFFB6D3F3),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Workout Complete',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 31,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            _buildSuccessCard(),
            const SizedBox(height: 20),
            _buildStatistics(),
            const SizedBox(height: 20),
            _buildRecap(),
            const SizedBox(height: 20),
            _buildNotes(),
            const SizedBox(height: 20),
            _buildNextWorkout(),
            const SizedBox(height: 22),
            _buildFinishButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFF3264B6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'DAY ${widget.summary.dayNumber} OF '
            '${widget.summary.totalDays} FINISHED',
            style: const TextStyle(
              color: Color(0xFF657B9A),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.summary.workoutTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: workoutNavy,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nice work. Every set you logged today is saved to your history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF71849E),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = [
      ('DURATION', '${widget.summary.durationMinutes} min'),
      ('EXERCISES', '${widget.summary.completedExercises.length}'),
      ('SETS', '${widget.summary.totalSets}'),
      (
        'TOTAL VOLUME',
        '${widget.summary.totalVolume.toStringAsFixed(0)} '
            'lb'
      ),
    ];

    return Row(
      children: List.generate(stats.length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == stats.length - 1 ? 0 : 7,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 106),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: workoutLightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stats[index].$1,
                    style: const TextStyle(
                      color: Color(0xFF667D9A),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      stats[index].$2,
                      style: const TextStyle(
                        color: workoutNavy,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRecap() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Session recap',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: workoutNavy,
                ),
              ),
              Text(
                '${widget.summary.completedExercises.length} of '
                '${widget.summary.completedExercises.length} done',
                style: const TextStyle(
                  color: Color(0xFF687D98),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFDCE6F1)),
          ...widget.summary.completedExercises.map((completed) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completed.exercise.name,
                          style: const TextStyle(
                            color: workoutNavy,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${completed.exercise.sets} sets × '
                          '${completed.exercise.reps} reps',
                          style: const TextStyle(
                            color: Color(0xFF71849E),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${completed.workingWeight.toStringAsFixed(0)} lb',
                    style: const TextStyle(
                      color: workoutNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: workoutLightBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'How did it feel? ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: '(optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF71849E),
                  ),
                ),
              ],
            ),
            style: TextStyle(
              color: workoutNavy,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Write about your workout...',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextWorkout() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Up next: ${widget.nextWorkout}'),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UP NEXT',
                    style: TextStyle(
                      color: Color(0xFFB6D3F3),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
            Text(
              widget.nextWorkout,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishButton() {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveAndReturn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2F65B7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Finish & Return to Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SHARED UI HELPER
// ---------------------------------------------------------

Widget _eyebrow(
  String text, {
  Color color = const Color(0xFF7089A5),
}) {
  return Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
  );
}
