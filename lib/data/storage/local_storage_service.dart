import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workout.dart';
import '../../models/workout_draft.dart';

class LocalStorageService {
  LocalStorageService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _preferences;
  static const String _storageKey = 'pace_local_data';
  static const String draftKey = 'pace_active_workout';
  Future<void> _pending = Future<void>.value();

  Future<T> _write<T>(Future<T> Function() operation) {
    final task = _pending.catchError((Object _) {}).then((_) => operation());
    _pending = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
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
  Future<({int xp, List<Workout> workouts})> completeWorkout({
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
    if (!history.any((w) => w.sessionId == workout.sessionId)) {
      history.insert(0, workout);
      total += workout.xp;
      data.addAll({
        'xp': total,
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
    return (xp: total, workouts: history);
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

    final raw = jsonEncode(data);
    return _write(() async {
      final prefs = await _preferences();
      if (!await prefs.setString(_storageKey, raw)) {
        throw StateError('Progress not saved');
      }
    });
  }
}
