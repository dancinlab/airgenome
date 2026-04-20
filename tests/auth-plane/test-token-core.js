#!/usr/bin/env node
// tests/auth-plane/test-token-core.js
// 순수 판정 함수 단위 테스트. temp dir 로 격리, 실 계정/KC 미접근.
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'ag-token-core-'));
process.env.CLAUDX_STATE = path.join(TMP, 'claudx');
fs.mkdirSync(process.env.CLAUDX_STATE, { recursive: true });
process.env.CLAUDX_POOL = path.join(TMP, 'accounts.json');
process.env.CLAUDX_KEYCHAIN_SSOT = path.join(TMP, 'kc-ssot.json');
fs.writeFileSync(process.env.CLAUDX_POOL, JSON.stringify({ accounts: [] }));
fs.writeFileSync(process.env.CLAUDX_KEYCHAIN_SSOT, JSON.stringify({ map: {} }));

const core = require('/Users/ghost/Dev/airgenome/shared/claudx/token-core.js');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); console.log('  ✓', name); pass++; }
  catch (e) { console.log('  ✗', name, '→', e.message); fail++; }
}
function eq(a, b, msg) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw new Error(`${msg||''} expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
  }
}

function mkAcct(name, oauth) {
  const dir = path.join(TMP, '.claude-' + name);
  fs.mkdirSync(dir, { recursive: true });
  if (oauth !== undefined) {
    fs.writeFileSync(path.join(dir, '.credentials.json'), JSON.stringify({ claudeAiOauth: oauth }));
  }
  return dir;
}

const now = Date.now();

console.log('token-core.js tests');

t('sha8 deterministic + empty handling', () => {
  eq(core.sha8('abc').length, 8, 'length');
  eq(core.sha8('abc'), core.sha8('abc'), 'determinism');
  eq(core.sha8(''), null, 'empty → null');
  eq(core.sha8(null), null);
  if (core.sha8('a') === core.sha8('b')) throw new Error('collision');
});

t('isAccessAlive — null/empty/no-exp/future/past', () => {
  eq(core.isAccessAlive(null, now), false);
  eq(core.isAccessAlive({}, now), false);
  eq(core.isAccessAlive({ accessToken: 'x' }, now), true, 'no expiresAt → alive');
  eq(core.isAccessAlive({ accessToken: 'x', expiresAt: now + 1000 }, now), true);
  eq(core.isAccessAlive({ accessToken: 'x', expiresAt: now - 1000 }, now), false);
});

t('hasRefresh', () => {
  eq(core.hasRefresh(null), false);
  eq(core.hasRefresh({}), false);
  eq(core.hasRefresh({ refreshToken: 'rt' }), true);
});

t('oauthFingerprint fields', () => {
  const fp = core.oauthFingerprint({ accessToken: 'at-value', refreshToken: 'rt-value', expiresAt: 100 });
  if (typeof fp.at !== 'string' || fp.at.length !== 8) throw new Error('at sha8');
  if (typeof fp.rt !== 'string' || fp.rt.length !== 8) throw new Error('rt sha8');
  eq(fp.exp, 100);
  const empty = core.oauthFingerprint(null);
  eq(empty.at, null); eq(empty.rt, null); eq(empty.exp, null);
});

t('readFileCred — missing', () => {
  const dir = mkAcct('missing');
  eq(core.readFileCred(dir), null);
});

t('readFileCred — valid', () => {
  const dir = mkAcct('ok', { accessToken: 'at', refreshToken: 'rt', expiresAt: now + 3600000 });
  const o = core.readFileCred(dir);
  eq(o.accessToken, 'at');
  eq(o.refreshToken, 'rt');
});

t('readFileCred — malformed JSON', () => {
  const dir = path.join(TMP, '.claude-bad');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, '.credentials.json'), '{not json');
  eq(core.readFileCred(dir), null);
});

t('pickCredential — file alive (no KC)', () => {
  const dir = mkAcct('alive1', { accessToken: 'at', refreshToken: 'rt', expiresAt: now + 3600000 });
  const p = core.pickCredential(dir, { now, keychainMap: {} });
  eq(p.source, 'file');
  eq(p.alive, true);
  eq(p.has_refresh, true);
});

t('pickCredential — file expired, has refresh (no KC)', () => {
  const dir = mkAcct('stale1', { accessToken: 'at', refreshToken: 'rt', expiresAt: now - 1000 });
  const p = core.pickCredential(dir, { now, keychainMap: {} });
  eq(p.source, 'file-stale');
  eq(p.alive, false);
  eq(p.has_refresh, true);
});

t('pickCredential — empty dir', () => {
  const dir = mkAcct('empty');
  const p = core.pickCredential(dir, { now, keychainMap: {} });
  eq(p.source, 'none');
  eq(p.alive, false);
  eq(p.has_refresh, false);
});

t('detectDrift — both missing', () => {
  const dir = mkAcct('dm');
  eq(core.detectDrift(dir, { keychainMap: {} }).status, 'both_missing');
});

t('detectDrift — file only → kc_missing', () => {
  const dir = mkAcct('fonly', { accessToken: 'at', refreshToken: 'rt', expiresAt: now + 1000 });
  eq(core.detectDrift(dir, { keychainMap: {} }).status, 'kc_missing');
});

console.log(`\ntoken-core.js: ${pass} pass, ${fail} fail`);
fs.rmSync(TMP, { recursive: true, force: true });
process.exit(fail ? 1 : 0);
