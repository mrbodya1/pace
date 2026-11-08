import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/sport_catalog.dart';
import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_widgets.dart';
import '../tracker/widgets/route_painter.dart';

class WorkoutDetailsPage extends StatelessWidget {
  const WorkoutDetailsPage({super.key, required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    final pace = w.distance > 0 ? w.duration.inSeconds / w.distance : 0.0;
    final seconds = pace.round();
    final speed = w.duration.inSeconds > 0
        ? w.distance * 3600 / w.duration.inSeconds
        : 0.0;
    final useSpeed = SportCatalog.usesSpeed(w.sport);
    return Scaffold(
      appBar: AppBar(title: Text(w.sport)),
      body: PaceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
          children: [
            Text(
              '${w.date.day.toString().padLeft(2, '0')}.'
              '${w.date.month.toString().padLeft(2, '0')}.${w.date.year}',
              style: const TextStyle(color: muted, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Text(
              '${w.distance.toStringAsFixed(2).replaceAll('.', ',')} км',
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 22),
            statCard(
              'ВРЕМЯ',
              formatWorkoutDuration(w.duration),
              Icons.timer_outlined,
            ),
            const SizedBox(height: 12),
            statCard(
              useSpeed ? 'СРЕДНЯЯ СКОРОСТЬ' : 'СРЕДНИЙ ТЕМП',
              useSpeed
                  ? '${speed.toStringAsFixed(1)} км/ч'
                  : seconds > 0
                  ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} мин/км'
                  : '--:--',
              Icons.speed_rounded,
            ),
            const SizedBox(height: 12),
            statCard('ЗАРАБОТАНО XP', '+${w.xp}', Icons.bolt_rounded),
            const SizedBox(height: 24),
            sectionTitle('МАРШРУТ'),
            const SizedBox(height: 12),
            GlassPanel(
              child: SizedBox(
                height: 240,
                width: double.infinity,
                child: w.route.length >= 2
                    ? CustomPaint(painter: RoutePainter(w.route))
                    : const Center(
                        child: Text(
                          'У этой тренировки нет сохранённого маршрута.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
