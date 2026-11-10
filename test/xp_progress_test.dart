import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/models/xp_progress.dart';
import 'package:sport_platform/features/progress/levels_page.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';

import 'support/test_app.dart';

void main() {
  test('Existing levels 1 to 10 keep their exact XP thresholds', () {
    const thresholds = [
      0,
      1000,
      2500,
      5000,
      9000,
      15000,
      23000,
      34000,
      48000,
      65000,
    ];
    for (var i = 0; i < thresholds.length; i++) {
      expect(XpProgress.xpForLevel(i + 1), thresholds[i]);
      final progress = XpProgress(thresholds[i]);
      expect(progress.level, i + 1);
      expect(progress.levelStart, thresholds[i]);
      expect(progress.fraction, 0);
      if (i > 0) expect(XpProgress(thresholds[i] - 1).level, i);
    }
  });
  test('85k XP reaches level 11 and the next threshold continues to rise', () {
    const expected = {
      11: 85000,
      12: 108000,
      13: 134000,
      14: 163000,
      15: 195000,
      20: 400000,
      25: 680000,
      30: 1035000,
    };
    for (final entry in expected.entries) {
      expect(XpProgress.xpForLevel(entry.key), entry.value);
      expect(XpProgress(entry.value).level, entry.key);
      expect(XpProgress(entry.value - 1).level, entry.key - 1);
    }
    expect(const XpProgress(85000).remaining, 23000);
    expect(const XpProgress(85000).levelEnd, 108000);
  });
  test('A large XP award crosses multiple levels and preserves remainder', () {
    final before = const XpProgress(64900), after = const XpProgress(165000);
    expect(before.level, 9);
    expect(after.level, 14);
    expect(after.earnedInLevel, 2000);
    expect(after.remaining, 30000);
    expect(after.earnedInLevel + after.remaining, 32000);
    expect(const XpProgress(96500).fraction, .5);
  });
  test(
    'Level boundaries are continuous and later transition costs grow by 3000',
    () {
      for (var level = 10; level <= 500; level++) {
        final start = XpProgress.xpForLevel(level),
            end = XpProgress.xpForLevel(level + 1);
        expect(end, greaterThan(start));
        expect(XpProgress(end - 1).level, level);
        expect(XpProgress(end).level, level + 1);
        expect(XpProgress(end).remaining, greaterThan(0));
        expect(XpProgress.xpForLevel(level + 2) - end, (end - start) + 3000);
      }
    },
  );
  test('Large server-compatible balances find valid bounds without a per-level loop', () {
    for (final xp in [1000000000, 1000000000000, 9007199254740991]) {
      final progress = XpProgress(xp);
      expect(progress.level, greaterThan(30));
      expect(progress.levelStart, lessThanOrEqualTo(xp));
      expect(progress.levelEnd, greaterThan(xp));
      expect(progress.remaining, greaterThan(0));
      expect(progress.fraction.isFinite, isTrue);
      expect(progress.fraction, inInclusiveRange(0, 1));
    }
  });
  test('Negative input cannot produce negative progress, and level zero is invalid', () {
    const progress = XpProgress(-20);
    expect(progress.level, 1);
    expect(progress.earnedInLevel, 0);
    expect(progress.remaining, 1000);
    expect(progress.fraction, 0);
    expect(() => XpProgress.xpForLevel(0), throwsArgumentError);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Level scale remains usable on 320px with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const LevelsPage(xp: 85000),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Шкала уровней'), findsOneWidget);
      expect(find.text('23 000 XP до уровня 12'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('level-12')),
        150,
      );
      await tester.pumpAndSettle();
      expect(find.text('С 108 000 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Home opens the level scale and navigation never changes stored XP',
    (tester) async {
      final saved = jsonEncode({
        'xp': 85000,
        'selectedSport': 0,
        'workouts': [],
      });
      SharedPreferences.setMockInitialValues({'pace_local_data': saved});
      await tester.pumpWidget(const TestPaceApp());
      await tester.pumpAndSettle();
      expect(find.text('Уровень 11'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('open-levels')));
      await tester.tap(find.byKey(const ValueKey('open-levels')));
      await tester.pumpAndSettle();
      expect(find.byType(LevelsPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LevelsPage), findsNothing);
      expect(find.text('Уровень 11'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('pace_local_data'),
        saved,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
