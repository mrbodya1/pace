import 'package:flutter/foundation.dart';

import 'records_view.dart';

import 'package:flutter/material.dart';

import '../../widgets/glass_tabs.dart';
import '../../models/workout.dart';
import '../../models/achievement.dart';
import 'achievements_view.dart';
import '../../models/sport_catalog.dart';
import '../../widgets/common_widgets.dart';
import '../workouts/workout_details_page.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    required this.xp,
    required this.level,
    required this.workouts,
    this.historyUpdates,
    this.achievements,
    this.syncStatus,
    this.onSync,
    this.syncing = false,
  });
  final int xp, level;
  final List<Workout> workouts;
  final ValueListenable<List<Workout>>? historyUpdates;
  final AchievementState? achievements;
  final String? syncStatus;
  final Future<void> Function()? onSync;
  final bool syncing;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  String? sport;

  @override
  Widget build(BuildContext context) {
    final totalDistance = widget.workouts.fold<double>(
      0,
      (sum, w) => sum + w.distance,
    );
    final totalDuration = widget.workouts.fold<Duration>(
      Duration.zero,
      (sum, w) => sum + w.duration,
    );
    final sports =
        widget.workouts
            .map((w) => SportCatalog.displayName(w.sport))
            .toSet()
            .toList()
          ..sort();
    final filtered = widget.workouts
        .where(
          (w) => sport == null || SportCatalog.displayName(w.sport) == sport,
        )
        .toList();
    return DefaultTabController(
      length: 4,
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: Text(
              'Прогресс',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.onSync != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.syncStatus ?? 'Прогресс сохранён на устройстве',
                        key: const ValueKey('progress-sync-status'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.syncing ? null : widget.onSync,
                    child: Text(widget.syncing ? 'Обновляем…' : 'Обновить'),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GlassTabs(
              labels: ['Обзор', 'Тренировки', 'Достижения', 'Рекорды'],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  key: const PageStorageKey('progress-summary'),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 140),
                  children: [
                    sectionTitle('ЗА ВСЁ ВРЕМЯ'),
                    const SizedBox(height: 14),
                    statCard(
                      'УРОВЕНЬ',
                      '${widget.level}',
                      Icons.military_tech_rounded,
                    ),
                    const SizedBox(height: 12),
                    statCard('ОБЩИЙ XP', '${widget.xp}', Icons.bolt_rounded),
                    const SizedBox(height: 12),
                    statCard(
                      'ТРЕНИРОВКИ',
                      '${widget.workouts.length}',
                      Icons.directions_run_rounded,
                    ),
                    const SizedBox(height: 12),
                    statCard(
                      'ДИСТАНЦИЯ',
                      totalDistance.toStringAsFixed(2).replaceAll('.', ','),
                      Icons.route_rounded,
                      suffix: 'км',
                    ),
                    const SizedBox(height: 12),
                    statCard(
                      'ВРЕМЯ В ДВИЖЕНИИ',
                      formatWorkoutDuration(totalDuration),
                      Icons.timer_outlined,
                    ),
                  ],
                ),
                ListView(
                  key: const PageStorageKey('progress-history'),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 140),
                  children: [
                    if (sports.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: sport ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Вид спорта',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Все виды спорта'),
                          ),
                          for (final name in sports)
                            DropdownMenuItem(value: name, child: Text(name)),
                        ],
                        onChanged: (value) =>
                            setState(() => sport = value == '' ? null : value),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (filtered.isEmpty)
                      emptyCard('Здесь появятся твои записанные тренировки.')
                    else
                      for (final w in filtered)
                        Semantics(
                          button: true,
                          label: 'Открыть тренировку ${w.sport}',
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => WorkoutDetailsPage(
                                  workout: w,
                                  history: widget.workouts,
                                  historyUpdates: widget.historyUpdates,
                                ),
                              ),
                            ),
                            child: workoutCard(w),
                          ),
                        ),
                  ],
                ),
                AchievementsView(
                  workouts: widget.workouts,
                  state: widget.achievements,
                ),
                RecordsView(workouts: widget.workouts),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
