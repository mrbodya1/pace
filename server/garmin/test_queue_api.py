"""Receipt/cleanup integration on a disposable PocketBase. Never contacts Garmin."""
import copy
import hashlib
import json
import os
import secrets
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'server'))
from test_support import prepare_test_database

checks = 0
def check(value, label):
    global checks
    assert value, label
    checks += 1

def compact(value):
    return json.dumps(value, separators=(',', ':'), ensure_ascii=False)

def sha(value):
    return hashlib.sha256(value.encode()).hexdigest()

with tempfile.TemporaryDirectory(prefix='pace-garmin-queue-') as folder:
    temp = Path(folder)
    private = temp / 'private'
    private.mkdir()
    prepare_test_database(ROOT, temp)
    with socket.socket() as candidate:
        candidate.bind(('127.0.0.1', 0))
        port = candidate.getsockname()[1]
    env = {**os.environ, 'PACE_GARMIN_RUNTIME': str(private),
           'PACE_GARMIN_DATABASE': str(temp / 'data/data.db'), 'PACE_GARMIN_PYTHON': sys.executable}
    log = (temp / 'backend.log').open('wb')
    def start():
        return subprocess.Popen([str(ROOT / 'server/runtime/pocketbase.exe'), 'serve',
            f'--http=127.0.0.1:{port}', f'--dir={temp / "data"}',
            f'--migrationsDir={ROOT / "server/pb_migrations"}', f'--hooksDir={ROOT / "server/pb_hooks"}'],
            env=env, stdout=log, stderr=log, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    proc = start()
    def req(method, path, body=None, token=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = token
        request = Request(f'http://127.0.0.1:{port}{path}', headers=headers, method=method,
                          data=None if body is None else compact(body).encode())
        try:
            with urlopen(request, timeout=15) as response:
                return response.status, json.loads(response.read())
        except HTTPError as error:
            return error.code, json.loads(error.read())
    def ready():
        for _ in range(100):
            try:
                if req('GET', '/api/health')[0] == 200:
                    return
            except OSError:
                pass
            time.sleep(.1)
        raise AssertionError('Temporary backend startup failed')
    def action(token, name, **body):
        return req('POST', '/api/pace/v2/workouts', {'action': name, **body}, token)
    def queued():
        return json.loads((private / 'inbox.json').read_text(encoding='utf-8'))
    def receipts():
        with closing(sqlite3.connect((temp / 'data/data.db').as_uri() + '?mode=ro', uri=True)) as db:
            return db.execute('SELECT count(*) FROM pace_garmin_receipts').fetchone()[0]
    try:
        ready()
        users = []
        for i in range(2):
            email, password = f'queue-{i}@invalid.example', secrets.token_urlsafe(24)
            code, user = req('POST', '/api/collections/pace_users/records',
                {'email': email, 'password': password, 'passwordConfirm': password})
            assert code == 200
            code, login = req('POST', '/api/collections/pace_users/auth-with-password',
                              {'identity': email, 'password': password})
            assert code == 200
            users.append((user['id'], login['token']))
        owner, token = users[0]
        other_token = users[1][1]
        now = datetime.now(timezone.utc).replace(microsecond=0)
        began = now - timedelta(hours=2)
        iso = lambda date: date.isoformat().replace('+00:00', 'Z')
        config = {'version': 1, 'ownerId': owner, 'sinceUtc': iso(now - timedelta(days=1))}
        route = [{'latitude': 56.7 + i * .0001, 'longitude': 60.6,
                  'timestamp': iso(began + timedelta(seconds=i)), 'accuracy': 5, 'segment': 0} for i in range(2)]
        heart = [{'at': iso(began + timedelta(seconds=i)), 'bpm': 140 + i} for i in range(2)]
        packet = {'source': 'garmin-personal', 'externalId': '123', 'fitSha256': 'a' * 64,
                  'startedAt': iso(began), 'endedAt': iso(began + timedelta(hours=1)),
                  'sport': 'Бег', 'distanceKm': 10, 'durationSeconds': 3600, 'elevationGain': 30,
                  'route': route, 'heartRateSamples': heart, 'receivedAt': iso(now)}
        inbox = {**config, 'activities': [packet]}
        (private / 'import-config.json').write_text(compact(config), encoding='utf-8')
        (private / 'inbox.json').write_text(compact(inbox), encoding='utf-8')
        check(action(None, 'ackGarmin')[0] == 401, 'anonymous cleanup denied')
        check(action(other_token, 'ackGarmin')[1]['available'] is False, 'other owner cannot clean queue')
        code, maintenance = action(token, 'ackGarmin')
        assert code == 200, 'Synthetic maintenance failed with HTTP '+str(code)
        check(maintenance['removed'] == 0 and len(queued()['activities']) == 1,
              'local-only or staged training cannot be acknowledged')
        state = req('GET', '/api/pace/v2/state', token=token)[1]
        epoch = state['epoch']
        sid, upload = 'garmin-personal:123', sha('fixture upload')
        parts = []
        for kind, samples in [('route', route), ('timedRoute', route), ('heartRateSamples', heart)]:
            raw = compact(samples)
            part = {'kind': kind, 'part': 0, 'digest': sha(raw)}
            assert action(token, 'stage', epoch=epoch, sessionId=sid, uploadId=upload, dataJson=raw, **part)[0] == 200
            parts.append(part)
        summary = {'sessionId': sid, 'source': 'garmin-personal', 'externalId': '123',
                   'sourceFitHash': packet['fitSha256'], 'date': iso(began), 'startedAt': iso(began),
                   'endedAt': packet['endedAt'], 'sport': 'Бег', 'distance': 10,
                   'durationSeconds': 3600, 'elevationGain': 30, 'xp': 100}
        derived = {**state['derived'], 'xp': 100}
        body = {'epoch': epoch, 'revision': 0, 'summary': summary, 'fingerprint': upload,
                'manifest': {'uploadId': upload, 'parts': parts}, 'derived': derived}
        broken = copy.deepcopy(body)
        broken['manifest']['parts'] = parts[:2]
        check(action(token, 'commit', **broken)[0] == 400, 'missing HR cannot create receipt')
        broken = copy.deepcopy(body)
        broken['summary']['sourceFitHash'] = 'b' * 64
        check(action(token, 'commit', **broken)[0] == 400, 'wrong source hash cannot create receipt')
        broken['summary'] = {**summary, 'distance': 20}
        check(action(token, 'commit', **broken)[0] == 400, 'changed measurements cannot create receipt')
        check(receipts() == 0 and len(queued()['activities']) == 1, 'failed commit leaves source queue and receipt atomic')
        for changed_kind in ['route', 'heartRateSamples']:
            tampered_upload = sha(changed_kind)
            tampered_parts = []
            for kind, samples in [('route', route), ('timedRoute', route), ('heartRateSamples', heart)]:
                changed_samples = copy.deepcopy(samples)
                if kind == changed_kind:
                    changed_samples[0]['bpm' if kind == 'heartRateSamples' else 'latitude'] += 1
                raw = compact(changed_samples)
                part = {'kind': kind, 'part': 0, 'digest': sha(raw)}
                assert action(token, 'stage', epoch=epoch, sessionId=sid, uploadId=tampered_upload, dataJson=raw, **part)[0] == 200
                tampered_parts.append(part)
            tampered = {**body, 'fingerprint': tampered_upload, 'manifest': {'uploadId': tampered_upload, 'parts': tampered_parts}}
            check(action(token, 'commit', **tampered)[0] == 400 and receipts() == 0,
                  'modified '+changed_kind+' cannot acknowledge original FIT')
        check(action(token, 'commit', **body)[0] == 200 and receipts() == 1, 'receipt created with full committed workout')
        # Simulate loss of the HTTP acknowledgement and restart of the backend.
        proc.terminate()
        proc.wait(timeout=10)
        proc = start()
        ready()
        check(action(token, 'commit', **body)[1]['duplicate'] and receipts() == 1, 'restart and repeated commit keep one receipt')
        check(req('GET', '/api/pace/garmin', token=token)[1]['activities'] == [], 'committed source packet hidden before file cleanup')
        check(req('GET', '/api/collections/pace_garmin_receipts/records', token=token)[0] == 403, 'raw receipts private')
        if os.name == 'nt':
            import msvcrt
            with (private / 'collector.lock').open('a+b') as lock:
                lock.write(b'0')
                lock.flush()
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
                check(action(token, 'ackGarmin')[1]['phase'] == 'busy', 'active collector prevents cleanup race')
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
        check(len(queued()['activities']) == 1, 'busy cleanup leaves queue intact')
        check(action(token, 'ackGarmin')[1]['removed'] == 1 and queued()['activities'] == [], 'only durable packet physically pruned')
        check(action(token, 'ackGarmin')[1]['removed'] == 0, 'repeated cleanup is idempotent')
        detail = action(token, 'detail', epoch=epoch, sessionId=sid)[1]
        check(len(detail['parts']) == 3 and receipts() == 1, 'workout telemetry and receipt retained after cleanup')
        # Simulate an older, fully committed training that predates the new migration.
        (private / 'inbox.json').write_text(compact(inbox), encoding='utf-8')
        with closing(sqlite3.connect(temp / 'data/data.db')) as fixture, fixture:
            fixture.execute('DELETE FROM pace_garmin_receipts')
        check(action(token, 'ackGarmin')[1]['removed'] == 1 and receipts() == 1,
              'pre-upgrade commit reconciles after verifying its complete telemetry')
        changed = copy.deepcopy(inbox)
        changed['activities'][0]['fitSha256'] = 'c' * 64
        (private / 'inbox.json').write_text(compact(changed), encoding='utf-8')
        check(action(token, 'ackGarmin')[1]['removed'] == 0 and len(queued()['activities']) == 1, 'changed source FIT never silently discarded')
        check(not (private / 'personal-api-key.dpapi').exists(), 'maintenance works without key or Garmin login')
        print(f'GARMIN_QUEUE_API_CHECKS_PASSED={checks}; temporary database; no Garmin network')
    finally:
        proc.terminate()
        proc.wait(timeout=10)
        log.close()
