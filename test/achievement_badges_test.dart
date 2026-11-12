import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/models/achievement.dart';
import 'package:sport_platform/models/sport_catalog.dart';
import 'package:sport_platform/features/progress/achievements_view.dart';
import 'package:sport_platform/widgets/reward_badge.dart';

RewardBadge categoryExample(RewardCategory category) {
  if (category == RewardCategory.record) {
    return RewardBadge.record(10 * 1000, sport: 'Велосипед');
  }
  final sport = category.index < 4 ? 'Все виды' : 'Велосипед';
  final rules = AchievementCatalog.rules
      .where(
        (r) =>
            r.sport == sport && RewardCategory.fromMetric(r.metric) == category,
      )
      .toList();
  return RewardBadge.achievement(rules[rules.length ~/ 2]);
}

Future<void> settleBadgeImages(WidgetTester tester) async {
  final context = tester.element(find.byType(RewardBadge).first);
  await tester.runAsync(() async {
    for (final folder in ['materials', 'running-distance']) {
      for (final material in BadgeMaterial.values) {
        await precacheImage(
          AssetImage('assets/images/achievements/$folder/${material.name}.png'),
          context,
        );
      }
    }
  });
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  final folder = Platform.environment['PACE_BADGE_PREVIEW'];
  if (folder == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['PACE_BADGE_PREVIEW'] == null) return;
    final dir = Platform.environment['PACE_FONT_DIR']!;
    for (final item in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf'),
    ]) {
      await (FontLoader(item.$1)..addFont(
            File('$dir/${item.$2}')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          ))
          .load();
    }
    await (FontLoader('Roboto')
          ..addFont(
            File('$dir/roboto-regular.ttf')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          )
          ..addFont(
            File('$dir/roboto-bold.ttf')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          )
          ..addFont(
            File('$dir/roboto-black.ttf')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          ))
        .load();
  });

  test('All 311 achievements have monotone local ranks and unchanged six running milestones', () {
    expect(AchievementCatalog.rules, hasLength(311));
    final groups = <String, List<AchievementRule>>{};
    for (final r in AchievementCatalog.rules) {
      groups.putIfAbsent('${r.sport}|${r.metric}', () => []).add(r);
    }
    for (final rules in groups.values) {
      rules.sort((a, b) => a.threshold.compareTo(b.threshold));
      final ranks = rules
          .map((r) => BadgeMaterial.forAchievement(r).index)
          .toList();
      expect(ranks.first, 0);
      expect(ranks.last, 5);
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i], greaterThanOrEqualTo(ranks[i - 1]));
      }
    }
    final running = groups['Бег|Километры по виду']!;
    expect(running.map((r) => r.threshold), [25, 50, 100, 250, 500, 1000]);
    expect(running.map(BadgeMaterial.forAchievement), BadgeMaterial.values);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Badge left, description right at 320px and text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final rule = AchievementCatalog.rules.firstWhere(
          (r) => r.sport == 'Бег' && r.metric == 'Километры по виду',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: paceTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: AchievementsView(
                  workouts: const [],
                  initialSport: 'Бег',
                  initialMetric: 'Километры по виду',
                  state: AchievementState({
                    rule.id: AchievementUnlock(DateTime(2026, 11, 12), rule.xp),
                  }),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final badge = find.byType(RewardBadge).first;
        final title = find.text('Бег · Километры по виду').first;
        final reward = find.text('25 км · +50 XP');
        expect(
          tester.getTopLeft(title).dx,
          greaterThan(tester.getBottomRight(badge).dx),
        );
        expect(tester.getTopLeft(reward).dx, tester.getTopLeft(title).dx);
        expect(find.text('Получено 12.11.2026 · +50 XP'), findsOneWidget);
        final lockedRule = AchievementCatalog.rules
            .where((r) => r.sport == 'Бег' && r.metric == 'Километры по виду')
            .elementAt(1);
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('achievement-${lockedRule.id}')),
          160,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byIcon(Icons.lock_rounded), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Render six materials and all sports/categories without asset errors',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: paceTheme,
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('preview'),
              child: ColoredBox(
                color: bg,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text('Материалы · накопленные километры в беге'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final r in AchievementCatalog.rules.where(
                            (r) =>
                                r.sport == 'Бег' &&
                                r.metric == 'Километры по виду',
                          ))
                            RewardBadge.achievement(r, size: 66),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Категории'),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final c in RewardCategory.values)
                            SizedBox(
                              width: 100,
                              child: Column(
                                children: [
                                  categoryExample(c),
                                  Text(
                                    c.label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Виды спорта'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final i in SportCatalog.selectableIndices)
                            RewardBadge(
                              category: RewardCategory.workoutDistance,
                              value: '10',
                              unit: 'км',
                              sport: SportCatalog.names[i],
                              material: BadgeMaterial.gold,
                              size: 56,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Не получено'),
                      const RewardBadge(
                        category: RewardCategory.totalDistance,
                        value: '50000',
                        unit: 'км',
                        earned: false,
                        material: BadgeMaterial.diamond,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settleBadgeImages(tester);
      expect(tester.takeException(), isNull);
      await capture(tester, 'badge-catalog');
    },
  );

  testWidgets('Capture real achievement list with six earned material tokens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rules = AchievementCatalog.rules
        .where((r) => r.sport == 'Бег' && r.metric == 'Километры по виду')
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        theme: paceTheme,
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('preview'),
            child: ColoredBox(
              color: bg,
              child: AchievementsView(
                workouts: const [],
                initialSport: 'Бег',
                initialMetric: 'Километры по виду',
                state: AchievementState({
                  for (final r in rules)
                    r.id: AchievementUnlock(DateTime(2026, 11, 12), r.xp),
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await settleBadgeImages(tester);
    expect(tester.takeException(), isNull);
    await capture(tester, 'achievement-list');
  });
}
