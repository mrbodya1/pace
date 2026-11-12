import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/services/progress_sync.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sport_platform/services/account_service.dart';
import 'package:sport_platform/data/storage/profile_storage_service.dart';
import 'package:sport_platform/models/specialization.dart';
import 'package:sport_platform/models/participant_sex.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/account_fakes.dart';
import 'support/pocketbase_bootstrap.dart';

void main() {
  final executable = Platform.environment['PACE_POCKETBASE_EXE'];
  test(
    'Registration client works with a real isolated PocketBase database',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final temporary = await Directory.systemTemp.createTemp(
        'pace-account-api-',
      );
      Process? server;
      final client = http.Client();
      final vault = MemorySessionVault();
      AccountService? service;
      AccountService? restored;
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        final url = Uri.parse('http://127.0.0.1:$port');
        await preparePocketBaseTest(executable!, temporary);
        server = await Process.start(
          executable,
          [
            'serve',
            '--http=127.0.0.1:$port',
            '--dir=${temporary.path}${Platform.pathSeparator}data',
            '--migrationsDir=${Directory.current.path}${Platform.pathSeparator}server${Platform.pathSeparator}pb_migrations',
            '--hooksDir=${Directory.current.path}${Platform.pathSeparator}server${Platform.pathSeparator}pb_hooks',
          ],
          workingDirectory: temporary.path,
          environment: {'PACE_ENABLE_LEGACY_API': '1'},
        );
        // Consume logs without printing bootstrap URLs or authentication material.
        unawaited(server.stdout.drain<void>());
        unawaited(server.stderr.drain<void>());
        var ready = false;
        for (var attempt = 0; attempt < 80; attempt++) {
          try {
            final health = await client
                .get(url.resolve('/api/health'))
                .timeout(const Duration(seconds: 1));
            if (health.statusCode == 200) {
              ready = true;
              break;
            }
          } catch (_) {
            /* Retry only the read-only health endpoint. */
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          ready,
          isTrue,
          reason: 'Temporary PocketBase must become healthy',
        );
        service = AccountService(baseUrl: url, vault: vault);
        await service.register(
          email: 'athlete@example.com',
          password: 'alpha-password-123',
          passwordConfirm: 'alpha-password-123',
          name: 'Атлет',
        );
        expect(service.account?.email, 'athlete@example.com');
        expect(vault.value, isNotNull);
        restored = AccountService(baseUrl: url, vault: vault);
        await restored.initialize();
        expect(restored.account?.id, service.account?.id);
        await restored.updateName('Новое имя');
        expect(restored.account?.name, 'Новое имя');
        SharedPreferences.setMockInitialValues({});
        final profiles = ProfileStorageService(accounts: restored);
        await profiles.updateFields({
          'bio': 'Люблю лыжи',
          'city': 'Екатеринбург',
        });
        await profiles.selectSpecialization(
          Specialization.skier,
          participantSex: ParticipantSex.female,
        );
        await restored.signOut();
        // A new browser origin has no old local profile.
        SharedPreferences.setMockInitialValues({});
        await restored.signIn(
          email: 'athlete@example.com',
          password: 'alpha-password-123',
        );
        expect(restored.account?.name, 'Новое имя');
        final recovered = await profiles.load();
        expect(recovered['bio'], 'Люблю лыжи');
        expect(recovered['city'], 'Екатеринбург');
        expect(recovered['specializationId'], 'skier');
        expect(recovered['sex'], 'female');
        final progress = LocalStorageService(
          owner: restored.progressOwner,
          remote: AccountProgressRemote(restored),
        );
        await progress.completeWorkout(
          workout: Workout(
            date: DateTime.utc(2026, 11, 10),
            distance: 5,
            duration: const Duration(minutes: 30),
            xp: 360,
            sport: 'Бег',
            sessionId: 'server-workout-one',
          ),
          initialXp: 0,
          selectedSport: 0,
          initialWorkouts: [],
        );
        await progress.synchronize();
        expect((await progress.loadProgress())!['xp'], 610);
        final serverSnapshot = await restored.requestProgress(
          owner: restored.progressOwner!,
        );
        expect(serverSnapshot['revision'], 1);
        await expectLater(
          restored.requestProgress(
            owner: restored.progressOwner!,
            revision: 0,
            data: Map<String, dynamic>.from(serverSnapshot['data'] as Map),
          ),
          throwsA(isA<ProgressConflict>()),
        );
        final broken = Map<String, dynamic>.from(serverSnapshot['data'] as Map)
          ..['workouts'] = [];
        await expectLater(
          restored.requestProgress(
            owner: restored.progressOwner!,
            revision: 1,
            data: broken,
          ),
          throwsA(isA<AccountError>()),
        );
        SharedPreferences.setMockInitialValues({});
        final freshProgress = LocalStorageService(
          owner: restored.progressOwner,
          remote: AccountProgressRemote(restored),
        );
        await freshProgress.synchronize();
        expect((await freshProgress.loadProgress())!['xp'], 610);
        expect(
          ProgressMerger.workouts((await freshProgress.loadProgress())!)
              .single
              .sessionId,
          'server-workout-one',
        );
        Workout offlineWorkout(String id) => Workout(
          date: DateTime.utc(2026, 11, 10),
          distance: 5,
          duration: const Duration(minutes: 30),
          xp: 360,
          sport: 'Бег',
          sessionId: id,
        );
        final base = Map<String, dynamic>.from(serverSnapshot['data'] as Map);
        Future<bool> compete(String id) async {
          final candidate = ProgressMerger.merge(base, {
            '_sync': {
              'pending': [offlineWorkout(id).toJson()],
            },
          });
          try {
            await restored!.requestProgress(
              owner: restored.progressOwner!,
              revision: 1,
              data: candidate,
            );
            return true;
          } on ProgressConflict {
            return false;
          }
        }

        final racers = await Future.wait([
          compete('device-a'),
          compete('device-b'),
        ]);
        expect(racers.where((v) => v).length, 1);
        final loser = racers[0] ? 'device-b' : 'device-a';
        await freshProgress.completeWorkout(
          workout: offlineWorkout(loser),
          initialXp: 0,
          selectedSport: 0,
          initialWorkouts: [],
        );
        await freshProgress.synchronize();
        expect((await freshProgress.loadProgress())!['xp'], 1330);
        expect(
          ProgressMerger.workouts((await freshProgress.loadProgress())!).length,
          3,
        );
        final anonymousProgress = await client.get(
          url.resolve('/api/pace/progress'),
        );
        expect(anonymousProgress.statusCode, 401);
        // Respect the default 2 auth requests / 3 seconds; keep production limits enabled.
        await Future<void>.delayed(const Duration(seconds: 4));
        final otherVault = MemorySessionVault();
        final other = AccountService(baseUrl: url, vault: otherVault);
        try {
          await other.register(
            email: 'other@example.com',
            password: 'other-password-123',
            passwordConfirm: 'other-password-123',
            name: 'Другой',
          );
          final otherProgress = await other.requestProgress(
            owner: other.progressOwner!,
          );
          expect(otherProgress['revision'], 0);
          expect(otherProgress['data'], isNull);
          final otherProfile = await ProfileStorageService(accounts: other)
              .load();
          expect(otherProfile['bio'], isNull);
          expect(otherProfile['specializationId'], isNull);
          final token =
              (jsonDecode(otherVault.value!) as Map)['token'] as String;
          final forbidden = await client.patch(
            url.resolve(
              '/api/collections/pace_users/records/${restored.account!.id}',
            ),
            headers: {
              'Authorization': token,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'profile': {'bio': 'Чужое'},
            }),
          );
          expect(forbidden.statusCode, 404);
        } finally {
          other.dispose();
        }
        await expectLater(
          restored.signIn(
            email: 'athlete@example.com',
            password: 'wrong-password',
          ),
          throwsA(isA<AccountError>()),
        );
        await expectLater(
          service.register(
            email: 'athlete@example.com',
            password: 'alpha-password-123',
            passwordConfirm: 'alpha-password-123',
            name: '',
          ),
          throwsA(isA<AccountError>()),
        );
        // The ordinary registration cannot expose account listings anonymously.
        final listing = await client.get(
          url.resolve('/api/collections/pace_users/records'),
        );
        expect((jsonDecode(listing.body) as Map)['items'], isEmpty);
        await restored.signOut();
        expect(vault.value, isNull);
        expect(restored.account, isNull);
      } finally {
        restored?.dispose();
        service?.dispose();
        client.close();
        if (server != null) {
          server.kill();
          await server.exitCode.timeout(const Duration(seconds: 10));
        }
        // Only this invocation's freshly created temporary database is disposable.
        await temporary.delete(recursive: true);
      }
    }, _RealHttpOverrides()),
    skip: executable == null
        ? 'Set PACE_POCKETBASE_EXE to run the real API check'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

// This opt-in integration test needs sockets rather than the widget harness's
// fake HTTP client, which intentionally returns 400 for every request.
class _RealHttpOverrides extends HttpOverrides {}
