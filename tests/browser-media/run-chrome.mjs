// CDP over anonymous pipes: no TCP server and no virtual clock (media needs real
// decoder/event-loop progress). Use only this test's disposable browser process.
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { writeFileSync } from 'node:fs';

const browser = spawn(process.argv[2], [
  '--headless', '--disable-gpu', '--mute-audio', '--disable-audio-output',
  '--user-data-dir=' + process.argv[3], '--no-first-run', '--no-default-browser-check',
  '--disable-background-networking', '--disable-component-update', '--disable-sync',
  '--disable-extensions', '--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND',
  '--autoplay-policy=no-user-gesture-required', '--remote-debugging-pipe',
], { detached: true, stdio: ['ignore', 'ignore', 'pipe', 'pipe', 'pipe'] });
let nextID = 0, buffer = '', errors = '';
const pending = new Map();
browser.stderr.on('data', chunk => { errors += chunk; });
browser.stdio[4].on('data', chunk => {
  buffer += chunk;
  for (let end; (end = buffer.indexOf('\0')) >= 0;) {
    const message = JSON.parse(buffer.slice(0, end)); buffer = buffer.slice(end + 1);
    const waiter = pending.get(message.id);
    if (!waiter) continue;
    pending.delete(message.id);
    if (message.error) waiter.reject(new Error(JSON.stringify(message.error)));
    else waiter.resolve(message.result);
  }
});
function command(method, params = {}, sessionId) {
  return new Promise((resolve, reject) => {
    const id = ++nextID;
    pending.set(id, { resolve, reject });
    browser.stdio[3].write(JSON.stringify({ id, method, params, sessionId }) + '\0');
  });
}
const deadline = setTimeout(() => {
  for (const waiter of pending.values()) waiter.reject(new Error('browser regression timed out'));
}, 40000);
try {
  const { targetId } = await command('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await command('Target.attachToTarget', { targetId, flatten: true });
  await command('Page.enable', {}, sessionId);
  await command('Page.navigate', { url: pathToFileURL(resolve('.build/fixture.html')).href }, sessionId);
  let report = '';
  const until = Date.now() + 30000;
  while (Date.now() < until) {
    const value = await command('Runtime.evaluate', {
      expression: "document.getElementById('result')?.textContent || ''", returnByValue: true,
    }, sessionId);
    report = value.result?.value || '';
    if (/^(PASS|FAIL):/.test(report)) break;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  writeFileSync('.build/result.txt', report);
  console.log(report);
  if (!report.startsWith('PASS: ')) process.exitCode = 1;
} catch (error) {
  console.error('browser-media: FAIL:', error.message);
  process.exitCode = 1;
} finally {
  clearTimeout(deadline);
  writeFileSync('.build/chrome.log', errors);
  // Kill only the process group that this harness created, never a user's Chrome.
  try { process.kill(-browser.pid, 'SIGKILL'); } catch {}
}
