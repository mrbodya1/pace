import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/features/community/community_page.dart';
import 'package:sport_platform/models/community.dart';
import 'package:sport_platform/services/account_service.dart';
import 'package:sport_platform/widgets/glass_widgets.dart';

import 'support/account_fakes.dart';

Map<String, dynamic> club({bool joined = false}) => {
  'id': 'aaaaaaaaaaaaaaa',
  'name': 'PACE Running',
  'description': 'Бегаем вместе по набережной. Поддерживаем новичков и готовимся к новым стартам.',
  'sport': 'Бег',
  'city': 'Сургут',
  'owner': false,
  'joined': joined,
  'members': 12,
};
Map<String, dynamic> event() => {
  ...club(),
  'id': 'bbbbbbbbbbbbbbb',
  'name': 'Осенний старт',
  'kind': 'competition',
  'audience': 'open',
  'clubId': 'aaaaaaaaaaaaaaa',
  'clubName': 'PACE Running',
  'clubJoined': false,
  'startsAt': '2027-01-01T10:00:00Z',
  'endsAt': '2027-01-01T12:00:00Z',
};
Map<String, dynamic> feed(int xp, {bool owned = false, bool empty = false}) => {
  'xp': xp,
  'page': 0,
  'hasMore': false,
  'clubs': empty ? [] : [club()],
  'events': empty
      ? []
      : [
          event(),
          {
            ...event(),
            'id': 'ccccccccccccccc',
            'name': 'Воскресная пробежка',
            'kind': 'event',
            'audience': 'club',
          },
        ],
  'ownedClubs': owned
      ? [
          {'id': 'aaaaaaaaaaaaaaa', 'name': 'PACE Running'},
        ]
      : [],
};

Future<AccountService> accounts(MockClient client) async {
  final service = AccountService(
    baseUrl: Uri.parse('https://pace.example'),
    vault: MemorySessionVault(),
    client: client,
  );
  await service.signIn(
    email: 'fixture@invalid.example',
    password: 'fixture-password',
  );
  return service;
}

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Widget app(AccountService service, {bool active = true, double scale = 1}) =>
    MaterialApp(
      theme: paceTheme.copyWith(
        textTheme: paceTheme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('community-capture'),
            child: PaceBackground(
              child: CommunityPage(accounts: service, active: active),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_COMMUNITY')) return;
    final dir = Platform.environment['PACE_FONT_DIR']!;
    for (final item in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf'),
    ]) {
      await (FontLoader(item.$1)..addFont(
            File('$dir/${item.$2}')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
    }
  });
  test('club and competition access thresholds and membership checks', () {
    final c = CommunityItem.fromJson(club());
    expect(c.joinRestriction(8999, DateTime(2026)), contains('1 XP'));
    expect(c.joinRestriction(9000, DateTime(2026)), isNull);
    final e = CommunityItem.fromJson(event());
    expect(e.joinRestriction(999, DateTime(2026)), contains('уровня 2'));
    expect(e.joinRestriction(1000, DateTime(2026)), isNull);
    expect(e.joinRestriction(1000, DateTime(2028)), 'Событие завершено');
    final closed = CommunityItem.fromJson({...event(), 'audience': 'club'});
    expect(
      closed.joinRestriction(9000, DateTime(2026)),
      'Сначала вступи в клуб',
    );
  });
  test('server refusal preserves readable reason', () async {
    final service = await accounts(
      MockClient(
        (r) async => r.url.path.contains('auth-with-password')
            ? response(jsonDecode(accountResponse()))
            : response({'message': 'Нужен уровень 10.'}, 403),
      ),
    );
    await expectLater(
      service.requestCommunity(action: {'action': 'createClub'}),
      throwsA(
        isA<AccountError>().having(
          (e) => e.message,
          'message',
          'Нужен уровень 10.',
        ),
      ),
    );
    service.dispose();
  });
  test('account switch discards delayed community response', () async {
    late AccountService service;
    service = await accounts(
      MockClient((r) async {
        if (r.url.path.contains('auth-with-password')) {
          return response(jsonDecode(accountResponse()));
        }
        service.account = null;
        return response(feed(9000));
      }),
    );
    await expectLater(service.requestCommunity(), throwsA(isA<AccountError>()));
    service.dispose();
  });
  testWidgets('inactive community sends no requests; opening loads feed', (
    tester,
  ) async {
    var reads = 0;
    final service = await accounts(
      MockClient((r) async {
        if (r.url.path.contains('auth-with-password')) {
          return response(jsonDecode(accountResponse()));
        }
        reads++;
        return response(feed(9000));
      }),
    );
    await tester.pumpWidget(app(service, active: false));
    await tester.pumpAndSettle();
    expect(reads, 0);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('PACE Running'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets(
    'joining detail uses authenticated action then updates participation',
    (tester) async {
      final actions = <String>[];
      final service = await accounts(
        MockClient((r) async {
          if (r.url.path.contains('auth-with-password')) {
            return response(jsonDecode(accountResponse()));
          }
          expect(r.headers['Authorization'], 'test-session');
          if (r.method == 'POST') {
            final body = jsonDecode(r.body) as Map;
            actions.add(body['action'] as String);
            return response({...club(joined: true), 'members': 13});
          }
          return response(feed(9000));
        }),
      );
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PACE Running'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Вступить в клуб'));
      await tester.tap(find.text('Вступить в клуб'));
      await tester.pumpAndSettle();
      expect(actions, ['join']);
      expect(find.text('Покинуть клуб'), findsOneWidget);
      expect(find.text('13 участников'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets('new club form validates and saves to server', (tester) async {
    Map? saved;
    final service = await accounts(
      MockClient((r) async {
        if (r.url.path.contains('auth-with-password')) {
          return response(jsonDecode(accountResponse()));
        }
        if (r.method == 'POST') {
          saved = jsonDecode(r.body) as Map;
          return response({...club(), 'owner': true, 'joined': true});
        }
        return response(feed(65000));
      }),
    );
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать клуб'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Создать клуб'));
    await tester.tap(find.text('Создать клуб'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Введи название'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Новый клуб');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Совместные тренировки',
    );
    await tester.ensureVisible(find.text('Создать клуб'));
    await tester.tap(find.text('Создать клуб'));
    await tester.pumpAndSettle();
    expect(saved?['action'], 'createClub');
    expect(saved?['name'], 'Новый клуб');
    expect(find.text('Ты — владелец клуба'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets(
    'owner publishes competition with UTC dates from date/time pickers',
    (tester) async {
      Map? saved;
      final service = await accounts(
        MockClient((r) async {
          if (r.url.path.contains('auth-with-password')) {
            return response(jsonDecode(accountResponse()));
          }
          if (r.method == 'POST') {
            saved = jsonDecode(r.body) as Map;
            return response(event());
          }
          return response(feed(65000, owned: true));
        }),
      );
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Соревнования'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Создать соревнование'));
      await tester.tap(find.text('Создать соревнование'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Новый старт');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Встреча у стадиона',
      );
      for (final label in ['Выбрать начало', 'Выбрать окончание']) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Опубликовать'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Опубликовать'));
      await tester.pumpAndSettle();
      expect(saved?['action'], 'createEvent');
      expect(saved?['audience'], 'open');
      expect(saved?['clubId'], 'aaaaaaaaaaaaaaa');
      final start = DateTime.parse(saved?['startsAt'] as String),
          end = DateTime.parse(saved?['endsAt'] as String);
      expect(start.isUtc, isTrue);
      expect(end.isAfter(start), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );

  testWidgets('phone widths and large text fit all community tabs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = await accounts(
      MockClient(
        (r) async => r.url.path.contains('auth-with-password')
            ? response(jsonDecode(accountResponse()))
            : response(feed(0)),
      ),
    );
    await tester.pumpWidget(app(service, scale: 1.8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['Соревнования', 'Мероприятия']) {
      await tester.ensureVisible(find.text(tab));
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets('capture community screen with synthetic fixture', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = await accounts(
      MockClient(
        (r) async => r.url.path.contains('auth-with-password')
            ? response(jsonDecode(accountResponse()))
            : response(feed(9000)),
      ),
    );
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('CAPTURE_COMMUNITY')) {
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/pace_ambient.jpg'),
          tester.element(find.byType(CommunityPage)),
        );
      });
      await tester.pumpAndSettle();
      for (final tab in [
        ('Клубы', 'clubs'),
        ('Соревнования', 'competitions'),
        ('Мероприятия', 'events'),
      ]) {
        if (tab.$2 != 'clubs') {
          await tester.ensureVisible(find.text(tab.$1));
          await tester.tap(find.text(tab.$1));
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('community-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('docs/design').create(recursive: true);
          await File('docs/design/community-${tab.$2}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
