import 'package:flutter/material.dart';

import '../../services/api.dart';

class BodyWeightScreen extends StatefulWidget {
  const BodyWeightScreen({super.key});

  @override
  State<BodyWeightScreen> createState() => _BodyWeightScreenState();
}

class _BodyWeightScreenState extends State<BodyWeightScreen> {
  final _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _weights;

  @override
  void initState() {
    super.initState();
    _weights = ApiClient().getBodyWeights();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid body weight.')),
      );
      return;
    }
    try {
      await ApiClient().logBodyWeight(value);
      _controller.clear();
      setState(() => _weights = ApiClient().getBodyWeights());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body weight')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'lb',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _save, child: const Text('Log')),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _weights,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final entries = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (_, index) {
                      final entry = entries[index];
                      final date = DateTime.tryParse(
                        entry['logged_at'] as String? ?? '',
                      )?.toLocal();
                      return ListTile(
                        leading: const Icon(Icons.monitor_weight_outlined),
                        title: Text('${entry['weight']} lb'),
                        subtitle: Text(
                          date == null
                              ? ''
                              : '${date.month}/${date.day}/${date.year}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
