// shared/claudx/token-core.js — pure token health judgements.
// @convergence: auth-plane-phase1-refresh-defense
//
// pool.js 에서 oauth 판정 로직을 뽑아낸 순수 모듈. fs 호출은 여기서 수행하되
// 정책/판정 분기는 pure 함수 조합으로만. pool.js 는 이 턴에 수정하지 않는다 (L0 보호).
// 후속 턴에서 pool.js 가 이 모듈을 require 해 대체 가능.
//
// CLI:
//   node token-core.js probe <config_dir>        → JSON: {source, alive, has_refresh, ...}
//   node token-core.js probe-all                 → 12계정 매트릭스 JSON
//   node token-core.js sha8 <string>             → 16진수 8자
//
// Security: refresh_token/access_token 원문은 stdout 에 내지 않음. 해시만.

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

const HOME = process.env.HOME || process.env.USERPROFILE;
const POOL_CFG =
  process.env.CLAUDX_POOL ||
  path.join(HOME, 'Dev', 'nexus', 'shared', '.runtime', 'accounts', 'accounts.json');
const STATE_DIR = process.env.CLAUDX_STATE || path.join(HOME, '.airgenome', 'claudx');
const KEYCHAIN_MAP = path.join(STATE_DIR, 'keychain_map.json');
const KEYCHAIN_SSOT =
  process.env.CLAUDX_KEYCHAIN_SSOT ||
  path.join(HOME, 'Dev', 'nexus', 'shared', 'config', 'claude_keychain_map.json');

function readJSON(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; }
}

function sha8(s) {
  if (!s) return null;
  return crypto.createHash('sha256').update(String(s)).digest('hex').slice(0, 8);
}

// ─ pure predicates ────────────────────────────────────────────────
function isAccessAlive(oauth, now) {
  if (!oauth || !oauth.accessToken) return false;
  const exp = Number(oauth.expiresAt || 0);
  if (!exp) return true; // expiresAt 없으면 alive 로 간주 (보수적)
  return exp > (now || Date.now());
}

function hasRefresh(oauth) {
  return !!(oauth && oauth.refreshToken);
}

function oauthFingerprint(oauth) {
  if (!oauth) return { at: null, rt: null, exp: null };
  return {
    at: sha8(oauth.accessToken),
    rt: sha8(oauth.refreshToken),
    exp: Number(oauth.expiresAt || 0) || null,
  };
}

// ─ credential readers ─────────────────────────────────────────────
function readFileCred(configDir) {
  if (!configDir) return null;
  const f = path.join(configDir, '.credentials.json');
  const j = readJSON(f, null);
  return (j && j.claudeAiOauth) ? j.claudeAiOauth : null;
}

function _loadKeychainMap() {
  const local = readJSON(KEYCHAIN_MAP, null);
  const ssot = readJSON(KEYCHAIN_SSOT, null);
  const out = {};
  if (ssot && ssot.map) {
    const acc = readJSON(POOL_CFG, { accounts: [] }).accounts || [];
    for (const a of acc) {
      if (ssot.map[a.name] && a.config_dir) out[a.config_dir] = String(ssot.map[a.name]);
    }
  }
  if (local && local.map) {
    for (const [k, v] of Object.entries(local.map)) out[k] = String(v);
  }
  return out;
}

function readKcCred(configDir, keychainMap) {
  if (process.platform !== 'darwin') return null;
  const map = keychainMap || _loadKeychainMap();
  const hex = map[configDir];
  if (!hex) return null;
  let raw;
  try {
    raw = execSync(`security find-generic-password -s "Claude Code-credentials-${hex}" -w 2>/dev/null`, {
      timeout: 500,
      encoding: 'utf8',
    });
  } catch { return null; }
  if (!raw) return null;
  try {
    const j = JSON.parse(raw.trim());
    return (j && j.claudeAiOauth) ? j.claudeAiOauth : null;
  } catch { return null; }
}

// ─ pickCredential ─────────────────────────────────────────────────
// fileAlive > kcAlive > expiredFileButKcAlive > expired-anywhere > none
// 반환: { source, oauth, alive, has_refresh, fp:{file,kc} }
function pickCredential(configDir, opts) {
  const now = (opts && opts.now) || Date.now();
  const keychainMap = (opts && opts.keychainMap) || _loadKeychainMap();
  const fileOauth = readFileCred(configDir);
  const kcOauth = readKcCred(configDir, keychainMap);
  const fileAlive = isAccessAlive(fileOauth, now);
  const kcAlive = isAccessAlive(kcOauth, now);

  let picked = null;
  let source = 'none';
  if (fileAlive) { picked = fileOauth; source = 'file'; }
  else if (kcAlive) { picked = kcOauth; source = 'kc'; }
  else if (fileOauth && kcOauth && hasRefresh(kcOauth)) { picked = kcOauth; source = 'kc-stale'; }
  else if (fileOauth && hasRefresh(fileOauth)) { picked = fileOauth; source = 'file-stale'; }
  else if (kcOauth && hasRefresh(kcOauth)) { picked = kcOauth; source = 'kc-stale'; }

  return {
    source,
    alive: !!picked && isAccessAlive(picked, now),
    has_refresh: hasRefresh(picked),
    fp: {
      file: oauthFingerprint(fileOauth),
      kc: oauthFingerprint(kcOauth),
    },
    oauth: picked,
  };
}

// drift: file 과 KC 의 refresh_token 해시 비교
function detectDrift(configDir, opts) {
  const keychainMap = (opts && opts.keychainMap) || _loadKeychainMap();
  const fileOauth = readFileCred(configDir);
  const kcOauth = readKcCred(configDir, keychainMap);
  const fileRt = fileOauth && fileOauth.refreshToken ? sha8(fileOauth.refreshToken) : null;
  const kcRt = kcOauth && kcOauth.refreshToken ? sha8(kcOauth.refreshToken) : null;
  let status;
  if (!fileRt && !kcRt) status = 'both_missing';
  else if (!fileRt) status = 'file_missing';
  else if (!kcRt) status = 'kc_missing';
  else if (fileRt === kcRt) status = 'in_sync';
  else status = 'drift';
  return { status, file_rt: fileRt, kc_rt: kcRt };
}

module.exports = {
  sha8,
  isAccessAlive,
  hasRefresh,
  oauthFingerprint,
  readFileCred,
  readKcCred,
  pickCredential,
  detectDrift,
  _loadKeychainMap,
};

// ─ CLI ───────────────────────────────────────────────────────────
if (require.main === module) {
  const cmd = process.argv[2] || 'probe-all';
  const now = Date.now();
  const out = (o) => process.stdout.write(JSON.stringify(o, null, 2) + '\n');

  if (cmd === 'sha8') {
    process.stdout.write((sha8(process.argv[3]) || '') + '\n');
  } else if (cmd === 'probe') {
    const dir = process.argv[3];
    if (!dir) { process.stderr.write('usage: probe <config_dir>\n'); process.exit(2); }
    const p = pickCredential(dir, { now });
    out({ config_dir: dir, ...p, oauth: undefined });
  } else if (cmd === 'drift') {
    const dir = process.argv[3];
    if (!dir) { process.stderr.write('usage: drift <config_dir>\n'); process.exit(2); }
    out({ config_dir: dir, ...detectDrift(dir) });
  } else if (cmd === 'probe-all') {
    const acc = readJSON(POOL_CFG, { accounts: [] }).accounts || [];
    const kcMap = _loadKeychainMap();
    const rows = [];
    for (const a of acc) {
      const p = pickCredential(a.config_dir, { now, keychainMap: kcMap });
      const d = detectDrift(a.config_dir, { keychainMap: kcMap });
      rows.push({
        name: a.name,
        source: p.source,
        alive: p.alive,
        has_refresh: p.has_refresh,
        drift: d.status,
        file_exp: p.fp.file.exp ? new Date(p.fp.file.exp).toISOString() : null,
        kc_exp: p.fp.kc.exp ? new Date(p.fp.kc.exp).toISOString() : null,
      });
    }
    out(rows);
  } else {
    process.stderr.write('usage: node token-core.js {probe <dir>|probe-all|drift <dir>|sha8 <s>}\n');
    process.exit(2);
  }
}
