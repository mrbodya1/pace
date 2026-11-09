import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_app.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/specialization.dart';
import 'package:sport_platform/services/workout_xp_calculator.dart';
import 'package:sport_platform/features/workouts/workout_details_page.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';

import 'recording_flow_test.dart' show AlphaGps;

Position elevatedPoint(int step, double altitude) => Position(
  latitude: 56 + step * .0002,
  longitude: 60,
  timestamp: DateTime(2026, 11, 8, 12).add(Duration(seconds: step * 10)),
  accuracy: 5,
  altitude: altitude,
  altitudeAccuracy: 5,
  heading: 0,
  headingAccuracy: 0,
  speed: 2.2,
  speedAccuracy: .2,
);

void main() {
  testWidgets(
    'Recording snapshots class, excludes pause height and awards exactly once',
    (tester) async {
      final originalGps = GeolocatorPlatform.instance;
      final gps = AlphaGps();
      GeolocatorPlatform.instance = gps;
      addTearDown(() async {
        GeolocatorPlatform.instance = originalGps;
        await gps.positions.close();
      });
      SharedPreferences.setMockInitialValues({
        'pace_local_data': jsonEncode({
          'xp': 9100,
          'selectedSport': 0,
          'workouts': [],
        }),
        'pace_profile_data': jsonEncode({
          'specializationId': 'trailrunner',
          'sex': 'female',
        }),
      });
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record-workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-workout')));
      await tester.pumpAndSettle();
      for (var step = 1; step <= 3; step++) {
        gps.positions.add(elevatedPoint(step, 200 + step * 5));
        await tester.pump();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pace_profile_data',
        jsonEncode({'specializationId': 'cyclist', 'sex': 'male'}),
      );
      await tester.tap(find.byKey(const ValueKey('pause-workout')));
      await tester.pumpAndSettle();
      gps.positions.add(elevatedPoint(4, 350));
      await tester.tap(find.byKey(const ValueKey('pause-workout')));
      await tester.pumpAndSettle();
      gps.positions.add(elevatedPoint(5, 400));
      await tester.pump();
      gps.positions.add(elevatedPoint(6, 405));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('finish-workout')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Завершить'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      final data = jsonDecode(prefs.getString('pace_local_data')!) as Map;
      expect((data['workouts'] as List).length, 1);
      final workout = Workout.fromJson(
        Map<String, dynamic>.from((data['workouts'] as List).single as Map),
      );
      expect(workout.elevationGain, 20);
      expect(workout.distance, closeTo(.08896, .001));
      expect(workout.xpBreakdown!.specialization, Specialization.trailrunner);
      expect(workout.xpBreakdown!.participantSex!.name, 'female');
      expect(
        workout.xpBreakdown!.bonusFraction,
        closeTo(.0133333333, .00000001),
      );
      expect(workout.route.last.altitude, 405);
      expect(workout.startedAt, isNotNull);
      expect(data['xp'], 9100 + workout.xp);
      expect(workout.xp, workout.xpBreakdown!.total);
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      final reopened = jsonDecode(prefs.getString('pace_local_data')!) as Map;
      expect((reopened['workouts'] as List).length, 1);
      expect(reopened['xp'], data['xp']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved XP breakdown is readable on small screens with large type',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final breakdown = WorkoutXpCalculator.calculate(
        sport: 'Бег',
        distanceKm: 10,
        activeDuration: const Duration(hours: 1),
        elevationMeters: 100,
        specialization: Specialization.runner,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WorkoutDetailsPage(
            workout: Workout(
              date: DateTime(2026, 11, 8),
              distance: 10,
              duration: const Duration(hours: 1),
              xp: 480,
              sport: 'Бег',
              elevationGain: 100,
              xpBreakdown: breakdown,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('За что начислены XP'), 200);
      await tester.scrollUntilVisible(find.text('480 XP'), 160);
    await tester.pumpAndSettle();
      expect(find.text('480 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
