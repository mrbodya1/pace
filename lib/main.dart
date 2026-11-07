
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lime = Color(0xFFC7F36B);
const bg = Color(0xFF111310);
const panel = Color(0xFF1C1F1A);
const muted = Color(0xFF92978A);

void main() {
  runApp(const PaceApp());
}

class PaceApp extends StatelessWidget {
  const PaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PACE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: lime,
          surface: panel,
        ),
        useMaterial3: true,
      ),
      home: const PaceHome(),
    );
  }
}

class RoutePoint {
  final double latitude;
  final double longitude;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class Workout {
  final DateTime date;
  final double distance;
  final Duration duration;
  final int xp;
  final String sport;
  final List<RoutePoint> route;

  Workout({
    required this.date,
    required this.distance,
    required this.duration,
    required this.xp,
    required this.sport,
    this.route = const [],
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'distance': distance,
        'durationSeconds': duration.inSeconds,
        'xp': xp,
        'sport': sport,
        'route': route.map((point) => point.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> json) {
    final savedRoute = (json['route'] as List<dynamic>? ?? [])
        .map((item) => RoutePoint.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();

    return Workout(
      date: DateTime.parse(json['date'] as String),
      distance: (json['distance'] as num).toDouble(),
      duration: Duration(seconds: (json['durationSeconds'] as num).toInt()),
      xp: (json['xp'] as num).toInt(),
      sport: json['sport'] as String,
      route: savedRoute,
    );
  }
}


class RoutePainter extends CustomPainter {
  final List<RoutePoint> points;

  RoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;

    final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLon = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLon = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    final latRange = (maxLat - minLat).abs();
    final lonRange = (maxLon - minLon).abs();
    final safeLat = latRange < 0.000001 ? 0.000001 : latRange;
    final safeLon = lonRange < 0.000001 ? 0.000001 : lonRange;
    final scale = (size.width - 24) / safeLon < (size.height - 20) / safeLat
        ? (size.width - 24) / safeLon
        : (size.height - 20) / safeLat;
    final drawWidth = safeLon * scale;
    final drawHeight = safeLat * scale;
    final offsetX = (size.width - drawWidth) / 2;
    final offsetY = (size.height - drawHeight) / 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = offsetX + (point.longitude - minLon) * scale;
      final y = size.height - offsetY - (point.latitude - minLat) * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final start = points.first;
    final end = points.last;
    final startOffset = Offset(
      offsetX + (start.longitude - minLon) * scale,
      size.height - offsetY - (start.latitude - minLat) * scale,
    );
    final endOffset = Offset(
      offsetX + (end.longitude - minLon) * scale,
      size.height - offsetY - (end.latitude - minLat) * scale,
    );
    canvas.drawCircle(startOffset, 4, Paint()..color = Colors.white);
    canvas.drawCircle(endOffset, 4, Paint()..color = lime);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}

class PaceHome extends StatefulWidget {
  const PaceHome({super.key});

  @override
  State<PaceHome> createState() => _PaceHomeState();
}

class _PaceHomeState extends State<PaceHome>
    with WidgetsBindingObserver {
  int tab = 0;
  int xp = 6840;
  int selectedSport = 0;

  final List<Workout> workouts = [];
  final List<Position> route = [];

  StreamSubscription<Position>? gpsSubscription;
  Timer? clock;
  final Stopwatch stopwatch = Stopwatch();

  bool tracking = false;
  bool paused = false;
  bool starting = false;
  bool workoutFinished = false;
  double finishedDistance = 0;
  Duration finishedDuration = Duration.zero;
  int finishedXp = 0;
  String finishedSport = 'Бег';
  bool finishedWasSaved = false;

  double distance = 0;
  double speed = 0;
  double pace = 0;
  double lastAccuracy = 0;
  Duration elapsed = Duration.zero;
  Position? lastPosition;
  String gpsStatus = 'GPS не запущен';

  final sports = ['Бег', 'Ходьба', 'Велосипед'];
  final sportIcons = [
    Icons.directions_run_rounded,
    Icons.directions_walk_rounded,
    Icons.directions_bike_rounded,
  ];

  int get level {
    if (xp >= 65000) return 10;
    if (xp >= 48000) return 9;
    if (xp >= 34000) return 8;
    if (xp >= 23000) return 7;
    if (xp >= 15000) return 6;
    if (xp >= 9000) return 5;
    if (xp >= 5000) return 4;
    if (xp >= 2500) return 3;
    if (xp >= 1000) return 2;
    return 1;
  }

  int get levelStart {
    const levels = [
      0, 1000, 2500, 5000, 9000,
      15000, 23000, 34000, 48000, 65000,
    ];
    return levels[level - 1];
  }

  int get levelEnd {
    const levels = [
      1000, 2500, 5000, 9000, 15000,
      23000, 34000, 48000, 65000, 85000,
    ];
    return levels[level - 1];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pace_local_data');

      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedWorkouts = (data['workouts'] as List<dynamic>? ?? [])
          .map((item) => Workout.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        xp = (data['xp'] as num?)?.toInt() ?? 6840;
        final savedSport = (data['selectedSport'] as num?)?.toInt() ?? 0;
        selectedSport = savedSport >= 0 && savedSport < sports.length
            ? savedSport
            : 0;
        workouts
          ..clear()
          ..addAll(savedWorkouts);
      });
    } catch (e) {
      _message('Не удалось загрузить сохранённый прогресс.');
    }
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'xp': xp,
        'selectedSport': selectedSport,
        'workouts': workouts.map((workout) => workout.toJson()).toList(),
      };
      await prefs.setString('pace_local_data', jsonEncode(data));
    } catch (e) {
      _message('Не удалось сохранить прогресс на устройстве.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (tracking && state == AppLifecycleState.paused) {
      // This screen alone does not guarantee background GPS recording.
      gpsStatus = 'Приложение свернуто';
    }
    if (mounted) setState(() {});
  }

  Future<void> startWorkout() async {
    if (starting) return;

    if (tracking && paused) {
      stopwatch.start();
      setState(() {
        paused = false;
        gpsStatus = 'Запись маршрута';
      });
      _listenGps();
      return;
    }

    setState(() {
      starting = true;
      gpsStatus = 'Проверяем GPS…';
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _message('Включи геолокацию на устройстве.');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _message('Разреши PACE доступ к геолокации.');
        return;
      }

      final firstPosition =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      await gpsSubscription?.cancel();
      clock?.cancel();

      stopwatch
        ..reset()
        ..start();

      route.clear();
      route.add(firstPosition);

      setState(() {
        distance = 0;
        speed = 0;
        pace = 0;
        elapsed = Duration.zero;
        lastPosition = firstPosition;
        lastAccuracy = firstPosition.accuracy;
        tracking = true;
        paused = false;
        workoutFinished = false;
        gpsStatus = 'Запись маршрута';
      });

      _listenGps();

      clock = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (!mounted || !stopwatch.isRunning) return;
          setState(() => elapsed = stopwatch.elapsed);
        },
      );
    } catch (e) {
      _message('Не удалось получить GPS. Проверь сигнал и разрешения.');
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  void _listenGps() {
    gpsSubscription?.cancel();

    gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    ).listen(
      (position) {
        if (!mounted || !tracking || paused) return;

        // Ignore inaccurate readings.
        if (position.accuracy > 30) return;

        final previous = lastPosition;

        if (previous == null) {
          setState(() {
            lastPosition = position;
            lastAccuracy = position.accuracy;
            route.add(position);
          });
          return;
        }

        final seconds = position.timestamp
                .difference(previous.timestamp)
                .inMilliseconds /
            1000.0;

        if (seconds <= 0) return;

        final segment = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          position.latitude,
          position.longitude,
        );

        final segmentSpeed = segment / seconds;

        // Reject obvious GPS jumps and implausible speeds.
        if (segmentSpeed > 12) return;

        setState(() {
          lastPosition = position;
          lastAccuracy = position.accuracy;

          if (segment >= 2) {
            distance += segment;

            final reportedSpeed = position.speed;
            speed = reportedSpeed.isFinite && reportedSpeed >= 0
                ? reportedSpeed
                : segmentSpeed;

            pace = speed > 0 ? 1000 / speed : 0;
            route.add(position);
          }
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => gpsStatus = 'Ошибка получения GPS');
        }
      },
    );
  }

  void pauseWorkout() {
    if (!tracking || paused) return;

    stopwatch.stop();
    gpsSubscription?.cancel();

    setState(() {
      paused = true;
      elapsed = stopwatch.elapsed;
      gpsStatus = 'Пауза';
    });
  }

  Future<void> finishWorkout() async {
    if (!tracking) return;

    stopwatch.stop();
    clock?.cancel();
    await gpsSubscription?.cancel();

    final finalDistance = distance / 1000;
    final finalDuration = stopwatch.elapsed;
    final savedRoute = route
        .map((position) => RoutePoint(
              latitude: position.latitude,
              longitude: position.longitude,
            ))
        .toList(growable: false);
    final wasSaved = finalDistance >= 0.05;
    final earnedXp = wasSaved ? (finalDistance * 100).round() : 0;
    final finishedActivity = sports[selectedSport];

    setState(() {
      tracking = false;
      paused = false;
      workoutFinished = true;

      // Keep the result separately, then clear the active tracker.
      finishedDistance = finalDistance;
      finishedDuration = finalDuration;
      finishedXp = earnedXp;
      finishedSport = finishedActivity;
      finishedWasSaved = wasSaved;

      distance = 0;
      speed = 0;
      pace = 0;
      elapsed = Duration.zero;
      lastAccuracy = 0;
      lastPosition = null;
      route.clear();
      gpsStatus = 'Тренировка завершена';
    });

    if (wasSaved) {
      setState(() {
        xp += earnedXp;
        workouts.insert(
          0,
          Workout(
            date: DateTime.now(),
            distance: finalDistance,
            duration: finalDuration,
            xp: earnedXp,
            sport: finishedActivity,
            route: savedRoute,
          ),
        );
      });
      await _saveProgress();

      _message(
        'Тренировка сохранена: ${finalDistance.toStringAsFixed(2)} км · +$earnedXp XP',
      );
    } else {
      _message('Тренировка короче 50 м — результат не добавлен в историю.');
    }
  }

  void startNewWorkout() {
    setState(() {
      workoutFinished = false;
      distance = 0;
      speed = 0;
      pace = 0;
      elapsed = Duration.zero;
      lastAccuracy = 0;
      lastPosition = null;
      route.clear();
      gpsStatus = 'GPS не запущен';
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String formatPace(double secondsPerKm) {
    if (!secondsPerKm.isFinite || secondsPerKm <= 0) {
      return '--:--';
    }
    final seconds = secondsPerKm.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock?.cancel();
    gpsSubscription?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      homePage(),
      trackerPage(),
      progressPage(),
      profilePage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: const Color(0xFF191B17),
        indicatorColor: lime.withValues(alpha: 0.14),
        selectedIndex: tab,
        onDestinationSelected: (index) {
          setState(() => tab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded, color: lime),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_rounded),
            selectedIcon: Icon(Icons.directions_run_rounded, color: lime),
            label: 'Трекер',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_rounded),
            selectedIcon: Icon(Icons.insights_rounded, color: lime),
            label: 'Прогресс',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: lime),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  Widget header() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: bg,
            size: 29,
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PACE',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            Text(
              'ATHLETE COMMUNITY',
              style: TextStyle(
                fontSize: 8,
                color: muted,
                letterSpacing: 1.7,
              ),
            ),
          ],
        ),
        const Spacer(),
        const Icon(Icons.notifications_none_rounded),
        const SizedBox(width: 12),
        const CircleAvatar(
          radius: 19,
          backgroundColor: panel,
          child: Text(
            'B',
            style: TextStyle(color: lime, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget homePage() {
    final progress =
        ((xp - levelStart) / (levelEnd - levelStart)).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        header(),
        const SizedBox(height: 28),
        const Text(
          'ТВОЙ ПУТЬ. ТВОИ ПРАВИЛА.',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Стань своей\nлучшей версией.',
          style: TextStyle(
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF292E24), Color(0xFF1A1D17)],
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'АТЛЕТ · УРОВЕНЬ',
                style: TextStyle(
                  color: lime,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$level',
                    style: const TextStyle(
                      fontSize: 65,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BODYA',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Универсальный атлет',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '$xp XP',
                style: const TextStyle(
                  color: lime,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(lime),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${levelEnd - xp} XP до уровня ${level + 1}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        sectionTitle('ТВОЯ СТАТИСТИКА'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: statCard(
                'ТРЕНИРОВКИ',
                '${workouts.length}',
                Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: statCard(
                'ДИСТАНЦИЯ',
                workouts.fold<double>(
                  0,
                  (sum, w) => sum + w.distance,
                ).toStringAsFixed(1),
                Icons.route_rounded,
                suffix: 'км',
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        sectionTitle('ПОСЛЕДНИЕ ТРЕНИРОВКИ'),
        const SizedBox(height: 12),
        if (workouts.isEmpty)
          emptyCard('Здесь появятся твои реальные GPS-тренировки.')
        else
          ...workouts.take(3).map(workoutCard),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => setState(() => tab = 1),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Начать тренировку'),
          style: FilledButton.styleFrom(
            backgroundColor: lime,
            foregroundColor: bg,
            minimumSize: const Size.fromHeight(54),
          ),
        ),
      ],
    );
  }

  Widget trackerPage() {
    final km = distance / 1000;
    final displayedPace = pace > 0
        ? pace
        : (km > 0 ? elapsed.inSeconds / km : 0.0);
    final displayedRoute = route.isNotEmpty
        ? route
            .map((position) => RoutePoint(
                  latitude: position.latitude,
                  longitude: position.longitude,
                ))
            .toList(growable: false)
        : (workoutFinished && workouts.isNotEmpty
            ? workouts.first.route
            : const <RoutePoint>[]);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        const Text(
          'Трекер',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'Записывай движение. Улучшай результат.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 23),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
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
                  Text(
                    km.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 58,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
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
                    onPressed: startNewWorkout,
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
                    onPressed: starting ? null : startWorkout,
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
                        onPressed: paused
                            ? startWorkout
                            : pauseWorkout,
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
                        onPressed: finishWorkout,
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
              color: const Color(0xFF252A20),
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
                          fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
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
                  onTap: tracking
                      ? null
                      : () => setState(() => selectedSport = i),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: selected ? lime : panel,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          sportIcons[i],
                          color: selected ? bg : muted,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sports[i],
                          style: TextStyle(
                            color: selected ? bg : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
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

  Widget progressPage() {
    final totalDistance = workouts.fold<double>(
      0,
      (sum, w) => sum + w.distance,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        const Text(
          'Твой прогресс',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        statCard('УРОВЕНЬ', '$level', Icons.military_tech_rounded),
        const SizedBox(height: 12),
        statCard('ОБЩИЙ XP', '$xp', Icons.bolt_rounded),
        const SizedBox(height: 12),
        statCard(
          'ЗАПИСАННЫЕ КМ',
          totalDistance.toStringAsFixed(2),
          Icons.route_rounded,
        ),
        const SizedBox(height: 24),
        sectionTitle('ДОСТИЖЕНИЯ'),
        const SizedBox(height: 12),
        achievement(
          Icons.directions_run_rounded,
          'Первый шаг',
          'Запиши первую тренировку',
          workouts.isNotEmpty,
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
          xp >= 9000,
        ),
      ],
    );
  }

  Widget profilePage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        const Text(
          'Профиль',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 28),
        const CircleAvatar(
          radius: 46,
          backgroundColor: panel,
          child: Icon(Icons.person_rounded, size: 54, color: lime),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'BODYA',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 5),
        const Center(
          child: Text(
            'Универсальный атлет',
            style: TextStyle(color: muted),
          ),
        ),
        const SizedBox(height: 25),
        sectionTitle('СПОРТИВНЫЙ ПРОФИЛЬ'),
        const SizedBox(height: 12),
        ...sports.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: ListTile(
              tileColor: panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(
                sportIcons[entry.key],
                color: selectedSport == entry.key ? lime : muted,
              ),
              title: Text(entry.value),
              trailing: selectedSport == entry.key
                  ? const Icon(Icons.check_circle, color: lime)
                  : null,
              onTap: tracking
                  ? null
                  : () {
                      setState(() => selectedSport = entry.key);
                      _saveProgress();
                    },
            ),
          );
        }),
        const SizedBox(height: 15),
        const Text(
          'PACE · Локальный прототип',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }

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
                      '${w.date.year} · ${formatDuration(w.duration)}',
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
}
