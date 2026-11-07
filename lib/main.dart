
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'models/workout.dart';
import 'data/storage/local_storage_service.dart';
import 'app/theme/pace_theme.dart';
import 'features/home/home_page.dart';
import 'features/tracker/tracker_page.dart';
import 'features/progress/progress_page.dart';
import 'features/profile/profile_page.dart';

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
      theme: paceTheme,
      home: const PaceHome(),
    );
  }
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

  final LocalStorageService _storageService = LocalStorageService();

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
      final data = await _storageService.loadProgress();

      if (data == null) return;
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
      await _storageService.saveProgress(
        xp: xp,
        selectedSport: selectedSport,
        workouts: workouts,
      );
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
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        if (!mounted || !tracking || paused) return;

        // Keep usable emulator and real-device readings; reject only very poor fixes.
        if (position.accuracy > 50) return;

        final previous = lastPosition;

        if (previous == null) {
          setState(() {
            lastPosition = position;
            lastAccuracy = position.accuracy;
            route.add(position);
          });
          return;
        }

        final segment = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          position.latitude,
          position.longitude,
        );

        final seconds = position.timestamp
                .difference(previous.timestamp)
                .inMilliseconds /
            1000.0;
        final segmentSpeed = seconds > 0 ? segment / seconds : 0.0;

        setState(() {
          // Always advance the reference point so one rejected jump cannot
          // block every subsequent GPS update.
          lastPosition = position;
          lastAccuracy = position.accuracy;

          if (segment >= 1) {
            // Keep the route geometry even when emulator playback is too fast
            // to count that segment toward workout distance.
            route.add(position);

            // Count only plausible movement to avoid GPS jumps inflating distance.
            if (segment <= 100 && seconds > 0 && segmentSpeed <= 20) {
              distance += segment;

              final reportedSpeed = position.speed;
              speed = reportedSpeed.isFinite && reportedSpeed > 0
                  ? reportedSpeed
                  : segmentSpeed;

              pace = speed > 0 ? 1000 / speed : 0;
            }
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
      HomePage(
        xp: xp,
        level: level,
        levelStart: levelStart,
        levelEnd: levelEnd,
        workouts: workouts,
        header: header(),
        onStartWorkout: () => setState(() => tab = 1),
      ),
      TrackerPage(
        distance: distance,
        pace: pace,
        elapsed: elapsed,
        speed: speed,
        route: route,
        workouts: workouts,
        tracking: tracking,
        paused: paused,
        starting: starting,
        workoutFinished: workoutFinished,
        gpsStatus: gpsStatus,
        finishedWasSaved: finishedWasSaved,
        finishedSport: finishedSport,
        finishedDistance: finishedDistance,
        finishedDuration: finishedDuration,
        finishedXp: finishedXp,
        sports: sports,
        sportIcons: sportIcons,
        selectedSport: selectedSport,
        formatDuration: formatDuration,
        formatPace: formatPace,
        onNewWorkout: startNewWorkout,
        onStartWorkout: startWorkout,
        onPauseWorkout: pauseWorkout,
        onFinishWorkout: finishWorkout,
        onSelectSport: (i) => setState(() => selectedSport = i),
      ),
      ProgressPage(
        xp: xp,
        level: level,
        workouts: workouts,
      ),
      ProfilePage(
        sports: sports,
        sportIcons: sportIcons,
        selectedSport: selectedSport,
        tracking: tracking,
        onSelectSport: (i) {
          setState(() => selectedSport = i);
          _saveProgress();
        },
      ),
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
}
