import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/features/onboarding/startup_flow.dart';
import 'package:sport_platform/features/onboarding/welcome_stories.dart';
import 'package:sport_platform/features/auth/sign_in_page.dart';
import 'package:sport_platform/features/profile/specialization_page.dart';
import 'package:sport_platform/services/account_service.dart';

import 'support/account_fakes.dart';

const completeKey = 'pace_welcome_completed_v1';
Widget startup(AccountService accounts) => MaterialApp(
  home: StartupFlow(
    accounts: accounts,
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            const Text('Главный экран'),
            TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      const Scaffold(body: Text('Закрытая страница')),
                ),
              ),
              child: const Text('Открыть страницу'),
            ),
          ],
        ),
      ),
    ),
  ),
);
AccountService service(MemorySessionVault vault, {MockClient? client}) =>
    AccountService(
      vault: vault,
      client:
          client ??
          MockClient(
            (_) async => http.Response(
              accountResponse(),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
    );

Future<void> login(WidgetTester tester, {bool register = false}) async {
  await tester.ensureVisible(find.text(register ? 'Регистрация' : 'Войти'));
  await tester.tap(find.text(register ? 'Регистрация' : 'Войти'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('auth-email')),
    'athlete@example.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('auth-password')),
    'long-password-123',
  );
  if (register) {
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm')),
      'long-password-123',
    );
  }
  await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
  await tester.tap(find.byKey(const ValueKey('auth-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'First launch shows four stories; skipping leads to required login',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final accounts = service(MemorySessionVault());
      addTearDown(accounts.dispose);
      await tester.pumpWidget(startup(accounts));
      await tester.pumpAndSettle();
      expect(find.text('Твои тренировки. Твой прогресс.'), findsOneWidget);
      expect(find.text('Главный экран'), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('welcome-stories')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 4'), findsOneWidget);
      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();
      expect(find.text('4 / 4'), findsOneWidget);
      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool(completeKey),
        isTrue,
      );
      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.text('Продолжить без входа'), findsNothing);
      expect(find.text('Главный экран'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
      await login(tester);
      expect(find.text('Главный экран'), findsOneWidget);
      expect(find.text('Ты в PACE'), findsNothing);
      await tester.tap(find.text('Открыть страницу'));
      await tester.pumpAndSettle();
      expect(find.text('Закрытая страница'), findsOneWidget);
      await accounts.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Закрытая страница'), findsNothing);
      expect(find.text('Главный экран'), findsNothing);
      expect(find.byType(SignInPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Главный экран'), findsNothing);
    },
  );

  testWidgets('Skip is remembered on a fresh launch without a session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = service(MemorySessionVault());
    addTearDown(accounts.dispose);
    await tester.pumpWidget(startup(accounts));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final next = service(MemorySessionVault());
    addTearDown(next.dispose);
    await tester.pumpWidget(startup(next));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeStories), findsNothing);
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Главный экран'), findsNothing);
  });

  testWidgets('Saved valid session restores straight to the home screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({completeKey: true});
    final vault = MemorySessionVault();
    final first = service(vault);
    await first.signIn(
      email: 'athlete@example.com',
      password: 'long-password-123',
    );
    first.dispose();
    final restored = service(vault);
    addTearDown(restored.dispose);
    await tester.pumpWidget(startup(restored));
    await tester.pumpAndSettle();
    expect(find.text('Главный экран'), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
  });

  testWidgets('Rejected stored session never exposes the main screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({completeKey: true});
    final vault = MemorySessionVault()
      ..value = jsonEncode({
        'server': 'http://127.0.0.1:8090',
        'token': 'old-token',
      });
    final accounts = service(
      vault,
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    addTearDown(accounts.dispose);
    await tester.pumpWidget(startup(accounts));
    await tester.pumpAndSettle();
    expect(vault.value, isNull);
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Главный экран'), findsNothing);
  });

  testWidgets('Registration completes character step before entering the app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({completeKey: true});
    final accounts = service(MemorySessionVault());
    addTearDown(accounts.dispose);
    await tester.pumpWidget(startup(accounts));
    await tester.pumpAndSettle();
    await login(tester, register: true);
    expect(find.byType(SpecializationPage), findsOneWidget);
    expect(find.text('Главный экран'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Главный экран'), findsOneWidget);
  });

  testWidgets('Welcome fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: WelcomeStories(onComplete: () async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
