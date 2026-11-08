import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'models/workout.dart';
import 'models/xp_progress.dart';
import 'models/sport_catalog.dart';
import 'models/specialization.dart';
import 'models/participant_sex.dart';
import 'models/workout_xp.dart';
import 'services/workout_xp_calculator.dart';
import 'services/elevation_tracker.dart';
import 'data/storage/profile_storage_service.dart';
import 'data/storage/local_storage_service.dart';
import 'app/theme/pace_theme.dart';
import 'widgets/pace_header.dart';
import 'widgets/glass_widgets.dart';
import 'features/home/home_page.dart';
import 'features/community/community_page.dart';
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

class _PaceHomeState extends State<PaceHome> with WidgetsBindingObserver {
  int tab = 0;
  int xp = 6840;
  int selectedSport = 0;

  final LocalStorageService _storageService = LocalStorageService();

  final List<Workout> workouts = [];
  final List<Position> route = [];

  StreamSubscription<Position>? gpsSubscription;
  Timer? clock;
  final Stopwatch stopwatch = Stopwatch();
  final ElevationTracker elevation = ElevationTracker();
  Specialization? workoutSpecialization;
  ParticipantSex? workoutParticipantSex;
  DateTime? workoutStartedAt;
  WorkoutXp? finishedXpBreakdown;
  double finishedElevation = 0;

  bool workoutOpen = false;
  bool finishing = false;
  List<RoutePoint> finishedRoute = [];
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

  final sports = SportCatalog.names;
  final sportIcons = SportCatalog.icons;

  void _openWorkout() {
    if (workoutFinished && !tracking) startNewWorkout();
    setState(() => workoutOpen = true);
  }

  void _closeWorkout() {
    if (starting || finishing) return;
    setState(() => workoutOpen = false);
  }

  void _selectSport(int index) {
    if (tracking ||
        starting ||
        finishing ||
        !SportCatalog.isSelectable(index)) {
      return;
    }
    setState(() => selectedSport = index);
    unawaited(_saveProgress());
  }

  int get level => XpProgress(xp).level;

  int get levelStart => XpProgress(xp).levelStart;

  int get levelEnd => XpProgress(xp).levelEnd;

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
          .map(
            (item) => Workout.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        xp = (data['xp'] as num?)?.toInt() ?? 6840;
        final savedSport = (data['selectedSport'] as num?)?.toInt() ?? 0;
        selectedSport = SportCatalog.restoreSelection(savedSport);
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
    if (starting || finishing || (tracking && !paused)) return;

    if (tracking && paused) {
      lastPosition = null;
      elevation.resetAnchor();
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

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

      Map<String, dynamic> profile;
      try {
        profile = await ProfileStorageService().load();
      } catch (_) {
        _message('Не удалось прочитать специализацию. Попробуй начать снова.');
        return;
      }
      final firstPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      await gpsSubscription?.cancel();
      clock?.cancel();

      if (!mounted) return;
      workoutSpecialization = Specialization.fromId(
        profile['specializationId'],
      );
      workoutParticipantSex = ParticipantSex.fromId(profile['sex']);
      workoutStartedAt = DateTime.now();
      elevation
        ..reset()
        ..add(firstPosition.altitude);

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

      clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !stopwatch.isRunning) return;
        setState(() => elapsed = stopwatch.elapsed);
      });
    } catch (e) {
      _message('Не удалось получить GPS. Проверь сигнал и разрешения.');
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  void _listenGps() {
    gpsSubscription?.cancel();

    gpsSubscription =
        Geolocator.getPositionStream(
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
                elevation.add(position.altitude);
              });
              return;
            }

            final segment = Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              position.latitude,
              position.longitude,
            );

            final seconds =
                position.timestamp
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
                  elevation.add(position.altitude);

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
    if (!tracking || finishing) return;
    setState(() => finishing = true);
    try {
      stopwatch.stop();
      clock?.cancel();
      await gpsSubscription?.cancel();

      final finalDistance = distance / 1000;
      final finalDuration = stopwatch.elapsed;
      final savedRoute = route
          .map(
            (position) => RoutePoint(
              latitude: position.latitude,
              longitude: position.longitude,
              altitude: position.altitude.isFinite ? position.altitude : null,
            ),
          )
          .toList(growable: false);
      final wasSaved = finalDistance >= 0.05;
      final finishedActivity = sports[selectedSport];
      final gainedElevation = elevation.gain;
      final breakdown = wasSaved
          ? WorkoutXpCalculator.calculate(
              sport: finishedActivity,
              distanceKm: finalDistance,
              activeDuration: finalDuration,
              elevationMeters: gainedElevation,
              specialization: workoutSpecialization,
              participantSex: workoutParticipantSex,
            )
          : null;
      final earnedXp = breakdown?.total ?? 0;

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
        finishedRoute = savedRoute;
        finishedElevation = gainedElevation;
        finishedXpBreakdown = breakdown;

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
              date: workoutStartedAt ?? DateTime.now(),
              distance: finalDistance,
              duration: finalDuration,
              xp: earnedXp,
              sport: finishedActivity,
              route: savedRoute,
              elevationGain: gainedElevation,
              xpBreakdown: breakdown,
              startedAt: workoutStartedAt,
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
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  void startNewWorkout() {
    setState(() {
      workoutFinished = false;
      finishedRoute = [];
      finishedXpBreakdown = null;
      finishedElevation = 0;
      workoutSpecialization = null;
      workoutParticipantSex = null;
      workoutStartedAt = null;
      elevation.reset();
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
        header: PaceHeader(onProfile: () => setState(() => tab = 3)),
      ),
      const CommunityPage(),
      ProgressPage(xp: xp, level: level, workouts: workouts),
      ProfilePage(
        xp: xp,
        sports: sports,
        sportIcons: sportIcons,
        selectedSport: selectedSport,
        tracking: tracking || starting || finishing,
        onSelectSport: _selectSport,
      ),
    ];

    return PopScope(
      canPop: !workoutOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && workoutOpen) _closeWorkout();
      },
      child: Scaffold(
        extendBody: true,
        body: PaceBackground(
          child: SafeArea(
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: workoutOpen,
                  child: IndexedStack(index: tab, children: pages),
                ),
                if (workoutOpen)
                  Positioned.fill(
                    child: TrackerPage(
                      distance: distance,
                      pace: pace,
                      elapsed: elapsed,
                      speed: speed,
                      route: route,
                      tracking: tracking,
                      paused: paused,
                      starting: starting,
                      finishing: finishing,
                      workoutFinished: workoutFinished,
                      gpsStatus: gpsStatus,
                      finishedWasSaved: finishedWasSaved,
                      finishedSport: finishedSport,
                      finishedDistance: finishedDistance,
                      finishedDuration: finishedDuration,
                      finishedXp: finishedXp,
                      elevationGain: elevation.gain,
                      finishedElevation: finishedElevation,
                      finishedXpBreakdown: finishedXpBreakdown,
                      finishedRoute: finishedRoute,
                      sports: sports,
                      sportIcons: sportIcons,
                      selectedSport: selectedSport,
                      formatDuration: formatDuration,
                      formatPace: formatPace,
                      onNewWorkout: startNewWorkout,
                      onStartWorkout: startWorkout,
                      onPauseWorkout: pauseWorkout,
                      onFinishWorkout: finishWorkout,
                      onSelectSport: _selectSport,
                      onClose: _closeWorkout,
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: workoutOpen
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: GlassNavigation(
                  index: tab,
                  onSelect: (index) => setState(() => tab = index),
                  onRecord: _openWorkout,
                  recording: tracking,
                  paused: paused,
                ),
              ),
      ),
    );
  }
}
