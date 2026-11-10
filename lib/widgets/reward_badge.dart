import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import '../models/achievement.dart';

const recordGold = Color(0xFFF3C879);

enum RewardCategory {
  totalHours('Общие часы', Icons.access_time),
  totalWorkouts('Общие тренировки', Icons.layers_outlined),
  totalDistance('Общие километры', Icons.public),
  variety('Разные виды спорта', Icons.sports),
  sportHours('Часы по виду', Icons.timer_outlined),
  sportWorkouts('Тренировки по виду', Icons.directions_run),
  sportDistance('Километры по виду', Icons.route),
  workoutDistance('Дистанция тренировки', Icons.flag_outlined),
  workoutAscent('Набор за тренировку', Icons.landscape_outlined),
  totalAscent('Накопленный набор', Icons.terrain),
  record('Рекорд на дистанции', Icons.emoji_events_outlined);

  const RewardCategory(this.label, this.icon);
  final String label;
  final IconData icon;
  static RewardCategory fromMetric(String metric) => switch (metric) {
    'Общее время' => totalHours,
    'Общие тренировки' => totalWorkouts,
    'Общие километры' => totalDistance,
    'Разные виды спорта' => variety,
    'Время по виду' => sportHours,
    'Тренировки по виду' => sportWorkouts,
    'Километры по виду' => sportDistance,
    'Дистанция тренировки' => workoutDistance,
    'Набор за тренировку' => workoutAscent,
    'Накопленный набор' => totalAscent,
    'Рекорд на дистанции' => record,
    _ => throw ArgumentError.value(metric, 'metric', 'Unknown reward category'),
  };
}

class RewardBadge extends StatelessWidget {
  const RewardBadge({
    super.key,
    required this.category,
    required this.value,
    required this.unit,
    this.earned = true,
    this.size = 68,
  });
  factory RewardBadge.achievement(
    AchievementRule rule, {
    bool earned = true,
    double size = 68,
  }) {
    final number = displayNumber(rule.threshold, rule.unit);
    return RewardBadge(
      category: RewardCategory.fromMetric(rule.metric),
      value: number.value,
      unit: number.unit,
      earned: earned,
      size: size,
    );
  }
  factory RewardBadge.record(
    double meters, {
    bool earned = true,
    double size = 68,
  }) {
    final number = displayNumber(meters / 1000, 'км');
    return RewardBadge(
      category: RewardCategory.record,
      value: number.value,
      unit: number.unit,
      earned: earned,
      size: size,
    );
  }
  final RewardCategory category;
  final String value, unit;
  final bool earned;
  final double size;
  static ({String value, String unit}) displayNumber(
    double value,
    String unit,
  ) {
    if (unit == 'км' && value < 1) {
      return (value: (value * 1000).round().toString(), unit: 'м');
    }
    final label = switch (unit) {
      'тренировок' => 'трен.',
      'видов' => 'вида',
      _ => unit,
    };
    return (
      value: value
          .toString()
          .replaceAll(RegExp(r'\.0$'), '')
          .replaceAll('.', ','),
      unit: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = earned
        ? (category == RewardCategory.record ? recordGold : lime)
        : muted;
    return Semantics(
      label: '${category.label}: $value $unit',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size + 12,
          child: CustomPaint(
            painter: _BadgePainter(category, accent),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(category.icon, size: 16, color: accent),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 23,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: earned ? Colors.white : muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    unit,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter(this.category, this.accent);
  final RewardCategory category;
  final Color accent;
  Path _shape(Rect r) {
    if (category == RewardCategory.record ||
        category == RewardCategory.totalHours ||
        category == RewardCategory.sportHours) {
      return Path()..addOval(r);
    }
    final points = category == RewardCategory.sportWorkouts
        ? const [
            Offset(.5, 0),
            Offset(.93, .14),
            Offset(.88, .66),
            Offset(.72, .86),
            Offset(.5, 1),
            Offset(.28, .86),
            Offset(.12, .66),
            Offset(.07, .14),
          ]
        : const [
            Offset(.5, 0),
            Offset(.94, .24),
            Offset(.94, .76),
            Offset(.5, 1),
            Offset(.06, .76),
            Offset(.06, .24),
          ];
    return Path()..addPolygon(
      points
          .map((p) => Offset(r.left + p.dx * r.width, r.top + p.dy * r.height))
          .toList(),
      true,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = _shape(rect.deflate(2));
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF303846), Color(0xFF171B28)],
        ).createShader(rect),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: .25), accent],
        ).createShader(rect),
    );
    canvas.drawPath(
      _shape(rect.deflate(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = accent.withValues(alpha: .16),
    );
  }

  @override
  bool shouldRepaint(_BadgePainter oldDelegate) =>
      oldDelegate.category != category || oldDelegate.accent != accent;
}
