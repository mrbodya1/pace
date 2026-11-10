import 'package:flutter/foundation.dart';

import '../progress/levels_page.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/xp_ring.dart';
import '../workouts/workout_details_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.xp,
    required this.level,
    required this.levelStart,
    required this.levelEnd,
    required this.workouts,
    this.historyUpdates,
    required this.header,
  });

  final int xp, level, levelStart, levelEnd;
  final List<Workout> workouts;
  final ValueListenable<List<Workout>>? historyUpdates;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final totalDistance = workouts.fold<double>(
      0,
      (sum, w) => sum + w.distance,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 132),
      children: [
        header,
        const SizedBox(height: 4),
        Text(
          '${now.day} ${months[now.month - 1]} ${now.year}',
          style: const TextStyle(color: muted, fontSize: 16),
        ),
        const SizedBox(height: 16),
        XpRing(
          xp: xp,
          level: level,
          levelStart: levelStart,
          levelEnd: levelEnd,
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            key: const ValueKey('open-levels'),
            onPressed: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => LevelsPage(xp: xp))),
            icon: const Icon(Icons.stairs_outlined),
            label: const Text('Шкала уровней'),
          ),
        ),
        const SizedBox(height: 18),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _Summary(
                  icon: CupertinoIcons.flame,
                  label: 'Тренировки',
                  value: '${workouts.length}',
                ),
              ),
              const VerticalDivider(width: 24),
              Expanded(
                child: _Summary(
                  icon: CupertinoIcons.location,
                  label: 'Дистанция',
                  value: '${totalDistance.toStringAsFixed(1)} км',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 24),
        const Text(
          'Последняя тренировка',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        if (workouts.isEmpty)
          emptyCard('Здесь появится твоя первая GPS-тренировка.')
        else
          Semantics(
            button: true,
            label: 'Открыть последнюю тренировку',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailsPage(
                    workout: workouts.first,
                    fromHistory: false,
                    history: workouts,
                    historyUpdates: historyUpdates,
                  ),
                ),
              ),
              child: workoutCard(workouts.first, showRoute: false),
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: muted, size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 14)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
