import 'dart:convert';

import '../models/workout.dart';
import '../models/workout_upload.dart';
import '../models/progress_v2.dart';
import '../data/storage/workout_database.dart';
import 'account_service.dart';

class WorkoutSyncV2 {
  WorkoutSyncV2(this.accounts, this.db, this.owner);
  final AccountService accounts;
  final WorkoutDatabase db;
  final String owner;
  void _check() {
    if (accounts.progressOwner != owner || !accounts.hasSession) {
      throw const AccountError('Аккаунт изменился.');
    }
  }

  String digest(String value) => WorkoutUpload.digest(value);
  Future<Map<String, dynamic>> _request([Map<String, dynamic>? body]) {
    _check();
    return accounts.requestWorkoutsV2(owner: owner, action: body);
  }

  Future<void> synchronize() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await _pull();
        await _push();
        // Workout commit is already durable. Maintenance may be retried on the
        // next opening; its failure must not undo a successful upload.
        try {
          await _request({'action': 'ackGarmin'});
        } on AccountError {
          _check();
        }
        return;
      } on WorkoutSyncConflict catch (e) {
        if (e.reason == 'collision') {
          throw const AccountError(
            'Найдены разные записи с одним ID. Локальная тренировка сохранена; нужна проверка.',
          );
        }
        if (attempt == 4) {
          throw const AccountError(
            'Прогресс меняется на другом устройстве. Повтори обновление.',
          );
        }
      }
    }
  }

  Future<void> _pull() async {
    final remote = await _request(), local = await db.state(owner);
    final epoch = remote['epoch'] as String, head = remote['revision'] as int;
    var cursor = local['epoch'] == epoch ? local['revision'] as int : 0;
    if (cursor > head) {
      throw const AccountError(
        'Сервер вернул более старую историю. Локальные данные сохранены.',
      );
    }
    final summaries = <Map<String, dynamic>>[];
    final fingerprints = <String, String>{};
    while (cursor < head) {
      final page = await _request({
        'action': 'list',
        'epoch': epoch,
        'after': cursor,
        'through': head,
      });
      if (page['epoch'] != epoch) {
        throw const FormatException('History epoch mismatch');
      }
      final next = page['next'] as int;
      if (next <= cursor || next > head) {
        throw const FormatException('Invalid history cursor');
      }
      for (final item in page['items'] as List) {
        final summary = Map<String, dynamic>.from(
          (item as Map)['summary'] as Map,
        );
        summaries.add(summary);
        fingerprints[summary['sessionId'] as String] =
            item['fingerprint'] as String;
      }
      cursor = next;
    }
    _check();
    await db.adopt(
      owner,
      epoch,
      head,
      Map<String, dynamic>.from(remote['derived'] as Map),
      summaries,
      fingerprints: fingerprints,
    );
  }

  Future<void> _push() async {
    for (final id in await db.pending(owner)) {
      _check();
      if (!(await db.pending(owner)).contains(id)) continue;
      final state = await db.state(owner), workout = await db.base(owner, id);
      final result = ProgressV2.append(db.decode(state['canonical']), workout);
      final upload = WorkoutUpload(workout),
          parts = upload.parts,
          payloads = upload.payloads,
          fingerprint = upload.fingerprint;
      for (var i = 0; i < parts.length; i++) {
        final ack = await _request({
          'action': 'stage',
          'epoch': state['epoch'],
          'sessionId': id,
          'uploadId': fingerprint,
          ...parts[i],
          'dataJson': payloads[i],
        });
        if (ack['digest'] != parts[i]['digest']) {
          throw const FormatException('Telemetry acknowledgement mismatch');
        }
      }
      final response = await _request({
        'action': 'commit',
        'epoch': state['epoch'],
        'revision': state['revision'],
        'summary': ProgressV2.summary(result.workout),
        'fingerprint': fingerprint,
        'manifest': {'uploadId': fingerprint, 'parts': parts},
        'derived': result.state,
      });
      _check();
      if ((response['summary'] as Map?)?['sessionId'] != id ||
          response['fingerprint'] != fingerprint ||
          response['epoch'] != state['epoch'] ||
          response['revision'] is! int ||
          (response['revision'] as int) <= (state['revision'] as int)) {
        throw const FormatException('Invalid workout acknowledgement');
      }
      if (response['duplicate'] == true) {
        await _pull();
        continue;
      }
      await db.adopt(
        owner,
        response['epoch'] as String,
        response['revision'] as int,
        Map<String, dynamic>.from(response['derived'] as Map),
        [Map<String, dynamic>.from(response['summary'] as Map)],
        acknowledged: id,
        fingerprints: {id: fingerprint},
      );
    }
  }

  Future<Workout?> loadDetail(String id) async {
    final database = await db.database;
    final known = await database.query(
      'workout_telemetry',
      columns: ['kind'],
      where: 'owner=? AND session_id=?',
      whereArgs: [owner, id],
    );
    if (known.length == 3) return db.workout(owner, id);
    final state = await db.state(owner), epoch = state['epoch'] as String;
    var offset = 0;
    final data = <String, List<dynamic>>{
      'route': [],
      'timedRoute': [],
      'heartRateSamples': [],
    };
    do {
      final response = await _request({
        'action': 'detail',
        'epoch': epoch,
        'sessionId': id,
        'offset': offset,
      });
      for (final raw in response['parts'] as List) {
        final part = Map<String, dynamic>.from(raw as Map),
            json = part['dataJson'] as String;
        if (digest(json) != part['digest']) {
          throw const FormatException('Invalid telemetry digest');
        }
        data[part['kind']]!.addAll(jsonDecode(json) as List);
      }
      final next = response['next'] as int;
      if (response['hasMore'] == true && next <= offset) {
        throw const FormatException('Invalid detail cursor');
      }
      offset = next;
      if (response['hasMore'] != true) break;
    } while (true);
    _check();
    await database.transaction((tx) async {
      final current = await db.state(owner, executor: tx);
      if (current['epoch'] != epoch) {
        throw const AccountError('История обновлена. Открой тренировку снова.');
      }
      final workout = await db.workout(owner, id, full: false, executor: tx);
      if (workout == null) throw const AccountError('Тренировка недоступна.');
      await db.putTelemetry(
        tx,
        owner,
        Workout.fromJson({...workout.toJson(), ...data}),
      );
    });
    return db.workout(owner, id);
  }
}
