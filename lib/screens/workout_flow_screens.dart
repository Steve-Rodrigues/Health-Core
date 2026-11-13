
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
  final double? recommendedWeight; //null when the user has never done this exercise

  const WorkoutExercise({
    this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    this.recommendedWeight,
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

// One set row that got sent to the backend. completed=false means the user
// hit skip (sent as sets: 0); it still exists so we know it was missed.
class LoggedSet {
  final int reps;
  final double weight;
  final bool completed;

  const LoggedSet({
    required this.reps,
    required this.weight,
    this.completed = true,
  });

  double get volume => completed ? reps * weight : 0;
}

class CompletedExercise {
  final WorkoutExercise exercise;
  final List<LoggedSet> sets; // every set row, done or skipped, in order
  final bool isPr; // beat the previous personal record for this exercise

  const CompletedExercise({
    required this.exercise,
    required this.sets,
    this.isPr = false,
  });

  List<LoggedSet> get doneSets => sets.where((s) => s.completed).toList();

  double get volume => sets.fold(0, (sum, s) => sum + s.volume);
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
        (sum, item) => sum + item.doneSets.length,
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

  int _currentExerciseIndex = 0;
  final List<CompletedExercise> _completedExercises = [];

  // One weight/reps box per planned set of the current exercise.
  // _loggedSets[i] is null until set i has been saved.
  List<TextEditingController> _weightControllers = [];
  List<TextEditingController> _repsControllers = [];
  List<LoggedSet?> _loggedSets = [];
  int? _savingSetIndex; // which set is mid-request, so we can show a spinner

  bool _isFinishing = false;

  WorkoutExercise get _currentExercise =>
      widget.plan.exercises[_currentExerciseIndex];

  int get _loggedCount => _loggedSets.whereType<LoggedSet>().length;

  @override
  void initState() {
    super.initState();

    _stopwatch = Stopwatch()..start();
    _setUpSetRows();
  }

  // Builds a row for every set the program prescribes for this exercise,
  // prefilled with the recommended weight and target reps.
  void _setUpSetRows() {
    _disposeSetControllers();
    final exercise = _currentExercise;
    final setCount = exercise.sets < 1 ? 1 : exercise.sets;

    _weightControllers = List.generate(
      setCount,
      (_) => TextEditingController(
        text: _formatWeight(exercise.recommendedWeight),
      ),
    );
    _repsControllers = List.generate(
      setCount,
      (_) => TextEditingController(text: '${exercise.reps}'),
    );
    _loggedSets = List.filled(setCount, null);
  }

  void _disposeSetControllers() {
    for (final c in [..._weightControllers, ..._repsControllers]) {
      c.dispose();
    }
  }

  //empty string when there is no recommendation so the weight box starts blank
  String _formatWeight(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _disposeSetControllers();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // Sends one set row to the backend (sets: 1 if done, 0 if skipped).
  // Returns true if it saved. Skipped sets still send the planned
  // weight/reps so the row shows what was missed.
  Future<bool> _sendSet(int index, {required bool completed}) async {
    final exercise = _currentExercise;
    var weight = double.tryParse(_weightControllers[index].text);
    var reps = int.tryParse(_repsControllers[index].text);

    if (completed) {
      if (weight == null || !weight.isFinite || weight < 0) {
        _showError('Enter a valid weight for set ${index + 1}.');
        return false;
      }
      if (reps == null || reps < 1) {
        _showError('Enter how many reps you did for set ${index + 1}.');
        return false;
      }
    } else {
      // whatever is in the boxes doesn't matter much for a skip, so fall
      // back to the plan instead of blocking the user
      if (weight == null || !weight.isFinite || weight < 0) {
        weight = exercise.recommendedWeight ?? 0;
      }
      if (reps == null || reps < 0) reps = exercise.reps;
    }

    setState(() => _savingSetIndex = index);
    try {
      if (widget.workoutId != null && exercise.exerciseId != null) {
        await ApiClient().finishExercise(
          workoutId: widget.workoutId!,
          exerciseId: exercise.exerciseId!,
          reps: reps,
          weight: weight,
          completed: completed,
        );
      }
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
      return false;
    } finally {
      if (mounted) setState(() => _savingSetIndex = null);
    }

    if (!mounted) return false;
    setState(() {
      _loggedSets[index] =
          LoggedSet(reps: reps!, weight: weight!, completed: completed);
      // Carry a changed weight forward so they don't retype it every set.
      if (completed) {
        for (var i = index + 1; i < _loggedSets.length; i++) {
          if (_loggedSets[i] == null) {
            _weightControllers[i].text = _formatWeight(weight);
          }
        }
      }
    });
    return true;
  }

  Future<void> _onSetButton(int index, {required bool completed}) async {
    if (_savingSetIndex != null || _loggedSets[index] != null) return;
    FocusScope.of(context).unfocus();
    await _sendSet(index, completed: completed);
  }

  Future<void> _completeExercise() async {
    if (_savingSetIndex != null) return;

    final remaining = _loggedSets.length - _loggedCount;
    if (remaining > 0) {
      final skip = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            _loggedCount == 0 ? 'Skip this exercise?' : 'Skip remaining sets?',
          ),
          content: Text(
            '$remaining set${remaining == 1 ? '' : 's'} of '
            '${_currentExercise.name} will be marked as skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep going'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Skip'),
            ),
          ],
        ),
      );
      if (skip != true || !mounted) return;

      // Save every open set as skipped (sets: 0), one request at a time.
      // If one fails we stop here so nothing gets double-sent on retry.
      for (var i = 0; i < _loggedSets.length; i++) {
        if (_loggedSets[i] != null) continue;
        final ok = await _sendSet(i, completed: false);
        if (!ok || !mounted) return;
      }
    }

    final logged = _loggedSets.whereType<LoggedSet>().toList();
    setState(() {
      // only show it in the recap if at least one set was actually done
      if (logged.any((s) => s.completed)) {
        _completedExercises.add(
          CompletedExercise(exercise: _currentExercise, sets: logged),
        );
      }
    });

    if (_currentExerciseIndex < widget.plan.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _setUpSetRows();
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

    // The backend's `pr` list holds every PR set during this workout.
    final prNames = (backendSummary?['pr'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((pr) => pr['name'])
        .whereType<String>()
        .toSet();
    final completed = _completedExercises
        .map(
          (c) => CompletedExercise(
            exercise: c.exercise,
            sets: c.sets,
            isPr: prNames.contains(c.exercise.name),
          ),
        )
        .toList();

    final summary = WorkoutSummary(
      workoutId: widget.workoutId,
      workoutTitle: widget.plan.title,
      durationMinutes: (backendSummary?['duration'] as num?)?.round() ??
          _stopwatch.elapsed.inMinutes,
      completedExercises: List.unmodifiable(completed),
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
            // finished exercises + how far through the current one's sets
            value: (_currentExerciseIndex +
                    (_loggedSets.isEmpty
                        ? 0
                        : _loggedCount / _loggedSets.length)) /
                totalExercises,
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
              _statBox('SETS', '$_loggedCount / ${_loggedSets.length}'),
              const SizedBox(width: 12),
              _statBox('TARGET REPS', '${_currentExercise.reps}'),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Log your sets',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: workoutText,
                  fontSize: 15,
                ),
              ),
              if (_currentExercise.recommendedWeight != null)
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
          const SizedBox(height: 14),
          _buildSetHeader(),
          const SizedBox(height: 6),
          for (var i = 0; i < _loggedSets.length; i++) _buildSetRow(i),
          const SizedBox(height: 8),
          const Text(
            'Tap ✓ after each set, or ✕ if you skip it. Changing the weight '
            'carries it to the sets below.',
            style: TextStyle(
              color: Color(0xFF71869C),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetHeader() {
    const style = TextStyle(
      color: Color(0xFF667D9A),
      fontWeight: FontWeight.bold,
      fontSize: 11,
      letterSpacing: 0.6,
    );
    return Row(
      children: [
        const SizedBox(width: 32, child: Text('SET', style: style)),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Text('WEIGHT (${widget.weightUnit.toUpperCase()})',
              style: style),
        ),
        const SizedBox(width: 10),
        const Expanded(flex: 2, child: Text('REPS', style: style)),
        const SizedBox(width: 100), // skip + done buttons
      ],
    );
  }

  Widget _buildSetRow(int index) {
    final logged = _loggedSets[index];
    final isDone = logged?.completed == true;
    final isSkipped = logged != null && !logged.completed;
    final isSaving = _savingSetIndex == index;
    final locked = logged != null || isSaving;
    final busy = _savingSetIndex != null;

    const doneGreen = Color(0xFF397C61);
    const skipGrey = Color(0xFF9AA9BA);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDone
                  ? doneGreen
                  : isSkipped
                      ? skipGrey
                      : workoutLightBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: logged != null ? Colors.white : workoutText,
                fontWeight: FontWeight.bold,
                decoration: isSkipped ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: _setField(
              controller: _weightControllers[index],
              enabled: !locked,
              decimal: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _setField(
              controller: _repsControllers[index],
              enabled: !locked,
              decimal: false,
            ),
          ),
          const SizedBox(width: 8),
          if (isSaving)
            const SizedBox(
              width: 92,
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else ...[
            _setButton(
              icon: Icons.close_rounded,
              tooltip: isSkipped ? 'Skipped' : 'Skip set ${index + 1}',
              // outlined grey until chosen, solid grey once skipped
              color: skipGrey,
              filled: isSkipped,
              hidden: isDone,
              onPressed: (locked || busy)
                  ? null
                  : () => _onSetButton(index, completed: false),
            ),
            const SizedBox(width: 4),
            _setButton(
              icon: Icons.check_rounded,
              tooltip: isDone ? 'Done' : 'Log set ${index + 1}',
              color: isDone ? doneGreen : workoutBlue,
              filled: !isSkipped,
              hidden: isSkipped,
              onPressed: (locked || busy)
                  ? null
                  : () => _onSetButton(index, completed: true),
            ),
          ],
        ],
      ),
    );
  }

  // Square icon button used for skip / done. `hidden` keeps the space so
  // the rows stay lined up once the other option has been picked.
  Widget _setButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required bool filled,
    required bool hidden,
    required VoidCallback? onPressed,
  }) {
    if (hidden) return const SizedBox(width: 44, height: 44);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
    );
    return SizedBox(
      width: 44,
      height: 44,
      child: filled
          ? IconButton.filled(
              onPressed: onPressed,
              tooltip: tooltip,
              style: IconButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor:
                    onPressed == null && color == workoutBlue
                        ? const Color(0xFFD5E5F1)
                        : color,
                shape: shape,
              ),
              icon: Icon(icon, color: Colors.white),
            )
          : IconButton.outlined(
              onPressed: onPressed,
              tooltip: tooltip,
              style: IconButton.styleFrom(
                side: BorderSide(color: color.withValues(alpha: 0.6), width: 2),
                shape: shape,
              ),
              icon: Icon(icon, color: color),
            ),
    );
  }

  Widget _setField({
    required TextEditingController controller,
    required bool enabled,
    required bool decimal,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD5E5F1), width: 2),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d*'),
        ),
      ],
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: enabled ? const Color(0xFFF9FCFF) : workoutLightBlue,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 13,
        ),
        enabledBorder: border,
        disabledBorder: border.copyWith(borderSide: BorderSide.none),
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: workoutBlue, width: 2),
        ),
      ),
      style: const TextStyle(
        color: workoutText,
        fontWeight: FontWeight.bold,
        fontSize: 16,
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
        onPressed: (_isFinishing || _savingSetIndex != null)
            ? null
            : _completeExercise,
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

  String _fmt(double w) =>
      w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();

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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                completed.exercise.name,
                                style: const TextStyle(
                                  color: workoutNavy,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (completed.isPr) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1C2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'New PR!',
                                  style: TextStyle(
                                    color: Color(0xFF8A6100),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          // e.g. "135×10 · 135×10 · skipped"
                          completed.sets
                              .map((s) => s.completed
                                  ? '${_fmt(s.weight)}×${s.reps}'
                                  : 'skipped')
                              .join(' · '),
                          style: const TextStyle(
                            color: Color(0xFF71849E),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${completed.doneSets.length}/${completed.sets.length} '
                    'sets',
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
