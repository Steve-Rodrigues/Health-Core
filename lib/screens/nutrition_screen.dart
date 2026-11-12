import 'package:flutter/material.dart';

import '../services/api.dart';
import 'barcode_flow_screens.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  static const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  final _api = ApiClient();
  DateTime _day = _dateOnly(DateTime.now());
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _commonMeals = [];
  bool _loading = true;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Sunday at midnight of the week containing [_day].
  DateTime get _weekStart =>
      DateTime(_day.year, _day.month, _day.day - _day.weekday % 7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loaded separately so a failure here doesn't hide the daily summary.
  Future<void> _loadCommonMeals() async {
    try {
      final meals = await _api.getMostCommonMeals();
      if (mounted) setState(() => _commonMeals = meals);
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _load() async {
    _loadCommonMeals();
    final requested = _day;
    setState(() => _loading = true);
    try {
      final summary = await _api.getNutritionSummary(requested);
      // Ignore stale responses if the user tapped another day meanwhile.
      if (mounted && _sameDay(requested, _day)) {
        setState(() => _summary = summary);
      }
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted && _sameDay(requested, _day)) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectDay(DateTime day) {
    final picked = _dateOnly(day);
    final today = _dateOnly(DateTime.now());
    if (picked.isAfter(today) || _sameDay(picked, _day)) return;
    setState(() => _day = picked);
    _load();
  }

  /// Moves the strip by a week, landing on the same weekday (clamped to today).
  void _shiftWeek(int weeks) {
    final target = DateTime(_day.year, _day.month, _day.day + 7 * weeks);
    final today = _dateOnly(DateTime.now());
    _selectDay(target.isAfter(today) ? today : target);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) _selectDay(picked);
  }

  Widget _buildWeekStrip() {
    final scheme = Theme.of(context).colorScheme;
    final today = _dateOnly(DateTime.now());
    return GestureDetector(
      // Swipe right for the previous week, left for the next one.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 200) _shiftWeek(-1);
        if (v < -200) _shiftWeek(1);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: List.generate(7, (i) {
            final day = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i);
            final selected = _sameDay(day, _day);
            final future = day.isAfter(today);
            final isToday = _sameDay(day, today);
            final color = selected
                ? scheme.onPrimary
                : future
                    ? scheme.onSurface.withValues(alpha: 0.38)
                    : scheme.onSurface;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: future ? null : () => _selectDay(day),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : null,
                    borderRadius: BorderRadius.circular(16),
                    border: isToday && !selected
                        ? Border.all(color: scheme.primary)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(_weekdayLabels[i],
                          style: TextStyle(fontSize: 12, color: color)),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCommonMealCard(Map<String, dynamic> meal) {
    String amount(String key) => formatAmount(meal[key] as num? ?? 0);
    return Card(
      child: ListTile(
        title: Text(meal['meal_name']?.toString() ?? ''),
        subtitle: Text(
          'P ${amount('protein')}g · C ${amount('carbs')}g · F ${amount('fat')}g',
        ),
        trailing: Text(
          '${amount('calories')} kcal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _addMeal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _MealDialog(),
    );
    if (result == null) return;
    try {
      await _api.createMeal(
        mealName: result['name'].toString(),
        mealType: result['type'].toString(),
        calories: result['calories']!,
        protein: result['protein']!,
        carbs: result['carbs']!,
        fat: result['fat']!,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }

  }

  Future<void> _scanBarcode() async {
    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (logged == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal logged')),
      );
      await _load();
    }
  }

  Future<void> _editGoals() async {
    final goals = await showDialog<List<int>>(
      context: context,
      builder: (context) => const _GoalsDialog(),
    );
    if (goals == null) return;
    try {
      await _api.saveNutritionGoals(
        calories: goals[0],
        protein: goals[1],
        carbs: goals[2],
        fat: goals[3],
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumed = _summary?['macros_consumed_counts'] as Map? ?? {};
    final goals = _summary?['macro_goals'] as Map?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          IconButton(
            tooltip: 'Pick a date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekStrip(),
          Expanded(
            child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            '${(_summary?['macro_score'] as num?)?.toStringAsFixed(1) ?? '—'}%',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          const Text('Daily macro score'),
                          const SizedBox(height: 18),
                          for (final macro in ['calories', 'protein', 'carbs', 'fat'])
                            ListTile(
                              title: Text(macro[0].toUpperCase() + macro.substring(1)),
                              trailing: Text(
                                formatAmount(consumed[macro] as num? ?? 0) +
                                    (goals == null ? '' : ' / ${goals[macro] ?? 0}'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addMeal,
                    icon: const Icon(Icons.add),
                    label: const Text('Log a meal'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan a barcode'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _editGoals,
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(goals == null ? 'Set macro goals' : 'Edit macro goals'),
                  ),
                  if (_commonMeals.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Your usual meals',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final meal in _commonMeals) _buildCommonMealCard(meal),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _GoalsDialog extends StatefulWidget {
  const _GoalsDialog();

  @override
  State<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends State<_GoalsDialog> {
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_calories, _protein, _carbs, _fat]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextField field(TextEditingController controller, String label) =>
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        );
    return AlertDialog(
      title: const Text('Macro goals'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field(_calories, 'Calories'),
          field(_protein, 'Protein (g)'),
          field(_carbs, 'Carbs (g)'),
          field(_fat, 'Fat (g)'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final values = [_calories, _protein, _carbs, _fat]
                .map((controller) => int.tryParse(controller.text) ?? 0)
                .toList();
            if (values.any((value) => value <= 0)) return;
            Navigator.pop(context, values);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _MealDialog extends StatefulWidget {
  const _MealDialog();

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  final _name = TextEditingController();
  final _calories = TextEditingController(text: '0');
  final _protein = TextEditingController(text: '0');
  final _carbs = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  String _type = 'breakfast';

  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextField field(TextEditingController controller, String label) =>
        TextField(controller: controller, decoration: InputDecoration(labelText: label));
    return AlertDialog(
      title: const Text('Log a meal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field(_name, 'Meal name'),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: ['breakfast', 'lunch', 'dinner', 'snack']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _type = value!),
              decoration: const InputDecoration(labelText: 'Meal type'),
            ),
            field(_calories, 'Calories'),
            field(_protein, 'Protein'),
            field(_carbs, 'Carbs'),
            field(_fat, 'Fat'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'type': _type,
              'calories': int.tryParse(_calories.text) ?? 0,
              'protein': int.tryParse(_protein.text) ?? 0,
              'carbs': int.tryParse(_carbs.text) ?? 0,
              'fat': int.tryParse(_fat.text) ?? 0,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
