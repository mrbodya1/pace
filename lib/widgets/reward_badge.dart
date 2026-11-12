import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import '../models/achievement.dart';
import '../models/sport_catalog.dart';

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

enum BadgeMaterial {
  wood('Дерево'),
  iron('Железо'),
  bronze('Бронза'),
  silver('Серебро'),
  gold('Золото'),
  diamond('Бриллиант');

  const BadgeMaterial(this.label);
  final String label;
  Color get ink =>
      index < 2 ? const Color(0xFFFFF3D6) : const Color(0xFF080B10);

  static BadgeMaterial forAchievement(AchievementRule rule) {
    // Rank is local to this sport/metric, never inferred from XP or rule IDs.
    final thresholds =
        AchievementCatalog.rules
            .where((r) => r.sport == rule.sport && r.metric == rule.metric)
            .map((r) => r.threshold)
            .toSet()
            .toList()
          ..sort();
    final index = thresholds.indexOf(rule.threshold);
    if (index < 0 || thresholds.length < 2) return wood;
    return values[(index * (values.length - 1) / (thresholds.length - 1))
        .round()];
  }
}

class RewardBadge extends StatelessWidget {
  const RewardBadge({
    super.key,
    required this.category,
    required this.value,
    required this.unit,
    this.earned = true,
    this.size = 68,
    this.sport = 'Все виды',
    this.material = BadgeMaterial.wood,
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
      sport: rule.sport,
      material: BadgeMaterial.forAchievement(rule),
    );
  }
  factory RewardBadge.record(
    double meters, {
    bool earned = true,
    double size = 68,
    String sport = 'Все виды',
  }) {
    final number = displayNumber(meters / 1000, 'км');
    return RewardBadge(
      category: RewardCategory.record,
      value: number.value,
      unit: number.unit,
      earned: earned,
      size: size,
      sport: sport,
      // Records repeat indefinitely: do not invent a final improvement tier.
      material: BadgeMaterial.gold,
    );
  }
  final RewardCategory category;
  final String value, unit, sport;
  final bool earned;
  final double size;
  final BadgeMaterial material;

  IconData get sportIcon {
    final index = SportCatalog.names.indexOf(SportCatalog.displayName(sport));
    return index < 0 ? Icons.bolt_rounded : SportCatalog.icons[index];
  }

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
    final height = size + 12;
    final runningDistance =
        sport == 'Бег' && category == RewardCategory.sportDistance;
    final folder = runningDistance ? 'running-distance' : 'materials';
    final image = Image.asset(
      'assets/images/achievements/$folder/${material.name}.png',
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
    final ink = earned ? material.ink : const Color(0xFFE0E2EA);
    return Semantics(
      label:
          '$sport, ${category.label}: $value $unit, ${material.label}, ${earned ? 'получено' : 'не получено'}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (earned)
                image
              else
                Opacity(
                  opacity: .4,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: image,
                  ),
                ),
              if (!runningDistance) ...[
                Positioned(
                  top: height * .13,
                  left: size * .3,
                  right: size * .3,
                  child: Icon(sportIcon, color: ink, size: height * .2),
                ),
                Positioned(
                  bottom: height * .12,
                  left: size * .3,
                  right: size * .3,
                  child: Icon(category.icon, color: ink, size: height * .17),
                ),
              ],
              Positioned(
                top: height * .34,
                height: height * .27,
                left: size * .15,
                right: size * .15,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: size * .43,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: height * .62,
                height: height * .09,
                left: size * .2,
                right: size * .2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    unit,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: size * .15,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
              ),
              if (!earned)
                Positioned(
                  right: 0,
                  bottom: 1,
                  child: Icon(
                    Icons.lock_rounded,
                    size: size * .19,
                    color: muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
