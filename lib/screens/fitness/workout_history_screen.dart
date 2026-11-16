import 'package:flutter/material.dart';
import '../../services/api.dart';

class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF062D63),
      appBar: AppBar(
        title: const Text('Workout log'),
        backgroundColor: const Color(0xFF062D63),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ApiClient().getWorkoutHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Could not load your workout log.',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          }
          final workouts = snapshot.data ?? [];
          if (workouts.isEmpty) {
            return const Center(child: Text('Completed workouts will appear here.', style: TextStyle(color: Colors.white)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: workouts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final workout = workouts[index];
              final completed = DateTime.tryParse(workout['completed_at'] as String? ?? '')?.toLocal();
              final date = completed == null ? 'Date unavailable' : '${completed.month}/${completed.day}/${completed.year}';
              final volume = (workout['total_volume'] as num?)?.round() ?? 0;
              return Card(
                child: ListTile(
                  title: Text(workout['workout_name'] as String? ?? 'Workout'),
                  subtitle: Text('$date · ${workout['duration'] ?? 0} min · ${workout['total_sets'] ?? 0} sets'),
                  trailing: Text('$volume lb\nvolume', textAlign: TextAlign.end),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
