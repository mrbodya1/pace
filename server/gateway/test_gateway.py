"""Exercise the actual Caddy config against a local fake backend, never PocketBase."""
import argparse
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


class Backend(BaseHTTPRequestHandler):
    calls = []
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def handle(self):
        try:
            super().handle()
        except (ConnectionResetError, BrokenPipeError):
            pass

    def handle_request(self):
        self.connection.settimeout(3)
        body = b''
        try:
            body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        except (TimeoutError, OSError):
            return
        record = {'method': self.command, 'path': self.path,
                  'xff': self.headers.get('X-Forwarded-For'),
                  'realIp': self.headers.get('X-Real-IP'),
                  'forwarded': self.headers.get('Forwarded'),
                  'authorization': self.headers.get('Authorization'),
                  'bytes': len(body)}
        self.calls.append(record)
        data = json.dumps(record).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = handle_request
    do_TRACE = do_CONNECT = handle_request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--caddy', default=os.environ.get('CADDY_EXE',
                        r'D:\Applications\HomeServer\Caddy\bin\caddy.exe'))
    args = parser.parse_args()
    caddy = Path(args.caddy)
    if not caddy.is_file():
        raise SystemExit('Set CADDY_EXE or --caddy to a verified Caddy binary.')
    config = Path(__file__).with_name('Caddyfile').read_text(encoding='utf-8-sig')
    port, backend_port = free_port(), free_port()
    backend = ThreadingHTTPServer(('127.0.0.1', backend_port), Backend)
    threading.Thread(target=backend.serve_forever, daemon=True).start()
    checked = 0
    with tempfile.TemporaryDirectory(prefix='pace-gateway-test-') as temp:
        temp = Path(temp)
        config = config.replace(':8091', f':{port}').replace('127.0.0.1:8090', f'127.0.0.1:{backend_port}')
        config = config.replace('D:/Applications/HomeServer/Caddy/data', (temp / 'data').as_posix())
        file = temp / 'Caddyfile'
        file.write_text(config, encoding='utf-8')
        result = subprocess.run([str(caddy), 'adapt', '--config', str(file), '--adapter', 'caddyfile'],
                                capture_output=True, check=True)
        adapted = json.loads(result.stdout)
        listeners = [listener for server in adapted['apps']['http']['servers'].values()
                     for listener in server['listen']]
        assert listeners == [f'127.0.0.1:{port}'], listeners
        assert adapted.get('admin', {}).get('disabled') is True
        log = (temp / 'caddy.log').open('wb')
        process = subprocess.Popen([str(caddy), 'run', '--config', str(file), '--adapter', 'caddyfile'],
                                   stdout=log, stderr=log)

        def request(method, path, body=None, headers=None):
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=8)
            all_headers = {'Host': 'pace-test.example', 'Content-Type': 'application/json'}
            all_headers.update(headers or {})
            try:
                conn.request(method, path, body=body, headers=all_headers)
                response = conn.getresponse()
                return response.status, response.read(), dict(response.getheaders())
            finally:
                conn.close()

        try:
            for _ in range(100):
                try:
                    if request('GET', '/api/health')[0] == 200:
                        break
                except OSError:
                    if process.poll() is not None:
                        raise AssertionError('Caddy exited: ' + (temp / 'caddy.log').read_text(errors='replace'))
                time.sleep(0.05)
            else:
                raise AssertionError('Caddy did not start')
            Backend.calls.clear()
            routes = [('GET', '/api/health'), ('POST', '/api/collections/pace_users/records'),
                      ('POST', '/api/collections/pace_users/auth-with-password'),
                      ('POST', '/api/collections/pace_users/auth-refresh'),
                      ('PATCH', '/api/collections/pace_users/records/aaaaaaaaaaaaaaa'),
                      ('GET', '/api/pace/progress'), ('PUT', '/api/pace/progress'), ('GET', '/api/pace/garmin'), ('POST', '/api/pace/garmin/refresh'), ('GET', '/api/pace/community'), ('POST', '/api/pace/community/action'), ('GET','/api/pace/garmin/status')]
            for method, path in routes:
                status, data, headers = request(method, path, None if method == 'GET' else b'{}',
                                                {'Authorization': 'fixture-token'})
                assert status == 200, (method, path, status, data)
                value = json.loads(data)
                assert (value['method'], value['path']) == (method, path)
                assert value['authorization'] == 'fixture-token'
                assert headers.get('Cache-Control') == 'no-store'
                checked += 1
                assert request('OPTIONS', path, headers={'Origin': 'http://localhost:5050',
                               'Access-Control-Request-Method': method})[0] == 200
                checked += 1
            denied = [('/', 'GET'), ('/_/', 'GET'), ('/api/settings', 'GET'),
                      ('/api/backups', 'GET'), ('/api/collections', 'GET'),
                      ('/api/collections/_superusers/auth-with-password', 'POST'),
                      ('/api/batch', 'POST'), ('/api/files/test/file', 'GET'),
                      ('/api/collections/pace_users/records', 'GET'),
                      ('/api/collections/pace_users/records/aaaaaaaaaaaaaaa', 'DELETE'),
                      ('/api/collections/pace_users/auth-methods', 'GET'),
                      ('/api/health', 'POST'), ('/api/pace/progress', 'DELETE'),
                      ('/api/health?expand=anything', 'GET'),
                      ('/api/health/', 'GET'), ('/api//health', 'GET'),
                      ('/api/%68ealth', 'GET'), ('/api/health/../../_/', 'GET'),
                      ('/api/health%2f..%2f..%2f_/', 'GET'),
                      ('/api/collections/pace_users/records/aaaaaaaaaaaaaaa%2f..', 'PATCH'),
                      ('/api/pace/progress;anything', 'PUT'), ('/api/health', 'TRACE'),
                      ('/api/health', 'CONNECT'), ('/api/settings', 'OPTIONS'), ('/api/pace/garmin', 'POST'), ('/api/pace/garmin?owner=x', 'GET'), ('/api/pace/garmin/', 'GET'), ('/api/pace/%67armin', 'GET'), ('/api/pace/garmin/refresh', 'GET'), ('/api/pace/garmin/refresh?force=true', 'POST'), ('/api/pace/garmin/refresh/', 'POST'), ('/api/pace/community?owner=x','GET'), ('/api/pace/community/','GET'), ('/api/pace/community','POST'), ('/api/pace/community/action','GET'), ('/api/pace/community/action?x=1','POST'), ('/api/collections/pace_clubs/records','POST'), ('/api/pace/garmin/status?x=1','GET'), ('/api/pace/garmin/status/','GET'), ('/api/pace/garmin/%73tatus','GET'), ('/api/pace/garmin/status','POST')]
            for path, method in denied:
                before = len(Backend.calls)
                status, data, _ = request(method, path)
                assert status == 404, (method, path, status, data)
                assert len(Backend.calls) == before, (method, path, 'reached backend')
                checked += 1
            # This request simulates trusted tailscaled on loopback. Tailscale itself
            # overwrites visitor-supplied XFF; actual public spoofing is checked separately.
            _, data, _ = request('GET', '/api/health', headers={
                'X-Forwarded-For': '198.51.100.99, 203.0.113.20',
                'X-Real-IP': '192.0.2.40', 'Forwarded': 'for=192.0.2.50'})
            value = json.loads(data)
            assert value['realIp'] == '203.0.113.20', value
            assert value['xff'] == '203.0.113.20' and value['forwarded'] is None, value
            checked += 1
            for method, path, length in [('POST', '/api/collections/pace_users/records', 65537),
                                         ('PUT', '/api/pace/progress', 33554433), ('POST', '/api/pace/garmin/refresh', 1025), ('POST','/api/pace/community/action',8193)]:
                status, data, _ = request(method, path, b'x' * length)
                assert status == 413, (path, status, data)
                checked += 1
            print(f'GATEWAY_TESTS_PASSED={checked}; loopback-only; admin disabled; '
                  'allowlist, bypasses, IP canonicalization and body limits verified')
        finally:
            process.terminate()
            process.wait(timeout=10)
            log.close()
            backend.shutdown()
            backend.server_close()


if __name__ == '__main__':
    main()
