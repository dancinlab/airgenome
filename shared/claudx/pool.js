// shared/claudx/pool.js — account pool logic shared between interceptor.js (in-process
// rotation) and bin/claudx (pre-launch best-pick). Stateless module; reads SSOT files
// on every call (cheap; 12-row JSON).
//
// Inputs (env-overridable paths):
//   CLAUDX_POOL   → accounts.json  (list of {name, config_dir})
//   CLAUDX_USAGE  → usage-cache.json (per-acct {week_all_pct, session_pct, error, _retry_at})
//   CLAUDX_STATE  → state dir (exhausted.json, rotations.jsonl)
//
// Output of pickBest:
//   { name, config_dir, token, score }  (null if none available)

'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const HOME = process.env.HOME || process.env.USERPROFILE;
const STATE_DIR = process.env.CLAUDX_STATE || path.join(HOME, '.airgenome', 'claudx');
const POOL_CFG =
  process.env.CLAUDX_POOL ||
  path.join(HOME, 'Dev', 'nexus', 'shared', '.runtime', 'accounts', 'accounts.json');
const USAGE_CACHE =
  process.env.CLAUDX_USAGE ||
  path.join(HOME, 'Dev', 'nexus', 'shared', '.runtime', 'accounts', 'usage-cache.json');
const EXHAUSTED = path.join(STATE_DIR, 'exhausted.json');
const STICKY = path.join(STATE_DIR, 'sticky.json');
const PENALTY = path.join(STATE_DIR, 'penalty.json');
const KEYCHAIN_MAP = path.join(STATE_DIR, 'keychain_map.json');
// SSOT keychain map maintained by bin/remote_account_sync + cl-refresh.
// Format: { map: { claudeN: "<hex8>" } }. We prefer this over brute-force discovery.
const KEYCHAIN_SSOT =
  process.env.CLAUDX_KEYCHAIN_SSOT ||
  path.join(HOME, 'Dev', 'nexus', 'shared', 'config', 'claude_keychain_map.json');

function mkdirp(p) {
  try { fs.mkdirSync(p, { recursive: true }); } catch (_) {}
}

function readJSON(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (_) { return fallback; }
}

// Optional prefix remap for cross-host execution (e.g., Mac accounts.json stores
// /Users/ghost/... but we may run on Linux where those live under $HOME/mac_home).
// CLAUDX_HOME_MAP="/Users/ghost:/home/aiden/mac_home" (single pair) or
// comma-separated for multiple pairs.
function remapPath(p) {
  const raw = process.env.CLAUDX_HOME_MAP || '';
  if (!raw || !p) return p;
  for (const pair of raw.split(',')) {
    const [from, to] = pair.split(':');
    if (from && to && p.startsWith(from)) return to + p.slice(from.length);
  }
  return p;
}

function writeJSON(p, obj) {
  mkdirp(path.dirname(p));
  const tmp = p + '.tmp.' + process.pid;
  try {
    fs.writeFileSync(tmp, JSON.stringify(obj, null, 2));
    fs.renameSync(tmp, p);
  } catch (_) {}
}

function basenameToAcct(p) {
  return path.basename(p || '').replace(/^\.claude-/, '');
}

function currentAccountName() {
  return basenameToAcct(process.env.CLAUDE_CONFIG_DIR || '');
}

// ------------------------------------------------------------------
// Mac Keychain fallback (M11e · cross-host claude)
//
// On macOS, `claude` stores OAuth tokens in the login keychain rather than
// writing `.credentials.json`. Without this fallback, loadPool returns empty
// on Mac and claudx rotation cannot function.
//
// Lookup strategy (cheapest → safest):
//   1) in-memory _keychainMap (per-process)
//   2) $CLAUDX_STATE/keychain_map.json (persisted cache)
//   3) SSOT map at shared/config/claude_keychain_map.json (hand-maintained)
//   4) brute-force pair `security dump-keychain` hashes with known accounts
//      — only triggered when a config_dir has no known mapping.
//
// All keychain invocations are gated behind process.platform === 'darwin' so
// Linux/Windows hot paths are unaffected.
// ------------------------------------------------------------------

let _keychainMap = null; // { [config_dir]: "<hex8>" }
let _dumpedHashes = null; // string[] of hex8 candidates from `security dump-keychain`

function _loadKeychainMap() {
  if (_keychainMap) return _keychainMap;
  // 1) local cache first (writable, per-host)
  const cached = readJSON(KEYCHAIN_MAP, null);
  if (cached && typeof cached === 'object' && cached.map && typeof cached.map === 'object') {
    _keychainMap = Object.assign({}, cached.map);
  } else {
    _keychainMap = {};
  }
  // 2) merge SSOT (name → hex8) by resolving each account's config_dir.
  //    SSOT keys are account names (claude1..12), so we need accounts.json
  //    to translate. We only merge entries not already in the local cache.
  const ssot = readJSON(KEYCHAIN_SSOT, null);
  const ssotMap = ssot && ssot.map && typeof ssot.map === 'object' ? ssot.map : null;
  let changed = false;
  if (ssotMap) {
    const acc = readJSON(POOL_CFG, { accounts: [] });
    for (const a of acc.accounts || []) {
      const hex = ssotMap[a.name];
      if (!hex || !a.config_dir) continue;
      if (!_keychainMap[a.config_dir]) {
        _keychainMap[a.config_dir] = String(hex);
        changed = true;
      }
    }
  }
  // Persist on first SSOT materialization so subsequent runs (and hosts that
  // no longer reach the nexus SSOT) can resolve purely from the local cache.
  if (changed) _persistKeychainMap();
  return _keychainMap;
}

function _persistKeychainMap() {
  try {
    writeJSON(KEYCHAIN_MAP, { schema_version: 1, updated_at: new Date().toISOString(), map: _keychainMap || {} });
  } catch (_) {}
}

function _dumpKeychainHashes() {
  if (_dumpedHashes) return _dumpedHashes;
  if (process.platform !== 'darwin') { _dumpedHashes = []; return _dumpedHashes; }
  try {
    const out = execSync('security dump-keychain 2>/dev/null', { timeout: 2000, encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
    const hashes = new Set();
    const re = /"Claude Code-credentials-([0-9a-f]{8})"/g;
    let m;
    while ((m = re.exec(out)) !== null) hashes.add(m[1]);
    _dumpedHashes = Array.from(hashes);
  } catch (_) {
    _dumpedHashes = [];
  }
  return _dumpedHashes;
}

// Try to resolve a keychain hex8 for a given config_dir. Returns null if
// nothing can be matched. Results are cached & persisted on success.
function _resolveKeychainHex(configDir) {
  if (!configDir) return null;
  if (process.platform !== 'darwin') return null;
  const m = _loadKeychainMap();
  if (m[configDir]) return m[configDir];

  // Brute-force discovery: iterate unknown hashes, read each entry, and parse
  // the JSON to see if its stored path (if present) references config_dir.
  // Claude Code's blob is pure OAuth JSON (no path), so we can't disambiguate
  // from the blob itself. Instead we rely on the fact that brand-new accounts
  // produce exactly one new hash — we record any leftover hashes but won't
  // mis-assign them. For paired brute-force we lean on the SSOT first.
  // (Re-read SSOT each call is cheap compared to the keychain syscall.)
  const ssot = readJSON(KEYCHAIN_SSOT, null);
  const ssotMap = ssot && ssot.map && typeof ssot.map === 'object' ? ssot.map : null;
  if (ssotMap) {
    const acctName = basenameToAcct(configDir);
    if (acctName && ssotMap[acctName]) {
      m[configDir] = String(ssotMap[acctName]);
      _persistKeychainMap();
      return m[configDir];
    }
  }
  // Last resort: if there is exactly one unclaimed dumped hash and exactly one
  // unresolved config_dir in the pool, pair them. Otherwise bail — silent
  // no-op is preferable to a wrong assignment.
  const dumped = _dumpKeychainHashes();
  if (dumped && dumped.length) {
    const claimed = new Set(Object.values(m));
    const leftover = dumped.filter(h => !claimed.has(h));
    if (leftover.length === 1) {
      m[configDir] = leftover[0];
      _persistKeychainMap();
      return m[configDir];
    }
  }
  return null;
}

function _readKeychainCreds(configDir) {
  if (process.platform !== 'darwin') return null;
  const hex = _resolveKeychainHex(configDir);
  if (!hex) return null;
  let raw;
  try {
    raw = execSync(`security find-generic-password -s "Claude Code-credentials-${hex}" -w 2>/dev/null`, {
      timeout: 300,
      encoding: 'utf8',
    });
  } catch (_) {
    return null;
  }
  if (!raw) return null;
  try {
    return JSON.parse(raw.trim());
  } catch (_) {
    return null;
  }
}

function loadPool(excludeNames, opts) {
  const exclude = new Set(excludeNames || []);
  const acc = readJSON(POOL_CFG, { accounts: [] });
  const usage = readJSON(USAGE_CACHE, {});
  const exhausted = readJSON(EXHAUSTED, {});
  const penalty = readJSON(PENALTY, {});
  const now = Math.floor(Date.now() / 1000);
  const softSession = (opts && opts.sessionCap) || 95;
  const softWeek = (opts && opts.weekCap) || 100;
  const out = [];
  for (const a of acc.accounts || []) {
    if (exclude.has(a.name)) continue;
    const u = usage[a.name] || {};
    const ex = exhausted[a.name] || {};
    if (ex.until && ex.until > now) continue;
    if ((u.week_all_pct || 0) >= softWeek) continue;
    if ((u.session_pct || 0) >= softSession) continue;
    if (u._retry_at && u._retry_at > now) continue;
    const remapped = remapPath(a.config_dir);
    const cred = path.join(remapped, '.credentials.json');
    let creds = readJSON(cred, null);
    let oauth = creds && creds.claudeAiOauth;
    // Mac fallback: no .credentials.json → read from macOS Keychain. Only when
    // the config_dir is the true Mac path (not a remap to linux fs) AND we are
    // actually running on darwin. This keeps Linux behavior identical.
    if ((!oauth || !oauth.accessToken) && process.platform === 'darwin' && remapped === a.config_dir) {
      const kc = _readKeychainCreds(a.config_dir);
      if (kc && kc.claudeAiOauth) {
        creds = kc;
        oauth = kc.claudeAiOauth;
      }
    }
    if (!oauth || !oauth.accessToken) continue;
    if (oauth.expiresAt && oauth.expiresAt < Date.now()) continue;
    const pen = penalty[a.name];
    const penDelta = (pen && pen.until > now) ? (Number(pen.delta) || 0) : 0;
    out.push({
      name: a.name,
      config_dir: a.config_dir,
      token: oauth.accessToken,
      week_pct: u.week_all_pct || 0,
      session_pct: u.session_pct || 0,
      penalty: penDelta,
      score: (u.week_all_pct || 0) * 2 + (u.session_pct || 0) + penDelta,
    });
  }
  out.sort((x, y) => x.score - y.score);
  return out;
}

// sticky: session_id ↔ preferred_acct 매핑 (M13d · hive forge/sticky 이식).
// 같은 session_id 는 rotation 불가피할 때만 바꿈 — Anthropic prompt cache 보호.
function stickyGet(sid) {
  if (!sid) return null;
  const st = readJSON(STICKY, {});
  return st[sid] && st[sid].acct ? st[sid].acct : null;
}

function stickySet(sid, acct) {
  if (!sid || !acct) return;
  const st = readJSON(STICKY, {});
  st[sid] = { acct, last_used: new Date().toISOString() };
  writeJSON(STICKY, st);
}

function stickyClear(sid) {
  const st = readJSON(STICKY, {});
  if (sid) delete st[sid]; else for (const k of Object.keys(st)) delete st[k];
  writeJSON(STICKY, st);
}

function pickBest(excludeNames, opts) {
  const sid = (opts && opts.stickyFor) || null;
  const all = loadPool(excludeNames);
  if (sid) {
    const pref = stickyGet(sid);
    if (pref) {
      const hit = all.find(p => p.name === pref);
      if (hit) return hit; // sticky 유효 — 첫 자리로
    }
    if (all[0]) stickySet(sid, all[0].name); // 첫 rotation 은 sticky 세팅
  }
  return all[0] || null;
}

function markExhausted(name, seconds) {
  const ex = readJSON(EXHAUSTED, {});
  const until = Math.floor(Date.now() / 1000) + (seconds || 3600);
  ex[name] = { until, ts: new Date().toISOString() };
  writeJSON(EXHAUSTED, ex);
}

function clearExhausted(name) {
  const ex = readJSON(EXHAUSTED, {});
  if (name) delete ex[name]; else for (const k of Object.keys(ex)) delete ex[k];
  writeJSON(EXHAUSTED, ex);
}

// score penalty (2026-04-19 · M13g): "soft prefer next" — markExhausted 만큼은 아닌데
// 다음 request 에서 이 계정을 피하고 싶을 때 점수만 올려 sort 후순위로 내림. TTL 만료시
// 자동 복구. delta > 0 = 덜 선호 (score 오름차순 정렬 기준).
function addScorePenalty(name, delta, seconds) {
  if (!name) return;
  const pen = readJSON(PENALTY, {});
  const until = Math.floor(Date.now() / 1000) + (seconds || 300);
  pen[name] = { delta: Number(delta) || 0, until, ts: new Date().toISOString() };
  writeJSON(PENALTY, pen);
}

function clearPenalty(name) {
  const pen = readJSON(PENALTY, {});
  if (name) delete pen[name]; else for (const k of Object.keys(pen)) delete pen[k];
  writeJSON(PENALTY, pen);
}

function listPenalties() {
  const pen = readJSON(PENALTY, {});
  const now = Math.floor(Date.now() / 1000);
  const out = {};
  for (const [k, v] of Object.entries(pen)) {
    if (v && v.until && v.until > now) out[k] = v;
  }
  return out;
}

function statusTable() {
  const acc = readJSON(POOL_CFG, { accounts: [] });
  const usage = readJSON(USAGE_CACHE, {});
  const ex = readJSON(EXHAUSTED, {});
  const now = Math.floor(Date.now() / 1000);
  const rows = [];
  for (const a of acc.accounts || []) {
    const u = usage[a.name] || {};
    const e = ex[a.name] || {};
    let tag = 'ok';
    if ((u.week_all_pct || 0) >= 100) tag = 'week_exhausted';
    else if ((u.session_pct || 0) >= 95) tag = 'session_cap';
    else if (u._retry_at && u._retry_at > now) tag = 'retry_at=' + u._retry_at;
    else if (e.until && e.until > now) tag = 'local_exh_until=' + e.until;
    else if (u.error && u.error !== null) tag = String(u.error);
    rows.push({
      name: a.name,
      week: u.week_all_pct || 0,
      session: u.session_pct || 0,
      tag,
    });
  }
  return rows;
}

module.exports = {
  loadPool,
  pickBest,
  markExhausted,
  clearExhausted,
  addScorePenalty,
  clearPenalty,
  listPenalties,
  stickyGet,
  stickySet,
  stickyClear,
  currentAccountName,
  basenameToAcct,
  statusTable,
  paths: { POOL_CFG, USAGE_CACHE, EXHAUSTED, STATE_DIR, STICKY, PENALTY },
};

// CLI: node pool.js {pick|status|clear [name]}
if (require.main === module) {
  const cmd = process.argv[2] || 'pick';
  if (cmd === 'pick') {
    const best = pickBest();
    if (!best) { process.exit(1); }
    // format: <name>\t<config_dir>\t<week_pct>\t<session_pct>
    process.stdout.write([best.name, best.config_dir, best.week_pct, best.session_pct].join('\t') + '\n');
  } else if (cmd === 'status') {
    const rows = statusTable();
    for (const r of rows) {
      process.stdout.write([r.name, r.week + '%', r.session + '%', r.tag].join('\t') + '\n');
    }
  } else if (cmd === 'clear') {
    clearExhausted(process.argv[3]);
    process.stdout.write('cleared\n');
  } else if (cmd === 'penalty') {
    const sub = process.argv[3] || 'list';
    if (sub === 'add') {
      const name = process.argv[4];
      const delta = parseFloat(process.argv[5] || '50');
      const ttl = parseInt(process.argv[6] || '300', 10);
      if (!name) { process.stderr.write('usage: node pool.js penalty add <name> <delta> <ttl_sec>\n'); process.exit(2); }
      addScorePenalty(name, delta, ttl);
      process.stdout.write(`added\t${name}\t${delta}\t${ttl}\n`);
    } else if (sub === 'list') {
      const pen = listPenalties();
      for (const [k, v] of Object.entries(pen)) process.stdout.write([k, v.delta, 'until=' + v.until].join('\t') + '\n');
    } else if (sub === 'clear') {
      clearPenalty(process.argv[4]);
      process.stdout.write('cleared\n');
    } else {
      process.stderr.write('usage: node pool.js penalty {add|list|clear} ...\n');
      process.exit(2);
    }
  } else if (cmd === 'sticky') {
    const sub = process.argv[3] || 'get';
    const sid = process.argv[4];
    if (sub === 'get' && sid) process.stdout.write((stickyGet(sid) || '') + '\n');
    else if (sub === 'set' && sid && process.argv[5]) { stickySet(sid, process.argv[5]); process.stdout.write('set\n'); }
    else if (sub === 'clear') { stickyClear(sid); process.stdout.write('cleared\n'); }
    else if (sub === 'list') {
      const st = readJSON(STICKY, {});
      for (const [k, v] of Object.entries(st)) process.stdout.write(`${k}\t${v.acct}\t${v.last_used}\n`);
    } else { process.stderr.write('usage: node pool.js sticky {get|set|clear|list} [sid] [acct]\n'); process.exit(2); }
  } else {
    process.stderr.write('usage: node pool.js {pick|status|clear [name]|sticky ...}\n');
    process.exit(2);
  }
}
