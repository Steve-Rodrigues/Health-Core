import 'package:flutter/material.dart';

import '../services/api.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _api = ApiClient();
  final _notes = TextEditingController();
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  int _quality = 4;
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool bed) async {
    final value = await showTimePicker(
      context: context,
      initialTime: bed ? _bed : _wake,
    );
    if (value == null || !mounted) return;
    setState(() {
      if (bed) {
        _bed = value;
      } else {
        _wake = value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _api.logSleep(
        wakeDate: DateTime.now(),
        bedTime: _time(_bed),
        wakeTime: _time(_wake),
        quality: _quality,
        notes: _notes.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sleep logged successfully.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Health')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Log last night', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Bed time'),
              trailing: Text(_time(_bed)),
              onTap: () => _pick(true),
            ),
            ListTile(
              title: const Text('Wake time'),
              trailing: Text(_time(_wake)),
              onTap: () => _pick(false),
            ),
            const SizedBox(height: 12),
            const Text('Sleep quality'),
            Slider(
              value: _quality.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_quality / 5',
              onChanged: (value) => setState(() => _quality = value.round()),
            ),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Log sleep'),
            ),
          ],
        ),
      );
}
