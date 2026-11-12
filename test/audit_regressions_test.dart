import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/data/storage/profile_storage_service.dart';
import 'package:sport_platform/features/community/community_page.dart';
import 'package:sport_platform/services/garmin_import_service.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';

import 'community_test.dart' show accounts, response, feed, club;
import 'support/account_fakes.dart';

class FailedClaimPreferences extends Fake implements SharedPreferences {
  FailedClaimPreferences(this.delegate);
  final SharedPreferences delegate;
  String? cachedOwner;
  int writes = 0, reloads = 0;
  @override
  String? getString(String key) =>
      key == 'pace_profile_legacy_owner' && cachedOwner != null
      ? cachedOwner
      : delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) async {
    writes++;
    cachedOwner = value;
    return false;
  }

  @override
  Future<void> reload() async {
    reloads++;
    cachedOwner = null;
    await delegate.reload();
  }
}

void main() {
  for (final nameFirst in [true, false]) {
    test(
      'concurrent name/profile responses preserve both fields, nameFirst=$nameFirst',
      () async {
        final nameResponse = Completer<dynamic>(),
            profileResponse = Completer<dynamic>();
        final service = await accounts(
          MockClient((r) async {
            if (r.method != 'PATCH') {
              return response(jsonDecode(accountResponse()));
            }
            if ((jsonDecode(r.body) as Map).containsKey('name')) {
              return await nameResponse.future;
            }
            return await profileResponse.future;
          }),
        );
        final profile = {'specializationId': 'skier', 'bio': 'Новое описание'};
        final nameTask = service.updateName('Новое имя');
        final profileTask = service.updateProfile(profile);
        if (nameFirst) {
          nameResponse.complete(
            response({'id': 'test-user', 'name': 'Новое имя'}),
          );
          await nameTask;
          profileResponse.complete(
            response({'id': 'test-user', 'profile': profile}),
          );
          await profileTask;
        } else {
          profileResponse.complete(
            response({'id': 'test-user', 'profile': profile}),
          );
          await profileTask;
          nameResponse.complete(
            response({'id': 'test-user', 'name': 'Новое имя'}),
          );
          await nameTask;
        }
        expect(service.account!.name, 'Новое имя');
        expect(service.account!.profile, profile);
        service.dispose();
      },
    );
  }
  test(
    'failed profile ownership claim never uploads legacy data, including retry',
    () async {
      SharedPreferences.setMockInitialValues({
        'pace_profile_data': jsonEncode({
          'specializationId': 'runner',
          'city': 'Legacy',
        }),
      });
      var patches = 0;
      final service = await accounts(
        MockClient((r) async {
          if (r.method == 'PATCH') {
            patches++;
            return response({
              'id': 'test-user',
              'profile': jsonDecode(r.body)['profile'],
            });
          }
          return response(jsonDecode(accountResponse()));
        }),
      );
      final prefs = FailedClaimPreferences(
        await SharedPreferences.getInstance(),
      );
      final storage = ProfileStorageService(
        accounts: service,
        preferences: () async => prefs,
      );
      await expectLater(storage.load(), throwsStateError);
      await expectLater(storage.load(), throwsStateError);
      expect(patches, 0);
      expect(prefs.writes, 2);
      expect(prefs.reloads, 2);
      expect(prefs.cachedOwner, isNull);
      service.dispose();
    },
  );
  testWidgets(
    'typing search invalidates an older response before debounce and blocks pagination',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final stale = Completer<dynamic>();
      final pages = <Map>[];
      var reads = 0;
      final service = await accounts(
        MockClient((r) async {
          if (r.url.path.contains('auth-with-password')) {
            return response(jsonDecode(accountResponse()));
          }
          if (r.method == 'GET') {
            reads++;
            if (reads == 2) return await stale.future;
            return response({...feed(9000), 'hasMore': true});
          }
          final body = jsonDecode(r.body) as Map;
          pages.add(body);
          return response({
            ...feed(9000),
            'clubs': [
              {...club(), 'name': 'Новый клуб'},
            ],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityPage(accounts: service)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Обновить'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('search-club')),
        'Новый',
      );
      await tester.pump();
      stale.complete(response({...feed(9000), 'hasMore': true}));
      await tester.pump();
      await tester.pump();
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Загрузить ещё'),
      );
      expect(button.onPressed, isNull);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(pages, hasLength(1));
      expect(pages.single['page'], 0);
      expect(pages.single['search'], 'Новый');
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  test('refresh polls only small status; downloads workout inbox once after completion', () async {
    SharedPreferences.setMockInitialValues({});
    var statusCalls = 0, inboxCalls = 0, waits = 0;
    final service = await accounts(
      MockClient((r) async {
        if (r.url.path.contains('auth-with-password')) {
          return response(jsonDecode(accountResponse()));
        }
        if (r.method == 'POST') return response({'phase': 'running'}, 202);
        if (r.url.path.endsWith('/status')) {
          statusCalls++;
          return response({
            'available': true,
            'refresh': {'phase': statusCalls < 4 ? 'running' : 'ready'},
          });
        }
        inboxCalls++;
        return response({
          'available': true,
          'sinceUtc': DateTime.now().toUtc().toIso8601String(),
          'activities': [],
        });
      }),
    );
    final result = await GarminImportService.importNew(
      accounts: service,
      storage: LocalStorageService(owner: service.progressOwner),
      profile: {},
      refresh: true,
      wait: (_) async {
        waits++;
      },
    );
    expect(result.imported, 0);
    expect(statusCalls, 4);
    expect(waits, 2);
    expect(inboxCalls, 1);
    service.dispose();
  });
}
