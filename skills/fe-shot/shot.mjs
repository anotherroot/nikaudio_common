#!/usr/bin/env node
// Headless screenshot harness for the Nikaudio/Librofono frontend.
// Needs Node >= 22 (global WebSocket). Chromium path via $CHROME_BIN or arg.
//
// Usage:
//   node shot.mjs <url> <out.png> [--dark] [--width=1600] [--height=900] [--wait=2500]
//
// Dark mode is emulated via prefers-color-scheme (the app maps it to the .dark class).

import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const url = args[0];
const out = args[1];
if (!url || !out) {
  console.error('usage: shot.mjs <url> <out.png> [--dark] [--width=N] [--height=N] [--wait=ms]');
  process.exit(1);
}
const opt = (name, dflt) => {
  const a = args.find((x) => x.startsWith(`--${name}=`));
  return a ? a.split('=')[1] : dflt;
};
const dark = args.includes('--dark');
const width = Number(opt('width', 1600));
const height = Number(opt('height', 900));
const settleMs = Number(opt('wait', 2500));
const chrome = process.env.CHROME_BIN || 'chromium';

const proc = spawn(chrome, [
  '--headless=new',
  '--remote-debugging-port=0',
  '--no-first-run',
  '--no-default-browser-check',
  '--hide-scrollbars',
  `--window-size=${width},${height}`,
  'about:blank',
]);

const wsUrl = await new Promise((resolve, reject) => {
  let buf = '';
  proc.stderr.on('data', (d) => {
    buf += d.toString();
    const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
    if (m) resolve(m[1]);
  });
  proc.on('exit', (c) => reject(new Error(`chromium exited early (${c})\n${buf}`)));
  setTimeout(() => reject(new Error('timeout waiting for DevTools ws\n' + buf)), 15000);
});

const ws = new WebSocket(wsUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

let msgId = 0;
const pending = new Map();
const events = [];
ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
  } else if (msg.method) {
    events.push(msg);
    for (const w of waiters) w(msg);
  }
};
const waiters = new Set();
const send = (method, params = {}, sessionId) =>
  new Promise((resolve, reject) => {
    const id = ++msgId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });
const waitEvent = (method, sessionId, timeoutMs = 20000) =>
  new Promise((resolve, reject) => {
    const done = events.find((m) => m.method === method && m.sessionId === sessionId);
    if (done) return resolve(done);
    const w = (m) => {
      if (m.method === method && m.sessionId === sessionId) {
        waiters.delete(w);
        resolve(m);
      }
    };
    waiters.add(w);
    setTimeout(() => { waiters.delete(w); reject(new Error(`timeout waiting ${method}`)); }, timeoutMs);
  });

try {
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });

  await send('Page.enable', {}, sessionId);
  await send('Emulation.setDeviceMetricsOverride',
    { width, height, deviceScaleFactor: 1, mobile: false }, sessionId);
  await send('Emulation.setEmulatedMedia',
    { features: [{ name: 'prefers-color-scheme', value: dark ? 'dark' : 'light' }] }, sessionId);

  await send('Page.navigate', { url }, sessionId);
  await waitEvent('Page.loadEventFired', sessionId);
  await new Promise((r) => setTimeout(r, settleMs)); // let Angular render/fetch

  const { data } = await send('Page.captureScreenshot', { format: 'png' }, sessionId);
  writeFileSync(out, Buffer.from(data, 'base64'));
  console.log(`wrote ${out} (${width}x${height}, ${dark ? 'dark' : 'light'})`);
} finally {
  ws.close();
  proc.kill();
}
