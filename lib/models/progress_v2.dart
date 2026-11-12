import 'achievement.dart';
import 'workout.dart';
import '../services/personal_record_engine.dart';

abstract final class ProgressV2 {
  static Map<String, dynamic> empty() => {
    'version': 2,
    'xp': 0,
    'achievements': AchievementState().toJson(),
    'records': PersonalRecordEngine.toJson({}),
    'totals': AchievementProgress([]).toJson(),
  };
  static Workout base(Workout workout) {
    final data = workout.toJson();
    data['xp'] = workout.xp - workout.achievementXp - workout.recordXp;
    if ((data['xp'] as int) < 0) {
      throw const FormatException('Invalid base reward');
    }
    for (final key in [
      'achievementXp',
      'achievementIds',
      'recordXp',
      'records',
      'xpBefore',
      'xpAfter',
    ]) {
      data.remove(key);
    }
    return Workout.fromJson(data);
  }

  static ({
    Map<String, dynamic> state,
    Workout workout,
    int achievementXp,
    int recordXp,
  })
  append(Map<String, dynamic> state, Workout incoming) {
    final workout = base(incoming);
    final totals = AchievementProgress.fromJson(
      Map<String, dynamic>.from(state['totals'] as Map),
    ).plus(workout);
    final achievement = AchievementEngine.apply(
      AchievementEngine.restore(state['achievements'], []),
      [],
      workout,
      aggregated: totals,
    );
    final records = PersonalRecordEngine.apply(
      PersonalRecordEngine.restore(state['records'], []),
      workout,
    );
    final saved = workout.withAchievements(
      achievement.xp,
      achievement.awards.map((a) => a.id).toList(),
      recordReward: records.xp,
      recordResults: records.awards,
      xpBefore: state['xp'] as int,
    );
    return (
      state: {
        'version': 2,
        'xp': (state['xp'] as int) + saved.xp,
        'achievements': achievement.state.toJson(),
        'records': PersonalRecordEngine.toJson(records.best),
        'totals': totals.toJson(),
      },
      workout: saved,
      achievementXp: achievement.xp,
      recordXp: records.xp,
    );
  }

  static Map<String, dynamic> summary(Workout workout) {
    final data = workout.toJson();
    for (final key in ['route', 'timedRoute', 'heartRateSamples']) {
      data.remove(key);
    }
    return data;
  }
}
