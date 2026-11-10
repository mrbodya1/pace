import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/workout_draft.dart';
import 'package:sport_platform/models/personal_record.dart';
import 'package:sport_platform/services/personal_record_engine.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/features/progress/records_view.dart';

final epoch = DateTime.utc(2026, 11, 10);
final meterScale = Geolocator.distanceBetween(0, 0, .001, 0) / .001;
RoutePoint point(
  double meters,
  double seconds, {
  int segment = 0,
  double accuracy = 2,
}) => RoutePoint(
  latitude: meters / meterScale,
  longitude: 0,
  timestamp: epoch.add(Duration(milliseconds: (seconds * 1000).round())),
  accuracy: accuracy,
  segment: segment,
);
List<RoutePoint> line(double seconds) => [
  for (var i = 0; i <= 12; i++) point(i * 10, i * seconds / 12),
];
Workout run(String id, double seconds) => Workout(
  date: epoch,
  distance: .12,
  duration: const Duration(minutes: 30),
  xp: 40,
  sport: 'Бег',
  sessionId: id,
  timedRoute: line(seconds),
);
void main() {
  test('67 record distances exactly match approved first-result rules', () {
    final rows =
        (jsonDecode(
                  File('docs/achievements-v1.json').readAsStringSync(),
                )['rows']
                as List)
            .where((r) => r['event'] == 'Первый результат')
            .toList();
    expect(RecordDistance.catalog.length, 67);
    expect(RecordDistance.catalog.map((r) => r.id).toSet().length, 67);
    for (final r in rows) {
      expect(
        RecordDistance.catalog
            .where(
              (d) =>
                  d.sport == r['sport'] &&
                  d.meters == (r['threshold'] as num) * 1000,
            )
            .length,
        1,
      );
    }
  });
  test(
    'Fastest interval uses interpolation including starts between GPS points',
    () {
      final time = PersonalRecordEngine.fastest([
        point(0, 0),
        point(60, 12),
        point(120, 18),
        point(180, 30),
      ], 100);
      expect(time, closeTo(14000, 1));
    },
  );
  test('Pauses cannot be bridged even with nearly adjacent timestamps', () {
    final route = [
      point(0, 0),
      point(60, 12),
      point(60, 13, segment: 1),
      point(120, 25, segment: 1),
    ];
    expect(PersonalRecordEngine.fastest(route, 100), isNull);
  });
  test('Missing time, poor accuracy, gaps and GPS jumps interrupt eligible stretches', () {
    final bad = [
      [point(0, 0), point(60, 12), point(120, 40)],
      [point(0, 0), point(60, 12, accuracy: 30), point(120, 24)],
      [point(0, 0), point(60, 0), point(120, 12)],
      [point(0, 0), point(1000, 1), point(1060, 13)],
      [
        const RoutePoint(latitude: 0, longitude: 0),
        point(60, 12),
        point(120, 24),
      ],
    ];
    for (final route in bad) {
      expect(PersonalRecordEngine.fastest(route, 100), isNull);
    }
  });
  test('Stationary samples preserve elapsed time inside interval', () {
    expect(
      PersonalRecordEngine.fastest([
        point(0, 0),
        point(50, 10),
        point(50, 20),
        point(100, 30),
      ], 100),
      closeTo(30000, 1),
    );
  });
  test('First result 50, unlimited improvements 100, tie slower and same session give zero', () {
    var state = <String, PersonalRecord>{};
    for (var i = 0; i < 12; i++) {
      final workout = run('session$i', 120 - i * 2);
      final result = PersonalRecordEngine.apply(state, workout);
      expect(result.xp, i == 0 ? 50 : 100);
      expect(result.awards.single.improvements, i);
      state = result.best;
      expect(PersonalRecordEngine.apply(state, workout).xp, 0);
    }
    expect(PersonalRecordEngine.apply(state, run('tie', 98)).xp, 0);
    expect(PersonalRecordEngine.apply(state, run('slower', 110)).xp, 0);
    final restored = PersonalRecordEngine.restore(
      PersonalRecordEngine.toJson(state),
      [],
    );
    expect(
      restored.values.single.milliseconds,
      state.values.single.milliseconds,
    );
  });
  test('Several distances get one best result each within one workout', () {
    final w = Workout(
      date: epoch,
      distance: .45,
      duration: const Duration(minutes: 5),
      xp: 0,
      sport: 'Бег',
      sessionId: 'multi',
      timedRoute: [for (var i = 0; i <= 45; i++) point(i * 10, i * 2)],
    );
    final r = PersonalRecordEngine.apply({}, w);
    expect(r.awards.map((r) => r.meters), [100.0, 200.0, 400.0]);
    expect(r.xp, 150);
  });
  test(
    'Untimed legacy workouts and implausibly long GPS time cannot get records',
    () {
      final legacy = Workout(
        date: epoch,
        distance: 5,
        duration: const Duration(minutes: 20),
        xp: 100,
        sport: 'Бег',
        sessionId: 'old',
      );
      expect(PersonalRecordEngine.apply({}, legacy).xp, 0);
      final short = Workout(
        date: epoch,
        distance: .12,
        duration: const Duration(seconds: 1),
        xp: 0,
        sport: 'Бег',
        sessionId: 'short',
        timedRoute: line(120),
      );
      expect(PersonalRecordEngine.apply({}, short).xp, 0);
    },
  );
  test('Record XP and best times persist atomically; retry and sport save keep balance', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    final first = await storage.completeWorkout(
      workout: run('one', 120),
      initialXp: 0,
      selectedSport: 0,
      initialWorkouts: [],
    );
    expect(first.recordXp, 50);
    expect(first.xp, 100); // 40 base + 10 first training + 50 record.
    final second = await storage.completeWorkout(
      workout: run('two', 108),
      initialXp: 0,
      selectedSport: 0,
      initialWorkouts: [],
    );
    expect(second.recordXp, 100);
    expect(second.xp, 240);
    final retry = await storage.completeWorkout(
      workout: run('two', 108),
      initialXp: 0,
      selectedSport: 0,
      initialWorkouts: [],
    );
    expect(retry.xp, 240);
    expect(retry.workouts.length, 2);
    await storage.saveProgress(
      xp: retry.xp,
      selectedSport: 2,
      workouts: retry.workouts,
    );
    final data = (await storage.loadProgress())!;
    final best = PersonalRecordEngine.restore(data['records'], []);
    expect(best.values.single.improvements, 1);
    final w = Workout.fromJson(
      jsonDecode(jsonEncode(retry.workouts.first.toJson()))
          as Map<String, dynamic>,
    );
    expect(w.recordXp, 100);
    expect(w.records.single.sessionId, 'two');
    expect(w.timedRoute.last.timestamp, line(108).last.timestamp);
  });
  test('Draft round trip preserves timing and segment boundaries', () {
    final draft = WorkoutDraft(
      id: 'draft',
      sportIndex: 0,
      startedAt: epoch,
      savedAt: epoch,
      activeDuration: const Duration(seconds: 20),
      distanceMeters: 100,
      elevationMeters: 0,
      route: [],
      timedRoute: [point(0, 0), point(60, 12, segment: 1)],
    );
    final restored = WorkoutDraft.fromJson(
      jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
    );
    expect(restored.timedRoute.last.segment, 1);
    expect(
      restored.timedRoute.last.timestamp,
      epoch.add(const Duration(seconds: 12)),
    );
  });
  testWidgets('Records view works on small screen and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = PersonalRecordEngine.apply({}, run('ui', 120)).awards;
    final workout = run(
      'ui',
      120,
    ).withAchievements(0, [], recordReward: 50, recordResults: record);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: RecordsView(workouts: [workout])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Личные рекорды'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(record.single.timeLabel),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text(record.single.timeLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
