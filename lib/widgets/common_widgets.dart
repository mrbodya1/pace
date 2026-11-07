import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import '../models/workout.dart';
import '../features/tracker/widgets/route_painter.dart';

Widget sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: muted,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
    ),
  );
}

Widget metric(
  String label,
  String value,
  IconData icon, {
  String? suffix,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: lime, size: 19),
        const SizedBox(height: 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (suffix != null)
          Text(
            suffix,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

Widget statCard(
  String label,
  String value,
  IconData icon, {
  String? suffix,
}) {
  return Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Icon(icon, color: lime, size: 23),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$value${suffix == null ? '' : ' $suffix'}',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String formatWorkoutDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
}

Widget workoutCard(Workout w) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_rounded, color: lime, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.sport,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${w.date.day.toString().padLeft(2, '0')}.'
                    '${w.date.month.toString().padLeft(2, '0')}.'
                    '${w.date.year} · ${formatWorkoutDuration(w.duration)}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${w.distance.toStringAsFixed(2)} км',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '+${w.xp} XP',
                  style: const TextStyle(
                    color: lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (w.route.length >= 2) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            width: double.infinity,
            child: CustomPaint(
              painter: RoutePainter(w.route),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'GPS-маршрут сохранён',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'GPS-маршрут не записан',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ],
    ),
  );
}

Widget achievement(
  IconData icon,
  String title,
  String subtitle,
  bool unlocked,
) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: unlocked ? lime : muted, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Icon(
          unlocked ? Icons.check_circle : Icons.lock_outline,
          color: unlocked ? lime : muted,
        ),
      ],
    ),
  );
}

Widget emptyCard(String text) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: const TextStyle(color: muted, height: 1.5),
    ),
  );
}
