#!/usr/bin/env node
// tests/auth-plane/test-oauth-monitor.js
// @convergence: auth-plane-test-suite-36-45, auth-plane-phase2-oauth-monitor
// oauth-monitor 의 순수 판정 함수 단위 테스트 + 이벤트 기록 확인.
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'ag-oauth-mon-'));
process.env.CLAUDX_STATE = TMP;

const mon = require('/Users/ghost/Dev/airgenome/shared/claudx/oauth-monitor.js');

let pass = 0, fail = 0;
function t(n, fn) {
  try { fn(); console.log('  ✓', n); pass++; }
  catch (e) { console.log('  ✗', n, '→', e.message); fail++; }
}
function eq(a, b, m) {
  if (a !== b) throw new Error(`${m||''} expected ${b}, got ${a}`);
}

console.log('oauth-monitor.js tests');

t('match anthropic /v1/oauth/', () => {
  eq(mon._isOauthTarget('console.anthropic.com', '/v1/oauth/token'), true);
});
t('match anthropic /oauth/token', () => {
  eq(mon._isOauthTarget('api.anthropic.com', '/oauth/token'), true);
});
t('miss anthropic non-oauth path', () => {
  eq(mon._isOauthTarget('api.anthropic.com', '/v1/messages'), false);
});
t('miss non-anthropic oauth path', () => {
  eq(mon._isOauthTarget('example.com', '/oauth/token'), false);
});
t('miss empty', () => {
  eq(mon._isOauthTarget('', ''), false);
});

t('extractHostPath — string URL', () => {
  const { host, url_path } = mon._extractHostPath('https://console.anthropic.com/v1/oauth/token?x=1');
  eq(host, 'console.anthropic.com');
  eq(url_path, '/v1/oauth/token');
});
t('extractHostPath — options object', () => {
  const { host, url_path } = mon._extractHostPath({ hostname: 'api.anthropic.com', path: '/oauth/token?grant=refresh' });
  eq(host, 'api.anthropic.com');
  eq(url_path, '/oauth/token');
});
t('extractHostPath — malformed silent null', () => {
  const { host, url_path } = mon._extractHostPath(null);
  eq(host, '');
  eq(url_path, '');
});

t('_logEvent appends to token-health.jsonl', () => {
  mon._logEvent({ acct: 'test', event: 'oauth_request', proto: 'https', host: 'api.anthropic.com', path: '/oauth/token' });
  const txt = fs.readFileSync(path.join(TMP, 'token-health.jsonl'), 'utf8');
  const last = JSON.parse(txt.trim().split('\n').pop());
  eq(last.acct, 'test');
  eq(last.writer, 'oauth-monitor');
  if (!last.ts) throw new Error('no ts');
});

console.log(`\noauth-monitor.js: ${pass} pass, ${fail} fail`);
fs.rmSync(TMP, { recursive: true, force: true });
process.exit(fail ? 1 : 0);
