import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_platform/models/achievement.dart';
import 'package:sport_platform/models/workout.dart';
import 'package:sport_platform/data/storage/local_storage_service.dart';
import 'package:sport_platform/features/progress/achievements_view.dart';

Workout run(
  String id, {
  double km = 5,
  String sport = 'Бег',
  double elevation = 0,
}) => Workout(
  date: DateTime.utc(2026, 11, 10),
  distance: km,
  duration: const Duration(minutes: 30),
  xp: 360,
  sport: sport,
  sessionId: id,
  elevationGain: elevation,
);
void main() {
  test(
    'Catalog matches all approved non-record rules and stable unique IDs',
    () {
      final source =
          (jsonDecode(File('docs/achievements-v1.json').readAsStringSync())
                  as Map)['rows']
              as List;
      final approved = source
          .where((r) => r['metric'] != 'Рекорд на дистанции')
          .toList();
      expect(AchievementCatalog.rules.length, 311);
      expect(AchievementCatalog.rules.map((r) => r.id).toSet().length, 311);
      for (final rule in AchievementCatalog.rules) {
        expect(
          approved
              .where(
                (r) =>
                    r['sport'] == rule.sport &&
                    r['metric'] == rule.metric &&
                    r['threshold'] == rule.threshold &&
                    r['xp'] == rule.xp,
              )
              .length,
          1,
        );
      }
    },
  );
  test('First 5 km awards every crossed distance once: 240 plus first sport workout 10', () {
    final w = run('one');
    final result = AchievementEngine.apply(AchievementState(), [], w);
    expect(result.xp, 250);
    expect(
      result.awards.where((r) => r.metric == 'Дистанция тренировки').length,
      6,
    );
    expect(
      result.awards
          .where((r) => r.metric == 'Дистанция тренировки')
          .fold<int>(0, (s, r) => s + r.xp),
      240,
    );
    final again = AchievementEngine.apply(result.state, [w], run('two'));
    expect(again.xp, 0);
  });
  test('Old history is recognised without retroactive XP or missing a newly crossed tier', () {
    final old = [run('old', km: 3)];
    final state = AchievementEngine.restore(null, old);
    expect(
      state.unlocked.values.every((v) => v.historical && v.xp == 0),
      isTrue,
    );
    final result = AchievementEngine.apply(state, old, run('new'));
    expect(result.xp, 100);
    expect(
      AchievementState.fromJson(result.state.toJson()).unlocked.keys.toSet(),
      result.state.unlocked.keys.toSet(),
    );
  });
  test('General totals, diversity, sport-specific totals and swimming height are separate', () {
    final swim = run('s', km: 1, sport: 'Плавание', elevation: 500);
    final first = AchievementEngine.apply(AchievementState(), [], swim);
    expect(
      first.awards.any(
        (r) => r.metric.contains('набор') || r.metric.contains('Набор'),
      ),
      isFalse,
    );
    final next = AchievementEngine.apply(first.state, [swim], run('r', km: .4));
    expect(
      next.awards
          .where((r) => r.metric == 'Разные виды спорта')
          .single
          .threshold,
      2,
    );
    expect(next.awards.any((r) => r.metric == 'Общие километры'), isFalse);
  });
  test(
    'Atomic completion retry and settings save preserve ledger and balance',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      final first = await storage.completeWorkout(
        workout: run('id'),
        initialXp: 0,
        selectedSport: 0,
        initialWorkouts: [],
      );
      expect(first.xp, 610);
      expect(first.achievementXp, 250);
      expect(first.workouts.single.achievementXp, 250);
      expect(first.workouts.single.xp, 610);
      final retry = await LocalStorageService().completeWorkout(
        workout: run('id'),
        initialXp: 0,
        selectedSport: 0,
        initialWorkouts: [],
      );
      expect(retry.xp, 610);
      expect(retry.workouts.length, 1);
      await storage.saveProgress(
        xp: retry.xp,
        selectedSport: 2,
        workouts: retry.workouts,
      );
      final saved = await storage.loadProgress();
      expect(saved!['xp'], 610);
      expect(saved['selectedSport'], 2);
      expect(
        (saved['achievements'] as Map)['unlocked'],
        first.achievements.toJson()['unlocked'],
      );
    },
  );
  test('Two storage instances serialize completions without losing history or rewards', () async {
    SharedPreferences.setMockInitialValues({});
    final a = LocalStorageService(), b = LocalStorageService();
    await Future.wait([
      a.completeWorkout(
        workout: run('one'),
        initialXp: 0,
        selectedSport: 0,
        initialWorkouts: [],
      ),
      b.completeWorkout(
        workout: run('two', km: .4),
        initialXp: 0,
        selectedSport: 0,
        initialWorkouts: [],
      ),
    ]);
    final saved = await a.loadProgress();
    expect((saved!['workouts'] as List).length, 2);
    expect(saved['xp'], 970);
  });

  testWidgets(
    'Earned achievements are displayed with correct reward and filters',
    (tester) async {
      final w = run('ui');
      final result = AchievementEngine.apply(AchievementState(), [], w);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsView(
              workouts: [
                w.withAchievements(
                  result.xp,
                  result.awards.map((r) => r.id).toList(),
                ),
              ],
              state: result.state,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Достижения: 7 / 311'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
