import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.xp,
    required this.level,
    required this.levelStart,
    required this.levelEnd,
    required this.workouts,
    required this.header,
    required this.onStartWorkout,
  });

  final int xp;
  final int level;
  final int levelStart;
  final int levelEnd;
  final List<Workout> workouts;
  final Widget header;
  final VoidCallback onStartWorkout;

  @override
  Widget build(BuildContext context) {
    final progress =
        ((xp - levelStart) / (levelEnd - levelStart)).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        header,
        const SizedBox(height: 28),
        const Text(
          'ТВОЙ ПУТЬ. ТВОИ ПРАВИЛА.',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Стань своей\nлучшей версией.',
          style: TextStyle(
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF292E24), Color(0xFF1A1D17)],
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'АТЛЕТ · УРОВЕНЬ',
                style: TextStyle(
                  color: lime,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$level',
                    style: const TextStyle(
                      fontSize: 65,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BODYA',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Универсальный атлет',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '$xp XP',
                style: const TextStyle(
                  color: lime,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(lime),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${levelEnd - xp} XP до уровня ${level + 1}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        sectionTitle('ТВОЯ СТАТИСТИКА'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: statCard(
                'ТРЕНИРОВКИ',
                '${workouts.length}',
                Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: statCard(
                'ДИСТАНЦИЯ',
                workouts.fold<double>(
                  0,
                  (sum, w) => sum + w.distance,
                ).toStringAsFixed(1),
                Icons.route_rounded,
                suffix: 'км',
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        sectionTitle('ПОСЛЕДНИЕ ТРЕНИРОВКИ'),
        const SizedBox(height: 12),
        if (workouts.isEmpty)
          emptyCard('Здесь появятся твои реальные GPS-тренировки.')
        else
          ...workouts.take(3).map(workoutCard),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onStartWorkout,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Начать тренировку'),
          style: FilledButton.styleFrom(
            backgroundColor: lime,
            foregroundColor: bg,
            minimumSize: const Size.fromHeight(54),
          ),
        ),
      ],
    );
  }

}
