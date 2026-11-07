import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/workout.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_widgets.dart';
import 'widgets/route_painter.dart';

class TrackerPage extends StatelessWidget {
  const TrackerPage({
    super.key,
    required this.distance,
    required this.pace,
    required this.elapsed,
    required this.speed,
    required this.route,
    required this.workouts,
    required this.tracking,
    required this.paused,
    required this.starting,
    required this.workoutFinished,
    required this.gpsStatus,
    required this.finishedWasSaved,
    required this.finishedSport,
    required this.finishedDistance,
    required this.finishedDuration,
    required this.finishedXp,
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
  });

  final double distance, pace, speed, finishedDistance;
  final Duration elapsed, finishedDuration;
  final List<Position> route;
  final List<Workout> workouts;
  final bool tracking, paused, starting, workoutFinished, finishedWasSaved;
  final String gpsStatus, finishedSport;
  final int finishedXp, selectedSport;
  final List<String> sports;
  final List<IconData> sportIcons;
  final String Function(Duration) formatDuration;
  final String Function(double) formatPace;
  final VoidCallback onNewWorkout,
      onStartWorkout,
      onPauseWorkout,
      onFinishWorkout;
  final ValueChanged<int> onSelectSport;

  @override
  Widget build(BuildContext context) {
    final km = distance / 1000;
    final displayedPace = pace > 0
        ? pace
        : (km > 0 ? elapsed.inSeconds / km : 0.0);
    final displayedRoute = route.isNotEmpty
        ? route
              .map(
                (position) => RoutePoint(
                  latitude: position.latitude,
                  longitude: position.longitude,
                ),
              )
              .toList(growable: false)
        : (workoutFinished && workouts.isNotEmpty
              ? workouts.first.route
              : const <RoutePoint>[]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 132),
      children: [
        const SizedBox(height: 10),
        const Text(
          'Трекер',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        const Text(
          'Записывай движение. Улучшай результат.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 23),
        GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    tracking && !paused
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                    color: lime,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      starting ? 'Получаем координаты…' : gpsStatus,
                      style: const TextStyle(
                        color: lime,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                'ДИСТАНЦИЯ',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        km.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 64,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('км', style: TextStyle(color: muted)),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: metric(
                      'ВРЕМЯ',
                      formatDuration(elapsed),
                      Icons.timer_outlined,
                    ),
                  ),
                  Expanded(
                    child: metric(
                      'ТЕМП / КМ',
                      formatPace(displayedPace),
                      Icons.speed_rounded,
                    ),
                  ),
                  Expanded(
                    child: metric(
                      'СКОРОСТЬ',
                      (speed * 3.6).toStringAsFixed(1),
                      Icons.bolt_rounded,
                      suffix: 'км/ч',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              if (workoutFinished)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: onNewWorkout,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Новая тренировка'),
                    style: FilledButton.styleFrom(
                      backgroundColor: lime,
                      foregroundColor: bg,
                    ),
                  ),
                )
              else if (!tracking)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: starting ? null : onStartWorkout,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      starting ? 'Ожидание GPS…' : 'Начать тренировку',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: lime,
                      foregroundColor: bg,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: paused ? onStartWorkout : onPauseWorkout,
                        icon: Icon(
                          paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(paused ? 'Продолжить' : 'Пауза'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: lime,
                          side: const BorderSide(color: lime),
                          minimumSize: const Size(0, 52),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onFinishWorkout,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Завершить'),
                        style: FilledButton.styleFrom(
                          backgroundColor: lime,
                          foregroundColor: bg,
                          minimumSize: const Size(0, 52),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (workoutFinished) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xD02A2C40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: lime.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: lime),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ИТОГ ПОСЛЕДНЕЙ ТРЕНИРОВКИ',
                        style: TextStyle(
                          color: lime,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      finishedWasSaved ? 'Сохранена' : 'Не сохранена',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$finishedSport · ${finishedDistance.toStringAsFixed(2)} км',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Время ${formatDuration(finishedDuration)}'
                  '${finishedWasSaved ? ' · +$finishedXp XP' : ' · меньше 50 м'}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        sectionTitle('МАРШРУТ'),
        const SizedBox(height: 12),
        Container(
          height: 145,
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(20),
          ),
          child: displayedRoute.length >= 2
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: RoutePainter(displayedRoute),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        workoutFinished
                            ? 'Маршрут последней тренировки · ${displayedRoute.length} точек'
                            : 'Записано GPS-точек: ${displayedRoute.length}',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.route_rounded, color: lime, size: 34),
                      const SizedBox(height: 9),
                      Text(
                        route.isEmpty
                            ? (workoutFinished
                                  ? 'Для этой тренировки нет сохранённого GPS-маршрута.'
                                  : 'Маршрут появится после получения GPS')
                            : 'Записано GPS-точек: ${route.length}. Нужно минимум две.',
                        style: const TextStyle(color: muted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 18),
        sectionTitle('ТИП АКТИВНОСТИ'),
        const SizedBox(height: 12),
        Row(
          children: List.generate(sports.length, (i) {
            final selected = selectedSport == i;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                child: InkWell(
                  onTap: tracking ? null : () => onSelectSport(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: selected ? lime : const Color(0xD02A2C40),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(sportIcons[i], color: selected ? bg : muted),
                        const SizedBox(height: 6),
                        Text(
                          sports[i],
                          style: TextStyle(
                            color: selected ? bg : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        const Text(
          'История тренировок и GPS-маршруты сохраняются на устройстве. '
          'Фоновая GPS-запись при блокировке экрана ещё не реализована.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}
