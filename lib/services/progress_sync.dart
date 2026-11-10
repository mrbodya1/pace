import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/achievement.dart';
import '../models/workout.dart';
import 'personal_record_engine.dart';
import 'account_service.dart';

export 'account_service.dart' show ProgressConflict;

class ProgressSnapshot {
  const ProgressSnapshot(this.revision, this.data);
  final int revision;
  final Map<String, dynamic>? data;
  factory ProgressSnapshot.fromJson(Map<String, dynamic> json) {
    final revision = json['revision'];
    if (revision is! int ||
        revision < 0 ||
        (revision == 0 && json['data'] != null) ||
        (revision > 0 && json['data'] is! Map)) {
      throw const FormatException('Invalid progress revision');
    }
    return ProgressSnapshot(
      revision,
      json['data'] == null
          ? null
          : Map<String, dynamic>.from(json['data'] as Map),
    );
  }
}

abstract interface class ProgressRemote {
  Future<ProgressSnapshot> load();
  Future<ProgressSnapshot> save(int revision, Map<String, dynamic> data);
}

class AccountProgressRemote implements ProgressRemote {
  AccountProgressRemote(this.accounts) : owner = accounts.progressOwner!;
  final AccountService accounts;
  final String owner;
  @override
  Future<ProgressSnapshot> load() async =>
      ProgressSnapshot.fromJson(await accounts.requestProgress(owner: owner));
  @override
  Future<ProgressSnapshot> save(
    int revision,
    Map<String, dynamic> data,
  ) async => ProgressSnapshot.fromJson(
    await accounts.requestProgress(
      owner: owner,
      revision: revision,
      data: data,
    ),
  );
}

abstract final class ProgressMerger {
  static Map<String, dynamic> copy(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  static Map<String, dynamic> empty() => {
    'version': 1,
    'xp': 0,
    'selectedSport': 0,
    'workouts': <dynamic>[],
    'achievements': AchievementState().toJson(),
    'records': PersonalRecordEngine.toJson({}),
    'imports': <String>[],
  };
  static List<Workout> workouts(Map<String, dynamic> data) =>
      (data['workouts'] as List? ?? [])
          .map((w) => Workout.fromJson(Map<String, dynamic>.from(w as Map)))
          .toList();
  static String digest(Object data) =>
      sha256.convert(utf8.encode(jsonEncode(data))).toString();
  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    if (raw.containsKey('version') && raw['version'] != 1) {
      throw const FormatException('Unknown progress version');
    }
    final data = copy(raw)..remove('_sync');
    final history = workouts(data);
    final ids = <String>{};
    final saved = <Map<String, dynamic>>[];
    for (final w in history) {
      if (w.xp < 0 ||
          !w.distance.isFinite ||
          w.distance < 0 ||
          w.duration.isNegative) {
        throw const FormatException('Invalid workout');
      }
      final json = w.toJson();
      json['sessionId'] = w.sessionId == null || w.sessionId!.isEmpty
          ? 'legacy-${digest(json)}'
          : w.sessionId;
      if (!ids.add(json['sessionId'] as String)) {
        throw const FormatException('Duplicate session');
      }
      saved.add(json);
    }
    final xp = data['xp'] ?? 0;
    if (xp is! int || xp < 0) throw const FormatException('Invalid XP');
    data['version'] = 1;
    data['xp'] = xp;
    data['workouts'] = saved;
    data['achievements'] = AchievementEngine.restore(
      data['achievements'],
      history,
    ).toJson();
    data['records'] = PersonalRecordEngine.toJson(
      PersonalRecordEngine.restore(data['records'], history),
    );
    data['imports'] ??= <String>[];
    return data;
  }

  static String importId(Map<String, dynamic> legacy) {
    final ids = workouts(legacy).map((w) => w.sessionId).toList()
      ..sort((a, b) => a!.compareTo(b!));
    return digest(ids);
  }

  static Map<String, dynamic> merge(
    Map<String, dynamic>? remote,
    Map<String, dynamic> local,
  ) {
    var data = remote == null ? empty() : normalize(remote);
    final sync = Map<String, dynamic>.from(local['_sync'] as Map? ?? {});
    final rawLegacy = sync['legacy'];
    if (rawLegacy != null) {
      final legacy = normalize(Map<String, dynamic>.from(rawLegacy as Map));
      final id = importId(legacy);
      final imports = List<String>.from(data['imports'] as List);
      if (!imports.contains(id)) {
        final oldHistory = workouts(legacy);
        final credit =
            (legacy['xp'] as int) - oldHistory.fold<int>(0, (s, w) => s + w.xp);
        if (remote == null) {
          // Preserve the first device's pre-sync balance exactly, including
          // historical achievements which deliberately earned no retroactive XP.
          data = copy(legacy);
          data['legacyCredit'] = credit;
        } else {
          final current = AchievementEngine.restore(
            data['achievements'],
            workouts(data),
          );
          final old = AchievementEngine.restore(
            legacy['achievements'],
            oldHistory,
          );
          // Restore paid legacy awards only when they are not already claimed.
          final historicalOnly = {...current.unlocked};
          for (final e in old.unlocked.entries) {
            if (e.value.historical) {
              historicalOnly.putIfAbsent(e.key, () => e.value);
            }
          }
          data['achievements'] = AchievementState(historicalOnly).toJson();
          for (final w in oldHistory.reversed) {
            _append(data, _base(w));
          }
          if (!data.containsKey('legacyCredit')) {
            data['legacyCredit'] = credit;
            data['xp'] = (data['xp'] as int) + credit;
          }
        }
        data['imports'] = {
          ...imports,
          ...List<String>.from(data['imports'] as List? ?? []),
          id,
        }.toList();
      }
    }
    for (final raw in sync['pending'] as List? ?? []) {
      _append(data, Workout.fromJson(Map<String, dynamic>.from(raw as Map)));
    }
    if ((data['xp'] as int) < 0) {
      throw const FormatException('Invalid merged balance');
    }
    return data;
  }

  static Workout _base(Workout w) {
    final json = w.toJson()..['xp'] = w.xp - w.achievementXp - w.recordXp;
    json.remove('achievementXp');
    json.remove('achievementIds');
    json.remove('recordXp');
    json.remove('records');
    if ((json['xp'] as int) < 0) throw const FormatException('Invalid base XP');
    return Workout.fromJson(json);
  }

  static void _append(Map<String, dynamic> data, Workout w) {
    final history = workouts(data);
    if (w.sessionId == null || w.sessionId!.isEmpty) {
      throw const FormatException('Missing session');
    }
    if (history.any((v) => v.sessionId == w.sessionId)) return;
    final achievements = AchievementEngine.apply(
      AchievementEngine.restore(data['achievements'], history),
      history,
      w,
    );
    final records = PersonalRecordEngine.apply(
      PersonalRecordEngine.restore(data['records'], history),
      w,
    );
    final saved = w.withAchievements(
      achievements.xp,
      achievements.awards.map((r) => r.id).toList(),
      recordReward: records.xp,
      recordResults: records.awards,
    );
    data['xp'] = (data['xp'] as int) + saved.xp;
    data['workouts'] = [saved.toJson(), ...history.map((w) => w.toJson())];
    data['achievements'] = achievements.state.toJson();
    data['records'] = PersonalRecordEngine.toJson(records.best);
  }
}
