import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sport_platform/features/home/home_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/features/progress/progress_page.dart';
import 'package:sport_platform/features/progress/achievements_view.dart';
import 'package:sport_platform/features/progress/records_view.dart';
import 'package:sport_platform/features/workouts/workout_details_page.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/personal_record.dart';
import 'package:sport_platform/services/progress_sync.dart';
import 'package:sport_platform/widgets/workout_rewards.dart';
import 'package:sport_platform/widgets/workout_xp_panel.dart';

import 'workout_result_test.dart' as fixture;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Widget app(Widget child, double scale) => RepaintBoundary(
  key: const ValueKey('result-preview'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: paceTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['PACE_RESULT_PREVIEW'] == null) return;
    final text = FontLoader('Roboto')
      ..addFont(
        File('C:/Windows/Fonts/segoeui.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    await text.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'History opens saved awards and preserves expansion at 320px / $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final e = fixture.example();
        SharedPreferences.setMockInitialValues({'untouched': 'saved'});
        final prefs = await SharedPreferences.getInstance();
        final before = prefs.getKeys().map((k) => [k, prefs.get(k)]).toList();
        await tester.pumpWidget(
          app(
            Scaffold(
              body: ProgressPage(
                xp: 1180,
                level: 2,
                workouts: [e.saved],
                achievements: e.state,
              ),
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Тренировки'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Тренировки'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Бег'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutDetailsPage), findsOneWidget);
        expect(find.text('10,00 км'), findsOneWidget);
        if (scale == 1) await fixture.capture(tester, 'history-overview');
        await reveal(tester, find.byKey(const ValueKey('history-xp-heading')));
        expect(find.byType(WorkoutXpPanel), findsNothing);
        await tester.tap(find.byKey(const ValueKey('history-xp-heading')));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutXpPanel), findsOneWidget);
        expect(find.text('1 → 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('history-xp-heading')));
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.byKey(const ValueKey('rewards-heading-Достижения')),
        );
        expect(find.text('Первая тренировка · Бег'), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('rewards-heading-Достижения')),
        );
        await tester.pumpAndSettle();
        final first = find.text('Первая тренировка · Бег');
        await reveal(tester, first);
        if (scale == 1) await fixture.capture(tester, 'history-awards');
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(find.byType(AchievementsView), findsOneWidget);
        expect(
          tester
              .widget<AchievementsView>(find.byType(AchievementsView))
              .initialSport,
          'Бег',
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Первая тренировка · Бег'), findsOneWidget);
        await reveal(
          tester,
          find.byKey(const ValueKey('rewards-heading-Достижения')),
        );
        await tester.tap(
          find.byKey(const ValueKey('rewards-heading-Достижения')),
        );
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.byKey(const ValueKey('rewards-heading-Рекорды')),
        );
        await tester.tap(find.byKey(const ValueKey('rewards-heading-Рекорды')));
        await tester.pumpAndSettle();
        final record = find.byKey(
          ValueKey('earned-record-${e.saved.records.first.id}'),
        );
        await reveal(tester, record);
        await tester.tap(record);
        await tester.pumpAndSettle();
        expect(
          tester.widget<RecordsView>(find.byType(RecordsView)).selectedId,
          e.saved.records.first.id,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('history-detail-back')));
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('history-detail-back')),
        );
        expect(button.style!.foregroundColor!.resolve({}), bg);
        await tester.tap(find.byKey(const ValueKey('history-detail-back')));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutDetailsPage), findsNothing);
        expect(
          jsonEncode(prefs.getKeys().map((k) => [k, prefs.get(k)]).toList()),
          jsonEncode(before),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Latest workout on Home opens the same detail and returns to Home',
    (tester) async {
      final e = fixture.example();
      await tester.pumpWidget(
        app(
          HomePage(
            xp: 1180,
            level: 2,
            levelStart: 1000,
            levelEnd: 2500,
            workouts: [e.saved],
            header: const SizedBox.shrink(),
          ),
          1,
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Бег'));
      await tester.tap(find.text('Бег'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutDetailsPage), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('history-detail-back')));
      expect(find.text('К главной'), findsOneWidget);
      await tester.tap(find.text('К главной'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutDetailsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Old workouts have no invented route, elevation, records or level',
    (tester) async {
      final old = Workout(
        date: DateTime(2026, 11, 6),
        distance: 5.2,
        duration: const Duration(seconds: 1938),
        xp: 520,
        sport: 'Бег',
      );
      await tester.pumpWidget(app(WorkoutDetailsPage(workout: old), 1));
      await tester.pumpAndSettle();
      expect(find.text('Нет данных'), findsOneWidget);
      await reveal(
        tester,
        find.text('У этой тренировки нет сохранённого маршрута.'),
      );
      await reveal(tester, find.byKey(const ValueKey('history-total-xp')));
      expect(find.text('+520 XP'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-level')), findsNothing);
      await reveal(tester, find.byType(WorkoutRewards));
      expect(
        find.byKey(const ValueKey('rewards-heading-Рекорды')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'An open history detail replaces provisional rewards after canonical sync',
    (tester) async {
      final e = fixture.example();
      final other = fixture.example('other');
      final updates = ValueNotifier<List<Workout>>([e.saved]);
      addTearDown(updates.dispose);
      await tester.pumpWidget(
        app(WorkoutDetailsPage(workout: e.saved, historyUpdates: updates), 1),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('history-total-xp')));
      expect(find.text('+1 180 XP'), findsOneWidget);
      final remote = ProgressMerger.merge(null, {
        '_sync': {
          'pending': [other.raw.toJson()],
        },
      });
      final canonical = ProgressMerger.merge(remote, {
        '_sync': {
          'pending': [e.raw.toJson()],
        },
      });
      updates.value = (canonical['workouts'] as List)
          .map((w) => Workout.fromJson(Map<String, dynamic>.from(w as Map)))
          .toList();
      await tester.pumpAndSettle();
      expect(find.text('+330 XP'), findsOneWidget);
      final summary = tester.widget<WorkoutRewards>(
        find.byType(WorkoutRewards),
      );
      expect(summary.workout.achievementIds, isEmpty);
      expect(summary.workout.records, isEmpty);
      updates.value = [];
      await tester.pumpAndSettle();
      expect(
        find.text('Тренировка больше не доступна в истории.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'A former record stays in its workout while records navigation shows the newer best',
    (tester) async {
      final e = fixture.example();
      final previous = e.saved.records.last;
      final better = PersonalRecord(
        sport: previous.sport,
        meters: previous.meters,
        milliseconds: previous.milliseconds - 1000,
        at: DateTime(2026, 11, 11),
        sessionId: 'later',
        improvements: 1,
        xp: 100,
      );
      final later = Workout(
        date: DateTime(2026, 11, 11),
        distance: 10,
        duration: const Duration(minutes: 59),
        xp: 430,
        sport: 'Бег',
        records: [better],
        recordXp: 100,
      );
      await tester.pumpWidget(
        app(WorkoutDetailsPage(workout: e.saved, history: [later, e.saved]), 1),
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('rewards-heading-Рекорды')),
      );
      await tester.tap(find.byKey(const ValueKey('rewards-heading-Рекорды')));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('earned-record-${previous.id}'));
      await reveal(tester, row);
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(previous.timeLabel),
        ),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(ValueKey('record-${previous.id}')));
      expect(find.text(better.timeLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final sport in ['Плавание', 'Велосипед', 'Ролики']) {
    testWidgets('History uses saved $sport units and data', (tester) async {
      final w = Workout(
        date: DateTime(2026, 11, 10),
        startedAt: DateTime(2026, 11, 10, 8, 10),
        distance: 1,
        duration: const Duration(minutes: 10),
        xp: 30,
        sport: sport,
        elevationGain: 0,
      );
      await tester.pumpWidget(app(WorkoutDetailsPage(workout: w), 1));
      await tester.pumpAndSettle();
      expect(
        find.text(sport == 'Плавание' ? 'Темп, мин/100 м' : 'Темп, мин/км'),
        findsOneWidget,
      );
      expect(
        find.text(sport == 'Плавание' ? '1:00' : '10:00'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('6,0'), findsOneWidget);
      expect(find.text('10.11.2026 · 08:10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
