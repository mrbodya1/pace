import 'package:flutter_test/flutter_test.dart';
import 'package:sport_platform/models/specialization.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/services/elevation_tracker.dart';
import 'package:sport_platform/services/workout_xp_calculator.dart';

void main() {
  for (final entry in {
    'Бег': 10.0,
    'Трейл': 10.0,
    'Ходьба': 5.0,
    'Лыжи': 15.0,
    'Роллеры': 15.0,
    'Ролики': 15.0,
    'Велосипед': 30.0,
    'Плавание': 2.0,
  }.entries) {
    test('${entry.key}: four reference components are each 100 XP', () {
      final result = WorkoutXpCalculator.calculate(
        sport: entry.key,
        distanceKm: entry.value,
        activeDuration: const Duration(hours: 1),
        elevationMeters: entry.key == 'Плавание' ? 0 : 100,
      );
      expect(
        [result.distance, result.pace, result.duration, result.elevation],
        [100, 100, 100, 100],
      );
      expect(result.total, 400);
    });
  }

  test(
    'Fixed specializations only reward their discipline; no implicit default',
    () {
      for (final pair in {
        Specialization.runner: ('Бег', 10.0),
        Specialization.skier: ('Лыжи', 15.0),
        Specialization.cyclist: ('Велосипед', 30.0),
        Specialization.swimmer: ('Плавание', 2.0),
      }.entries) {
        final result = WorkoutXpCalculator.calculate(
          sport: pair.value.$1,
          distanceKm: pair.value.$2,
          activeDuration: const Duration(hours: 1),
          elevationMeters: pair.value.$1 == 'Плавание' ? 0 : 100,
          specialization: pair.key,
        );
        expect(result.total, 480);
      }
      final outside = WorkoutXpCalculator.calculate(
        sport: 'Бег',
        distanceKm: 10,
        activeDuration: const Duration(hours: 1),
        elevationMeters: 100,
        specialization: Specialization.cyclist,
      );
      expect(outside.total, 400);
      final all = WorkoutXpCalculator.calculate(
        sport: 'Роллеры',
        distanceKm: 15,
        activeDuration: const Duration(hours: 1),
        elevationMeters: 100,
        specialization: Specialization.multiathlete,
      );
      expect(all.total, 420);
    },
  );

  test(
    'Linear marathon and trail bonuses match approved examples, with no cap',
    () {
      final marathon = WorkoutXpCalculator.calculate(
        sport: 'Бег',
        distanceKm: 10,
        activeDuration: const Duration(hours: 1),
        elevationMeters: 100,
        specialization: Specialization.marathoner,
      );
      expect(marathon.bonusFraction, closeTo(.095238095, .00000001));
      expect(marathon.total, 438);
      final trail = WorkoutXpCalculator.calculate(
        sport: 'Трейл',
        distanceKm: 10,
        activeDuration: const Duration(hours: 1),
        elevationMeters: 150,
        specialization: Specialization.trailrunner,
      );
      expect(trail.bonusFraction, .10);
      expect(trail.total, 495);
      for (final specialization in [
        Specialization.marathoner,
        Specialization.trailrunner,
      ]) {
        final result = WorkoutXpCalculator.calculate(
          sport: 'Бег',
          distanceKm: 21,
          activeDuration: const Duration(hours: 2),
          elevationMeters: 300,
          specialization: specialization,
        );
        expect(result.base, 815);
        expect(result.total, 978);
        final longer = WorkoutXpCalculator.calculate(
          sport: 'Бег',
          distanceKm: 42,
          activeDuration: const Duration(hours: 4),
          elevationMeters: 600,
          specialization: specialization,
        );
        expect(longer.bonusFraction, .40);
      }
    },
  );

  test(
    'Pace is independent of volume and zero time does not divide by zero',
    () {
      final short = WorkoutXpCalculator.calculate(
        sport: 'Бег',
        distanceKm: 1,
        activeDuration: const Duration(minutes: 5),
        elevationMeters: 0,
      );
      final long = WorkoutXpCalculator.calculate(
        sport: 'Бег',
        distanceKm: 10,
        activeDuration: const Duration(minutes: 50),
        elevationMeters: 0,
      );
      expect(short.pace, 120);
      expect(long.pace, 120);
      expect(short.total, 138);
      expect(long.total, 303);
      final zero = WorkoutXpCalculator.calculate(
        sport: 'Бег',
        distanceKm: 0,
        activeDuration: Duration.zero,
        elevationMeters: 0,
      );
      expect(zero.total, 0);
      expect(zero.pace, 0);
    },
  );

  test('Elevation ascent, descent, small oscillations and pause anchors', () {
    final tracker = ElevationTracker();
    for (final altitude in <double>[100, 101, 99, 100, 102]) {
      tracker.add(altitude);
    }
    expect(tracker.gain, 0);
    tracker.add(105);
    expect(tracker.gain, 5);
    tracker.add(95);
    tracker.add(100);
    expect(tracker.gain, 10);
    tracker.resetAnchor();
    tracker.add(300);
    tracker.add(304);
    expect(tracker.gain, 14);
    tracker.add(double.nan);
    tracker.reset();
    expect(tracker.gain, 0);
  });

  test('Legacy workouts keep their XP and omit unavailable new fields', () {
    final old = {
      'date': '2026-11-06T12:00:00.000',
      'distance': 5.0,
      'durationSeconds': 1800,
      'xp': 500,
      'sport': 'Бег',
      'route': [
        {'latitude': 56.0, 'longitude': 60.0},
      ],
    };
    final workout = Workout.fromJson(old);
    expect(workout.xp, 500);
    expect(workout.elevationGain, isNull);
    expect(workout.xpBreakdown, isNull);
    expect(workout.toJson(), old);
  });

  test(
    'Saved XP snapshot and altitude round-trip independently of profile',
    () {
      final breakdown = WorkoutXpCalculator.calculate(
        sport: 'Бег',
        distanceKm: 10,
        activeDuration: const Duration(hours: 1),
        elevationMeters: 100,
        specialization: Specialization.runner,
      );
      final workout = Workout(
        date: DateTime(2026, 11, 8),
        distance: 10,
        duration: const Duration(hours: 1),
        xp: 480,
        sport: 'Бег',
        elevationGain: 100,
        xpBreakdown: breakdown,
        startedAt: DateTime(2026, 11, 8),
        route: [const RoutePoint(latitude: 56, longitude: 60, altitude: 200)],
      );
      final restored = Workout.fromJson(workout.toJson());
      expect(restored.toJson(), workout.toJson());
      expect(restored.xpBreakdown!.specialization, Specialization.runner);
      expect(restored.xpBreakdown!.total, 480);
      expect(restored.route.single.altitude, 200);
    },
  );
}
