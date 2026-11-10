import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/main.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/features/onboarding/startup_flow.dart';
import 'package:sport_platform/services/account_service.dart';
import 'package:sport_platform/services/progress_sync.dart';

import 'support/account_fakes.dart';
import 'progress_sync_test.dart' show MemoryRemote, run, pending;

class OwnerProbe extends StatefulWidget {
  const OwnerProbe({super.key, required this.accounts});
  final AccountService accounts;
  @override
  State<OwnerProbe> createState() => _OwnerProbeState();
}

class _OwnerProbeState extends State<OwnerProbe> {
  late final owner = widget.accounts.account!.id;
  @override
  Widget build(BuildContext context) => Scaffold(body: Text('Owner:$owner'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Offline status and retry download account progress on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final accounts = AccountService(vault: MemorySessionVault())
        ..initialized = true
        ..account = const PaceAccount(
          id: 'alice',
          email: 'alice@example.com',
          name: 'Атлет',
          profile: {},
        );
      addTearDown(accounts.dispose);
      final remote = MemoryRemote()..offline = true;
      final storage = LocalStorageService(
        owner: accounts.progressOwner,
        remote: remote,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: PaceHome(accounts: accounts, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNavigation),
          matching: find.text('Прогресс'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('На устройстве.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      remote
        ..offline = false
        ..data = ProgressMerger.merge(null, pending([run('cloud')]))
        ..revision = 1;
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(find.text('Прогресс сохранён в аккаунте'), findsOneWidget);
      expect((await storage.loadProgress())!['xp'], 610);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Switching account rebuilds protected app state even without an intermediate logout',
    (tester) async {
      final accounts = AccountService(
        vault: MemorySessionVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          final id = (body['identity'] as String).startsWith('alice')
              ? 'alice'
              : 'bob';
          final response = jsonDecode(accountResponse()) as Map;
          (response['record'] as Map)['id'] = id;
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(accounts.dispose);
      await accounts.signIn(
        email: 'alice@example.com',
        password: 'long-password',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StartupFlow(
            accounts: accounts,
            home: OwnerProbe(accounts: accounts),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Owner:alice'), findsOneWidget);
      await accounts.signIn(
        email: 'bob@example.com',
        password: 'long-password',
      );
      await tester.pumpAndSettle();
      expect(find.text('Owner:bob'), findsOneWidget);
      expect(find.text('Owner:alice'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'Response from an old account cannot be accepted after logout',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final accounts = AccountService(
        vault: MemorySessionVault(),
        client: MockClient((request) async {
          if (request.url.path == '/api/pace/progress') {
            entered.complete();
            await release.future;
            return http.Response(
              jsonEncode({'revision': 0, 'data': null}),
              200,
            );
          }
          return http.Response(
            accountResponse(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(accounts.dispose);
      await accounts.signIn(
        email: 'alice@example.com',
        password: 'long-password',
      );
      final request = accounts.requestProgress(owner: accounts.progressOwner!);
      final rejected = expectLater(request, throwsA(isA<AccountError>()));
      await entered.future;
      await accounts.signOut();
      release.complete();
      await rejected;
      expect(accounts.account, isNull);
    },
  );
}
