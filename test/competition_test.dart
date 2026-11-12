import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/models/competition.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/features/community/competition_results_page.dart';
import 'package:sport_platform/features/community/competition_rules_form.dart';

import 'community_test.dart' show accounts, response;
import 'support/account_fakes.dart';

Map<String, dynamic> results({int page = 0, bool more = false}) => {
  'available': true,
  'page': page,
  'hasMore': more,
  'participants': 3,
  'ranked': 2,
  'rule': {'version': 1, 'metric': 'distance'},
  'rows': [
    {
      'entryId': 'entry-one',
      'name': 'Александра Длинное Имя',
      'rank': 1,
      'score': 30000,
      'workouts': 3,
      'me': false,
    },
    {
      'entryId': 'entry-two',
      'name': 'Бегун',
      'rank': 1,
      'score': 30000,
      'workouts': 2,
      'me': true,
    },
  ],
  'mine': {
    'score': 30000,
    'workouts': 2,
    'rank': 1,
    'excluded': {'sport': 1},
  },
};
void main() {
  test(
    'workout end survives JSON and rewards; times serialize with timezone',
    () {
      final start = DateTime(2026, 11, 12, 10),
          end = start.add(const Duration(hours: 1));
      final w = Workout(
        date: start,
        startedAt: start,
        endedAt: end,
        distance: 10,
        duration: const Duration(hours: 1),
        xp: 10,
        sport: 'Бег',
      );
      final copy = Workout.fromJson(
        w.withAchievements(50, ['fixture']).toJson(),
      );
      expect(copy.endedAt, end.toUtc());
      expect(copy.startedAt, start.toUtc());
      expect(w.toJson()['startedAt'], endsWith('Z'));
      expect(w.toJson()['date'], start.toIso8601String());
      final legacy = Workout(
        date: start,
        startedAt: start,
        distance: 10,
        duration: const Duration(hours: 1),
        xp: 10,
        sport: 'Бег',
      );
      expect(legacy.toJson()['startedAt'], start.toIso8601String());
    },
  );
  test('score units and optional draft fields are explicit and validated even when collapsed', () {
    expect(
      CompetitionRule.fromJson({'metric': 'distance'}).format(12500),
      '12,5 км',
    );
    expect(
      CompetitionRule.fromJson({'metric': 'duration'}).format(3661),
      '1 ч 01 мин 01 с',
    );
    expect(CompetitionRule.fromJson({'metric': 'ascent'}).format(30), '30 м');
    final draft = CompetitionRuleDraft();
    draft.distance.text = '2,5';
    draft.duration.text = '30';
    draft.minPace.text = '5:00';
    draft.maxPace.text = '7:30';
    expect(draft.paceError, isNull);
    expect(draft.toJson()['minDurationSeconds'], 1800);
    expect(draft.toJson()['minDistanceKm'], 2.5);
    draft.duration.text = 'ошибка';
    expect(draft.paceError, isNotNull);
    draft.duration.clear();
    draft.minPace.text = '8:00';
    expect(draft.paceError, isNotNull);
    draft.dispose();
  });
  testWidgets(
    'leaderboard shows tied ranks and private exclusion reasons at large type',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = await accounts(
        MockClient(
          (r) async => r.url.path.contains('auth-with-password')
              ? response(jsonDecode(accountResponse()))
              : response(results()),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: CompetitionResultsPage(
              accounts: service,
              eventId: 'b' * 15,
              title: 'Беговой зачёт',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Не вошли в зачёт').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Не вошли в зачёт'));
      await tester.pumpAndSettle();
      expect(find.text('Другой вид спорта'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Бегун · ты').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Бегун · ты'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets(
    'results refresh and pagination do not duplicate an updated entry',
    (tester) async {
      var page = 0;
      final service = await accounts(
        MockClient((r) async {
          if (r.url.path.contains('auth-with-password')) {
            return response(jsonDecode(accountResponse()));
          }
          page = (jsonDecode(r.body) as Map)['page'] as int;
          final value = results(page: page, more: page == 0);
          if (page == 1) {
            value['rows'] = [
              (value['rows'] as List).last,
              {
                'entryId': 'entry-three',
                'name': 'Новый участник',
                'rank': 3,
                'score': 10000,
                'workouts': 1,
                'me': false,
              },
            ];
          }
          return response(value);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          home: CompetitionResultsPage(
            accounts: service,
            eventId: 'b' * 15,
            title: 'Беговой зачёт',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Загрузить ещё'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Загрузить ещё'));
      await tester.pumpAndSettle();
      expect(page, 1);
      expect(find.text('Бегун · ты'), findsOneWidget);
      expect(find.text('Новый участник'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets('club-only results refusal displays reason with retry', (
    tester,
  ) async {
    final service = await accounts(
      MockClient(
        (r) async => r.url.path.contains('auth-with-password')
            ? response(jsonDecode(accountResponse()))
            : response({
                'message': 'Результаты доступны участникам клуба',
              }, 403),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: paceTheme,
        home: CompetitionResultsPage(
          accounts: service,
          eventId: 'b' * 15,
          title: 'Клубной старт',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Результаты доступны участникам клуба'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets('render results with synthetic standings', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = await accounts(
      MockClient(
        (r) async => r.url.path.contains('auth-with-password')
            ? response(jsonDecode(accountResponse()))
            : response(results()),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('competition-preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: paceTheme.copyWith(
            textTheme: paceTheme.textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: CompetitionResultsPage(
            accounts: service,
            eventId: 'b' * 15,
            title: 'Беговой ноябрь',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
