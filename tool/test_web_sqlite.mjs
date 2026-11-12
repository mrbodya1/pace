// Run after compiling web_sqlite_probe.dart into build/webprobe/main.js and copying
// web/sqflite_sw.js + web/sqlite3.wasm there. Uses a fresh Chrome profile only.
import { createServer } from 'node:http';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
const root = path.resolve('build/webprobe');
const profile = await mkdtemp(path.join(tmpdir(), 'pace-websqlite-'));
const server = createServer(async (req, res) => {
  const file = path.resolve(root, '.' + (req.url === '/' ? '/index.html' : req.url));
  if (!file.startsWith(root + path.sep)) { res.writeHead(404).end(); return; }
  try {
    const data = await readFile(file);
    res.setHeader('Content-Type', file.endsWith('.wasm') ? 'application/wasm' : file.endsWith('.js') ? 'text/javascript' : 'text/html');
    res.end(data);
  } catch { res.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const chrome = spawn(process.env.CHROME_EXE || 'C:/Program Files/Google/Chrome/Application/chrome.exe', [
  '--headless=new', '--disable-gpu', '--no-first-run', '--remote-debugging-port=0',
  `--user-data-dir=${profile}`, 'about:blank'
], { windowsHide: true, stdio: 'ignore' });
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
let ws;
try {
  let port;
  for (let i = 0; i < 100; i++) {
    try { port = (await readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break; }
    catch { await pause(100); }
  }
  if (!port) throw Error('Chrome did not start');
  const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  ws = new WebSocket(pages.find(p => p.type === 'page').webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let id = 0;
  const pending = new Map();
  ws.onmessage = e => {
    const data = JSON.parse(e.data);
    if (pending.has(data.id)) { pending.get(data.id)(data); pending.delete(data.id); }
  };
  const call = (method, params = {}) => new Promise(resolve => {
    const key = ++id; pending.set(key, resolve); ws.send(JSON.stringify({id: key, method, params}));
  });
  await call('Page.enable');
  await call('Page.navigate', {url: `http://127.0.0.1:${server.address().port}/`});
  let text = '';
  for (let i = 0; i < 100; i++) {
    const r = await call('Runtime.evaluate', {expression: 'document.body?.textContent'});
    text = r.result?.result?.value || '';
    if (text.includes('SQLITE_WEB_OK')) { console.log('SQLITE_WEB_TRANSACTION_REOPEN=ok'); break; }
    if (text.includes('SQLITE_WEB_ERROR')) throw Error(text.slice(0, 1000));
    await pause(300);
  }
  if (!text.includes('SQLITE_WEB_OK')) throw Error('SQLite web timeout: ' + text.slice(0, 500));
} finally {
  ws?.close();
  chrome.kill();
  await new Promise(resolve => { if (chrome.exitCode !== null) resolve(); else chrome.once('exit', resolve); });
  server.close();
  const resolved = path.resolve(profile);
  if (path.dirname(resolved) !== path.resolve(tmpdir()) || !path.basename(resolved).startsWith('pace-websqlite-')) throw Error('Unsafe cleanup target');
  await rm(resolved, {recursive: true, force: true, maxRetries: 5, retryDelay: 200});
}
