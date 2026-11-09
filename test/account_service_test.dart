import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_platform/services/account_service.dart';

import 'support/account_fakes.dart';

void main() {
  final url = Uri.parse('http://127.0.0.1:8090');
  test('Registration creates an ordinary account then stores only a server-bound token', () async {
    final requests = <http.Request>[];
    final vault = MemorySessionVault();
    final service = AccountService(
      baseUrl: url,
      vault: vault,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.url.path.endsWith('/records')
              ? '{"id":"test-user"}'
              : accountResponse(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    await service.register(
      email: ' athlete@example.com ',
      password: 'long-password-123',
      passwordConfirm: 'long-password-123',
      name: ' Атлет ',
    );
    expect(requests.map((r) => r.url.path), [
      '/api/collections/pace_users/records',
      '/api/collections/pace_users/auth-with-password',
    ]);
    expect(jsonDecode(requests.first.body), {
      'email': 'athlete@example.com',
      'password': 'long-password-123',
      'passwordConfirm': 'long-password-123',
      'name': 'Атлет',
    });
    expect(requests.first.headers.containsKey('authorization'), isFalse);
    expect(jsonDecode(vault.value!), {
      'server': url.toString(),
      'token': 'test-session',
    });
    expect(service.account?.email, 'athlete@example.com');
  });

  test('Creation followed by failed login reports partial success without duplicating registration', () async {
    var creates = 0;
    var rejectLogin = true;
    final service = AccountService(
      baseUrl: url,
      vault: MemorySessionVault(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/records')) {
          creates++;
          return http.Response('{"id":"test-user"}', 200);
        }
        return rejectLogin
            ? http.Response('{}', 503)
            : http.Response(
                accountResponse(),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      }),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.register(
        email: 'athlete@example.com',
        password: 'long-password-123',
        passwordConfirm: 'long-password-123',
        name: '',
      ),
      throwsA(
        isA<AccountError>().having((e) => e.accountCreated, 'created', true),
      ),
    );
    expect(service.account, isNull);
    rejectLogin = false;
    await service.signIn(
      email: 'athlete@example.com',
      password: 'long-password-123',
    );
    expect(creates, 1);
    expect(service.account, isNotNull);
  });

  test(
    'A secure storage failure must not report a successful sign-in',
    () async {
      final vault = MemorySessionVault()..failWrite = true;
      final service = AccountService(
        baseUrl: url,
        vault: vault,
        client: MockClient(
          (_) async => http.Response(
            accountResponse(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.signIn(
          email: 'athlete@example.com',
          password: 'long-password-123',
        ),
        throwsA(isA<AccountError>()),
      );
      expect(service.account, isNull);
      expect(vault.value, isNull);
    },
  );

  test('A rejected restored session is removed', () async {
    final vault = MemorySessionVault()
      ..value = jsonEncode({'server': url.toString(), 'token': 'expired'});
    final service = AccountService(
      baseUrl: url,
      vault: vault,
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'expired');
        return http.Response('{}', 401);
      }),
    );
    addTearDown(service.dispose);
    await service.initialize();
    expect(service.account, isNull);
    expect(vault.value, isNull);
    expect(service.initialized, isTrue);
  });

  test(
    'Network failure retains the stored session and retry can restore it',
    () async {
      final vault = MemorySessionVault()
        ..value = jsonEncode({'server': url.toString(), 'token': 'saved'});
      var offline = true;
      final service = AccountService(
        baseUrl: url,
        vault: vault,
        client: MockClient((_) async {
          if (offline) throw http.ClientException('offline');
          return http.Response(
            accountResponse(token: 'refreshed'),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      await expectLater(service.initialize(), throwsA(isA<AccountError>()));
      expect(service.initialized, isFalse);
      expect(jsonDecode(vault.value!)['token'], 'saved');
      offline = false;
      await service.initialize();
      expect(service.account, isNotNull);
      expect(jsonDecode(vault.value!)['token'], 'refreshed');
    },
  );

  test('Changing server does not forward an existing token', () async {
    final vault = MemorySessionVault()
      ..value = jsonEncode({
        'server': 'https://old.example.com',
        'token': 'private',
      });
    final service = AccountService(
      baseUrl: url,
      vault: vault,
      client: MockClient(
        (_) async => throw StateError('Must not send a request'),
      ),
    );
    addTearDown(service.dispose);
    await service.initialize();
    expect(vault.value, isNull);
  });

  test('Failed logout preserves visible account until its token is actually removed', () async {
    final vault = MemorySessionVault();
    final service = AccountService(
      baseUrl: url,
      vault: vault,
      client: MockClient(
        (_) async => http.Response(
          accountResponse(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(service.dispose);
    await service.signIn(
      email: 'athlete@example.com',
      password: 'long-password-123',
    );
    vault.failClear = true;
    await expectLater(service.signOut(), throwsA(isA<AccountError>()));
    expect(service.account, isNotNull);
    vault.failClear = false;
    await service.signOut();
    expect(service.account, isNull);
    expect(vault.value, isNull);
  });

  test('Nonlocal HTTP cannot receive credentials', () async {
    final service = AccountService(
      baseUrl: Uri.parse('http://example.com'),
      vault: MemorySessionVault(),
      client: MockClient(
        (_) async => throw StateError('Must not send credentials'),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.signIn(
        email: 'athlete@example.com',
        password: 'long-password-123',
      ),
      throwsA(isA<AccountError>()),
    );
  });
}
