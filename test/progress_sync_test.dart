import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/workout_draft.dart';
import 'package:sport_platform/services/progress_sync.dart';
import 'package:sport_platform/services/account_service.dart';

Workout run(String id) => Workout(
  date: DateTime.utc(2026, 11, 10),
  distance: 5,
  duration: const Duration(minutes: 30),
  xp: 360,
  sport: 'Бег',
  sessionId: id,
);
Map<String, dynamic> pending(List<Workout> values) => {
  '_sync': {'pending': values.map((w) => w.toJson()).toList()},
};

class MemoryRemote implements ProgressRemote {
  int revision = 0, saves = 0;
  Map<String, dynamic>? data;
  bool offline = false, loseReply = false;
  Future<void> Function()? beforeSave;
  @override
  Future<ProgressSnapshot> load() async {
    if (offline) throw const AccountError('Нет связи');
    return ProgressSnapshot(
      revision,
      data == null ? null : ProgressMerger.copy(data!),
    );
  }

  @override
  Future<ProgressSnapshot> save(
    int expected,
    Map<String, dynamic> value,
  ) async {
    if (beforeSave != null) await beforeSave!();
    if (expected != revision) throw ProgressConflict();
    saves++;
    revision++;
    data = ProgressMerger.copy(value);
    if (loseReply) {
      loseReply = false;
      throw const AccountError('Ответ потерян');
    }
    return ProgressSnapshot(revision, ProgressMerger.copy(data!));
  }
}

Future<void> finish(LocalStorageService s, String id) async =>
    s.completeWorkout(
      workout: run(id),
      initialXp: 0,
      selectedSport: 0,
      initialWorkouts: [],
    );

class RejectAckPreferences extends Fake implements SharedPreferences {
  RejectAckPreferences(this.delegate);
  final SharedPreferences delegate;
  @override
  Future<void> reload() => delegate.reload();
  bool reject = false;
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  bool containsKey(String key) => delegate.containsKey(key);
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> setString(String key, String value) async =>
      reject ? false : delegate.setString(key, value);
}

class CacheBeforeFailurePreferences extends RejectAckPreferences {
  CacheBeforeFailurePreferences(super.delegate);
  final shadow = <String, String>{};
  @override
  String? getString(String key) => shadow[key] ?? delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) async {
    if (reject) {
      shadow[key] = value;
      return false;
    }
    return delegate.setString(key, value);
  }

  @override
  Future<void> reload() async {
    shadow.clear();
    await delegate.reload();
  }
}

class DroppingRemote extends MemoryRemote {
  @override
  Future<ProgressSnapshot> save(
    int expected,
    Map<String, dynamic> data,
  ) async => ProgressSnapshot(expected + 1, ProgressMerger.empty());
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Account caches, drafts and legacy ownership never cross owners',
    () async {
      final legacy = {
        'xp': 9460,
        'workouts': [run('legacy').toJson()],
        'selectedSport': 2,
      };
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
      SharedPreferences.setMockInitialValues({
        'pace_local_data': jsonEncode(legacy),
        LocalStorageService.draftKey: jsonEncode(draft.toJson()),
      });
      final a = LocalStorageService(owner: 'server|alice');
      final b = LocalStorageService(owner: 'server|bob');
      expect((await a.loadProgress())!['xp'], 9460);
      expect((await a.loadDraft())!.id, 'draft');
      expect(await b.loadProgress(), isNull);
      expect(await b.loadDraft(), isNull);
      await finish(b, 'bob');
      expect((await a.loadProgress())!['xp'], 9460);
      expect((await b.loadProgress())!['xp'], 610);
      expect(
        (await SharedPreferences.getInstance()).getString('pace_local_data'),
        jsonEncode(legacy),
      );
    },
  );
  test('Existing profile ownership blocks another account from claiming legacy history', () async {
    SharedPreferences.setMockInitialValues({
      'pace_profile_legacy_owner': 'server|alice',
      'pace_local_data': jsonEncode({
        'xp': 360,
        'workouts': [run('old').toJson()],
      }),
    });
    expect(
      await LocalStorageService(owner: 'server|bob').loadProgress(),
      isNull,
    );
    expect(
      (await LocalStorageService(owner: 'server|alice').loadProgress())!['xp'],
      360,
    );
  });
  test('First legacy import preserves balance and is idempotent after lost response', () async {
    SharedPreferences.setMockInitialValues({
      'pace_local_data': jsonEncode({
        'xp': 9460,
        'selectedSport': 2,
        'workouts': [run('old').toJson()],
      }),
    });
    final remote = MemoryRemote()..loseReply = true;
    final s = LocalStorageService(owner: 'server|alice', remote: remote);
    expect((await s.loadProgress())!['xp'], 9460);
    await expectLater(s.synchronize(), throwsA(isA<AccountError>()));
    await s.synchronize();
    expect(remote.data!['xp'], 9460);
    expect(ProgressMerger.workouts(remote.data!).length, 1);
    final sync = (await s.loadProgress())!['_sync'] as Map;
    expect(sync['legacy'], isNull);
    expect(sync['pending'], isEmpty);
  });
  test('Stable legacy IDs survive copies without a session ID', () {
    final raw = run('x').toJson()..remove('sessionId');
    final a = ProgressMerger.normalize({
      'xp': 360,
      'workouts': [raw],
    });
    final b = ProgressMerger.normalize({
      'xp': 360,
      'workouts': [raw],
    });
    expect(
      ProgressMerger.workouts(a).single.sessionId,
      ProgressMerger.workouts(b).single.sessionId,
    );
    final merged = ProgressMerger.merge(null, {
      '_sync': {'legacy': a},
    });
    expect(
      ProgressMerger.merge(merged, {
        '_sync': {'legacy': b},
      })['xp'],
      360,
    );
  });
  test('Offline completion survives restart, uploads once, and fresh device downloads progress', () async {
    final remote = MemoryRemote()..offline = true;
    final s = LocalStorageService(owner: 'server|alice', remote: remote);
    await finish(s, 'one');
    await expectLater(s.synchronize(), throwsA(isA<AccountError>()));
    final local = (await s.loadProgress())!;
    expect(local['xp'], 610);
    expect(((local['_sync'] as Map)['pending'] as List).length, 1);
    remote.offline = false;
    final reopened = LocalStorageService(owner: 'server|alice', remote: remote);
    await reopened.synchronize();
    await reopened.synchronize();
    expect(remote.saves, 1);
    expect(remote.data!['xp'], 610);
    SharedPreferences.setMockInitialValues({});
    final fresh = LocalStorageService(owner: 'server|alice', remote: remote);
    await fresh.synchronize();
    expect((await fresh.loadProgress())!['xp'], 610);
    expect(
      ProgressMerger.workouts((await fresh.loadProgress())!).single.sessionId,
      'one',
    );
  });
  test('Two offline devices only receive each ordinary achievement once after merge', () {
    final a = ProgressMerger.merge(null, pending([run('a')]));
    final b = ProgressMerger.merge(a, pending([run('b')]));
    expect(b['xp'], 970);
    expect(ProgressMerger.workouts(b).first.achievementXp, 0);
    expect(ProgressMerger.merge(b, pending([run('a'), run('b')]))['xp'], 970);
  });
  test('Revision conflict refetches and merges another device instead of losing it', () async {
    final remote = MemoryRemote();
    remote.beforeSave = () async {
      remote.beforeSave = null;
      remote.data = ProgressMerger.merge(null, pending([run('other-device')]));
      remote.revision = 1;
    };
    final s = LocalStorageService(owner: 'server|alice', remote: remote);
    await finish(s, 'local');
    await s.synchronize();
    expect(remote.revision, 2);
    expect((await s.loadProgress())!['xp'], 970);
    expect(
      ProgressMerger.workouts(remote.data!).map((w) => w.sessionId).toSet(),
      {'local', 'other-device'},
    );
  });
  test(
    'A failed response after accepted upload never duplicates workout or XP',
    () async {
      final remote = MemoryRemote()..loseReply = true;
      final s = LocalStorageService(owner: 'server|alice', remote: remote);
      await finish(s, 'one');
      await expectLater(s.synchronize(), throwsA(isA<AccountError>()));
      expect(
        ((await s.loadProgress())!['_sync'] as Map)['pending'],
        isNotEmpty,
      );
      await s.synchronize();
      expect(remote.data!['xp'], 610);
      expect(ProgressMerger.workouts(remote.data!).length, 1);
    },
  );
  test('Local completion is not blocked by upload; acknowledgement keeps new queued workout', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final remote = MemoryRemote();
    remote.beforeSave = () async {
      remote.beforeSave = null;
      entered.complete();
      await release.future;
    };
    final s = LocalStorageService(owner: 'server|alice', remote: remote);
    await finish(s, 'one');
    final sync = s.synchronize();
    await entered.future;
    await finish(s, 'two').timeout(const Duration(seconds: 1));
    release.complete();
    await sync;
    expect(remote.data!['xp'], 970);
    expect(ProgressMerger.workouts(remote.data!).length, 2);
    expect(((await s.loadProgress())!['_sync'] as Map)['pending'], isEmpty);
  });
  test(
    'Stale settings snapshot cannot overwrite newer history and pending queue',
    () async {
      final s = LocalStorageService(owner: 'server|alice');
      await finish(s, 'one');
      await s.saveProgress(xp: 0, selectedSport: 2, workouts: []);
      final data = (await s.loadProgress())!;
      expect(data['xp'], 610);
      expect(data['selectedSport'], 2);
      expect(ProgressMerger.workouts(data).length, 1);
      expect((data['_sync'] as Map)['pending'], isNotEmpty);
    },
  );
  test('Different servers using the same user ID remain separate', () async {
    final a = LocalStorageService(owner: 'server-a|alice'),
        b = LocalStorageService(owner: 'server-b|alice');
    await finish(a, 'one');
    expect(await b.loadProgress(), isNull);
  });
  test(
    'Invalid or future snapshots fail without silently changing balance',
    () {
      expect(
        () => ProgressMerger.normalize({'version': 2, 'xp': 10}),
        throwsFormatException,
      );
      expect(
        () => ProgressMerger.normalize({'xp': -10}),
        throwsFormatException,
      );
      expect(
        () => ProgressSnapshot.fromJson({'revision': 1, 'data': null}),
        throwsFormatException,
      );
    },
  );
  test('Record rewards merge against already accepted best times without duplicates', () {
    final scale = Geolocator.distanceBetween(0, 0, .001, 0) / .001;
    Workout timed(String id, int seconds) => Workout(
      date: DateTime.utc(2026),
      distance: 5,
      duration: const Duration(minutes: 30),
      xp: 360,
      sport: 'Бег',
      sessionId: id,
      timedRoute: [
        for (var i = 0; i <= 12; i++)
          RoutePoint(
            latitude: i * 10 / scale,
            longitude: 0,
            timestamp: DateTime.utc(2026)
                .add(Duration(milliseconds: i * seconds * 1000 ~/ 12)),
            accuracy: 2,
          ),
      ],
    );
    final first = ProgressMerger.merge(null, pending([timed('one', 120)]));
    final next = ProgressMerger.merge(first, pending([timed('two', 108)]));
    expect(first['xp'], 660);
    expect(next['xp'], 1120);
    expect(ProgressMerger.workouts(next).first.recordXp, 100);
    final third = ProgressMerger.merge(next, pending([timed('three', 120)]));
    expect(third['xp'], 1480);
    expect(ProgressMerger.workouts(third).first.recordXp, 0);
    expect(
      ProgressMerger.merge(third, pending([timed('two', 108)]))['xp'],
      1480,
    );
  });
  test('Import into an existing account retains history and claims old balance credit once', () {
    final remote = ProgressMerger.merge(null, pending([run('server')]));
    final legacy = ProgressMerger.normalize({
      'xp': 9460,
      'workouts': [run('old').toJson()],
    });
    final merged = ProgressMerger.merge(remote, {
      '_sync': {'legacy': legacy},
    });
    expect(merged['xp'], 10070);
    expect(ProgressMerger.workouts(merged).length, 2);
    final expanded = ProgressMerger.normalize({
      'xp': 9820,
      'workouts': [run('another-old').toJson(), run('old').toJson()],
    });
    final again = ProgressMerger.merge(merged, {
      '_sync': {'legacy': expanded},
    });
    expect(again['xp'], 10430);
    expect(ProgressMerger.workouts(again).length, 3);
  });
  test(
    'A server response missing the sent workout does not clear the queue',
    () async {
      final s = LocalStorageService(
        owner: 'server|alice',
        remote: DroppingRemote(),
      );
      await finish(s, 'one');
      await expectLater(s.synchronize(), throwsFormatException);
      expect(
        ((await s.loadProgress())!['_sync'] as Map)['pending'],
        isNotEmpty,
      );
      expect((await s.loadProgress())!['xp'], 610);
    },
  );
  test('Failure saving acknowledgement keeps queued data and safely retries accepted upload', () async {
    final prefs = RejectAckPreferences(await SharedPreferences.getInstance());
    final remote = MemoryRemote();
    final s = LocalStorageService(
      owner: 'server|alice',
      remote: remote,
      preferences: () async => prefs,
    );
    await finish(s, 'one');
    remote.beforeSave = () async {
      remote.beforeSave = null;
      prefs.reject = true;
    };
    await expectLater(s.synchronize(), throwsStateError);
    expect(((await s.loadProgress())!['_sync'] as Map)['pending'], isNotEmpty);
    prefs.reject = false;
    await s.synchronize();
    expect((await s.loadProgress())!['xp'], 610);
    expect(((await s.loadProgress())!['_sync'] as Map)['pending'], isEmpty);
  });
  test(
    'Missing acknowledged server history never erases the local backup',
    () async {
      final remote = MemoryRemote();
      final s = LocalStorageService(owner: 'server|alice', remote: remote);
      await finish(s, 'one');
      await s.synchronize();
      remote
        ..data = null
        ..revision = 0;
      await expectLater(s.synchronize(), throwsA(isA<AccountError>()));
      expect((await s.loadProgress())!['xp'], 610);
      expect(
        ProgressMerger.workouts((await s.loadProgress())!).single.sessionId,
        'one',
      );
    },
  );
  test('A failed platform write cannot become a phantom completion in the preference cache', () async {
    final prefs = CacheBeforeFailurePreferences(
      await SharedPreferences.getInstance(),
    );
    final s = LocalStorageService(
      owner: 'server|alice',
      preferences: () async => prefs,
    );
    prefs.reject = true;
    await expectLater(finish(s, 'one'), throwsStateError);
    expect(await s.loadProgress(), isNull);
    prefs.reject = false;
    await finish(s, 'one');
    expect((await s.loadProgress())!['xp'], 610);
    expect(ProgressMerger.workouts((await s.loadProgress())!).length, 1);
    expect(
      (((await s.loadProgress())!['_sync'] as Map)['pending'] as List).length,
      1,
    );
  });
}
