import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import '../models/workout.dart';
import '../models/sport_catalog.dart';
import '../features/tracker/widgets/route_painter.dart';
import 'glass_widgets.dart';

Widget sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: muted,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );
}

Widget metric(String label, String value, IconData icon, {String? suffix}) {
  return Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: muted, size: 22),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        if (suffix != null)
          Text(suffix, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    ),
  );
}

Widget statCard(String label, String value, IconData icon, {String? suffix}) {
  return GlassPanel(
    child: Row(
      children: [
        Icon(icon, color: lime, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                '$value${suffix == null ? '' : ' $suffix'}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
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

Widget workoutCard(Workout w, {bool showRoute = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x354F526B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x506F748E)),
                ),
                child: Icon(
                  w.sport == 'Велосипед'
                      ? Icons.directions_bike_rounded
                      : w.sport == 'Ходьба'
                      ? Icons.directions_walk_rounded
                      : Icons.directions_run_rounded,
                  color: lime,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SportCatalog.displayName(w.sport),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${w.distance.toStringAsFixed(2)} км · ${formatWorkoutDuration(w.duration)}',
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${w.date.day.toString().padLeft(2, '0')}.'
                      '${w.date.month.toString().padLeft(2, '0')}.'
                      '${w.date.year} · +${w.xp} XP',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showRoute) ...[
            const SizedBox(height: 14),
            if (w.route.length >= 2)
              SizedBox(
                height: 76,
                width: double.infinity,
                child: CustomPaint(painter: RoutePainter(w.route)),
              ),
            const SizedBox(height: 4),
            Text(
              w.route.length >= 2
                  ? 'GPS-маршрут сохранён'
                  : 'GPS-маршрут не записан',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget achievement(
  IconData icon,
  String title,
  String subtitle,
  bool unlocked,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      child: Row(
        children: [
          Icon(icon, color: unlocked ? lime : muted, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            unlocked ? Icons.check_circle : Icons.lock_outline,
            color: unlocked ? lime : muted,
            size: 22,
          ),
        ],
      ),
    ),
  );
}

Widget emptyCard(String text) {
  return GlassPanel(
    child: Row(
      children: [
        const Icon(Icons.route_rounded, color: muted, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: muted, fontSize: 15, height: 1.5),
          ),
        ),
      ],
    ),
  );
}
