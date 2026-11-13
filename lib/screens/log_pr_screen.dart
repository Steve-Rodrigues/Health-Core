import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';

/// Lets the user log a PR they set outside the app: filter by muscle,
/// search by name, tap an exercise, then enter weight and reps.
class LogPrScreen extends StatefulWidget {
  const LogPrScreen({super.key});

  @override
  State<LogPrScreen> createState() => _LogPrScreenState();
}

class _LogPrScreenState extends State<LogPrScreen> {
  static const Color background = Color(0xFFF2F7FC);
  static const Color navy = Color(0xFF062D63);
  static const Color blue = Color(0xFF086AC7);
  static const Color mutedText = Color(0xFF657B9A);
  static const Color successGreen = Color(0xFF397C61);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _exercises = []; // everything from /lifting/exercises
  List<String> _muscles = []; // built from the data so new muscles show up on their own
  String? _selectedMuscle; // null = All
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final exercises = await ApiClient().getExercises();
      if (!mounted) return;
      final muscles = exercises
          .map((e) => e['primary_muscle'] as String? ?? '')
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _exercises = exercises;
        _muscles = muscles;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  /// Filtering happens on the device, so results update as the user types.
  List<Map<String, dynamic>> get _filtered {
    final query = _query.trim().toLowerCase();
    return _exercises.where((e) {
      if (_selectedMuscle != null && e['primary_muscle'] != _selectedMuscle) return false;
      if (query.isEmpty) return true;
      return (e['name'] as String? ?? '').toLowerCase().contains(query);
    }).toList();
  }

  /// "middle back" -> "Middle Back"
  String _titleCase(String text) => text
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Log a PR'),
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: navy)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadExercises, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final results = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search exercises…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _muscleChip(null, 'All'),
              for (final muscle in _muscles) _muscleChip(muscle, _titleCase(muscle)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${results.length} exercises',
              style: const TextStyle(color: mutedText, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('No exercises match that search.', style: TextStyle(color: mutedText)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: results.length,
                  itemBuilder: (_, i) => _exerciseTile(results[i]),
                ),
        ),
      ],
    );
  }

  Widget _muscleChip(String? muscle, String label) {
    final selected = _selectedMuscle == muscle;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedMuscle = muscle),
        selectedColor: navy,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : navy, fontWeight: FontWeight.w500),
        showCheckmark: false,
        side: BorderSide(color: selected ? navy : const Color(0xFFD5E5F1)),
      ),
    );
  }

  Widget _exerciseTile(Map<String, dynamic> exercise) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(exercise['name'] as String? ?? 'Exercise', style: const TextStyle(color: navy)),
        subtitle: Text(
          _titleCase(exercise['primary_muscle'] as String? ?? ''),
          style: const TextStyle(color: mutedText, fontSize: 12),
        ),
        trailing: const Icon(Icons.add_circle_outline, color: blue),
        onTap: () => _openLogSheet(exercise),
      ),
    );
  }

  Future<void> _openLogSheet(Map<String, dynamic> exercise) async {
    final name = exercise['name'] as String? ?? 'Exercise';
    final newPr = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // lets the sheet move up above the keyboard
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LogPrSheet(exerciseId: exercise['id'] as String, exerciseName: name),
    );
    if (newPr == null || !mounted) return; // sheet closed without saving

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newPr ? 'New PR saved for $name! 🎉' : 'Not saved: your current $name PR is higher.',
        ),
        backgroundColor: newPr ? successGreen : navy,
      ),
    );
  }
}

/// Bottom sheet with weight + reps fields. Pops with the backend's `new_pr`.
class _LogPrSheet extends StatefulWidget {
  const _LogPrSheet({required this.exerciseId, required this.exerciseName});

  final String exerciseId;
  final String exerciseName;

  @override
  State<_LogPrSheet> createState() => _LogPrSheetState();
}

class _LogPrSheetState extends State<_LogPrSheet> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weightController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    // Same rules as the backend schema: weight >= 0, reps >= 1.
    if (weight == null || !weight.isFinite || weight < 0) {
      setState(() => _error = 'Enter a valid weight.');
      return;
    }
    if (reps == null || reps < 1) {
      setState(() => _error = 'Enter at least 1 rep.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final newPr = await ApiClient().setPersonalRecord(
        exerciseId: widget.exerciseId,
        weight: weight,
        reps: reps,
      );
      if (mounted) Navigator.pop(context, newPr);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keep the fields above the on-screen keyboard.
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.exerciseName,
            style: const TextStyle(
              color: _LogPrScreenState.navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Only saved if it beats your current PR (by estimated 1-rep max).',
            style: TextStyle(color: _LogPrScreenState.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    suffixText: 'lb',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Reps',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _LogPrScreenState.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save PR'),
          ),
        ],
      ),
    );
  }
}
