import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sport_platform/main.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';

import 'progress_sync_test.dart' show MemoryRemote;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_platform/services/garmin_import_service.dart';
import 'package:sport_platform/services/account_service.dart';
import 'package:sport_platform/services/progress_sync.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';

import 'support/account_fakes.dart';

Map<String, dynamic> packet([String id = '123']) => {
  'source': 'garmin-personal',
  'externalId': id,
  'startedAt': since.add(const Duration(hours: 1)).toIso8601String(),
  'sport': 'Бег',
  'distanceKm': 10,
  'durationSeconds': 3600,
  'elevationGain': 30,
  'receivedAt': DateTime.now().toUtc().toIso8601String(),
  'fitSha256': 'fixture',
  'route': [
    {
      'latitude': 1.0,
      'longitude': 2.0,
      'timestamp': since.add(const Duration(hours: 1)).toIso8601String(),
    },
  ],
  'heartRateSamples': [
    {'at': since.add(const Duration(hours: 1)).toIso8601String(), 'bpm': 140},
    {
      'at': since.add(const Duration(hours: 1, seconds: 1)).toIso8601String(),
      'bpm': 141,
    },
  ],
};
final since = DateTime.now().toUtc().subtract(const Duration(hours: 2));

void main() {
  test('Automatic opening/resume gate waits five minutes; manual refresh bypasses it', () {
    final gate = GarminRefreshGate();
    final now = DateTime.utc(2026, 11, 12, 10);
    expect(gate.claim(now), isTrue);
    expect(
      gate.claim(now.add(const Duration(minutes: 4, seconds: 59))),
      isFalse,
    );
    expect(gate.claim(now.add(const Duration(minutes: 5))), isTrue);
    expect(
      gate.claim(now.add(const Duration(minutes: 5, seconds: 1)), force: true),
      isTrue,
    );
    expect(
      gate.claim(now.add(const Duration(minutes: 5, seconds: 2))),
      isFalse,
    );
  });

  test('Leaving the app stops polling a running refresh; no background timer is retained', () async {
    SharedPreferences.setMockInitialValues({});
    var gets = 0, posts = 0, active = true;
    final accounts = AccountService(
      baseUrl: Uri.parse('https://pace.example'),
      vault: MemorySessionVault(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('auth-with-password')) {
          return http.Response(
            accountResponse(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'POST') {
          posts++;
          return http.Response('{"phase":"running"}', 202);
        }
        gets++;
        return http.Response(
          jsonEncode({
            'available': true,
            'sinceUtc': since.toIso8601String(),
            'activities': [],
            'refresh': {'phase': gets == 1 ? 'idle' : 'running'},
          }),
          200,
        );
      }),
    );
    await accounts.signIn(email: 'athlete@example.com', password: 'fixture');
    final storage = LocalStorageService(owner: accounts.progressOwner);
    final result = await GarminImportService.importNew(
      accounts: accounts,
      storage: storage,
      profile: {},
      refresh: true,
      shouldContinue: () => active,
      wait: (_) async {
        active = false;
      },
    );
    expect(result.imported, 0);
    expect(posts, 1);
    expect(gets, 2);
    accounts.dispose();
  });

  testWidgets(
    'Opening triggers one refresh, quick resume does not, Update forces a refresh',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final forced = <bool>[];
      final accounts = AccountService(
        baseUrl: Uri.parse('https://pace.example'),
        vault: MemorySessionVault(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('auth-with-password')) {
            return http.Response(
              accountResponse(),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.method == 'POST') {
            forced.add((jsonDecode(request.body) as Map)['force'] as bool);
            return http.Response('{"phase":"ready"}', 202);
          }
          return http.Response(
            jsonEncode({
              'available': true,
              'sinceUtc': since.toIso8601String(),
              'activities': [],
              'refresh': {'phase': 'ready'},
            }),
            200,
          );
        }),
      );
      await accounts.signIn(email: 'athlete@example.com', password: 'fixture');
      final storage = LocalStorageService(
        owner: accounts.progressOwner,
        remote: MemoryRemote(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          home: PaceHome(accounts: accounts, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(forced, [false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(forced, [false]);
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNavigation),
          matching: find.text('Прогресс'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(forced, [false, true]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      accounts.dispose();
    },
  );

  test(
    'Garmin metadata and pulse survive rewards, JSON and canonical merge',
    () {
      final w = GarminImportService.parse(packet(), since, {});
      final rewarded = w.withAchievements(10, ['test']);
      final restored = Workout.fromJson(
        jsonDecode(jsonEncode(rewarded.toJson())) as Map<String, dynamic>,
      );
      expect(restored.source, 'garmin-personal');
      expect(restored.externalId, '123');
      expect(restored.heartRateSamples.map((s) => s.bpm), [140, 141]);
      expect(restored.timedRoute.single.accuracy, isNull);
      final merged = ProgressMerger.merge(null, {
        '_sync': {
          'pending': [w.toJson()],
        },
      });
      final once = merged['xp'];
      final twice = ProgressMerger.merge(merged, {
        '_sync': {
          'pending': [w.toJson()],
        },
      });
      expect(twice['xp'], once);
      expect((twice['workouts'] as List), hasLength(1));
      expect(
        ProgressMerger.workouts(twice).single.heartRateSamples,
        hasLength(2),
      );
    },
  );
  test('Old and malformed activities are rejected before saving', () {
    for (final invalid in [
      packet()
        ..['startedAt'] = since
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      packet()..['externalId'] = '../x',
      packet()..['distanceKm'] = -1,
      packet()
        ..['heartRateSamples'] = [
          {
            'at': since.add(const Duration(hours: 1)).toIso8601String(),
            'bpm': 0,
          },
        ],
    ]) {
      expect(
        () => GarminImportService.parse(invalid, since, {}),
        throwsA(anything),
      );
    }
  });
  test('Likely PACE/device duplicates are held instead of double rewarded', () {
    final w = GarminImportService.parse(packet(), since, {});
    final recorded = Workout(
      date: w.date,
      distance: 10,
      duration: const Duration(hours: 1),
      xp: 1,
      sport: 'Бег',
      sessionId: 'pace-session',
    );
    expect(GarminImportService.possibleDuplicate(w, recorded), isTrue);
    expect(GarminImportService.possibleDuplicate(w, w), isFalse);
  });
  test('Legacy workout JSON still has no invented source or pulse', () {
    final w = Workout(
      date: since,
      distance: 1,
      duration: const Duration(minutes: 6),
      xp: 1,
      sport: 'Бег',
    );
    final restored = Workout.fromJson(w.toJson());
    expect(restored.source, isNull);
    expect(restored.heartRateSamples, isEmpty);
  });
  test('Import remains idempotent and does not clear an active draft', () async {
    SharedPreferences.setMockInitialValues({});
    final accounts = AccountService(
      baseUrl: Uri.parse('https://pace.example'),
      vault: MemorySessionVault(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('auth-with-password')) {
          return http.Response(
            accountResponse(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'available': true,
            'sinceUtc': since.toIso8601String(),
            'activities': [packet()],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await accounts.signIn(
      email: 'athlete@example.com',
      password: 'test-password',
    );
    final storage = LocalStorageService(owner: accounts.progressOwner);
    final prefs = await SharedPreferences.getInstance();
    final draftKey =
        'pace_progress_v2:${Uri.encodeComponent(accounts.progressOwner!)}:draft';
    await prefs.setString(draftKey, 'active-draft-marker');
    final first = await GarminImportService.importNew(
      accounts: accounts,
      storage: storage,
      profile: {},
    );
    final xp = (await storage.loadProgress())!['xp'];
    final second = await GarminImportService.importNew(
      accounts: accounts,
      storage: storage,
      profile: {},
    );
    expect(first.imported, 1);
    expect(second.imported, 0);
    expect((await storage.loadProgress())!['xp'], xp);
    expect(prefs.getString(draftKey), 'active-draft-marker');
    accounts.dispose();
  });
}
