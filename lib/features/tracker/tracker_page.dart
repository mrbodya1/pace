import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/sport_catalog.dart';
import '../../models/workout.dart';
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
  });

  final double distance, pace, speed, finishedDistance;
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
                            ? (paused ? 'На паузе' : gpsStatus)
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
                        label: usesSpeed ? 'Скорость, км/ч' : 'Темп, мин/км',
                        value: usesSpeed
                            ? displayedSpeed
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ',')
                            : formatPace(calculatedPace),
                        icon: CupertinoIcons.speedometer,
                      ),
                    ),
                  ],
                ),
              ),
              if (result) ...[
                const SizedBox(height: 18),
                if (finishedWasSaved)
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
              const SizedBox(height: 22),
              _WorkoutRoute(points: points),
              if (!result) ...[
                const SizedBox(height: 18),
                const Text(
                  'Пока запись работает при открытом приложении. '
                  'Не блокируй экран во время тренировки.',
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
              onPressed: onClose,
              child: const Text('Готово'),
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
            onPressed: finishing
                ? null
                : (paused ? onStartWorkout : onPauseWorkout),
            child: Text(paused ? 'Продолжить' : 'Пауза'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const ValueKey('finish-workout'),
            onPressed: finishing ? null : () => _confirmFinish(context),
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
