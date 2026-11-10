import '../../models/achievement.dart';
import '../../models/personal_record.dart';
import '../../widgets/workout_rewards.dart';
import '../../widgets/workout_result_summary.dart';
import '../../widgets/pace_page_scaffold.dart';
import '../progress/achievements_view.dart';
import '../progress/records_view.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/sport_catalog.dart';
import '../../models/workout.dart';
import '../../models/workout_xp.dart';
import '../../widgets/workout_xp_panel.dart';
import '../../services/workout_location_settings.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/glass_segmented_control.dart';
import 'widgets/route_painter.dart';

class TrackerPage extends StatelessWidget {
  const TrackerPage({
    super.key,
    required this.distance,
    required this.pace,
    required this.elapsed,
    required this.speed,
    required this.route,
    required this.tracking,
    required this.paused,
    required this.starting,
    required this.finishing,
    required this.workoutFinished,
    required this.gpsStatus,
    required this.finishedWasSaved,
    required this.finishedSport,
    required this.finishedDistance,
    required this.finishedDuration,
    required this.finishedXp,
    required this.finishedRoute,
    required this.sports,
    required this.sportIcons,
    required this.selectedSport,
    required this.formatDuration,
    required this.formatPace,
    required this.onNewWorkout,
    required this.onStartWorkout,
    required this.onPauseWorkout,
    required this.onFinishWorkout,
    required this.onSelectSport,
    required this.onClose,
    this.elevationGain = 0,
    this.finishedElevation = 0,
    this.finishedXpBreakdown,
    this.finishedAchievementXp = 0,
    this.finishedRecordXp = 0,
    this.finishedWorkout,
    this.history = const [],
    this.achievementState,
    this.recoveredWorkout = false,
  });

  final double distance, pace, speed, finishedDistance;
  final double elevationGain, finishedElevation;
  final WorkoutXp? finishedXpBreakdown;
  final int finishedAchievementXp;
  final int finishedRecordXp;
  final Workout? finishedWorkout;
  final List<Workout> history;
  final AchievementState? achievementState;
  final bool recoveredWorkout;
  final Duration elapsed, finishedDuration;
  final List<Position> route;
  final List<RoutePoint> finishedRoute;
  final bool tracking,
      paused,
      starting,
      finishing,
      workoutFinished,
      finishedWasSaved;
  final String gpsStatus, finishedSport;
  final int finishedXp, selectedSport;
  final List<String> sports;
  final List<IconData> sportIcons;
  final String Function(Duration) formatDuration;
  final String Function(double) formatPace;
  final VoidCallback onNewWorkout, onStartWorkout, onPauseWorkout, onClose;
  final Future<void> Function() onFinishWorkout;
  final ValueChanged<int> onSelectSport;

  List<Workout> get _awardHistory =>
      history.isNotEmpty ? history : [?finishedWorkout];
  void _openAchievement(BuildContext context, AchievementRule rule) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PacePageScaffold(
          title: 'Достижения',
          body: AchievementsView(
            workouts: _awardHistory,
            state: achievementState,
            initialSport: rule.sport,
            initialMetric: rule.metric,
            selectedId: rule.id,
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
          body: RecordsView(
            workouts: _awardHistory,
            initialSport: record.sport,
            selectedId: record.id,
          ),
        ),
      ),
    );
  }

  Future<void> _chooseSport(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Text(
                  'Виды спорта',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: SportCatalog.selectableIndices.length,
                  itemBuilder: (context, position) {
                    final i = SportCatalog.selectableIndices[position];
                    return ListTile(
                      leading: Icon(
                        sportIcons[i],
                        color: selectedSport == i ? lime : muted,
                      ),
                      title: Text(sports[i]),
                      trailing: selectedSport == i
                          ? const Icon(CupertinoIcons.check_mark, color: lime)
                          : null,
                      onTap: () => Navigator.pop(context, i),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null &&
        context.mounted &&
        !tracking &&
        !starting &&
        !finishing) {
      onSelectSport(selected);
    }
  }

  Future<void> _confirmFinish(BuildContext context) async {
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить тренировку?'),
        content: const Text('Запись остановится, и ты увидишь результат.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Продолжить запись'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (finish == true && context.mounted) await onFinishWorkout();
  }

  @override
  Widget build(BuildContext context) {
    final result = workoutFinished;
    final km = result ? finishedDistance : distance / 1000;
    final duration = result ? finishedDuration : elapsed;
    final sport = SportCatalog.displayName(
      result ? finishedSport : sports[selectedSport],
    );
    final usesSpeed = SportCatalog.usesSpeed(sport);
    final calculatedPace = result
        ? (km > 0 ? duration.inSeconds / km : 0.0)
        : (pace > 0 ? pace : (km > 0 ? duration.inSeconds / km : 0.0));
    final displayedSpeed = result
        ? (duration.inSeconds > 0 ? km * 3600 / duration.inSeconds : 0.0)
        : speed * 3.6;
    final points = result
        ? finishedRoute
        : route
              .map(
                (p) => RoutePoint(latitude: p.latitude, longitude: p.longitude),
              )
              .toList(growable: false);
    final locked = tracking || starting || finishing;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  result
                      ? 'Результат'
                      : tracking
                      ? sport
                      : 'Тренировка',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('close-workout'),
                onPressed: starting || finishing ? null : onClose,
                tooltip: tracking ? 'Свернуть тренировку' : 'Закрыть',
                icon: Icon(
                  tracking ? CupertinoIcons.chevron_down : CupertinoIcons.xmark,
                  color: muted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('workout-screen'),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            children: [
              if (recoveredWorkout) ...[
                const GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Восстановлена тренировка',
                        style: TextStyle(
                          color: lime,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Восстановлены данные последнего автосохранения. Запись на паузе — можно продолжить или завершить. Время, пока PACE не работал, не учитывается.',
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (!result && !tracking) ...[
                const Text(
                  'Выбери свой ритм',
                  style: TextStyle(color: muted, fontSize: 16),
                ),
                const SizedBox(height: 18),
                GlassSegmentedControl(
                  key: const ValueKey('sport-selector'),
                  labels: [
                    for (final i in SportCatalog.quickIndices) sports[i],
                  ],
                  selectedIndex:
                      SportCatalog.quickIndices.contains(selectedSport)
                      ? SportCatalog.quickIndices.indexOf(selectedSport)
                      : null,
                  onChanged: locked
                      ? null
                      : (index) =>
                            onSelectSport(SportCatalog.quickIndices[index]),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: locked ? null : () => _chooseSport(context),
                    icon: Icon(
                      !SportCatalog.quickIndices.contains(selectedSport)
                          ? sportIcons[selectedSport]
                          : CupertinoIcons.ellipsis_circle,
                      size: 21,
                    ),
                    label: Text(
                      !SportCatalog.quickIndices.contains(selectedSport)
                          ? sports[selectedSport]
                          : 'Другие виды спорта',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (result) ...[
                const Center(
                  child: Icon(
                    CupertinoIcons.check_mark_circled,
                    color: lime,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    finishedWasSaved
                        ? 'Тренировка сохранена'
                        : 'Тренировка завершена',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    sport,
                    style: const TextStyle(color: muted, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 26),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      paused
                          ? CupertinoIcons.pause_circle
                          : tracking
                          ? CupertinoIcons.circle_filled
                          : CupertinoIcons.location,
                      size: 18,
                      color: tracking && !paused ? lime : muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        starting
                            ? 'Получаем координаты…'
                            : tracking
                            ? (paused && gpsStatus == 'Пауза'
                                  ? 'На паузе'
                                  : gpsStatus)
                            : 'GPS подключится после старта',
                        style: TextStyle(
                          color: tracking && !paused ? lime : muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
              ],
              const Text(
                'Дистанция',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    km.toStringAsFixed(2).replaceAll('.', ','),
                    style: const TextStyle(
                      fontSize: 76,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -3,
                    ),
                  ),
                ),
              ),
              const Text(
                'километра',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 14),
              ),
              const SizedBox(height: 26),
              GlassPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _WorkoutMetric(
                        label: 'Время',
                        value: formatDuration(duration),
                        icon: CupertinoIcons.stopwatch,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _WorkoutMetric(
                        label: usesSpeed
                            ? 'Скорость, км/ч'
                            : sport == 'Плавание'
                            ? 'Темп, мин/100 м'
                            : 'Темп, мин/км',
                        value: usesSpeed
                            ? displayedSpeed
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ',')
                            : formatPace(
                                sport == 'Плавание'
                                    ? calculatedPace / 10
                                    : calculatedPace,
                              ),
                        icon: CupertinoIcons.speedometer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassPanel(
                child: Row(
                  children: [
                    const Icon(Icons.landscape_rounded, color: lime),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Набор высоты',
                        style: TextStyle(color: muted),
                      ),
                    ),
                    Text(
                      '${(result ? finishedElevation : elevationGain).round()} м',
                    ),
                  ],
                ),
              ),
              if (result) ...[
                const SizedBox(height: 18),
                if (finishedWasSaved && finishedWorkout != null)
                  WorkoutResultSummary(workout: finishedWorkout!)
                else if (finishedWasSaved)
                  Center(
                    child: Text(
                      '+$finishedXp XP',
                      style: const TextStyle(
                        color: lime,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Text(
                    'Тренировки короче 50 м не добавляются в историю.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
              ],
              if (result && finishedXpBreakdown != null) ...[
                const SizedBox(height: 18),
                GlassPanel(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    key: PageStorageKey(
                      'xp-details-${finishedWorkout?.sessionId ?? "result"}',
                    ),
                    initiallyExpanded: false,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: const Text('Расчёт XP'),
                    children: [
                      WorkoutXpPanel(
                        value: finishedXpBreakdown!,
                        achievementXp: finishedAchievementXp,
                        recordXp: finishedRecordXp,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _WorkoutRoute(points: points),
              if (result && finishedWasSaved && finishedWorkout != null) ...[
                const SizedBox(height: 20),
                WorkoutRewards(
                  workout: finishedWorkout!,
                  onAchievement: (rule) => _openAchievement(context, rule),
                  onRecord: (record) => _openRecord(context, record),
                ),
              ],
              if (!result) ...[
                const SizedBox(height: 18),
                Text(
                  WorkoutLocationSettings.supportsBackground
                      ? 'Начни тренировку в PACE — затем можно свернуть приложение или заблокировать экран. Черновик сохраняется автоматически; после закрытия запись можно восстановить.'
                      : 'На этом устройстве держи приложение открытым во время записи.',
                  style: TextStyle(color: muted, fontSize: 13, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: _controls(context),
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    if (workoutFinished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('finished-done'),
              style: FilledButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: bg,
              ),
              onPressed: onClose,
              child: const Text(
                'Готово',
                style: TextStyle(color: bg, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          TextButton(
            onPressed: onNewWorkout,
            child: const Text('Новая тренировка'),
          ),
        ],
      );
    }
    if (!tracking) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('start-workout'),
          onPressed: starting ? null : onStartWorkout,
          icon: starting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(CupertinoIcons.play_fill, size: 20),
          label: Text(starting ? 'Ожидание GPS…' : 'Начать'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('pause-workout'),
            onPressed: finishing || starting
                ? null
                : (paused ? onStartWorkout : onPauseWorkout),
            child: Text(paused ? 'Продолжить' : 'Пауза'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const ValueKey('finish-workout'),
            onPressed: finishing || starting
                ? null
                : () => _confirmFinish(context),
            child: Text(finishing ? 'Сохраняем…' : 'Завершить'),
          ),
        ),
      ],
    );
  }
}

class _WorkoutMetric extends StatelessWidget {
  const _WorkoutMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: muted),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: muted, fontSize: 13)),
      ],
    );
  }
}

class _WorkoutRoute extends StatelessWidget {
  const _WorkoutRoute({required this.points});
  final List<RoutePoint> points;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Маршрут',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 120,
            child: points.length >= 2
                ? CustomPaint(painter: RoutePainter(points))
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.location, color: muted, size: 28),
                        SizedBox(height: 10),
                        Text(
                          'Здесь появится GPS-маршрут',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
