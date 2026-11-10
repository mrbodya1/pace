import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import '../models/workout.dart';
import '../models/xp_progress.dart';
import 'glass_widgets.dart';

class WorkoutResultSummary extends StatelessWidget {
  const WorkoutResultSummary({super.key, required this.workout});
  final Workout workout;
  String _number(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
  Widget _line(String name, int xp) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(name, style: const TextStyle(color: muted, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Text('+${_number(xp)} XP', style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final before = workout.xpBefore, after = workout.xpAfter;
    final valid =
        before != null &&
        after != null &&
        before >= 0 &&
        after - before == workout.xp;
    final progress = valid ? XpProgress(after) : null;
    final previous = valid ? XpProgress(before) : null;
    return GlassPanel(
      key: const ValueKey('workout-result-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ТВОЙ ПРОГРЕСС',
            style: TextStyle(color: muted, fontSize: 12, letterSpacing: 1.3),
          ),
          const SizedBox(height: 8),
          Text(
            '+${_number(workout.xp)} XP',
            key: const ValueKey('result-total-xp'),
            style: const TextStyle(
              color: lime,
              fontSize: 34,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _line(
            'Тренировка',
            workout.xp - workout.achievementXp - workout.recordXp,
          ),
          _line(
            'Достижения · ${workout.achievementIds.length}',
            workout.achievementXp,
          ),
          _line('Рекорды · ${workout.records.length}', workout.recordXp),
          if (progress != null && previous != null) ...[
            const Divider(height: 28),
            Text(
              progress.level > previous.level
                  ? 'Новый уровень ${progress.level}'
                  : 'Уровень ${progress.level}',
              key: const ValueKey('result-level'),
              style: const TextStyle(
                color: lime,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (progress.level > previous.level)
              Text(
                '${previous.level} → ${progress.level}',
                style: const TextStyle(color: muted),
              ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.fraction,
              color: lime,
              backgroundColor: const Color(0xFF383D4E),
            ),
            const SizedBox(height: 8),
            Text(
              '${_number(progress.earnedInLevel)} / ${_number(progress.levelEnd - progress.levelStart)} XP',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            Text(
              'Ещё ${_number(progress.remaining)} XP до уровня ${progress.level + 1}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
