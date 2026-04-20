#!/usr/bin/env node
// tests/auth-plane/test-token-health.js
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'ag-token-health-'));
process.env.CLAUDX_STATE = TMP;

// NB: require AFTER env override — module 캡처 시점 중요
const h = require('/Users/ghost/Dev/airgenome/shared/claudx/token-health.js');

let pass = 0, fail = 0;
function t(n, fn) {
  try { fn(); console.log('  ✓', n); pass++; }
  catch (e) { console.log('  ✗', n, '→', e.message); fail++; }
}

console.log('token-health.js tests');

t('appendEvent — enriched fields', () => {
  const r = h.appendEvent({ acct: 'acc1', event: 'refresh', result: 'ok' });
  if (!r.ts) throw new Error('no ts');
  if (!r.host) throw new Error('no host');
  if (!r.writer) throw new Error('no writer');
  if (r.acct !== 'acc1') throw new Error('acct lost');
  if (r.event !== 'refresh') throw new Error('event lost');
});

t('appendEvent — persists to jsonl', () => {
  h.appendEvent({ acct: 'acc2', event: 'rotate' });
  const txt = fs.readFileSync(h.LOG_PATH, 'utf8');
  const lines = txt.trim().split('\n');
  if (lines.length < 2) throw new Error('append did not persist');
  const last = JSON.parse(lines[lines.length - 1]);
  if (last.acct !== 'acc2') throw new Error('wrong last record');
});

t('tail(n) — returns n or fewer, in order', () => {
  for (let i = 0; i < 10; i++) h.appendEvent({ acct: 'iter', event: 'probe', seq: i });
  const last5 = h.tail(5);
  if (last5.length !== 5) throw new Error(`expected 5, got ${last5.length}`);
  const parsed = last5.map(l => JSON.parse(l));
  if (parsed[4].seq !== 9) throw new Error('wrong order (last should be seq=9)');
});

t('appendEvent — rejects non-object', () => {
  let threw = false;
  try { h.appendEvent(null); } catch { threw = true; }
  if (!threw) throw new Error('should have thrown on null');
});

t('LOG_PATH lives under CLAUDX_STATE', () => {
  if (!h.LOG_PATH.startsWith(TMP)) {
    throw new Error(`LOG_PATH=${h.LOG_PATH} not under ${TMP}`);
  }
});

console.log(`\ntoken-health.js: ${pass} pass, ${fail} fail`);
fs.rmSync(TMP, { recursive: true, force: true });
process.exit(fail ? 1 : 0);
