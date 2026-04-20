// L0 CORE — 수정 금지 (nexus/shared/L0.json 등록). 변경 시 PR + L0 갱신.
// claudx interceptor — M13 + M13c (경제) + M13d (v1/hive 이식)
// Loaded via NODE_OPTIONS="--require .../interceptor.js"
//
// Hooks in claudx_fetch (순서):
//   0. URL 필터 — api.anthropic.com 완성 요청만. oauth/token/feedback/metrics 제외
//   1. budgetBlock() — 일일/월간 cost cap 초과시 synthetic 429 반환
//   2. cacheGet() — request body hash → TTL 24h 캐시 hit 이면 즉시 반환 (API 호출 생략)
//   3. origFetch
//   4. isRateLimited → rotation (Authorization swap + replay)
//   5. recordCost() — usage 파싱 → cost.jsonl append
//   6. freshenUsageCache() — anthropic-ratelimit-* 헤더에서 remaining 추출 → usage-cache.json 즉시 반영
//   7. preemptSwapCheck() — remaining < 임계치면 다음 요청 위해 exhausted 마크
//   8. cacheSet() — 성공 응답 cache 저장 (stream 제외)
//   9. scrubRateLimitHeaders() — UI 경고 원천 차단
//
// Storage:
//   $CLAUDX_STATE/cost.jsonl       — {ts, sid, acct, model, in, out, cache_r, cache_w, usd, cwd}
//   $CLAUDX_STATE/cache/<hash>.json — {ts, status, body, headers, usage}
//   $CLAUDX_STATE/sticky.json       — {sid: {acct, last_used}} (pool.js 사용)
//   $CLAUDX_STATE/rotations.jsonl   — rotation/budget/cache 이벤트 로그 (redact 된 payload)
//
// Env:
//   CLAUDX_BUDGET_DAILY   $5 기본값
//   CLAUDX_BUDGET_MONTHLY $50 기본값  (hive pre_provider 호환)
//   CLAUDX_PREEMPT_PCT       0.30 (soft: min(req,tok) remaining < 30% → pool score +50 (soft prefer next))
//   CLAUDX_PREEMPT_HARD_PCT  0.15 (hard: < 15% → markExhausted 300s)
//   CLAUDX_PREEMPT_PENALTY   50   (soft 진입 시 pool.addScorePenalty delta)
//   CLAUDX_PREEMPT_PEN_TTL   300  (penalty TTL 초)
//   CLAUDX_CACHE_TTL_SEC  86400
//   CLAUDX_NO_CACHE       1 → 캐시 전면 비활성
//   CLAUDX_NO_BUDGET      1 → budget cap 비활성
//   CLAUDX_NO_REDACT      1 → log redact 비활성
//   CLAUDX_MAX_ROT        4
//   CLAUDX_SCRUB          0 → UI 헤더 스크럽 끄기
//   CLAUDX_STALL_MAX_SEC  300 (pool 전체 exhausted 시 synthetic wait 최대 대기 — TUI crash 회피)
//   CLAUDX_STALL_POLL_SEC 10  (stall 중 pickBest 재시도 주기)

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const pool = require('./pool.js');

const STATE_DIR = pool.paths.STATE_DIR;
const ROT_LOG = path.join(STATE_DIR, 'rotations.jsonl');
const COST_LOG = path.join(STATE_DIR, 'cost.jsonl');
const PERF_LOG = path.join(STATE_DIR, 'perf.jsonl');
const CACHE_DIR = path.join(STATE_DIR, 'cache');
try { fs.mkdirSync(STATE_DIR, { recursive: true }); } catch (_) {}
try { fs.mkdirSync(CACHE_DIR, { recursive: true }); } catch (_) {}

// Stall 방지 임계치 (2026-04-19 사용자 observe: "갑자기 전달 많을때 멈춤, 확 돌아옴")
// - HEAVY_BODY_BYTES: 이 이상 response 는 cache/badge skip (clone+text read 가 stream block)
// - PERF_SLOW_MS: 각 hook 수행시간 > 임계치 → perf.jsonl append (모니터링)
const HEAVY_BODY_BYTES = parseInt(process.env.CLAUDX_HEAVY_BODY_BYTES || '500000', 10);
const PERF_SLOW_MS = parseInt(process.env.CLAUDX_PERF_SLOW_MS || '50', 10);
function logPerf(phase, ms, extra) {
  if (ms < PERF_SLOW_MS) return;
  try {
    fs.appendFileSync(PERF_LOG, JSON.stringify({ ts: new Date().toISOString(), phase, ms, ...(extra || {}) }) + '\n');
  } catch (_) {}
}
function timed(phase, fn) {
  const t0 = Date.now();
  try {
    const r = fn();
    if (r && typeof r.then === 'function') {
      return r.finally(() => logPerf(phase, Date.now() - t0));
    }
    logPerf(phase, Date.now() - t0);
    return r;
  } catch (e) {
    logPerf(phase, Date.now() - t0, { error: String(e).slice(0, 200) });
    throw e;
  }
}

const MAX_ROT = parseInt(process.env.CLAUDX_MAX_ROT || '4', 10);
const EXH_SEC = parseInt(process.env.CLAUDX_EXH_SEC || '3600', 10);
const STALL_MAX_SEC = parseInt(process.env.CLAUDX_STALL_MAX_SEC || '300', 10);
const STALL_POLL_SEC = Math.max(1, parseInt(process.env.CLAUDX_STALL_POLL_SEC || '10', 10));
const DEBUG = process.env.CLAUDX_DEBUG === '1';
const SCRUB = process.env.CLAUDX_SCRUB !== '0';
const BUDGET_DAILY = parseFloat(process.env.CLAUDX_BUDGET_DAILY || '5');
const BUDGET_MONTHLY = parseFloat(process.env.CLAUDX_BUDGET_MONTHLY || '50');
const NO_BUDGET = process.env.CLAUDX_NO_BUDGET === '1';
// 2026-04-21: 12계정 기준 설계(0.30/0.15)가 4계정 환경에서 과대 발동 → 매 요청마다
// 남은 한도가 자연스레 15% 밑으로 떨어져 preempt_hard 폭주 → 4계정이 순식간 전부
// exhausted 마크되고 풀 empty. 임계치를 0.10/0.03 로 낮춰 실제 임박(3%)에만 hard 발동.
const PREEMPT_PCT = parseFloat(process.env.CLAUDX_PREEMPT_PCT || '0.10');
const PREEMPT_HARD_PCT = parseFloat(process.env.CLAUDX_PREEMPT_HARD_PCT || '0.03');
const PREEMPT_PENALTY = parseFloat(process.env.CLAUDX_PREEMPT_PENALTY || '50');
const PREEMPT_PEN_TTL = parseInt(process.env.CLAUDX_PREEMPT_PEN_TTL || '300', 10);
const CACHE_TTL = parseInt(process.env.CLAUDX_CACHE_TTL_SEC || '86400', 10);
const NO_CACHE = process.env.CLAUDX_NO_CACHE === '1';
const NO_REDACT = process.env.CLAUDX_NO_REDACT === '1';

// --- Pricing table (USD per 1M tokens) — 대략. 정확 필요시 조정 ---
const PRICE = {
  'claude-opus-4': { in: 15, out: 75 },
  'claude-opus-4-7': { in: 15, out: 75 },
  'opus': { in: 15, out: 75 },
  'claude-sonnet-4': { in: 3, out: 15 },
  'claude-sonnet-4-6': { in: 3, out: 15 },
  'sonnet': { in: 3, out: 15 },
  'claude-haiku-4-5': { in: 0.8, out: 4 },
  'haiku': { in: 0.8, out: 4 },
  '_default': { in: 3, out: 15 },
};

function pricefor(model) {
  if (!model) return PRICE._default;
  if (PRICE[model]) return PRICE[model];
  for (const k of Object.keys(PRICE)) if (k !== '_default' && model.indexOf(k) >= 0) return PRICE[k];
  return PRICE._default;
}

function usdOfUsage(model, u) {
  const p = pricefor(model);
  const inTok = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) * 0.1 + (u.cache_creation_input_tokens || 0) * 1.25;
  const outTok = u.output_tokens || 0;
  return inTok * p.in / 1e6 + outTok * p.out / 1e6;
}

// --- Input filter (v1 gate.hexa 이식) ---

const HEAVY_KEYWORDS = [
  /\bstress\s+test\b/i,
  /\bfork[\s_-]?bomb\b/i,
  /:\(\)\{\s*:\|:&\s*\};:/,  // classic fork bomb
  /\byes\s*>\s*\//,            // yes > /...
  /\bcargo\s+build\s+--release\s+--all\s+--all-features\b/i,
  /\bblowup[\s_-]?engine\b/i,
  /\brm\s+-rf\s+\/(?:\*|$)/,
  /\bdd\s+if=\/dev\/zero\s+of=\//i,
];

const NO_UNSAFE = process.env.CLAUDX_UNSAFE !== '1';
const HEAVY_FILTER_ON = process.env.CLAUDX_HEAVY_FILTER === '1';
// Default: size 체크 OFF (Anthropic 서버가 실제 한도 enforce). 명시적으로 제한 원하면 env 로.
// heavy_keyword 필터는 false positive 가 잦아 기본 OFF. 필요 시 CLAUDX_HEAVY_FILTER=1.
const MAX_PROMPT_BYTES = parseInt(process.env.CLAUDX_MAX_PROMPT_BYTES || '0', 10); // 0 = unlimited

// M13f UI tune flags
const TITLE_LOCK = process.env.CLAUDX_TITLE_LOCK !== '0';
const NO_BADGE = process.env.CLAUDX_NO_BADGE === '1';
const NO_SLASH_ALIAS = process.env.CLAUDX_NO_SLASH_ALIAS === '1';

// Slash alias table — commands.json autonomous 키워드 축약
const SLASH_ALIAS = {
  '/s': 'smash',
  '/sm': 'smash',
  '/f': 'free',
  '/fd': 'free dfs 3',
  '/g': 'go',
  '/t': 'todo',
  '/k': 'keep',
  '/lm': 'lm',
};

function looksLikePathishPrompt(text) {
  if (!text) return false;
  const t = String(text).trim();
  return /^(~\/|\/Users\/|\/home\/|\.{1,2}\/)/.test(t) || /\s(?:~\/|\/Users\/|\/home\/|\.{1,2}\/)\S+/.test(t);
}

function textBlocksFromMessage(msg) {
  if (!msg) return [];
  if (typeof msg.content === 'string') return [msg.content];
  if (!Array.isArray(msg.content)) return [];
  const out = [];
  for (const c of msg.content) {
    if (c && c.type === 'text' && typeof c.text === 'string') out.push(c.text);
  }
  return out;
}

function expandSlashAlias(bodyStr) {
  if (!bodyStr || NO_SLASH_ALIAS) return bodyStr;
  try {
    const j = JSON.parse(bodyStr);
    if (!Array.isArray(j.messages) || j.messages.length === 0) return bodyStr;
    const last = j.messages[j.messages.length - 1];
    if (last.role !== 'user') return bodyStr;
    const mutate = (text) => {
      const trimmed = text.trim();
      for (const [from, to] of Object.entries(SLASH_ALIAS)) {
        if (trimmed === from) return to;
        if (trimmed.startsWith(from + ' ')) return to + trimmed.slice(from.length);
        if (trimmed.startsWith(from + '\n')) return to + trimmed.slice(from.length);
      }
      return text;
    };
    if (typeof last.content === 'string') {
      const n = mutate(last.content);
      if (n !== last.content) { last.content = n; return JSON.stringify(j); }
    } else if (Array.isArray(last.content)) {
      let touched = false;
      for (const c of last.content) {
        if (c.type === 'text' && typeof c.text === 'string') {
          const n = mutate(c.text);
          if (n !== c.text) { c.text = n; touched = true; }
        }
      }
      if (touched) return JSON.stringify(j);
    }
  } catch (_) {}
  return bodyStr;
}

// Badge prefix (print/json 모드 한정 — stream TUI 는 stderr status 로 우회)
function injectBadge(jsonText, acct) {
  if (NO_BADGE || !jsonText) return jsonText;
  try {
    const j = JSON.parse(jsonText);
    if (typeof j.result === 'string') {
      const today = todayCostUSD().toFixed(3);
      const prefix = `[${acct} · $${today}] `;
      j.result = prefix + j.result;
      return JSON.stringify(j);
    }
  } catch (_) {}
  return jsonText;
}

function todayCostUSD() {
  try {
    const cutoff = Math.floor(Date.now() / 1000) - 86400;
    const data = fs.readFileSync(COST_LOG, 'utf8');
    let total = 0;
    for (const line of data.split('\n')) {
      if (!line) continue;
      try {
        const j = JSON.parse(line);
        const t = Math.floor(new Date(j.ts).getTime() / 1000);
        if (t >= cutoff) total += j.usd || 0;
      } catch (_) {}
    }
    return total;
  } catch (_) { return 0; }
}

// Title lock — stdout 의 OSC 0;...\007 / 1;... / 2;... 이스케이프 필터
// claude TUI 가 session 중 title 덮어쓰는 것 방지.
if (TITLE_LOCK && process.stdout && typeof process.stdout.write === 'function') {
  const cwdName = path.basename(process.cwd());
  const origWrite = process.stdout.write.bind(process.stdout);
  const TITLE_RE = /\x1B\]([012]);[^\x07\x1B]*(?:\x07|\x1B\\)/g;
  process.stdout.write = function claudx_write(chunk, enc, cb) {
    try {
      if (typeof chunk === 'string') {
        chunk = chunk.replace(TITLE_RE, '');
      } else if (Buffer.isBuffer(chunk) && chunk.includes(0x1B)) {
        const s = chunk.toString('utf8');
        if (/\x1B\]/.test(s)) chunk = Buffer.from(s.replace(TITLE_RE, ''), 'utf8');
      }
    } catch (_) {}
    return origWrite(chunk, enc, cb);
  };
  // 한번 고정
  try { origWrite(`\x1B]0;${cwdName}\x07`); } catch (_) {}
}

function checkInputFilter(bodyStr) {
  if (!bodyStr || !NO_UNSAFE) return null;
  // image/document 블록 있으면 size 체크 skip (base64 팽창 감안)
  let hasBinaryContent = false;
  let msgs = [];
  let lastUserMsg = null;
  try {
    const j = JSON.parse(bodyStr);
    msgs = j.messages || [];
    for (const m of msgs) {
      if (m && m.role === 'user') lastUserMsg = m;
      if (Array.isArray(m.content)) {
        for (const c of m.content) {
          if (c && (c.type === 'image' || c.type === 'document' || c.type === 'tool_result')) {
            hasBinaryContent = true; break;
          }
        }
      }
      if (hasBinaryContent) break;
    }
  } catch (_) {}
  // size gate — last user text 에만 적용 (transcript/tool_result aggregate 는 면제).
  // 이유: 병렬 sub-agent 결과 누적으로 bodyStr 전체 길이 기반 체크는 false positive.
  if (MAX_PROMPT_BYTES > 0 && !hasBinaryContent) {
    const lastUserTexts = textBlocksFromMessage(lastUserMsg);
    let lastUserBytes = 0;
    for (const t of lastUserTexts) lastUserBytes += Buffer.byteLength(t, 'utf8');
    if (lastUserBytes > MAX_PROMPT_BYTES) {
      return { kind: 'size', bytes: lastUserBytes, limit: MAX_PROMPT_BYTES };
    }
  }
  // heavy keyword — 마지막 user text 입력에만 적용.
  // 첨부 파일/과거 transcript 컨텍스트까지 훑으면 정상적인 "path + fix" 요청이 false positive 된다.
  if (HEAVY_FILTER_ON) {
    const lastUserTexts = textBlocksFromMessage(lastUserMsg);
    for (const content of lastUserTexts) {
      if (looksLikePathishPrompt(content)) continue;
      for (const re of HEAVY_KEYWORDS) {
        if (re.test(content)) return { kind: 'heavy_keyword', pattern: re.toString() };
      }
    }
  }
  return null;
}

function syntheticFilterBlock(verdict) {
  const body = JSON.stringify({
    type: 'error',
    error: { type: 'invalid_request_error', message: 'claudx input filter: ' + verdict.kind + ' (CLAUDX_UNSAFE=1 로 bypass)' },
  });
  return new Response(body, { status: 400, headers: { 'content-type': 'application/json' } });
}

// --- Redact (M13d / v1e) ---

const REDACT_PATTERNS = [
  [/Bearer\s+[A-Za-z0-9._-]{20,}/g, 'Bearer ***'],
  [/sk-ant-[A-Za-z0-9_-]{20,}/g, 'sk-ant-***'],
  [/sk-[A-Za-z0-9_-]{30,}/g, 'sk-***'],
  [/"(password|api[_-]?key|secret|token)"\s*:\s*"[^"]+"/gi, '"$1":"***"'],
  [/password\s*=\s*\S+/gi, 'password=***'],
  [/\b\d{3}-\d{2}-\d{4}\b/g, '***-**-****'],
  [/\b010-\d{4}-\d{4}\b/g, '010-****-****'],
];

function redact(s) {
  if (NO_REDACT || !s) return s;
  let out = s;
  for (const [re, rep] of REDACT_PATTERNS) out = out.replace(re, rep);
  return out;
}

function logEvent(evt) {
  const line = JSON.stringify({ ts: new Date().toISOString(), pid: process.pid, ...evt });
  try { fs.appendFileSync(ROT_LOG, line + '\n'); } catch (_) {}
  if (DEBUG) try { process.stderr.write('[claudx] ' + line + '\n'); } catch (_) {}
}

// --- URL classification ---

function urlString(input) {
  if (typeof input === 'string') return input;
  if (input && typeof input.url === 'string') return input.url;
  try { return String(input); } catch (_) { return ''; }
}

function isAnthropicCompletion(u) {
  if (!u.includes('api.anthropic.com')) return false;
  if (u.includes('/api/oauth/')) return false;
  if (u.includes('/oauth/token')) return false;
  if (u.includes('/api/claude_cli_feedback')) return false;
  if (u.includes('/api/claude_code/metrics')) return false;
  return true;
}

// --- Header helpers ---

function getAuth(headers) {
  if (!headers) return null;
  try {
    if (typeof Headers !== 'undefined' && headers instanceof Headers) {
      return headers.get('authorization') || headers.get('Authorization');
    }
  } catch (_) {}
  if (Array.isArray(headers)) {
    for (const e of headers) if (e && String(e[0]).toLowerCase() === 'authorization') return e[1];
    return null;
  }
  if (typeof headers === 'object') return headers.Authorization || headers.authorization || null;
  return null;
}

function setAuth(headers, token) {
  const bearer = 'Bearer ' + token;
  try {
    if (typeof Headers !== 'undefined' && headers instanceof Headers) {
      const c = new Headers(headers);
      c.set('Authorization', bearer); c.delete('authorization');
      return c;
    }
  } catch (_) {}
  if (Array.isArray(headers)) {
    const n = headers.filter(e => !e || String(e[0]).toLowerCase() !== 'authorization');
    n.push(['Authorization', bearer]);
    return n;
  }
  if (!headers || typeof headers !== 'object') return { Authorization: bearer };
  const n = {};
  for (const k of Object.keys(headers)) if (k.toLowerCase() !== 'authorization') n[k] = headers[k];
  n.Authorization = bearer;
  return n;
}

function readHeader(resp, name) {
  try { return resp.headers.get(name); } catch (_) { return null; }
}

// --- Rate-limit detection ---

async function isRateLimited(resp) {
  if (resp.status === 429) return { hit: true, reason: 'status_429' };
  if (resp.status === 401) return { hit: true, reason: 'status_401_bearer' };
  if (resp.status < 400) return { hit: false };
  try {
    const clone = resp.clone();
    const txt = await clone.text();
    if (/rate_limit_error/i.test(txt)) return { hit: true, reason: 'body_rate_limit_error' };
    if (/usage[ _]limit/i.test(txt)) return { hit: true, reason: 'body_usage_limit' };
    if (/exceeded your/i.test(txt)) return { hit: true, reason: 'body_exceeded' };
    if (/invalid[ _]bearer/i.test(txt)) return { hit: true, reason: 'body_invalid_bearer' };
  } catch (_) {}
  return { hit: false };
}

// --- Cost ledger (e1) ---

async function parseUsageFromBody(resp) {
  // stream 응답은 여기서는 포기 (cli 가 --output-format json 이면 단일 JSON)
  // 2026-04-19: content-type event-stream 은 전체 body read 가 stream 종료까지 block 하므로 skip.
  try {
    const ct = resp.headers.get('content-type') || '';
    if (ct.includes('event-stream')) return null;
    const clone = resp.clone();
    const txt = await clone.text();
    if (!txt) return null;
    const trimmed = txt.trim();
    // stream-json 은 여러 라인. 마지막 "type":"result" 에서 usage 추출
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      const j = JSON.parse(trimmed);
      return j.usage || (j.message && j.message.usage) || null;
    }
    // stream-json multi-line
    const lines = trimmed.split('\n').filter(Boolean);
    for (let i = lines.length - 1; i >= 0; i--) {
      try {
        const j = JSON.parse(lines[i]);
        if (j.usage) return j.usage;
        if (j.message && j.message.usage) return j.message.usage;
      } catch (_) {}
    }
  } catch (_) {}
  return null;
}

function modelFromBody(body) {
  if (!body) return null;
  try {
    const j = typeof body === 'string' ? JSON.parse(body) : body;
    return j.model || null;
  } catch (_) { return null; }
}

async function recordCost(resp, { acct, model, sid, cwd }) {
  const u = await parseUsageFromBody(resp);
  if (!u) return;
  const usd = usdOfUsage(model, u);
  const rec = {
    ts: new Date().toISOString(),
    sid: sid || '',
    acct,
    model: model || '',
    in: u.input_tokens || 0,
    out: u.output_tokens || 0,
    cache_r: u.cache_read_input_tokens || 0,
    cache_w: u.cache_creation_input_tokens || 0,
    usd: Number(usd.toFixed(6)),
    cwd: cwd || process.cwd(),
  };
  try { fs.appendFileSync(COST_LOG, JSON.stringify(rec) + '\n'); } catch (_) {}
}

// --- Budget cap (e4) ---

function sumCostSince(sinceEpochSec) {
  if (!fs.existsSync(COST_LOG)) return 0;
  let total = 0;
  try {
    const data = fs.readFileSync(COST_LOG, 'utf8');
    for (const line of data.split('\n')) {
      if (!line) continue;
      try {
        const j = JSON.parse(line);
        const t = Math.floor(new Date(j.ts).getTime() / 1000);
        if (t >= sinceEpochSec) total += (j.usd || 0);
      } catch (_) {}
    }
  } catch (_) {}
  return total;
}

function budgetBlock() {
  if (NO_BUDGET) return null;
  const now = Math.floor(Date.now() / 1000);
  const dayAgo = now - 86400;
  const monAgo = now - 86400 * 30;
  const daily = sumCostSince(dayAgo);
  const monthly = sumCostSince(monAgo);
  if (daily >= BUDGET_DAILY) return { kind: 'daily', spent: daily, cap: BUDGET_DAILY };
  if (monthly >= BUDGET_MONTHLY) return { kind: 'monthly', spent: monthly, cap: BUDGET_MONTHLY };
  return null;
}

function synthetic429(reason, detail) {
  const body = JSON.stringify({
    type: 'error',
    error: { type: 'rate_limit_error', message: 'claudx budget cap reached: ' + reason + ' ($' + (detail.spent || 0).toFixed(2) + ' / cap $' + detail.cap + ')' },
  });
  return new Response(body, { status: 429, headers: { 'content-type': 'application/json' } });
}

// --- Preemptive swap (e2) ---

function preemptSwapCheck(resp, acct) {
  const rem = parseInt(readHeader(resp, 'anthropic-ratelimit-requests-remaining') || '0', 10);
  const lim = parseInt(readHeader(resp, 'anthropic-ratelimit-requests-limit') || '1', 10);
  const tokRem = parseInt(readHeader(resp, 'anthropic-ratelimit-input-tokens-remaining') || '0', 10);
  const tokLim = parseInt(readHeader(resp, 'anthropic-ratelimit-input-tokens-limit') || '1', 10);
  const rPct = lim > 0 ? rem / lim : 1;
  const tPct = tokLim > 0 ? tokRem / tokLim : 1;
  // AND 가 아닌 weighted: 둘 중 하나라도 임계 미만이면 발동.
  //  - HARD (< 15% 기본): 완전 exhausted 마크 (5분) → 전체 pool 에서 제외
  //  - SOFT (< 30% 기본): pool.addScorePenalty(+50, 300s) → sort 후순위로만 내림 (fallback 가능)
  const minPct = Math.min(rPct, tPct);
  if (minPct < PREEMPT_HARD_PCT) {
    pool.markExhausted(acct, 300);
    logEvent({ event: 'preempt_hard', acct, req_rem_pct: rPct, tok_rem_pct: tPct, threshold: PREEMPT_HARD_PCT });
  } else if (minPct < PREEMPT_PCT) {
    pool.addScorePenalty(acct, PREEMPT_PENALTY, PREEMPT_PEN_TTL);
    logEvent({ event: 'preempt_soft', acct, req_rem_pct: rPct, tok_rem_pct: tPct, threshold: PREEMPT_PCT, delta: PREEMPT_PENALTY, ttl: PREEMPT_PEN_TTL });
  }
}

// --- Usage cache freshen (e7) ---

function freshenUsageCache(resp, acct) {
  try {
    const cache = pool.paths.USAGE_CACHE;
    if (!fs.existsSync(cache)) return;
    const obj = JSON.parse(fs.readFileSync(cache, 'utf8'));
    const reqRem = parseInt(readHeader(resp, 'anthropic-ratelimit-requests-remaining') || '-1', 10);
    const reqLim = parseInt(readHeader(resp, 'anthropic-ratelimit-requests-limit') || '-1', 10);
    const reset = readHeader(resp, 'anthropic-ratelimit-requests-reset');
    if (reqRem < 0 || reqLim <= 0) return;
    const pct = Math.round(((reqLim - reqRem) / reqLim) * 100);
    obj[acct] = obj[acct] || {};
    obj[acct].session_pct = pct;
    if (reset) obj[acct]._retry_at = Math.floor(new Date(reset).getTime() / 1000);
    // atomic write
    const tmp = cache + '.tmp.' + process.pid;
    fs.writeFileSync(tmp, JSON.stringify(obj, null, 2));
    fs.renameSync(tmp, cache);
  } catch (_) {}
}

// --- Cache (e3) ---

function cacheHashFromInit(input, init) {
  try {
    const headers = init && init.headers ? init.headers : (input && input.headers) || {};
    // Authorization 는 해시에서 제외 — 계정 독립 캐시
    let authStripped = {};
    if (typeof Headers !== 'undefined' && headers instanceof Headers) {
      for (const [k, v] of headers.entries()) if (k.toLowerCase() !== 'authorization') authStripped[k] = v;
    } else if (Array.isArray(headers)) {
      for (const [k, v] of headers) if (String(k).toLowerCase() !== 'authorization') authStripped[k] = v;
    } else if (typeof headers === 'object') {
      for (const k of Object.keys(headers)) if (k.toLowerCase() !== 'authorization') authStripped[k] = headers[k];
    }
    const body = (init && init.body) || (input && typeof input.text === 'function' ? null : null);
    const key = JSON.stringify({ url: urlString(input), method: (init && init.method) || 'POST', body: typeof body === 'string' ? body : '', hdr: authStripped });
    return crypto.createHash('sha256').update(key).digest('hex');
  } catch (_) { return null; }
}

async function cacheHashFromRequestObject(req) {
  try {
    const headers = {};
    for (const [k, v] of req.headers.entries()) if (k.toLowerCase() !== 'authorization') headers[k] = v;
    const body = req.body ? await req.clone().text() : '';
    const key = JSON.stringify({ url: req.url, method: req.method, body, hdr: headers });
    return crypto.createHash('sha256').update(key).digest('hex');
  } catch (_) { return null; }
}

function cacheGet(hash) {
  if (NO_CACHE || !hash) return null;
  const p = path.join(CACHE_DIR, hash + '.json');
  if (!fs.existsSync(p)) return null;
  try {
    const rec = JSON.parse(fs.readFileSync(p, 'utf8'));
    const age = (Date.now() / 1000) - (rec.ts || 0);
    if (age > CACHE_TTL) return null;
    return rec;
  } catch (_) { return null; }
}

function cacheSet(hash, resp, bodyText) {
  if (NO_CACHE || !hash || !bodyText) return;
  try {
    const hdrs = {};
    try { for (const [k, v] of resp.headers.entries()) hdrs[k] = v; } catch (_) {}
    const rec = { ts: Math.floor(Date.now() / 1000), status: resp.status, body: bodyText, headers: hdrs };
    const p = path.join(CACHE_DIR, hash + '.json');
    const tmp = p + '.tmp.' + process.pid;
    fs.writeFileSync(tmp, JSON.stringify(rec));
    fs.renameSync(tmp, p);
  } catch (_) {}
}

function respFromCache(rec) {
  const headers = new Headers(rec.headers || {});
  headers.set('x-claudx-cache', 'hit');
  return new Response(rec.body, { status: rec.status || 200, headers });
}

// --- UI hide: scrub rate-limit headers ---

function scrubRateLimitHeaders(resp) {
  if (!SCRUB) return resp;
  let touched = false;
  const headers = new Headers(resp.headers);
  for (const h of Array.from(headers.keys())) {
    const lk = h.toLowerCase();
    if (lk.startsWith('anthropic-ratelimit-') || lk === 'x-ratelimit-remaining' || lk === 'x-ratelimit-limit' || lk === 'x-ratelimit-reset' || lk === 'retry-after') {
      headers.delete(h); touched = true;
    }
  }
  if (!touched) return resp;
  return new Response(resp.body, { status: resp.status, statusText: resp.statusText, headers });
}

// --- Request rebuild for rotation ---

async function rebuildInput(origInput, newHeaders) {
  if (origInput && typeof origInput === 'object' && 'url' in origInput && 'method' in origInput) {
    try {
      const method = (origInput.method || 'GET').toUpperCase();
      const body = method !== 'GET' && method !== 'HEAD' ? await origInput.clone().arrayBuffer() : undefined;
      return new Request(origInput.url, {
        method: origInput.method, headers: newHeaders, body,
        credentials: origInput.credentials, cache: origInput.cache, redirect: origInput.redirect,
        referrer: origInput.referrer, integrity: origInput.integrity, keepalive: origInput.keepalive,
        mode: origInput.mode, signal: origInput.signal,
      });
    } catch (_) { return origInput.url; }
  }
  return origInput;
}

// --- Stall absorption (2026-04-19 · M13g): pool 전체 exhausted 시 429 반환 금지 ---
// 기본 rotation 은 pickBest null 을 만나면 원본 429 를 그대로 돌려주는데, claude CLI 는
// 429 body 를 stream 으로 받다가 disconnect → TUI 튕김. 모든 계정이 동시에 cap 에 닿는
// 구간에서 UX 가 끊긴다. 해결: pickBest 이 null 인 동안 poll 하며 exhausted.json 의
// until 기준으로 다음 wake 까지만 sleep. 최대 STALL_MAX_SEC 까지 흡수. 흡수 성공하면
// rotation 루프가 그대로 이어져 사용자는 단지 응답이 조금 늦는 것처럼 보임.

function _earliestReadyEpoch(triedNames) {
  try {
    const obj = JSON.parse(fs.readFileSync(pool.paths.EXHAUSTED, 'utf8') || '{}');
    const now = Math.floor(Date.now() / 1000);
    const tried = new Set(triedNames || []);
    let soonest = Infinity;
    for (const k of Object.keys(obj)) {
      if (tried.has(k)) continue;
      const u = obj[k] && obj[k].until;
      if (u && u > now && u < soonest) soonest = u;
    }
    return soonest === Infinity ? null : soonest;
  } catch (_) { return null; }
}

async function waitForCandidate(triedNames) {
  const startEpoch = Math.floor(Date.now() / 1000);
  const deadline = startEpoch + STALL_MAX_SEC;
  let iter = 0;
  while (Math.floor(Date.now() / 1000) < deadline) {
    const now = Math.floor(Date.now() / 1000);
    const soonest = _earliestReadyEpoch(triedNames);
    let sleepSec = Math.min(STALL_POLL_SEC, deadline - now);
    if (soonest) sleepSec = Math.min(sleepSec, Math.max(1, soonest - now));
    if (sleepSec < 1) sleepSec = 1;
    await new Promise(r => setTimeout(r, sleepSec * 1000));
    iter++;
    const next = pool.pickBest(triedNames);
    if (next) {
      logEvent({ event: 'stall_resolved', waited_s: Math.floor(Date.now() / 1000) - startEpoch, iter, to: next.name });
      return next;
    }
  }
  logEvent({ event: 'stall_timeout', waited_s: STALL_MAX_SEC, iter });
  return null;
}

// --- Install ---

const origFetch = globalThis.fetch.bind(globalThis);

globalThis.fetch = async function claudx_fetch(input, init) {
  const u = urlString(input);
  if (!isAnthropicCompletion(u)) return origFetch(input, init);

  // Hook 0: budget cap (synthetic 429 before network)
  const block = budgetBlock();
  if (block) {
    logEvent({ event: 'budget_block', kind: block.kind, spent: block.spent, cap: block.cap, url: u.slice(0, 80) });
    return synthetic429(block.kind, block);
  }

  // Hook 0b: input filter (size + heavy keyword) — v1 gate 이식
  let _earlyBodyStr = '';
  try {
    if (init && typeof init.body === 'string') _earlyBodyStr = init.body;
    else if (input && typeof input === 'object' && input.body) {
      try { _earlyBodyStr = await input.clone().text(); } catch (_) {}
    }
  } catch (_) {}
  const filterVerdict = checkInputFilter(_earlyBodyStr);
  if (filterVerdict) {
    logEvent({ event: 'input_filter_block', ...filterVerdict, url: u.slice(0, 80) });
    return syntheticFilterBlock(filterVerdict);
  }

  // Hook 0c: slash alias expansion (M13f — /s → smash 등)
  if (_earlyBodyStr && !NO_SLASH_ALIAS) {
    const expanded = expandSlashAlias(_earlyBodyStr);
    if (expanded !== _earlyBodyStr) {
      logEvent({ event: 'slash_alias_expanded' });
      init = Object.assign({}, init || {}, { body: expanded });
      _earlyBodyStr = expanded;
    }
  }

  // model / cwd / sid 추출 — logging 용
  let reqBodyStr = '';
  try {
    if (init && typeof init.body === 'string') reqBodyStr = init.body;
    else if (init && init.body) reqBodyStr = '';
    else if (input && typeof input === 'object' && input.body) {
      try { reqBodyStr = await input.clone().text(); } catch (_) {}
    }
  } catch (_) {}
  const reqBodyModel = modelFromBody(reqBodyStr);

  // Hook 2: cache
  let hash = null;
  try {
    if (input && typeof input === 'object' && 'url' in input && !init) {
      hash = await cacheHashFromRequestObject(input);
    } else {
      hash = cacheHashFromInit(input, init);
    }
  } catch (_) {}
  if (hash) {
    const hit = cacheGet(hash);
    if (hit) {
      logEvent({ event: 'cache_hit', hash: hash.slice(0, 16), url: u.slice(0, 80) });
      return respFromCache(hit);
    }
  }

  // 정상 경로 — rotation 루프
  let attempt = 0;
  const triedNames = [pool.currentAccountName()];
  let curInput = input;
  let curInit = init || {};

  while (true) {
    let resp;
    try {
      resp = await origFetch(curInput, curInit);
    } catch (e) { throw e; }

    const verdict = await isRateLimited(resp);

    if (!verdict.hit) {
      // 성공 응답 후처리 (2026-04-19 stall 방지):
      //   - recordCost/freshenUsage/preemptSwap 은 fire-and-forget (await 제거) — 응답 반환 blocking 해제.
      //   - HEAVY_BODY_BYTES 초과 (또는 event-stream) 이면 cache set + badge 건너뜀.
      //   - 각 hook 수행시간 perf.jsonl 기록 (PERF_SLOW_MS 초과시만).
      const curAcct = triedNames[triedNames.length - 1];
      const ct = resp.headers.get('content-type') || '';
      const cl = parseInt(resp.headers.get('content-length') || '0', 10) || 0;
      const heavy = ct.includes('event-stream') || (cl > 0 && cl > HEAVY_BODY_BYTES);

      // fire-and-forget (응답 return 과 동시 실행)
      Promise.resolve().then(() => timed('recordCost', () => recordCost(resp, { acct: curAcct, model: reqBodyModel, cwd: process.cwd() }))).catch(() => {});
      try { timed('freshenUsage', () => freshenUsageCache(resp, curAcct)); } catch (_) {}
      try { timed('preemptSwap', () => preemptSwapCheck(resp, curAcct)); } catch (_) {}

      if (heavy) {
        // 큰 payload — cache/badge 스킵하고 즉시 반환 (stream block 방지)
        logEvent({ event: 'heavy_skip', bytes: cl, ct: ct.slice(0, 40) });
        return scrubRateLimitHeaders(resp);
      }

      // cache set + badge injection (print/json 모드만)
      if (hash && !NO_CACHE) {
        try {
          const clone = resp.clone();
          const tTxt = Date.now();
          let txt = await clone.text();
          logPerf('cacheSet_read', Date.now() - tTxt, { bytes: txt ? txt.length : 0 });
          if (txt && txt.length > 0 && txt.length < HEAVY_BODY_BYTES) {
            const badged = timed('injectBadge', () => injectBadge(txt, curAcct));
            if (badged !== txt) {
              timed('cacheSet', () => cacheSet(hash, resp, badged));
              const headers = new Headers(resp.headers);
              return scrubRateLimitHeaders(new Response(badged, { status: resp.status, headers }));
            }
            timed('cacheSet', () => cacheSet(hash, resp, txt));
          }
        } catch (_) {}
      }

      return scrubRateLimitHeaders(resp);
    }

    // rotation 경로
    if (attempt >= MAX_ROT) {
      logEvent({ event: 'rotation_exhausted', url: u.slice(0, 100), attempt, reason: verdict.reason });
      return resp;
    }
    const curName = triedNames[triedNames.length - 1];
    pool.markExhausted(curName, EXH_SEC);
    let next = pool.pickBest(triedNames);
    if (!next) {
      // pool 전체 exhausted — 원본 429 반환은 TUI crash. STALL_MAX_SEC 까지 흡수 시도.
      logEvent({ event: 'stall_begin', attempt, tried: triedNames, reason: verdict.reason, max_s: STALL_MAX_SEC });
      try { resp.body && resp.body.cancel && resp.body.cancel(); } catch (_) {}
      next = await waitForCandidate(triedNames);
      if (!next) {
        logEvent({ event: 'no_candidate', attempt, tried: triedNames, reason: verdict.reason });
        // stall 도 실패 — 원본 응답이 이미 cancel 된 상태라 synthetic 503 으로 대체.
        return new Response(JSON.stringify({ type: 'error', error: { type: 'overloaded_error', message: 'claudx: all accounts exhausted, stall timeout (' + STALL_MAX_SEC + 's)' } }), { status: 503, headers: { 'content-type': 'application/json' } });
      }
    }
    logEvent({ event: 'rotating', from: curName, to: next.name, attempt, reason: verdict.reason, url: u.slice(0, 100), status: resp.status });
    const initHeaders = curInit.headers;
    const reqHeaders = !initHeaders && curInput && typeof curInput === 'object' && curInput.headers ? curInput.headers : initHeaders;
    const swapped = setAuth(reqHeaders || {}, next.token);
    curInit = Object.assign({}, curInit, { headers: swapped });
    if (curInput && typeof curInput === 'object' && 'url' in curInput && !initHeaders) {
      curInput = await rebuildInput(curInput, swapped);
    }
    triedNames.push(next.name);
    attempt++;
    try { resp.body && resp.body.cancel && resp.body.cancel(); } catch (_) {}
  }
};

logEvent({ event: 'interceptor_installed', version: 'M13+c+d', config_dir: process.env.CLAUDE_CONFIG_DIR || '' });
