import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sport_platform/data/storage/workout_database.dart';
import 'package:sport_platform/data/storage/sqlite_workout_storage.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/progress_v2.dart';
import 'package:sport_platform/services/account_service.dart';

import 'support/account_fakes.dart';
import 'support/pocketbase_bootstrap.dart';

class LostCommitClient extends http.BaseClient {
  LostCommitClient(this.delegate);
  final http.Client delegate;
  bool loseNext = false;
  bool throttleNext = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (throttleNext && request.url.path.contains('/v2/')) {
      throttleNext = false;
      return http.StreamedResponse(
        Stream.value(utf8.encode('{}')),
        429,
        headers: {'retry-after': '0'},
      );
    }
    final response = await delegate.send(request);
    if (loseNext &&
        request is http.Request &&
        request.method == 'POST' &&
        request.url.path.endsWith('/v2/workouts') &&
        (jsonDecode(request.body) as Map)['action'] == 'commit' &&
        response.statusCode == 200) {
      loseNext = false;
      await response.stream.drain<void>();
      throw http.ClientException('Fixture: acknowledgement lost');
    }
    return response;
  }
}

Workout workout(String id, {bool trace = false}) {
  final start = DateTime.utc(2026, 11, 12, 10);
  final points = trace
      ? List.generate(
          1200,
          (i) => RoutePoint(
            latitude: 56.7 + i * .00001,
            longitude: 60.6,
            timestamp: start.add(Duration(seconds: i)),
            accuracy: 5,
          ),
        )
      : const <RoutePoint>[];
  return Workout(
    date: start,
    startedAt: start,
    endedAt: start.add(const Duration(hours: 1)),
    sessionId: id,
    sport: 'Бег',
    distance: 10,
    duration: const Duration(hours: 1),
    elevationGain: 30,
    xp: 100,
    route: points,
    timedRoute: points,
    heartRateSamples: trace ? [HeartRateSample(start, 140)] : [],
  );
}

void main() {
  final executable = Platform.environment['PACE_POCKETBASE_EXE'];
  test(
    'SQLite devices sync only new workouts, lazily fetch traces and recover a lost acknowledgement',
    () => HttpOverrides.runWithHttpOverrides(() async {
      sqfliteFfiInit();
      final temp = await Directory.systemTemp.createTemp(
        'pace-v2-integration-',
      );
      Process? server;
      final dbA = WorkoutDatabase(
            open: () => databaseFactoryFfiNoIsolate.openDatabase(
              inMemoryDatabasePath,
              options: OpenDatabaseOptions(singleInstance: false),
            ),
          ),
          dbB = WorkoutDatabase(
            open: () => databaseFactoryFfiNoIsolate.openDatabase(
              inMemoryDatabasePath,
              options: OpenDatabaseOptions(singleInstance: false),
            ),
          );
      final client = LostCommitClient(http.Client());
      AccountService? accounts;
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        await preparePocketBaseTest(executable!, temp);
        server = await Process.start(executable, [
          'serve',
          '--http=127.0.0.1:$port',
          '--dir=${temp.path}/data',
          '--migrationsDir=${Directory.current.path}/server/pb_migrations',
          '--hooksDir=${Directory.current.path}/server/pb_hooks',
        ]);
        unawaited(server.stdout.drain<void>());
        unawaited(server.stderr.drain<void>());
        final base = Uri.parse('http://127.0.0.1:$port');
        var ready = false;
        for (var i = 0; i < 100; i++) {
          try {
            if ((await client.get(base.resolve('/api/health'))).statusCode ==
                200) {
              ready = true;
              break;
            }
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(ready, isTrue);
        accounts = AccountService(
          baseUrl: base,
          vault: MemorySessionVault(),
          client: client,
        );
        await accounts.register(
          email: 'sqlite-fixture@invalid.example',
          password: 'synthetic-pass-123456',
          passwordConfirm: 'synthetic-pass-123456',
          name: 'Fixture',
        );
        expect(
          LocalStorageService.forAccount(accounts),
          isA<SqliteWorkoutStorage>(),
        );
        SharedPreferences.setMockInitialValues({
          'pace_local_data': jsonEncode({'xp': 6840, 'workouts': []}),
          'pace_profile_data': jsonEncode({'specializationId': 'skier'}),
        });
        final a = SqliteWorkoutStorage(accounts: accounts, database: dbA),
            b = SqliteWorkoutStorage(accounts: accounts, database: dbB);
        expect((await a.loadProgress())!['xp'], 0);
        expect(
          (await SharedPreferences.getInstance()).containsKey(
            'pace_local_data',
          ),
          isFalse,
        );
        expect(
          (await SharedPreferences.getInstance()).getString(
            'pace_profile_data',
          ),
          isNotNull,
        );
        final first = workout('phone:first', trace: true),
            second = workout('phone:second');
        await a.completeWorkout(
          workout: first,
          initialXp: 0,
          selectedSport: 0,
          initialWorkouts: [],
        );
        await b.completeWorkout(
          workout: second,
          initialXp: 0,
          selectedSport: 0,
          initialWorkouts: [],
        );
        client.throttleNext = true;
        await a.synchronize();
        expect(client.throttleNext, isFalse);
        await b.synchronize();
        await a.synchronize();
        final expected1 = ProgressV2.append(ProgressV2.empty(), first),
            expected2 = ProgressV2.append(expected1.state, second);
        expect((await a.loadProgress())!['xp'], expected2.state['xp']);
        expect((await b.loadProgress())!['xp'], expected2.state['xp']);
        expect(await dbA.pending(accounts.progressOwner!), isEmpty);
        expect(await dbB.pending(accounts.progressOwner!), isEmpty);
        expect(await b.loadHistory(), hasLength(2));
        final summary = (await b.loadHistory()).firstWhere(
          (w) => w.sessionId == first.sessionId,
        );
        expect(summary.route, isEmpty);
        expect(
          (await (await dbB.database).query(
            'workout_telemetry',
            where: 'owner=? AND session_id=?',
            whereArgs: [accounts.progressOwner, first.sessionId],
          )).length,
          0,
        );
        final detail = await b.loadWorkout(first.sessionId!);
        expect(detail!.route, hasLength(1200));
        expect(detail.heartRateSamples, hasLength(1));
        final third = workout('phone:lost');
        await a.completeWorkout(
          workout: third,
          initialXp: 0,
          selectedSport: 0,
          initialWorkouts: [],
        );
        client.loseNext = true;
        await expectLater(a.synchronize(), throwsA(isA<AccountError>()));
        expect(await dbA.pending(accounts.progressOwner!), ['phone:lost']);
        await a.synchronize();
        expect(await dbA.pending(accounts.progressOwner!), isEmpty);
        expect(await a.loadHistory(), hasLength(3));
        final expected3 = ProgressV2.append(expected2.state, third);
        expect((await a.loadProgress())!['xp'], expected3.state['xp']);
        final old = await accounts
            .requestProgress(owner: accounts.progressOwner!)
            .then<Object>((v) => v, onError: (Object e) => e);
        expect(old, isA<AccountError>());
        // An ID collision must keep the other device's pending data for diagnosis.
        await b.completeWorkout(
          workout: workout('phone:collision', trace: true),
          initialXp: 0,
          selectedSport: 0,
          initialWorkouts: [],
        );
        await a.completeWorkout(
          workout: workout('phone:collision'),
          initialXp: 0,
          selectedSport: 0,
          initialWorkouts: [],
        );
        await a.synchronize();
        await expectLater(b.synchronize(), throwsA(isA<AccountError>()));
        expect(await dbB.pending(accounts.progressOwner!), ['phone:collision']);
        expect(
          (await dbB.workout(
            accounts.progressOwner!,
            'phone:collision',
          ))!.route.length,
          1200,
        );
      } finally {
        await dbA.close();
        await dbB.close();
        accounts?.dispose();
        client.close();
        if (server != null) {
          server.kill();
          await server.exitCode.timeout(const Duration(seconds: 10));
        }
        await temp.delete(recursive: true);
      }
    }, _Sockets()),
    skip: executable == null ? 'Set PACE_POCKETBASE_EXE' : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _Sockets extends HttpOverrides {}
