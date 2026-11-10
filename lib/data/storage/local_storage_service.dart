import '../../services/personal_record_engine.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workout.dart';
import '../../models/achievement.dart';
import '../../models/workout_draft.dart';

class LocalStorageService {
  LocalStorageService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _preferences;
  static const String _storageKey = 'pace_local_data';
  static const String draftKey = 'pace_active_workout';
  static Future<void>? _pending;

  Future<T> _write<T>(Future<T> Function() operation) {
    final task = (_pending ?? Future<void>.value()).then((_) => operation());
    final completion = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = completion;
    completion.then((_) {
      if (identical(_pending, completion)) _pending = null;
    });
    return task;
  }

  Future<WorkoutDraft?> loadDraft() async {
    await _pending;
    final prefs = await _preferences();
    final raw = prefs.getString(draftKey);
    return raw == null
        ? null
        : WorkoutDraft.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
  }

  Future<void> saveDraft(WorkoutDraft draft) {
    final raw = jsonEncode(draft.toJson());
    return _write(() async {
      final prefs = await _preferences();
      if (!await prefs.setString(draftKey, raw)) {
        throw StateError('Draft not saved');
      }
    });
  }

  Future<void> clearDraft() => _write(() async {
    final prefs = await _preferences();
    if (prefs.containsKey(draftKey) && !await prefs.remove(draftKey)) {
      throw StateError('Draft not removed');
    }
  });

  /// Commit the result first. A leftover draft is harmless thanks to sessionId.
  Future<
    ({
      int xp,
      List<Workout> workouts,
      AchievementState achievements,
      int achievementXp,
      int recordXp,
    })
  >
  completeWorkout({
    required Workout workout,
    required int initialXp,
    required int selectedSport,
    required List<Workout> initialWorkouts,
  }) => _write(() async {
    if (workout.sessionId == null || workout.sessionId!.isEmpty) {
      throw ArgumentError('A completed session requires an ID');
    }
    final prefs = await _preferences();
    final raw = prefs.getString(_storageKey);
    final data = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final history = raw == null
        ? List<Workout>.from(initialWorkouts)
        : (data['workouts'] as List<dynamic>? ?? [])
              .map((w) => Workout.fromJson(Map<String, dynamic>.from(w as Map)))
              .toList();
    var total = (data['xp'] as num?)?.toInt() ?? initialXp;
    var achievements = AchievementEngine.restore(data['achievements'], history);
    var achievementXp = 0;
    var recordXp = 0;
    final recordBest = PersonalRecordEngine.restore(data['records'], history);
    final previous = history
        .where((w) => w.sessionId == workout.sessionId)
        .firstOrNull;
    if (previous == null) {
      final result = AchievementEngine.apply(achievements, history, workout);
      achievements = result.state;
      achievementXp = result.xp;
      final records = PersonalRecordEngine.apply(recordBest, workout);
      recordXp = records.xp;
      final saved = workout.withAchievements(
        result.xp,
        result.awards.map((r) => r.id).toList(),
        recordReward: records.xp,
        recordResults: records.awards,
      );
      history.insert(0, saved);
      total += saved.xp;
      data.addAll({
        'xp': total,
        'records': PersonalRecordEngine.toJson(records.best),
        'achievements': achievements.toJson(),
        'selectedSport': selectedSport,
        'workouts': history.map((w) => w.toJson()).toList(),
      });
      if (!await prefs.setString(_storageKey, jsonEncode(data))) {
        throw StateError('Workout not saved');
      }
    }
    // History is authoritative if the process stops between these writes.
    try {
      if (prefs.containsKey(draftKey)) await prefs.remove(draftKey);
    } catch (_) {}
    return (
      xp: total,
      workouts: history,
      achievements: achievements,
      achievementXp: previous?.achievementXp ?? achievementXp,
      recordXp: previous?.recordXp ?? recordXp,
    );
  });

  Future<Map<String, dynamic>?> loadProgress() async {
    await _pending;
    final prefs = await _preferences();
    final raw = prefs.getString(_storageKey);

    if (raw == null) return null;

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveProgress({
    required int xp,
    required int selectedSport,
    required List<Workout> workouts,
  }) {
    final data = {
      'xp': xp,
      'selectedSport': selectedSport,
      'workouts': workouts.map((workout) => workout.toJson()).toList(),
    };

    return _write(() async {
      final prefs = await _preferences();
      final previous = prefs.getString(_storageKey);
      final merged = previous == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(previous) as Map);
      merged.addAll(data);
      if (!await prefs.setString(_storageKey, jsonEncode(merged))) {
        throw StateError('Progress not saved');
      }
    });
  }
}
