// shared/claudx/token-health.js — append-only audit log for token lifecycle events.
//
// 저장 경로: $CLAUDX_STATE/token-health.jsonl (default ~/.airgenome/claudx/)
// 스키마: {ts, acct, event, old_rt_sha8, new_rt_sha8, old_at_sha8, new_at_sha8,
//          old_exp, new_exp, writer, host, result, reason}
// event:
//   probe     — 상태 조회만 수행 (drift/doctor 등)
//   refresh   — refresh 시도 (성공/실패 모두)
//   rotate    — refresh 응답의 refresh_token 이 바뀜 (rotation 감지)
//   revoke    — 서버가 invalid_grant 로 거절
//   drift     — file vs kc 불일치
//   write     — file/KC 쓰기 이벤트
//
// CLI:
//   node token-health.js append <json>
//   node token-health.js tail [n]

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = process.env.HOME || process.env.USERPROFILE;
const STATE_DIR = process.env.CLAUDX_STATE || path.join(HOME, '.airgenome', 'claudx');
const LOG_PATH = path.join(STATE_DIR, 'token-health.jsonl');

function _mkdirp(p) { try { fs.mkdirSync(p, { recursive: true }); } catch {} }

function appendEvent(ev) {
  if (!ev || typeof ev !== 'object') throw new TypeError('event must be object');
  const record = Object.assign(
    {
      ts: new Date().toISOString(),
      host: os.hostname(),
      writer: process.env.AG_WRITER || path.basename(process.argv[1] || process.title || 'unknown'),
    },
    ev,
  );
  _mkdirp(STATE_DIR);
  fs.appendFileSync(LOG_PATH, JSON.stringify(record) + '\n');
  return record;
}

function tail(n) {
  try {
    const txt = fs.readFileSync(LOG_PATH, 'utf8');
    const lines = txt.split('\n').filter(Boolean);
    return lines.slice(-Math.max(1, n || 50));
  } catch {
    return [];
  }
}

module.exports = { appendEvent, tail, LOG_PATH };

if (require.main === module) {
  const cmd = process.argv[2];
  if (cmd === 'append') {
    const raw = process.argv[3];
    if (!raw) { process.stderr.write('usage: append <json>\n'); process.exit(2); }
    let ev;
    try { ev = JSON.parse(raw); } catch (e) { process.stderr.write('bad json: ' + e.message + '\n'); process.exit(2); }
    const rec = appendEvent(ev);
    process.stdout.write(JSON.stringify(rec) + '\n');
  } else if (cmd === 'tail') {
    const n = parseInt(process.argv[3] || '50', 10);
    for (const l of tail(n)) process.stdout.write(l + '\n');
  } else {
    process.stderr.write('usage: token-health.js {append <json>|tail [n]}\n');
    process.exit(2);
  }
}
