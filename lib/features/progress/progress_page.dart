import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';
import '../workouts/workout_details_page.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    required this.xp,
    required this.level,
    required this.workouts,
  });
  final int xp, level;
  final List<Workout> workouts;

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
    final sports = widget.workouts.map((w) => w.sport).toSet().toList()..sort();
    final filtered = widget.workouts
        .where((w) => sport == null || w.sport == sport)
        .toList();
    return DefaultTabController(
      length: 3,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              labelColor: lime,
              unselectedLabelColor: muted,
              indicatorColor: lime,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Обзор'),
                Tab(text: 'Тренировки'),
                Tab(text: 'Достижения'),
              ],
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
                                builder: (_) => WorkoutDetailsPage(workout: w),
                              ),
                            ),
                            child: workoutCard(w),
                          ),
                        ),
                  ],
                ),
                ListView(
                  key: const PageStorageKey('progress-achievements'),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 140),
                  children: [
                    sectionTitle('ТВОИ ЦЕЛИ'),
                    const SizedBox(height: 14),
                    achievement(
                      Icons.directions_run_rounded,
                      'Первый шаг',
                      'Запиши первую тренировку',
                      widget.workouts.isNotEmpty,
                    ),
                    achievement(
                      Icons.route_rounded,
                      'Первые 10 км',
                      'Накопи 10 км',
                      totalDistance >= 10,
                    ),
                    achievement(
                      Icons.bolt_rounded,
                      'Уровень 5',
                      'Набери 9000 XP',
                      widget.xp >= 9000,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
