import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';

import 'support/test_app.dart';

import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/models/participant_sex.dart';
import 'package:sport_platform/models/specialization.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/workout_draft.dart';

import 'recording_flow_test.dart' show AlphaGps;

WorkoutDraft fixture({String id = 'recovered-run', double distance = 5000}) =>
    WorkoutDraft(
      id: id,
      sportIndex: 0,
      startedAt: DateTime.utc(2026, 11, 7, 10),
      savedAt: DateTime.utc(2026, 11, 7, 10, 30),
      activeDuration: const Duration(minutes: 30),
      distanceMeters: distance,
      elevationMeters: 100,
      specialization: Specialization.runner,
      participantSex: ParticipantSex.female,
      route: [AlphaGps.point(0), AlphaGps.point(1), AlphaGps.point(2)],
    );

Workout completed(String id) => Workout(
  date: DateTime.utc(2026, 11, 7, 10),
  distance: 5,
  duration: const Duration(minutes: 30),
  xp: 360,
  sport: 'Бег',
  sessionId: id,
);

class RejectingPreferences extends Fake implements SharedPreferences {
  RejectingPreferences(this.delegate);
  final SharedPreferences delegate;
  bool rejectProgress = true;
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  bool containsKey(String key) => delegate.containsKey(key);
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> setString(String key, String value) async =>
      key == 'pace_local_data' && rejectProgress
      ? false
      : await delegate.setString(key, value);
}

void main() {
  testWidgets(
    'Recovery controls remain available with large text on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'pace_active_workout': jsonEncode(fixture().toJson()),
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const PaceHome(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pause-workout')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('finish-workout')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A live recording checkpoints on background and reopens without starting GPS',
    (tester) async {
      final originalGps = GeolocatorPlatform.instance;
      final gps = AlphaGps();
      GeolocatorPlatform.instance = gps;
      addTearDown(() async {
        GeolocatorPlatform.instance = originalGps;
        await gps.positions.close();
      });
      final progress = jsonEncode({
        'xp': 9100,
        'selectedSport': 0,
        'workouts': [],
      });
      SharedPreferences.setMockInitialValues({
        'pace_local_data': progress,
        'pace_profile_data': jsonEncode({
          'specializationId': 'runner',
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
        gps.positions.add(AlphaGps.point(step));
        await tester.pump();
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final draft = (await LocalStorageService().loadDraft())!;
      expect(draft.route.length, 4);
      expect(draft.distanceMeters, closeTo(66.72, 1));
      expect(draft.specialization, Specialization.runner);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pace_local_data'), progress);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      expect(find.text('Восстановлена тренировка'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Продолжить'), findsOneWidget);
      expect(prefs.getString('pace_local_data'), progress);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Finishing a recovered recording under 50 m clears only its draft',
    (tester) async {
      final progress = jsonEncode({
        'xp': 9100,
        'selectedSport': 0,
        'workouts': [],
      });
      SharedPreferences.setMockInitialValues({
        'pace_local_data': progress,
        'pace_active_workout': jsonEncode(fixture(distance: 20).toJson()),
      });
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('finish-workout')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Завершить'),
        ),
      );
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pace_local_data'), progress);
      expect(prefs.getString('pace_active_workout'), isNull);
      expect(find.text('Тренировка завершена'), findsOneWidget);
    },
  );

  test('Draft preserves milliseconds, positions and start-time character', () {
    final draft = fixture();
    expect(WorkoutDraft.fromJson(draft.toJson()).toJson(), draft.toJson());
    expect(WorkoutDraft.newId(), isNot(WorkoutDraft.newId()));
    final bad = draft.toJson()..['version'] = 99;
    expect(() => WorkoutDraft.fromJson(bad), throwsFormatException);
  });

  test(
    'Draft writes are ordered; clearing wins over an earlier queued save',
    () async {
      final original = jsonEncode({
        'xp': 9100,
        'selectedSport': 0,
        'workouts': [],
      });
      SharedPreferences.setMockInitialValues({'pace_local_data': original});
      final storage = LocalStorageService();
      await Future.wait([
        storage.saveDraft(fixture(id: 'first')),
        storage.saveDraft(fixture(id: 'second')),
        storage.clearDraft(),
      ]);
      expect(await storage.loadDraft(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('pace_local_data'),
        original,
      );
    },
  );

  test(
    'Completion commits balance once even if the same session is retried',
    () async {
      SharedPreferences.setMockInitialValues({
        'pace_local_data': jsonEncode({
          'xp': 9100,
          'selectedSport': 0,
          'workouts': [],
        }),
      });
      final storage = LocalStorageService();
      await storage.saveDraft(fixture());
      final result = await storage.completeWorkout(
        workout: completed('recovered-run'),
        initialXp: 9100,
        selectedSport: 0,
        initialWorkouts: [],
      );
      expect(result.xp, 9710);
      expect(result.workouts.length, 1);
      expect(await storage.loadDraft(), isNull);
      await storage.saveDraft(
        fixture(),
      ); // Simulate a crash before draft cleanup.
      final retry = await storage.completeWorkout(
        workout: completed('recovered-run'),
        initialXp: 9710,
        selectedSport: 0,
        initialWorkouts: result.workouts,
      );
      expect(retry.xp, 9710);
      expect(retry.workouts.length, 1);
      expect(await storage.loadDraft(), isNull);
    },
  );

  test(
    'Failed final write leaves draft and balance available for retry',
    () async {
      final original = jsonEncode({
        'xp': 9100,
        'selectedSport': 0,
        'workouts': [],
      });
      SharedPreferences.setMockInitialValues({'pace_local_data': original});
      final prefs = RejectingPreferences(await SharedPreferences.getInstance());
      final storage = LocalStorageService(preferences: () async => prefs);
      await storage.saveDraft(fixture());
      await expectLater(
        storage.completeWorkout(
          workout: completed('recovered-run'),
          initialXp: 9100,
          selectedSport: 0,
          initialWorkouts: [],
        ),
        throwsStateError,
      );
      expect(prefs.getString('pace_local_data'), original);
      expect((await storage.loadDraft())!.id, 'recovered-run');
      prefs.rejectProgress = false;
      expect(
        (await storage.completeWorkout(
          workout: completed('recovered-run'),
          initialXp: 9100,
          selectedSport: 0,
          initialWorkouts: [],
        )).xp,
        9710,
      );
      expect(await storage.loadDraft(), isNull);
    },
  );

  testWidgets(
    'Reopening restores a paused session and finishing uses its original bonus',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'pace_local_data': jsonEncode({
          'xp': 9100,
          'selectedSport': 2,
          'workouts': [],
        }),
        'pace_active_workout': jsonEncode(fixture().toJson()),
        'pace_profile_data': jsonEncode({
          'specializationId': 'cyclist',
          'sex': 'male',
        }),
      });
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      expect(find.text('Восстановлена тренировка'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Продолжить'), findsOneWidget);
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
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString('pace_local_data')!) as Map;
      final record = Workout.fromJson(
        Map<String, dynamic>.from((data['workouts'] as List).single as Map),
      );
      expect(record.xp, 635);
      expect(record.achievementXp, 275);
      expect(record.duration, const Duration(minutes: 30));
      expect(record.elevationGain, 100);
      expect(record.xpBreakdown!.specialization, Specialization.runner);
      expect(record.xpBreakdown!.participantSex, ParticipantSex.female);
      expect(record.sessionId, 'recovered-run');
      expect(data['xp'], 9735);
      expect(prefs.getString('pace_active_workout'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      expect(find.text('Восстановлена тренировка'), findsNothing);
      expect(
        (jsonDecode(prefs.getString('pace_local_data')!) as Map)['xp'],
        9735,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Resume keeps previous time and resets the GPS gap before another recovery',
    (tester) async {
      final originalGps = GeolocatorPlatform.instance;
      final gps = AlphaGps();
      GeolocatorPlatform.instance = gps;
      addTearDown(() async {
        GeolocatorPlatform.instance = originalGps;
        await gps.positions.close();
      });
      SharedPreferences.setMockInitialValues({
        'pace_active_workout': jsonEncode(fixture().toJson()),
      });
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pause-workout')));
      await tester.pumpAndSettle();
      gps.positions.add(
        Position.fromMap({...AlphaGps.point(500).toJson(), 'altitude': 300.0}),
      );
      await tester.pump();
      gps.positions.add(
        Position.fromMap({...AlphaGps.point(501).toJson(), 'altitude': 305.0}),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pause-workout')));
      await tester.pumpAndSettle();
      final draft = (await LocalStorageService().loadDraft())!;
      expect(draft.activeDuration.inSeconds, inInclusiveRange(1800, 1805));
      expect(draft.distanceMeters, closeTo(5022.24, 1));
      expect(draft.elevationMeters, 105);
      expect(draft.specialization, Specialization.runner);
      expect(draft.route.length, 5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      expect(find.text('Восстановлена тренировка'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Продолжить'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('A completed leftover draft is cleared without another award', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'pace_local_data': jsonEncode({
        'xp': 9460,
        'selectedSport': 0,
        'workouts': [completed('recovered-run').toJson()],
      }),
      'pace_active_workout': jsonEncode(fixture().toJson()),
    });
    await tester.pumpWidget(const TestPaceApp());
    await tester.pumpAndSettle();
    expect(find.text('Восстановлена тренировка'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pace_active_workout'), isNull);
    final data = jsonDecode(prefs.getString('pace_local_data')!) as Map;
    expect(data['xp'], 9460);
    expect((data['workouts'] as List).length, 1);
  });

  testWidgets('Unreadable draft is retained until explicit deletion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'pace_active_workout': '{bad'});
    await tester.pumpWidget(const TestPaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record-workout')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось восстановить запись'), findsOneWidget);
    await tester.tap(find.text('Оставить'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pace_active_workout'), '{bad');
    await tester.tap(find.byKey(const ValueKey('record-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить черновик'));
    await tester.pumpAndSettle();
    expect(prefs.getString('pace_active_workout'), isNull);
    expect(find.byKey(const ValueKey('start-workout')), findsOneWidget);
  });
}
