import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/app/theme/pace_theme.dart';
import 'package:sport_platform/models/achievement.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/models/sport_catalog.dart';
import 'package:sport_platform/services/workout_xp_calculator.dart';
import 'package:sport_platform/services/personal_record_engine.dart';
import 'package:sport_platform/services/progress_sync.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/features/tracker/tracker_page.dart';
import 'package:sport_platform/features/progress/achievements_view.dart';
import 'package:sport_platform/features/progress/records_view.dart';
import 'package:sport_platform/widgets/reward_badge.dart';
import 'package:sport_platform/widgets/workout_rewards.dart';
import 'package:sport_platform/widgets/workout_result_summary.dart';

typedef Example = ({Workout raw, Workout saved, AchievementState state});
Example example([String id = 'first-10k']) {
  final scale = Geolocator.distanceBetween(0, 0, .001, 0) / .001;
  final points = [
    for (var i = 0; i <= 400; i++)
      RoutePoint(
        latitude: i * 25.00125 / scale,
        longitude: 0,
        timestamp: DateTime.utc(2026, 11, 10).add(Duration(seconds: i * 9)),
        accuracy: 2,
      ),
  ];
  final breakdown = WorkoutXpCalculator.calculate(
    sport: 'Бег',
    distanceKm: 10,
    activeDuration: const Duration(hours: 1),
    elevationMeters: 30,
  );
  final raw = Workout(
    date: DateTime.utc(2026, 11, 10),
    distance: 10,
    duration: const Duration(hours: 1),
    xp: breakdown.total,
    sport: 'Бег',
    sessionId: id,
    elevationGain: 30,
    xpBreakdown: breakdown,
    route: points,
    timedRoute: points,
  );
  final a = AchievementEngine.apply(AchievementState(), [], raw);
  final r = PersonalRecordEngine.apply({}, raw);
  return (
    raw: raw,
    saved: raw.withAchievements(
      a.xp,
      a.awards.map((r) => r.id).toList(),
      recordReward: r.xp,
      recordResults: r.awards,
      xpBefore: 0,
    ),
    state: a.state,
  );
}

Widget tracker(Example e) => TrackerPage(
  distance: 0,
  pace: 0,
  elapsed: Duration.zero,
  speed: 0,
  route: [],
  tracking: false,
  paused: false,
  starting: false,
  finishing: false,
  workoutFinished: true,
  gpsStatus: 'Тренировка завершена',
  finishedWasSaved: true,
  finishedSport: e.saved.sport,
  finishedDistance: e.saved.distance,
  finishedDuration: e.saved.duration,
  finishedXp: e.saved.xp,
  finishedRoute: e.saved.route,
  finishedWorkout: e.saved,
  history: [e.saved],
  achievementState: e.state,
  finishedElevation: 30,
  finishedXpBreakdown: e.saved.xpBreakdown,
  finishedAchievementXp: e.saved.achievementXp,
  finishedRecordXp: e.saved.recordXp,
  sports: SportCatalog.names,
  sportIcons: SportCatalog.icons,
  selectedSport: 0,
  formatDuration: (d) => '1:00:00',
  formatPace: (n) => '6:00',
  onNewWorkout: () {},
  onStartWorkout: () {},
  onPauseWorkout: () {},
  onFinishWorkout: () async {},
  onSelectSport: (_) {},
  onClose: () {},
);
Future<void> capture(WidgetTester tester, String suffix) async {
  final prefix = Platform.environment['PACE_RESULT_PREVIEW'];
  if (prefix == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('result-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$prefix-$suffix.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['PACE_RESULT_PREVIEW'] != null) {
      final text = FontLoader('Roboto')
        ..addFont(
          File('C:/Windows/Fonts/segoeui.ttf')
              .readAsBytes()
              .then((bytes) => ByteData.view(bytes.buffer)),
        );
      await text.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
        ..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        );
      await cupertino.load();
    }
  });
  test('All catalog metrics map to 11 distinct badge categories and readable numeric units', () {
    final categories =
        AchievementCatalog.rules
            .map((r) => RewardCategory.fromMetric(r.metric))
            .toSet()
          ..add(RewardCategory.record);
    expect(categories.length, 11);
    expect(categories.map((c) => c.icon).toSet().length, 11);
    expect(RewardBadge.displayNumber(.4, 'км'), (value: '400', unit: 'м'));
    expect(RewardBadge.displayNumber(1.5, 'км'), (value: '1,5', unit: 'км'));
    expect(RewardBadge.displayNumber(3000, 'м'), (value: '3000', unit: 'м'));
  });
  test('Real first 10k engine awards 8 achievements and 9 records, persisted with level snapshots', () async {
    SharedPreferences.setMockInitialValues({});
    final e = example();
    expect(e.raw.xp, 330);
    expect(e.saved.achievementIds.length, 8);
    expect(e.saved.achievementXp, 400);
    expect(e.saved.records.length, 9);
    expect(e.saved.recordXp, 450);
    expect(e.saved.xp, 1180);
    final store = LocalStorageService();
    final saved = await store.completeWorkout(
      workout: e.raw,
      initialXp: 0,
      selectedSport: 0,
      initialWorkouts: [],
    );
    expect(saved.workouts.single.xpBefore, 0);
    expect(saved.workouts.single.xpAfter, 1180);
    final retry = await store.completeWorkout(
      workout: e.raw,
      initialXp: 99999,
      selectedSport: 0,
      initialWorkouts: [],
    );
    expect(retry.xp, 1180);
    expect(retry.workouts.single.xpBefore, 0);
    final restored = Workout.fromJson(
      jsonDecode(jsonEncode(retry.workouts.single.toJson()))
          as Map<String, dynamic>,
    );
    expect(restored.xpBefore, 0);
    expect(restored.xpAfter, 1180);
    expect(restored.records.length, 9);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Saved result has collapsed rows, linked screens and dark Done at 320px / scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final e = example();
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('result-preview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: paceTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(body: tracker(e)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RewardBadge), findsNothing);
        final done = tester.widget<Text>(find.text('Готово'));
        expect(done.style!.color, bg);
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('finished-done')),
        );
        expect(button.style!.foregroundColor!.resolve({}), bg);
        final contrast =
            (lime.computeLuminance() + .05) / (bg.computeLuminance() + .05);
        expect(contrast, greaterThan(7));
        if (scale == 1) await capture(tester, 'collapsed');
        final scroll = find
            .descendant(
              of: find.byType(TrackerPage),
              matching: find.byType(Scrollable),
            )
            .first;
        final ach = find.byKey(const ValueKey('rewards-heading-Достижения'));
        await tester.scrollUntilVisible(ach, 180, scrollable: scroll);
        await tester.pumpAndSettle();
        await tester.tap(ach);
        await tester.pumpAndSettle();
        expect(find.byType(RewardBadge), findsNWidgets(8));
        if (scale == 1) await capture(tester, 'expanded');
        final selected = AchievementCatalog.rules.singleWhere(
          (r) =>
              r.sport == 'Бег' &&
              r.metric == 'Дистанция тренировки' &&
              r.threshold == 10,
        );
        await tester.ensureVisible(
          find.byKey(ValueKey('earned-${selected.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('earned-${selected.id}')));
        await tester.pumpAndSettle();
        final page = tester.widget<AchievementsView>(
          find.byType(AchievementsView),
        );
        expect(page.initialSport, 'Бег');
        expect(page.initialMetric, 'Дистанция тренировки');
        expect(page.selectedId, selected.id);
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('achievement-${selected.id}')),
          150,
        );
        expect(find.text('Выбранное достижение'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.ensureVisible(ach);
        await tester.pumpAndSettle();
        await tester.tap(ach);
        await tester.pumpAndSettle();
        expect(find.byType(RewardBadge), findsNothing);
        final rec = find.byKey(const ValueKey('rewards-heading-Рекорды'));
        await tester.scrollUntilVisible(rec, 150, scrollable: scroll);
        await tester.pumpAndSettle();
        await tester.tap(rec);
        await tester.pumpAndSettle();
        final record = e.saved.records.firstWhere((r) => r.meters == 1000);
        await tester.ensureVisible(
          find.byKey(ValueKey('earned-record-${record.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('earned-record-${record.id}')));
        await tester.pumpAndSettle();
        final records = tester.widget<RecordsView>(find.byType(RecordsView));
        expect(records.initialSport, 'Бег');
        expect(records.selectedId, record.id);
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('record-${record.id}')),
          150,
        );
        expect(find.text('Выбранный рекорд'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Legacy data cannot invent a level-up snapshot', (tester) async {
    final w = Workout(
      date: DateTime.utc(2026),
      distance: 1,
      duration: const Duration(minutes: 6),
      xp: 100,
      sport: 'Бег',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutResultSummary(workout: w)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-level')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('result-total-xp'))).data,
      '+100 XP',
    );
  });
  testWidgets(
    'Canonical sync removes provisional rewards and stale level-up banner',
    (tester) async {
      final local = example('local'), other = example('other');
      final remote = ProgressMerger.merge(null, {
        '_sync': {
          'pending': [other.raw.toJson()],
        },
      });
      final merged = ProgressMerger.merge(remote, {
        '_sync': {
          'pending': [local.raw.toJson()],
        },
      });
      final canonical = ProgressMerger.workouts(merged).first;
      expect(canonical.xp, 330);
      expect(canonical.xpBefore, 1180);
      expect(canonical.xpAfter, 1510);
      Widget panel(Workout w) => MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              WorkoutResultSummary(workout: w),
              WorkoutRewards(
                workout: w,
                onAchievement: (_) {},
                onRecord: (_) {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(panel(local.saved));
      await tester.pumpAndSettle();
      expect(find.text('Новый уровень 2'), findsOneWidget);
      await tester.pumpWidget(panel(canonical));
      await tester.pumpAndSettle();
      expect(find.text('Новый уровень 2'), findsNothing);
      expect(find.text('Уровень 2'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(
        find.textContaining('Новых достижений и рекордов пока нет'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('All 11 number medallions paint with four-digit values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Wrap(
              children: [
                for (final c in RewardCategory.values)
                  RewardBadge(category: c, value: '3000', unit: 'м'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RewardBadge), findsNWidgets(11));
    expect(tester.takeException(), isNull);
  });
}
