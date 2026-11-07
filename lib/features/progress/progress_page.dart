import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({
    super.key,
    required this.xp,
    required this.level,
    required this.workouts,
  });

  final int xp;
  final int level;
  final List<Workout> workouts;

  @override
  Widget build(BuildContext context) {
    final totalDistance = workouts.fold<double>(
      0,
      (sum, w) => sum + w.distance,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        const Text(
          'Твой прогресс',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        statCard('УРОВЕНЬ', '$level', Icons.military_tech_rounded),
        const SizedBox(height: 12),
        statCard('ОБЩИЙ XP', '$xp', Icons.bolt_rounded),
        const SizedBox(height: 12),
        statCard(
          'ЗАПИСАННЫЕ КМ',
          totalDistance.toStringAsFixed(2),
          Icons.route_rounded,
        ),
        const SizedBox(height: 24),
        sectionTitle('ДОСТИЖЕНИЯ'),
        const SizedBox(height: 12),
        achievement(
          Icons.directions_run_rounded,
          'Первый шаг',
          'Запиши первую тренировку',
          workouts.isNotEmpty,
        ),
        achievement(
          Icons.route_rounded,
          'Первые 10 км',
          'Накопи 10 км',
          totalDistance >= 10,
        ),
        achievement(
          Icons.bolt_rounded,
          'Уровень 5',
          'Набери 9000 XP',
          xp >= 9000,
        ),
      ],
    );
  }
}
