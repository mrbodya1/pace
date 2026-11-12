import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sport_platform/data/storage/workout_database.dart';
import 'package:sport_platform/models/achievement.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/workout_draft.dart';

Workout item(int n, {List<RoutePoint> route = const []}) {
  final start = DateTime.utc(2026, 11, 12).add(Duration(minutes: n));
  return Workout(
    date: start,
    startedAt: start,
    endedAt: start.add(const Duration(hours: 1)),
    sessionId: 'phone:$n',
    sport: 'Бег',
    distance: 10,
    duration: const Duration(hours: 1),
    elevationGain: 30,
    xp: 100,
    route: route,
    timedRoute: route,
  );
}

void main() {
  late WorkoutDatabase store;
  setUp(() {
    sqfliteFfiInit();
    store = WorkoutDatabase(
      open: () =>
          databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath),
    );
  });
  tearDown(() async => store.close());
  test(
    'atomic result stores summaries, telemetry, progress and outbox separately',
    () async {
      final route = [
        RoutePoint(
          latitude: 56.7,
          longitude: 60.6,
          timestamp: DateTime.utc(2026, 11, 12),
          accuracy: 5,
        ),
      ];
      final result = await store.complete(
        'server|alice',
        item(0, route: route),
        0,
      );
      expect(result.workout.xp, greaterThan(100));
      final db = await store.database;
      final row = (await db.query('workout_rows')).single;
      expect(jsonDecode(row['summary'] as String), isNot(contains('route')));
      expect(await store.pending('server|alice'), ['phone:0']);
      expect((await store.history('server|alice')).single.route, isEmpty);
      expect(
        (await store.workout('server|alice', 'phone:0'))!.route,
        hasLength(1),
      );
      expect((await store.history('server|bob')), isEmpty);
    },
  );
  test(
    'record failure rolls back result and leaves the active draft',
    () async {
      final draft = WorkoutDraft(
        id: 'draft',
        sportIndex: 0,
        startedAt: DateTime.utc(2026),
        savedAt: DateTime.utc(2026),
        activeDuration: Duration.zero,
        distanceMeters: 0,
        elevationMeters: 0,
        route: [],
      );
      await store.saveDraft('a', draft);
      await expectLater(
        store.complete(
          'a',
          item(
            0,
            route: [const RoutePoint(latitude: double.nan, longitude: 1)],
          ),
          0,
        ),
        throwsA(anything),
      );
      expect(await store.history('a'), isEmpty);
      expect(await store.pending('a'), isEmpty);
      expect((await store.draft('a'))!.id, 'draft');
    },
  );
  test('forty-three workouts paginate without reading all traces and totals stay complete', () async {
    for (var i = 0; i < 43; i++) {
      await store.complete('a', item(i), 0);
    }
    final first = await store.history('a'),
        second = await store.history('a', offset: 20),
        last = await store.history('a', offset: 40);
    expect([first.length, second.length, last.length], [20, 20, 3]);
    expect(
      {...first, ...second, ...last}.map((w) => w.sessionId).toSet(),
      hasLength(43),
    );
    final state = await store.state('a');
    final totals = AchievementProgress.fromJson(
      store.decode(state['derived'])['totals'] as Map<String, dynamic>,
    );
    expect(totals.totalsFor()[0], 43);
    expect(totals.totalsFor()[2], 430);
  });
  test('repeated commit never doubles rewards', () async {
    await store.complete('a', item(0), 0);
    final before = await store.state('a');
    await store.complete('a', item(0), 0);
    final after = await store.state('a');
    expect(after['derived'], before['derived']);
    expect(await store.pending('a'), hasLength(1));
  });
  test('disk restart preserves a pending workout and its telemetry', () async {
    final folder = await Directory.systemTemp.createTemp('pace-sqlite-v2-');
    final path = '${folder.path}/test.sqlite';
    final disk = WorkoutDatabase(
      open: () => databaseFactoryFfiNoIsolate.openDatabase(path),
    );
    await disk.complete(
      'a',
      item(1, route: [const RoutePoint(latitude: 1, longitude: 2)]),
      0,
    );
    await disk.close();
    final reopened = WorkoutDatabase(
      open: () => databaseFactoryFfiNoIsolate.openDatabase(path),
    );
    try {
      expect(await reopened.pending('a'), ['phone:1']);
      expect((await reopened.workout('a', 'phone:1'))!.route, hasLength(1));
    } finally {
      await reopened.close();
      await folder.delete(recursive: true);
    }
  });
}
