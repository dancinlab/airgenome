// shared/claudx/oauth-monitor.js — Phase 2-A 관측 hook.
//
// 책임: Node/Bun http(s).request 를 monkey-patch 해 Anthropic OAuth
// /oauth/token endpoint 호출을 관찰, token-health.jsonl 에 이벤트 기록.
//
// 실증 목적:
//   - Anthropic 이 refresh rotation 을 수행하는가?
//   - 한 계정에 동시 refresh 가 얼마나 발생하는가?
//   - revoke 이전 어떤 호스트/시각에서 refresh 시도가 있었나?
//
// 현재는 NO-OP SERIALIZE (관측만). 증거 쌓이면 lock/rate-limit 추가 예정.
//
// Wiring: bin/claudx 가 NODE_OPTIONS/BUN_OPTIONS 에 --require 로 주입.
// 존재하지 않으면 사용자 경험 무영향 (claudx 가 파일 유무 체크).

'use strict';

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = process.env.HOME || os.homedir();
const STATE_DIR = process.env.CLAUDX_STATE || path.join(HOME, '.airgenome', 'claudx');
const LOG_PATH = path.join(STATE_DIR, 'token-health.jsonl');
const PID = process.pid;

function _acctFromEnv() {
  const cfg = process.env.CLAUDE_CONFIG_DIR || '';
  if (!cfg) return null;
  return path.basename(cfg).replace(/^\.claude-/, '') || null;
}

function _logEvent(ev) {
  try {
    fs.mkdirSync(STATE_DIR, { recursive: true });
    fs.appendFileSync(LOG_PATH, JSON.stringify({
      ts: new Date().toISOString(),
      host: os.hostname(),
      writer: 'oauth-monitor',
      pid: PID,
      ...ev,
    }) + '\n');
  } catch {
    // silent — observer 는 주 프로세스를 방해하면 안 됨.
  }
}

function _extractHostPath(optsOrUrl) {
  let host = '';
  let url_path = '';
  try {
    if (typeof optsOrUrl === 'string') {
      const u = new URL(optsOrUrl);
      host = u.hostname;
      url_path = u.pathname;
    } else if (optsOrUrl && typeof optsOrUrl === 'object') {
      if (optsOrUrl.url || optsOrUrl.href) {
        const u = new URL(optsOrUrl.url || optsOrUrl.href);
        host = u.hostname;
        url_path = u.pathname;
      } else {
        host = optsOrUrl.hostname || optsOrUrl.host || '';
        if (host.includes(':')) host = host.split(':')[0];
        url_path = optsOrUrl.path || optsOrUrl.pathname || '';
        const qIdx = url_path.indexOf('?');
        if (qIdx >= 0) url_path = url_path.slice(0, qIdx);
      }
    }
  } catch {}
  return { host, url_path };
}

function _isOauthTarget(host, url_path) {
  if (!host || !url_path) return false;
  if (!/anthropic\.com$/i.test(host) && !/claude\.ai$/i.test(host)) return false;
  return /oauth.*token|token.*oauth|\/v1\/oauth\//i.test(url_path);
}

function _patch(mod, name) {
  const orig = mod.request;
  if (!orig || orig.__oauth_monitor_patched__) return;
  function patched(optsOrUrl, ...rest) {
    const { host, url_path } = _extractHostPath(optsOrUrl);
    if (_isOauthTarget(host, url_path)) {
      _logEvent({
        acct: _acctFromEnv(),
        event: 'oauth_request',
        proto: name,
        host,
        path: url_path,
      });
    }
    return orig.apply(this, [optsOrUrl, ...rest]);
  }
  patched.__oauth_monitor_patched__ = true;
  mod.request = patched;
}

try {
  _patch(http, 'http');
  _patch(https, 'https');
} catch {
  // 최악의 경우 silent — observer 실패가 claude 를 깨뜨리지 않게.
}

module.exports = { _logEvent, _isOauthTarget, _extractHostPath };
