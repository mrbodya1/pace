import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/workout.dart';
import '../../models/workout_draft.dart';
import '../../models/progress_v2.dart';
import '../../models/workout_upload.dart';
import '../../services/account_service.dart';
import 'sqlite_open.dart';

class WorkoutDatabase {
  WorkoutDatabase({Future<Database> Function()? open})
    : _open = open ?? openWorkoutDatabase;
  static final instance = WorkoutDatabase();
  final Future<Database> Function() _open;
  Future<Database>? _database;
  Future<Database> get database => _database ??= _initialize();
  Future<Database> _initialize() async {
    final db = await _open();
    await db.execute('PRAGMA foreign_keys=ON');
    await db.transaction((tx) async {
      await tx.execute(
        'CREATE TABLE IF NOT EXISTS account_state(owner TEXT PRIMARY KEY,epoch TEXT NOT NULL,revision INTEGER NOT NULL,canonical TEXT NOT NULL,derived TEXT NOT NULL,selected_sport INTEGER NOT NULL DEFAULT 0)',
      );
      await tx.execute(
        'CREATE TABLE IF NOT EXISTS workout_rows(owner TEXT NOT NULL,session_id TEXT NOT NULL,started_at TEXT NOT NULL,sport TEXT NOT NULL,summary TEXT NOT NULL,base TEXT NOT NULL,pending INTEGER NOT NULL,server_revision INTEGER,PRIMARY KEY(owner,session_id))',
      );
      await tx.execute(
        'CREATE INDEX IF NOT EXISTS workout_history ON workout_rows(owner,started_at DESC,session_id DESC)',
      );
      await tx.execute(
        'CREATE INDEX IF NOT EXISTS workout_pending ON workout_rows(owner,pending)',
      );
      await tx.execute(
        'CREATE INDEX IF NOT EXISTS workout_sport_history ON workout_rows(owner,sport,started_at DESC,session_id DESC)',
      );
      await tx.execute(
        'CREATE TABLE IF NOT EXISTS workout_telemetry(owner TEXT NOT NULL,session_id TEXT NOT NULL,kind TEXT NOT NULL,data TEXT NOT NULL,PRIMARY KEY(owner,session_id,kind),FOREIGN KEY(owner,session_id) REFERENCES workout_rows(owner,session_id) ON DELETE CASCADE)',
      );
      await tx.execute(
        'CREATE TABLE IF NOT EXISTS workout_drafts(owner TEXT PRIMARY KEY,data TEXT NOT NULL)',
      );
    });
    return db;
  }

  Future<void> close() async {
    final db = await _database;
    await db?.close();
    _database = null;
  }

  Map<String, dynamic> decode(Object? raw) =>
      Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
  Future<Map<String, dynamic>> state(
    String owner, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final rows = await db.query(
      'account_state',
      where: 'owner=?',
      whereArgs: [owner],
    );
    if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.single);
    final empty = jsonEncode(ProgressV2.empty());
    await db.insert('account_state', {
      'owner': owner,
      'epoch': '',
      'revision': 0,
      'canonical': empty,
      'derived': empty,
      'selected_sport': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return Map<String, dynamic>.from(
      (await db.query(
        'account_state',
        where: 'owner=?',
        whereArgs: [owner],
      )).single,
    );
  }

  Future<List<Workout>> history(
    String owner, {
    int limit = 20,
    int offset = 0,
    String? sport,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final rows = await db.query(
      'workout_rows',
      columns: ['summary'],
      where: sport == null ? 'owner=?' : 'owner=? AND sport=?',
      whereArgs: sport == null ? [owner] : [owner, sport],
      orderBy: 'started_at DESC,session_id DESC',
      limit: limit,
      offset: offset,
    );
    final list = rows.map((r) => Workout.fromJson(decode(r['summary'])));
    return list.toList();
  }

  Future<Workout?> workout(
    String owner,
    String sessionId, {
    bool full = true,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final rows = await db.query(
      'workout_rows',
      where: 'owner=? AND session_id=?',
      whereArgs: [owner, sessionId],
    );
    if (rows.isEmpty) return null;
    final data = decode(rows.single['summary']);
    if (full) {
      for (final row in await db.query(
        'workout_telemetry',
        where: 'owner=? AND session_id=?',
        whereArgs: [owner, sessionId],
      )) {
        data[row['kind'] as String] = jsonDecode(row['data'] as String);
      }
    }
    return Workout.fromJson(data);
  }

  Future<void> putTelemetry(
    DatabaseExecutor tx,
    String owner,
    Workout w,
  ) async {
    final json = w.toJson();
    for (final key in ['route', 'timedRoute', 'heartRateSamples']) {
      await tx.insert('workout_telemetry', {
        'owner': owner,
        'session_id': w.sessionId!,
        'kind': key,
        'data': jsonEncode(json[key] ?? []),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<({Workout workout, int achievementXp, int recordXp})> complete(
    String owner,
    Workout incoming,
    int selectedSport, {
    bool clearDraft = true,
  }) async {
    if (incoming.sessionId == null || incoming.sessionId!.isEmpty) {
      throw ArgumentError('Missing session ID');
    }
    final db = await database;
    return db.transaction((tx) async {
      final old = await workout(owner, incoming.sessionId!, executor: tx);
      if (old != null) {
        return (
          workout: old,
          achievementXp: old.achievementXp,
          recordXp: old.recordXp,
        );
      }
      final current = await state(owner, executor: tx);
      final result = ProgressV2.append(decode(current['derived']), incoming);
      await tx.insert('workout_rows', {
        'owner': owner,
        'session_id': incoming.sessionId!,
        'started_at': incoming.date.toUtc().toIso8601String(),
        'sport': incoming.sport,
        'summary': jsonEncode(ProgressV2.summary(result.workout)),
        'base': jsonEncode(ProgressV2.summary(ProgressV2.base(incoming))),
        'pending': 1,
      });
      await putTelemetry(tx, owner, incoming);
      await tx.update(
        'account_state',
        {'derived': jsonEncode(result.state), 'selected_sport': selectedSport},
        where: 'owner=?',
        whereArgs: [owner],
      );
      if (clearDraft) {
        await tx.delete('workout_drafts', where: 'owner=?', whereArgs: [owner]);
      }
      return (
        workout: result.workout,
        achievementXp: result.achievementXp,
        recordXp: result.recordXp,
      );
    });
  }

  Future<List<String>> pending(String owner) async =>
      (await (await database).query(
        'workout_rows',
        columns: ['session_id'],
        where: 'owner=? AND pending=1',
        whereArgs: [owner],
        orderBy: 'rowid',
      )).map((r) => r['session_id'] as String).toList();
  Future<Workout> base(String owner, String id) async {
    return _base(await database, owner, id);
  }

  Future<Workout> _base(DatabaseExecutor db, String owner, String id) async {
    final row = (await db.query(
      'workout_rows',
      where: 'owner=? AND session_id=?',
      whereArgs: [owner, id],
    )).single;
    final data = decode(row['base']);
    for (final part in await db.query(
      'workout_telemetry',
      where: 'owner=? AND session_id=?',
      whereArgs: [owner, id],
    )) {
      data[part['kind'] as String] = jsonDecode(part['data'] as String);
    }
    return Workout.fromJson(data);
  }

  Future<void> adopt(
    String owner,
    String epoch,
    int revision,
    Map<String, dynamic> canonical,
    List<Map<String, dynamic>> summaries, {
    String? acknowledged,
    Map<String, String>? fingerprints,
  }) async {
    final db = await database;
    await db.transaction((tx) async {
      final old = await state(owner, executor: tx);
      if (old['epoch'] == epoch && (old['revision'] as int) > revision) return;
      if (old['epoch'] != '' && old['epoch'] != epoch) {
        await tx.delete('workout_rows', where: 'owner=?', whereArgs: [owner]);
        await tx.delete('workout_drafts', where: 'owner=?', whereArgs: [owner]);
      }
      for (final summary in summaries) {
        final w = Workout.fromJson(summary),
            id = summary['sessionId'] as String;
        final existing = await tx.query(
          'workout_rows',
          columns: ['session_id', 'pending'],
          where: 'owner=? AND session_id=?',
          whereArgs: [owner, id],
        );
        if (existing.isNotEmpty &&
            existing.single['pending'] == 1 &&
            fingerprints != null) {
          final local = WorkoutUpload(await _base(tx, owner, id));
          if (fingerprints[id] != local.fingerprint) {
            throw const WorkoutSyncConflict('collision');
          }
        }
        final fields = {
          'started_at': w.date.toUtc().toIso8601String(),
          'sport': w.sport,
          'summary': jsonEncode(summary),
          'pending': 0,
          'server_revision': revision,
        };
        if (existing.isEmpty) {
          await tx.insert('workout_rows', {
            'owner': owner,
            'session_id': id,
            'base': jsonEncode(ProgressV2.summary(ProgressV2.base(w))),
            ...fields,
          });
        } else {
          await tx.update(
            'workout_rows',
            fields,
            where: 'owner=? AND session_id=?',
            whereArgs: [owner, id],
          );
        }
      }
      if (acknowledged != null) {
        await tx.update(
          'workout_rows',
          {'pending': 0},
          where: 'owner=? AND session_id=?',
          whereArgs: [owner, acknowledged],
        );
      }
      var derived = Map<String, dynamic>.from(canonical);
      for (final pending in await tx.query(
        'workout_rows',
        where: 'owner=? AND pending=1',
        whereArgs: [owner],
        orderBy: 'rowid',
      )) {
        final data = decode(pending['base']);
        for (final part in await tx.query(
          'workout_telemetry',
          where: 'owner=? AND session_id=?',
          whereArgs: [owner, pending['session_id']],
        )) {
          data[part['kind'] as String] = jsonDecode(part['data'] as String);
        }
        final result = ProgressV2.append(derived, Workout.fromJson(data));
        derived = result.state;
        await tx.update(
          'workout_rows',
          {'summary': jsonEncode(ProgressV2.summary(result.workout))},
          where: 'owner=? AND session_id=?',
          whereArgs: [owner, pending['session_id']],
        );
      }
      await tx.update(
        'account_state',
        {
          'epoch': epoch,
          'revision': revision,
          'canonical': jsonEncode(canonical),
          'derived': jsonEncode(derived),
        },
        where: 'owner=?',
        whereArgs: [owner],
      );
    });
  }

  Future<WorkoutDraft?> draft(String owner) async {
    final rows = await (await database).query(
      'workout_drafts',
      where: 'owner=?',
      whereArgs: [owner],
    );
    return rows.isEmpty
        ? null
        : WorkoutDraft.fromJson(decode(rows.single['data']));
  }

  Future<void> saveDraft(String owner, WorkoutDraft draft) async {
    await (await database).insert('workout_drafts', {
      'owner': owner,
      'data': jsonEncode(draft.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearDraft(String owner) async {
    await (await database).delete(
      'workout_drafts',
      where: 'owner=?',
      whereArgs: [owner],
    );
  }
}
