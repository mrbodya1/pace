import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/storage/local_storage_service.dart';
import '../../models/workout.dart';
import '../../models/achievement.dart';
import '../../widgets/pace_page_scaffold.dart';
import 'workout_details_page.dart';

class StoredWorkoutDetails extends StatefulWidget {
  const StoredWorkoutDetails({
    super.key,
    required this.storage,
    required this.id,
    this.updates,
  });
  final LocalStorageService storage;
  final String id;
  final ValueListenable<List<Workout>>? updates;
  @override
  State<StoredWorkoutDetails> createState() => _StoredWorkoutDetailsState();
}

class _StoredWorkoutDetailsState extends State<StoredWorkoutDetails> {
  late Future<({Workout? workout, Map<String, dynamic>? state})> future;
  @override
  void initState() {
    super.initState();
    future = _read();
    widget.updates?.addListener(_reload);
  }

  Future<({Workout? workout, Map<String, dynamic>? state})> _read() async => (
    workout: await widget.storage.loadWorkout(widget.id),
    state: await widget.storage.loadProgress(),
  );
  void _reload() {
    if (mounted) setState(() => future = _read());
  }

  @override
  void dispose() {
    widget.updates?.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return PacePageScaffold(
          title: 'Тренировка',
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Не удалось загрузить подробности. Если запись сделана на другом устройстве, проверь подключение к серверу.',
                    textAlign: TextAlign.center,
                  ),
                ),
                OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const PacePageScaffold(
          title: 'Тренировка',
          body: Center(child: CircularProgressIndicator()),
        );
      }
      final workout = data.workout, state = data.state;
      if (workout == null) {
        return const PacePageScaffold(
          title: 'Тренировка',
          body: Center(child: Text('Тренировка недоступна.')),
        );
      }
      return WorkoutDetailsPage(
        workout: workout,
        history: [workout],
        achievements: AchievementEngine.restore(state?['achievements'], []),
        aggregateProgress: state?['totals'] is Map
            ? AchievementProgress.fromJson(
                Map<String, dynamic>.from(state!['totals'] as Map),
              )
            : null,
        recordState: state?['records'] is Map
            ? Map<String, dynamic>.from(state!['records'] as Map)
            : null,
      );
    },
  );
}
