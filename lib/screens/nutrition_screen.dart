import 'package:flutter/material.dart';

import '../services/api.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final _api = ApiClient();
  DateTime _day = DateTime.now();
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await _api.getNutritionSummary(_day);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      appBar: AppBar(title: const Text('Nutrition')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() => _day = _day.subtract(const Duration(days: 1)));
                          _load();
                        },
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${_day.month}/${_day.day}/${_day.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _day = _day.add(const Duration(days: 1)));
                          _load();
                        },
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
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
                                '${consumed[macro] ?? 0}'
                                '${goals == null ? '' : ' / ${goals[macro] ?? 0}'}',
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
                  OutlinedButton.icon(
                    onPressed: _editGoals,
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(goals == null ? 'Set macro goals' : 'Edit macro goals'),
                  ),
                ],
              ),
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
