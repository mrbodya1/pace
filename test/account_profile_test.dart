import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/data/storage/profile_storage_service.dart';
import 'package:sport_platform/features/profile/profile_page.dart';
import 'package:sport_platform/models/participant_sex.dart';
import 'package:sport_platform/models/specialization.dart';
import 'package:sport_platform/models/sport_catalog.dart';
import 'package:sport_platform/services/account_service.dart';

import 'support/account_fakes.dart';

Widget profileHost(AccountService accounts) => MaterialApp(
  home: Scaffold(
    body: ProfilePage(
      accounts: accounts,
      sports: SportCatalog.names,
      sportIcons: SportCatalog.icons,
      selectedSport: 2,
      tracking: false,
      onSelectSport: (_) {},
      xp: 7300,
    ),
  ),
);

void main() {
  testWidgets('Profile login returns directly and logout is at the bottom', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = AccountService(
      vault: MemorySessionVault(),
      client: MockClient(
        (_) async => http.Response(
          accountResponse(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(accounts.dispose);
    await tester.pumpWidget(profileHost(accounts));
    await tester.pumpAndSettle();
    expect(find.text('Гость'), findsOneWidget);
    expect(find.text('BODYA'), findsNothing);
    expect(find.text('Универсальный атлет'), findsNothing);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Аккаунт PACE'), findsNothing);
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-name')), findsNothing);
    expect(find.byKey(const ValueKey('auth-confirm')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'athlete@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'long-password-123',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Атлет'), findsOneWidget);
    expect(find.text('Ты в PACE'), findsNothing);
    expect(find.text('Регистрация'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Выйти'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(accounts.account, isNull);
    await tester.scrollUntilVisible(
      find.text('Регистрация'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets(
    'Account name and saved character survive logout, login and session restoration',
    (tester) async {
      final progress = jsonEncode({
        'xp': 7300,
        'selectedSport': 2,
        'workouts': [],
      });
      SharedPreferences.setMockInitialValues({
        'pace_local_data': progress,
        'pace_profile_data': jsonEncode({
          'name': 'Старое имя',
          'specializationId': 'cyclist',
          'sex': 'female',
          'city': 'Екатеринбург',
          'specializationChangedAt': '2026-11-01T00:00:00.000Z',
        }),
      });
      final vault = MemorySessionVault();
      Map<String, dynamic>? serverProfile;
      AccountService createService() => AccountService(
        vault: vault,
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            serverProfile = Map<String, dynamic>.from(
              (jsonDecode(request.body) as Map)['profile'] as Map,
            );
            return http.Response(
              jsonEncode({'id': 'test-user', 'profile': serverProfile}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          final body = jsonDecode(accountResponse()) as Map;
          (body['record'] as Map)['profile'] = serverProfile;
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final accounts = createService();
      addTearDown(accounts.dispose);
      await accounts.signIn(
        email: 'athlete@example.com',
        password: 'long-password-123',
      );
      await tester.pumpWidget(profileHost(accounts));
      await tester.pumpAndSettle();
      expect(find.text('Атлет'), findsOneWidget);
      expect(find.text('Старое имя'), findsNothing);
      final image =
          tester.widget<Image>(find.byType(Image).first).image as AssetImage;
      expect(image.assetName, contains('female/cyclist.png'));
      await accounts.signOut();
      await tester.pumpAndSettle();
      await accounts.signIn(
        email: 'athlete@example.com',
        password: 'long-password-123',
      );
      await tester.pumpAndSettle();
      expect(find.text('Атлет'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        (await SharedPreferences.getInstance()).getString('pace_local_data'),
        progress,
      );
      SharedPreferences.setMockInitialValues({});
      final restored = createService();
      addTearDown(restored.dispose);
      await tester.pumpWidget(profileHost(restored));
      await tester.pumpAndSettle();
      expect(restored.account?.email, 'athlete@example.com');
      expect(find.text('Атлет'), findsOneWidget);
      final restoredImage =
          tester.widget<Image>(find.byType(Image).first).image as AssetImage;
      expect(restoredImage.assetName, contains('female/cyclist.png'));
      final profile = await ProfileStorageService(accounts: restored).load();
      expect(profile['specializationId'], 'cyclist');
      expect(profile['sex'], 'female');
      expect(profile['specializationChangedAt'], '2026-11-01T00:00:00.000Z');
      expect(profile['city'], 'Екатеринбург');
      expect(
        (await SharedPreferences.getInstance()).getString('pace_local_data'),
        isNull,
      );
    },
  );

  testWidgets(
    'Editing an account name updates the server and merges with a newer character choice',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'pace_profile_data': jsonEncode({
          'name': 'Старое имя',
          'specializationId': 'cyclist',
          'sex': 'female',
        }),
      });
      var serverName = 'Атлет';
      var patches = 0;
      Map<String, dynamic>? serverProfile;
      final accounts = AccountService(
        vault: MemorySessionVault(),
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            final payload = jsonDecode(request.body) as Map;
            if (payload.containsKey('profile')) {
              serverProfile = Map<String, dynamic>.from(
                payload['profile'] as Map,
              );
              return http.Response(
                jsonEncode({'id': 'test-user', 'profile': serverProfile}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            patches++;
            expect(
              request.url.path,
              '/api/collections/pace_users/records/test-user',
            );
            expect(request.headers['authorization'], 'test-session');
            expect(jsonDecode(request.body), {'name': 'Новое имя'});
            serverName = (jsonDecode(request.body) as Map)['name'] as String;
            return http.Response(
              jsonEncode({'id': 'test-user', 'name': serverName}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          final body = jsonDecode(accountResponse()) as Map<String, dynamic>;
          (body['record'] as Map)['name'] = serverName;
          (body['record'] as Map)['profile'] = serverProfile;
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(accounts.dispose);
      await accounts.signIn(
        email: 'athlete@example.com',
        password: 'long-password-123',
      );
      await tester.pumpWidget(profileHost(accounts));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать профиль'));
      await tester.pumpAndSettle();
      // Another operation saved a choice after the editor took its snapshot.
      await ProfileStorageService(accounts: accounts).selectSpecialization(
        Specialization.skier,
        participantSex: ParticipantSex.female,
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Новое имя');
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(patches, 1);
      expect(find.text('Новое имя'), findsOneWidget);
      expect(
        (await ProfileStorageService(accounts: accounts)
            .load())['specializationId'],
        'skier',
      );
      await accounts.signOut();
      await accounts.signIn(
        email: 'athlete@example.com',
        password: 'long-password-123',
      );
      await tester.pumpAndSettle();
      expect(find.text('Новое имя'), findsOneWidget);
      expect(
        (await ProfileStorageService(accounts: accounts)
            .load())['specializationId'],
        'skier',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Rejected profile save leaves confirmed server data unchanged',
    () async {
      SharedPreferences.setMockInitialValues({});
      var reject = true;
      final original = {'bio': 'Моё описание', 'specializationId': 'skier'};
      final accounts = AccountService(
        vault: MemorySessionVault(),
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            if (reject) return http.Response('{}', 500);
            return http.Response(
              jsonEncode({
                'id': 'test-user',
                'profile': (jsonDecode(request.body) as Map)['profile'],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          final body = jsonDecode(accountResponse()) as Map;
          (body['record'] as Map)['profile'] = original;
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(accounts.dispose);
      await accounts.signIn(
        email: 'athlete@example.com',
        password: 'long-password-123',
      );
      final storage = ProfileStorageService(accounts: accounts);
      await expectLater(
        storage.updateFields({'bio': 'Изменено'}),
        throwsA(isA<AccountError>()),
      );
      expect((await storage.load())['bio'], 'Моё описание');
      reject = false;
      await storage.updateFields({'bio': 'Изменено'});
      expect((await storage.load())['bio'], 'Изменено');
      expect((await storage.load())['specializationId'], 'skier');
    },
  );

  test('Concurrent name and character updates preserve both fields', () async {
    SharedPreferences.setMockInitialValues({});
    await Future.wait([
      ProfileStorageService().updateFields({
        'name': 'Новое имя',
        'height': 180,
      }),
      ProfileStorageService().selectSpecialization(
        Specialization.runner,
        participantSex: ParticipantSex.female,
      ),
    ]);
    final saved = await ProfileStorageService().load();
    expect(saved['name'], 'Новое имя');
    expect(saved['height'], 180);
    expect(saved['specializationId'], 'runner');
    expect(saved['sex'], 'female');
  });
}
