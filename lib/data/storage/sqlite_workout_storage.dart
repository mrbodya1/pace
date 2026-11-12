import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/achievement.dart';
import '../../models/workout.dart';
import '../../models/workout_draft.dart';
import '../../services/account_service.dart';
import '../../services/workout_sync_v2.dart';
import 'local_storage_service.dart';
import 'workout_database.dart';

class SqliteWorkoutStorage extends LocalStorageService {
  SqliteWorkoutStorage({required this.accounts, WorkoutDatabase? database})
    : db = database ?? WorkoutDatabase.instance,
      super(owner: accounts.progressOwner);
  final AccountService accounts;
  final WorkoutDatabase db;
  Future<void>? _initializing, _sync;
  late final engine = WorkoutSyncV2(accounts, db, owner!);
  @override
  bool get supportsSync => true;
  @override
  bool get pagedHistory => true;
  Future<void> _initialize() {
    if (_initializing != null) return _initializing!;
    final future = _prepare();
    _initializing = future;
    future.then(
      (_) {},
      onError: (Object _, StackTrace _) {
        _initializing = null;
      },
    );
    return future;
  }

  Future<void> _prepare() async {
    final prefs = await SharedPreferences.getInstance(),
        database = await db.database;
    await db.state(owner!);
    // Retain the sport selector for every cached account before removing history.
    for (final key
        in prefs
            .getKeys()
            .where((k) => k.startsWith('pace_progress_v2:'))
            .toList()) {
      try {
        final oldOwner = Uri.decodeComponent(
          key.substring('pace_progress_v2:'.length),
        );
        final current = await db.state(oldOwner);
        if (current['epoch'] != '') continue;
        final old = jsonDecode(prefs.getString(key)!) as Map;
        final selected = old['selectedSport'];
        if (selected is int) {
          await database.update(
            'account_state',
            {'selected_sport': selected},
            where: 'owner=?',
            whereArgs: [oldOwner],
          );
        }
      } catch (_) {
        /* Only a preference is retained, never legacy training data. */
      }
    }
    // The user explicitly approved a fresh training history, including cached old outboxes/drafts.
    for (final oldKey
        in prefs
            .getKeys()
            .where(
              (k) =>
                  k.startsWith('pace_progress_v2:') ||
                  [
                    'pace_local_data',
                    'pace_active_workout',
                    'pace_progress_legacy_owner',
                  ].contains(k),
            )
            .toList()) {
      if (!await prefs.remove(oldKey)) {
        throw StateError('Old training cache could not be reset');
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    await _initialize();
    final row = await db.state(owner!);
    return {
      ...db.decode(row['derived']),
      'selectedSport': row['selected_sport'],
      'workouts': (await db.history(owner!)).map((w) => w.toJson()).toList(),
      '_sync': {
        'pending': await db.pending(owner!),
        'revision': row['revision'],
        'epoch': row['epoch'],
      },
    };
  }

  @override
  Future<void> synchronize() {
    if (_sync != null) return _sync!;
    final future = () async {
      await _initialize();
      await engine.synchronize();
    }();
    _sync = future;
    future.then(
      (_) {
        _sync = null;
      },
      onError: (Object _, StackTrace _) {
        _sync = null;
      },
    );
    return future;
  }

  @override
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
    bool clearActiveDraft = true,
  }) async {
    await _initialize();
    final result = await db.complete(
      owner!,
      workout,
      selectedSport,
      clearDraft: clearActiveDraft,
    );
    final data = await loadProgress();
    final history = await db.history(owner!);
    final detailed = [
      for (final w in history)
        w.sessionId == workout.sessionId ? result.workout : w,
      if (!history.any((w) => w.sessionId == workout.sessionId)) result.workout,
    ];
    return (
      xp: data!['xp'] as int,
      workouts: detailed,
      achievements: AchievementEngine.restore(data['achievements'], []),
      achievementXp: result.achievementXp,
      recordXp: result.recordXp,
    );
  }

  @override
  Future<List<Workout>> loadHistory({
    int limit = 20,
    int offset = 0,
    String? sport,
  }) async {
    await _initialize();
    return db.history(owner!, limit: limit, offset: offset, sport: sport);
  }

  @override
  Future<Workout?> loadWorkout(String id) async {
    await _initialize();
    return engine.loadDetail(id);
  }

  @override
  Future<bool> hasWorkout(String id) async {
    await _initialize();
    return (await db.workout(owner!, id, full: false)) != null;
  }

  @override
  Future<WorkoutDraft?> loadDraft() async {
    await _initialize();
    return db.draft(owner!);
  }

  @override
  Future<void> saveDraft(WorkoutDraft draft) async {
    await _initialize();
    await db.saveDraft(owner!, draft);
  }

  @override
  Future<void> clearDraft() async {
    await _initialize();
    await db.clearDraft(owner!);
  }

  @override
  Future<void> saveProgress({
    required int xp,
    required int selectedSport,
    required List<Workout> workouts,
  }) async {
    await _initialize();
    await (await db.database).update(
      'account_state',
      {'selected_sport': selectedSport},
      where: 'owner=?',
      whereArgs: [owner],
    );
  }
}
