import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/xp_progress.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/pace_page_scaffold.dart';
import '../../widgets/xp_ring.dart';

class LevelsPage extends StatelessWidget {
  const LevelsPage({super.key, required this.xp});
  final int xp;
  String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
  @override
  Widget build(BuildContext context) {
    final progress = XpProgress(xp);
    final level = progress.level;
    final nearby = [
      for (var i = math.max(11, level - 1); i <= math.max(15, level + 4); i++)
        i,
    ];
    Widget tile(int n) {
      final start = XpProgress.xpForLevel(n);
      final end = XpProgress.xpForLevel(n + 1);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassPanel(
          key: ValueKey('level-$n'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Уровень $n',
                      style: TextStyle(
                        color: n == level ? lime : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (n <= level)
                    Icon(
                      n == level
                          ? Icons.my_location_rounded
                          : Icons.check_circle_outline_rounded,
                      semanticLabel: n == level
                          ? 'Текущий уровень'
                          : 'Уровень достигнут',
                      color: lime,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('С ${_number(start)} XP'),
              const SizedBox(height: 4),
              Text(
                n == level
                    ? 'Ещё ${_number(progress.remaining)} XP до уровня ${n + 1}'
                    : 'До следующего уровня: ${_number(end - start)} XP',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
      );
    }

    return PacePageScaffold(
      title: 'Шкала уровней',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
        children: [
          XpRing(
            xp: xp,
            level: level,
            levelStart: progress.levelStart,
            levelEnd: progress.levelEnd,
          ),
          const SizedBox(height: 16),
          const Text(
            'Один уровень для всех видов спорта',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'Тренировки, достижения и улучшения рекордов пополняют общий XP. Смена специализации не обнуляет прогресс.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          const Text(
            'У шкалы нет последнего уровня. После 10-го каждый следующий переход требует на 3 000 XP больше предыдущего.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          if (level > 10) ...[
            const Text('СЕЙЧАС И ДАЛЬШЕ', style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            for (final n in nearby) tile(n),
            const SizedBox(height: 12),
          ],
          const Text('ПЕРВЫЕ УРОВНИ', style: TextStyle(color: muted)),
          const SizedBox(height: 12),
          for (var n = 1; n <= 10; n++) tile(n),
          if (level <= 10) ...[
            const SizedBox(height: 12),
            const Text('ДАЛЬШЕ', style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            for (final n in nearby) tile(n),
          ],
        ],
      ),
    );
  }
}
