import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/achievement.dart';
import '../../models/personal_record.dart';
import '../../models/sport_catalog.dart';
import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/pace_page_scaffold.dart';
import '../../widgets/workout_result_summary.dart';
import '../../widgets/workout_rewards.dart';
import '../progress/achievements_view.dart';
import '../progress/records_view.dart';
import '../tracker/widgets/route_painter.dart';

class WorkoutDetailsPage extends StatelessWidget {
  const WorkoutDetailsPage({
    super.key,
    required this.workout,
    this.history = const [],
    this.historyUpdates,
    this.fromHistory = true,
  });
  final Workout workout;
  final List<Workout> history;
  final ValueListenable<List<Workout>>? historyUpdates;
  final bool fromHistory;

  Workout? _resolve(List<Workout> entries) => entries.where((w) {
    if (workout.sessionId != null) return w.sessionId == workout.sessionId;
    return identical(w, workout) ||
        (w.date == workout.date &&
            w.sport == workout.sport &&
            w.distance == workout.distance &&
            w.duration == workout.duration);
  }).firstOrNull;

  Widget _withHistory(Widget Function(List<Workout>) builder) {
    final updates = historyUpdates;
    if (updates == null) return builder(history.isEmpty ? [workout] : history);
    return ValueListenableBuilder<List<Workout>>(
      valueListenable: updates,
      builder: (_, entries, _) => builder(entries),
    );
  }

  void _openAchievement(BuildContext context, AchievementRule rule) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PacePageScaffold(
          title: 'Достижения',
          body: _withHistory(
            (entries) => AchievementsView(
              workouts: entries,
              initialSport: rule.sport,
              initialMetric: rule.metric,
              selectedId: rule.id,
            ),
          ),
        ),
      ),
    );
  }

  void _openRecord(BuildContext context, PersonalRecord record) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PacePageScaffold(
          title: 'Личные рекорды',
          body: _withHistory(
            (entries) => RecordsView(
              workouts: entries,
              initialSport: record.sport,
              selectedId: record.id,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _withHistory((entries) {
    final w = historyUpdates == null ? workout : _resolve(entries);
    if (w == null) {
      return PacePageScaffold(
        title: 'Тренировка',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Тренировка больше не доступна в истории.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    fromHistory ? 'К истории тренировок' : 'К главной',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final sport = SportCatalog.displayName(w.sport);
    final seconds = w.distance > 0
        ? (w.duration.inSeconds / w.distance / (w.sport == 'Плавание' ? 10 : 1))
              .round()
        : 0;
    final pace = seconds > 0
        ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
        : '--:--';
    final speed = w.duration.inSeconds > 0
        ? (w.distance * 3600 / w.duration.inSeconds)
              .toStringAsFixed(1)
              .replaceAll('.', ',')
        : '—';
    final start = w.startedAt?.toLocal();
    final date = start ?? w.date.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
        '${start == null ? '' : ' · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'}';
    final index = SportCatalog.names.indexOf(sport);
    final metrics = [
      _DetailMetric('Время в движении', formatWorkoutDuration(w.duration)),
      _DetailMetric(
        'Темп, ${w.sport == 'Плавание' ? 'мин/100 м' : 'мин/км'}',
        pace,
      ),
      _DetailMetric(
        'Набор высоты',
        w.elevationGain == null
            ? 'Нет данных'
            : '${w.elevationGain!.round()} м',
      ),
      _DetailMetric('Скорость, км/ч', speed),
    ];
    return PacePageScaffold(
      title: 'Тренировка',
      body: ListView(
        key: PageStorageKey(
          'history-detail-${workout.sessionId ?? workout.date.toIso8601String()}',
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        children: [
          Row(
            children: [
              Icon(
                index < 0 ? Icons.sports : SportCatalog.icons[index],
                color: lime,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sport, style: const TextStyle(color: lime)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$sport · тренировка',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(dateLabel, style: const TextStyle(color: muted)),
          if (w.source == 'garmin-personal') ...[
            const SizedBox(height: 8),
            Text(
              w.heartRateSamples.isEmpty
                  ? 'Garmin · Пульс: нет данных'
                  : 'Garmin · Пульс: есть запись',
              key: const ValueKey('garmin-workout-source'),
              style: const TextStyle(color: muted),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            '${w.distance.toStringAsFixed(2).replaceAll('.', ',')} км',
            key: const ValueKey('history-distance'),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 22),
          GlassPanel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    MediaQuery.textScalerOf(context).scale(14) > 21 ||
                        constraints.maxWidth < 230
                    ? 1
                    : 2;
                return Wrap(
                  spacing: 14,
                  runSpacing: 22,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 14) /
                            columns,
                        child: metric,
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Маршрут',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: w.route.length >= 2
                      ? Semantics(
                          label: 'Сохранённый маршрут тренировки',
                          image: true,
                          child: CustomPaint(painter: RoutePainter(w.route)),
                        )
                      : const Center(
                          child: Text(
                            'У этой тренировки нет сохранённого маршрута.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                        ),
                ),
                if (w.route.length >= 2)
                  const Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _RouteLegend('Старт', Colors.white),
                      _RouteLegend('Финиш', lime),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WorkoutResultSummary(workout: w, historical: true),
          const SizedBox(height: 16),
          const Text(
            'Получено в этой тренировке',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          WorkoutRewards(
            workout: w,
            onAchievement: (rule) => _openAchievement(context, rule),
            onRecord: (record) => _openRecord(context, record),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const ValueKey('history-detail-back'),
            style: FilledButton.styleFrom(
              backgroundColor: lime,
              foregroundColor: bg,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(
              fromHistory ? 'К истории тренировок' : 'К главной',
              textAlign: TextAlign.center,
              style: TextStyle(color: bg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  });
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, color: color, size: 8),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}
