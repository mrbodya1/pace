import '../../services/account_service.dart';
import '../../services/progress_sync.dart';
import '../../services/personal_record_engine.dart';

import 'dart:convert';

import 'sqlite_workout_storage.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workout.dart';
import '../../models/achievement.dart';
import '../../models/workout_draft.dart';

class LocalStorageService {
  LocalStorageService({
    Future<SharedPreferences> Function()? preferences,
    this.owner,
    this.remote,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;
  factory LocalStorageService.forAccount(AccountService accounts) {
    if (accounts.progressOwner == null) {
      throw const AccountError('Сначала войди в аккаунт.');
    }
    return SqliteWorkoutStorage(accounts: accounts);
  }
  final String? owner;
  final ProgressRemote? remote;
  bool get supportsSync => remote != null;
  bool get pagedHistory => false;
  Future<List<Workout>> loadHistory({
    int limit = 20,
    int offset = 0,
    String? sport,
  }) async {
    final data = await loadProgress();
    return (data?['workouts'] as List? ?? [])
        .map((w) => Workout.fromJson(Map<String, dynamic>.from(w as Map)))
        .where((w) => sport == null || w.sport == sport)
        .skip(offset)
        .take(limit)
        .toList();
  }

  Future<Workout?> loadWorkout(String id) async {
    final data = await loadProgress();
    return (data?['workouts'] as List? ?? [])
        .map((w) => Workout.fromJson(Map<String, dynamic>.from(w as Map)))
        .where((w) => w.sessionId == id)
        .firstOrNull;
  }

  Future<bool> hasWorkout(String id) async => (await loadWorkout(id)) != null;
  static final _syncing = <String, Future<void>>{};
  final Future<SharedPreferences> Function() _preferences;
  static const String _legacyKey = 'pace_local_data';
  String get _storageKey => owner == null
      ? _legacyKey
      : 'pace_progress_v2:${Uri.encodeComponent(owner!)}';
  static const String draftKey = 'pace_active_workout';
  String get _draftKey => owner == null ? draftKey : '$_storageKey:draft';
  static Future<void>? _pending;
  static final _requiresReload = <String>{};

  Future<void> _recoverCache(SharedPreferences prefs) async {
    if (!_requiresReload.contains(_storageKey)) return;
    await prefs.reload();
    _requiresReload.remove(_storageKey);
  }

  Future<bool> _persist(
    SharedPreferences prefs,
    Future<bool> Function() operation,
  ) async {
    try {
      final saved = await operation();
      if (saved) return true;
    } catch (_) {
      _requiresReload.add(_storageKey);
      try {
        await _recoverCache(prefs);
      } catch (_) {
        /* Reads must retry recovery before using this cache. */
      }
      rethrow;
    }
    // SharedPreferences mutates its cache before the platform write completes.
    // Reload persisted state so a retry cannot mistake a failed write for a commit.
    _requiresReload.add(_storageKey);
    try {
      await _recoverCache(prefs);
    } catch (_) {
      /* Keep the cache blocked. */
    }
    return false;
  }

  Future<bool> _setString(SharedPreferences prefs, String key, String value) =>
      _persist(prefs, () => prefs.setString(key, value));
  Future<bool> _remove(SharedPreferences prefs, String key) =>
      _persist(prefs, () => prefs.remove(key));

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
    await _recoverCache(prefs);
    final raw = prefs.getString(_draftKey);
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
      if (!await _setString(prefs, _draftKey, raw)) {
        throw StateError('Draft not saved');
      }
    });
  }

  Future<void> clearDraft() => _write(() async {
    final prefs = await _preferences();
    if (prefs.containsKey(_draftKey) && !await _remove(prefs, _draftKey)) {
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
    bool clearActiveDraft = true,
  }) => _write(() async {
    if (workout.sessionId == null || workout.sessionId!.isEmpty) {
      throw ArgumentError('A completed session requires an ID');
    }
    final prefs = await _preferences();
    final raw = await _read(prefs);
    final data = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(raw);
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
        xpBefore: total,
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
      if (owner != null) {
        final sync = Map<String, dynamic>.from(data['_sync'] as Map? ?? {});
        sync['pending'] = [...sync['pending'] as List? ?? [], workout.toJson()];
        data['_sync'] = sync;
        data['version'] = 1;
      }
      if (!await _setString(prefs, _storageKey, jsonEncode(data))) {
        throw StateError('Workout not saved');
      }
    }
    // History is authoritative if the process stops between these writes.
    try {
      if (clearActiveDraft && prefs.containsKey(_draftKey)) {
        await _remove(prefs, _draftKey);
      }
    } catch (_) {}
    return (
      xp: total,
      workouts: history,
      achievements: achievements,
      achievementXp: previous?.achievementXp ?? achievementXp,
      recordXp: previous?.recordXp ?? recordXp,
    );
  });

  Future<Map<String, dynamic>?> loadProgress() =>
      _write(() async => _read(await _preferences()));

  Future<Map<String, dynamic>?> _read(SharedPreferences prefs) async {
    await _recoverCache(prefs);
    final existing = prefs.getString(_storageKey);
    if (existing != null) {
      return Map<String, dynamic>.from(jsonDecode(existing) as Map);
    }
    if (owner == null) return null;
    final legacyRaw = prefs.getString(_legacyKey);
    final legacyDraft = prefs.getString(draftKey);
    if (legacyRaw == null && legacyDraft == null) return null;
    final claimed = prefs.getString('pace_progress_legacy_owner');
    final profileOwner = prefs.getString('pace_profile_legacy_owner');
    if ((claimed != null && claimed != owner) ||
        (claimed == null && profileOwner != null && profileOwner != owner)) {
      return null;
    }
    if (!await _setString(prefs, 'pace_progress_legacy_owner', owner!)) {
      throw StateError('Legacy owner not saved');
    }
    // Preserve the original global keys as a recovery backup; only their owner
    // can import them. Copy the draft before committing the imported progress.
    if (legacyDraft != null &&
        !prefs.containsKey(_draftKey) &&
        !await _setString(prefs, _draftKey, legacyDraft)) {
      throw StateError('Legacy draft not saved');
    }
    final baseline = legacyRaw == null
        ? ProgressMerger.empty()
        : ProgressMerger.normalize(
            Map<String, dynamic>.from(jsonDecode(legacyRaw) as Map),
          );
    final data = ProgressMerger.copy(baseline);
    data['_sync'] = {
      'pending': <dynamic>[],
      if (legacyRaw != null) 'legacy': baseline,
    };
    if (!await _setString(prefs, _storageKey, jsonEncode(data))) {
      throw StateError('Legacy progress not saved');
    }
    return data;
  }

  Future<void> synchronize() {
    if (remote == null || owner == null) return Future.value();
    final existing = _syncing[_storageKey];
    if (existing != null) return existing;
    final task = _synchronize();
    _syncing[_storageKey] = task;
    task.then(
      (_) {
        if (identical(_syncing[_storageKey], task)) {
          _syncing.remove(_storageKey);
        }
      },
      onError: (Object _, StackTrace _) {
        if (identical(_syncing[_storageKey], task)) {
          _syncing.remove(_storageKey);
        }
      },
    );
    return task;
  }

  Future<void> _synchronize([int round = 0]) async {
    // No network operation holds the write queue: a new workout can always be
    // committed locally while a slow upload is in flight.
    final local = await loadProgress() ?? ProgressMerger.empty();
    final sent = Map<String, dynamic>.from(local['_sync'] as Map? ?? {});
    final pending = sent['pending'] as List? ?? [];
    final ids = pending.map((w) => (w as Map)['sessionId']).toSet();
    ProgressSnapshot? accepted;
    for (var attempt = 0; attempt < 4; attempt++) {
      final snapshot = await remote!.load();
      final localRevision = (sent['revision'] as num?)?.toInt() ?? 0;
      final serverIds = snapshot.data == null
          ? <String?>{}
          : ProgressMerger.workouts(snapshot.data!)
                .map((w) => w.sessionId)
                .toSet();
      final importIds = sent['legacy'] == null
          ? <String?>{}
          : ProgressMerger.workouts(
              Map<String, dynamic>.from(sent['legacy'] as Map),
            ).map((w) => w.sessionId).toSet();
      final missing = ProgressMerger.workouts(local).any(
        (w) =>
            !serverIds.contains(w.sessionId) &&
            !ids.contains(w.sessionId) &&
            !importIds.contains(w.sessionId),
      );
      if (snapshot.revision < localRevision || missing) {
        throw const AccountError(
          'Сервер вернул неполную историю. Локальная копия сохранена; нужна проверка сервера.',
        );
      }
      if (pending.isEmpty && sent['legacy'] == null) {
        accepted = snapshot;
        break;
      }
      final merged = ProgressMerger.merge(snapshot.data, local);
      try {
        accepted = await remote!.save(snapshot.revision, merged);
        // A successful HTTP status alone is not an acknowledgement of our data.
        final confirmed = ProgressMerger.normalize(accepted.data!);
        final confirmedIds = ProgressMerger.workouts(confirmed)
            .map((w) => w.sessionId)
            .toSet();
        if (!confirmedIds.containsAll(ids) ||
            accepted.revision <= snapshot.revision ||
            (sent['legacy'] != null &&
                !(confirmed['imports'] as List).contains(
                  ProgressMerger.importId(
                    Map<String, dynamic>.from(sent['legacy'] as Map),
                  ),
                ))) {
          throw const FormatException('Server did not acknowledge progress');
        }
        break;
      } on ProgressConflict {
        if (attempt == 3) rethrow;
      }
    }
    if (accepted == null) throw StateError('Progress not synchronized');
    final ack = accepted;
    var hasMore = false;
    await _write(() async {
      final prefs = await _preferences();
      final current = await _read(prefs) ?? ProgressMerger.empty();
      final sync = Map<String, dynamic>.from(current['_sync'] as Map? ?? {});
      final remaining = (sync['pending'] as List? ?? [])
          .where((w) => !ids.contains((w as Map)['sessionId']))
          .toList();
      final retainedLegacy = sent['legacy'] == null ? sync['legacy'] : null;
      hasMore = remaining.isNotEmpty || retainedLegacy != null;
      final rebased = ProgressMerger.merge(ack.data, {
        '_sync': {'pending': remaining, 'legacy': ?retainedLegacy},
      });
      rebased['selectedSport'] =
          current['selectedSport'] ?? rebased['selectedSport'] ?? 0;
      rebased['_sync'] = {
        'pending': remaining,
        'legacy': ?retainedLegacy,
        'revision': ack.revision,
        'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
      };
      if (!await _setString(prefs, _storageKey, jsonEncode(rebased))) {
        throw StateError('Sync acknowledgement not saved');
      }
    });
    if (hasMore && round < 3) await _synchronize(round + 1);
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
      final previous = await _read(prefs);
      final merged = previous == null
          ? (owner == null ? <String, dynamic>{} : ProgressMerger.empty())
          : Map<String, dynamic>.from(previous);
      if (owner == null) {
        merged.addAll(data);
      } else {
        // A stale UI settings snapshot must never overwrite a newer sync/finish.
        merged['selectedSport'] = selectedSport;
      }
      if (!await _setString(prefs, _storageKey, jsonEncode(merged))) {
        throw StateError('Progress not saved');
      }
    });
  }
}
