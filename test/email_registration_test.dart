import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/features/auth/email_auth_page.dart';
import 'package:sport_platform/features/auth/sign_in_page.dart';
import 'package:sport_platform/features/profile/specialization_page.dart';
import 'package:sport_platform/services/account_service.dart';

import 'support/account_fakes.dart';

void main() {
  testWidgets(
    'Invalid email and mismatched passwords do not create an account',
    (tester) async {
      var requests = 0;
      final service = AccountService(
        vault: MemorySessionVault(),
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(home: EmailAuthPage(accounts: service)),
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'bad-email',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'short',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm')),
        'different',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Укажи корректный email'), findsOneWidget);
      expect(find.text('Пароли не совпадают'), findsOneWidget);
      expect(requests, 0);
    },
  );

  testWidgets(
    'Registration blocks double submission and opens character selection without altering XP',
    (tester) async {
      final progress = jsonEncode({
        'xp': 7300,
        'selectedSport': 2,
        'workouts': [],
      });
      SharedPreferences.setMockInitialValues({'pace_local_data': progress});
      final pending = Completer<http.Response>();
      var creates = 0;
      final service = AccountService(
        vault: MemorySessionVault(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/records')) {
            creates++;
            return pending.future;
          }
          return http.Response(
            accountResponse(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(MaterialApp(home: SignInPage(accounts: service)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Регистрация'));
      await tester.tap(find.text('Регистрация'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'athlete@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'long-password-123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm')),
        'long-password-123',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pump();
      expect(creates, 1);
      pending.complete(http.Response('{"id":"test-user"}', 200));
      await tester.pumpAndSettle();
      expect(find.byType(SpecializationPage), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pace_local_data'), progress);
      expect(prefs.getKeys().any((key) => key.contains('session')), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
