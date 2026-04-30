# JSONL filter 재해석 5개 — production 측정 (2026-04-30)

own 5 site-list (jsonl reinterpret) 5 필터를 airgenome production binary 의 `--mode=run-once` 으로 실행하여 lossless / panic / N/A 분류 + hexa-lang gap 식별. 코드 수정 / hive,hexa-lang touch / git commit 없음 — 측정 + 본 문서 신규 작성만.

측정 환경:
- binary: `/Applications/airgenome.app/Contents/MacOS/airgenome` (166208 B, 2026-04-30 20:08)
- entry: `airgenome_loop_run_once()` → `hexa run <module>` (no extra argv)
- log: `~/.airgenome/loop-run-once.log`
- 코퍼스: `/Users/ghost/.claude-claude9/projects/-Users-ghost-Dev-airgenome/d07e7302-7c0a-4f5b-803e-422a45af2e4e.jsonl` (5,488,489 B, 5.23 MB) — 두 E1/E3 필터의 hard-coded sample

---

## 1. 5 filter 측정 결과 표

| # | site | ROI# | baseline (OLD) | post (NEW) | lossless / status |
|---|---|---|---|---|---|
| E1 | claude_quantum.hexa (cold-storage) | #5 jsonl + #82 entanglement | n/a — hexa parse panic | **panic** | parse panic — `try{}catch{}` 미지원 (line 204/213) |
| E2 | claude_bytes.hexa (SESSION-CONST 헤더 + delta body) | #5 jsonl + #65 const-lift + #64 uuid-table | n/a — hexa parse panic | **panic** | parse panic — `try{}catch{}` 미지원 (line 137/143) |
| E3 | claude_runtime.hexa (msgpack/cbor in-mem blob) | #5 jsonl + #1 in-mem reinterp + #41 mmap-light | n/a — hexa parse panic | **panic** | parse panic — `try{}catch{}` 미지원 (line 20/200/284/300/311/320) |
| P3 | columnar_projection.hexa (jq → 1-col cache) | #70 columnar projection | jq full-scan (per perf_lab P3 원래 측정 2-9× ref) | **N/A** (no-arg → usage) | run-once arg 미전달 → entry 가 jsonl path 부재로 usage 출력. 파서 OK / 패닉 0 / lossless 측정 불가 |
| P5 | result_cache.hexa (tool_result body cache) | #70 columnar + #82 dedup | jq 100회 (per perf_lab P5 원래 측정 4.8-7.8× ref) | **N/A** (no-arg → usage) | run-once arg 미전달 → entry 가 jsonl path 부재로 usage 출력. 파서 OK / 패닉 0 / lossless 측정 불가 |

**raw log evidence**: `~/.airgenome/loop-run-once.log` (3회 갱신) — 모든 5 entry 의 stdout 캡처. exit=0 (run-once 자체 spawn) 이지만 hexa runtime 단계에서 parse 또는 usage 분기.

---

## 2. production-validated 분류

| 필터 | 분류 | 근거 |
|---|---|---|
| E1 claude_quantum | ✗ panic | `try { exec(...) } catch e { ... }` (line 204) — 현 hexa-lang interp 가 `try`/`catch` 토큰 미인식. 4 parse error. 진입 0. |
| E2 claude_bytes | ✗ panic | `try { exec(...) } catch e { ... }` (line 137, 143) — 동일 패턴. body 도달 못함. |
| E3 claude_runtime | ✗ panic | 4 위치 (20, 200, 284, 300, 311, 320) — 동일 패턴, 외부 PAYLOAD escape sequence + try/catch 둘 다 fail. |
| P3 columnar_projection | ⚠ N/A | parse OK (try/catch 0) — entry 진입 후 `args()` 가 빈 list. `path == ""` → usage 출력 후 정상 종료. 측정 자체는 성공할 코드, run-once dispatch 가 jsonl path 전달 못함. |
| P5 result_cache | ⚠ N/A | 동일 — parse OK, args 부재 → usage. |

**부산물 — 같은 cycle log 에 표면화된 별 issue**:
- `sh: perl: not found` (E1/E2/E3) — sandboxed spawn shell에서 `perl -e 'alarm 120'` watchdog 실패. 현 GUI session 의 PATH 에 perl 존재 (`/usr/bin/perl`) 이지만 spawn shell 은 BusyBox PATH.
- `sh: printenv: not found`, `nc: invalid option -- 'q'` (E2 동일 cycle) — BusyBox 환경 구속 추가 evidence.
- `Killed: 9 ( '...exe' 0<&3 2> '/tmp/.hexa-runtime/cache_err.<ts>.tmp' )` (cycle 1) — 가장 큰 hexa job 이 OOM/timeout? hexa wrapper 가 `2>` 를 자기 tmp 로 redirect — A8 evidence 재확인.

---

## 3. own 9 등록 권장 (loop integrate / exception / 측정 필요)

| 필터 | own 9 권장 | 사유 |
|---|---|---|
| E1 claude_quantum | **exception (defer)** | hexa-lang 가 try/catch 지원 또는 코드가 try-free 로 재작성 후 측정. 현 production 진입 0. |
| E2 claude_bytes | **exception (defer)** | 동일. body 도달 못함. |
| E3 claude_runtime | **exception (defer)** | 동일 + 4 site try/catch — fix 비용 가장 큼. |
| P3 columnar_projection | **측정 필요** (run-once arg 채널 또는 wrapper hexa) | parse OK. arg 전달만 해결되면 즉시 측정 가능. 권장: airgenome 측 wrapper hexa (e.g., `columnar_projection_runonce.hexa`) — 본 ledger 의 새 gap A9 (run-once arg pass-through) 와 함께 처리. **own 9 후보**: gap 해소 후 site-N 등록. |
| P5 result_cache | **측정 필요** | 동일 — wrapper 또는 A9 해소 후 등록. |

**loop integrate 권장 0** (현 5 측정 사이클 어느 것도 production-validated 아님).

---

## 4. hexa-lang upstream 신규 후보

기존 ledger A1~A8 외 본 측정에서 surface 한 신규 gap:

### A9 — `--mode=run-once=<path>` 의 추가 인자 pass-through

**Evidence**: `native/src/airgenome_loop.m#airgenome_loop_run_once` 가 `args[]` 를 hard-code (`{HEXA_BIN, "run", module_path, NULL}`). `airgenome_tap.m` 의 dispatch 도 `--timeout=120` 만 별도 파싱하고 추가 argv 전달 path 0. 결과: arg 의존 필터 (columnar_projection, result_cache, 그리고 perf_lab 도) 가 production 측정 불가능 — module 진입 후 `args()` 가 빈 list → usage 분기.

**Gap**: own 5 site-list 5 중 2 가 이 채널 부재로 N/A. 또 향후 `safari_topsites_mmap`, `prefix_trie_mmap`, `autocomplete_trie_mmap` 등 path-arg 받는 필터 모두 동일 차단막.

**Proposed API** (airgenome 측 변경, hexa-lang 변경 0):
```
--mode=run-once=<module_path>[?args=arg1,arg2,...]
or
--mode=run-once=<module_path> --runonce-arg=<v1> --runonce-arg=<v2>
```
loop dispatcher 가 추가 argv 를 `hexa run <module>` 뒤에 append.

**Caller in airgenome**: airgenome_tap.m line 1583 (`--mode=run-once=` parse). 현재 argv parsing 이 `=` 뒤만 path 로 인식. 추가 flag 두는 1-line 변경.

**Priority**: 🟢 **high** — 본 own 측정 5 중 2 즉시 unblock + 향후 site-N 모두 포함.

**Note**: 본 후보는 hexa-lang gap 이 아니라 **airgenome 측 dispatcher gap**. ledger 의 A1-A8 과는 결이 다름 — own 9 운영 layer 변경. 분리해서 RFC 작성 가능.

---

### A10 — hexa-lang `try { } catch e { }` syntax 또는 `result<T,E>` 도입

**Evidence**: 5 filter 중 3 (E1/E2/E3) 가 모두 다음 패턴 사용 후 parse panic:
```
let x = try { exec("date +%s%N").trim() } catch e { "0" }
```
현 hexa-lang grammar 에 `try`/`catch` 토큰 미존재. `Parse error at <line>:<col>: unexpected token Try ('try')`.

**필터 의도**: `exec()` 가 fail 할 수 있는 shell call 을 안전 default 로 fallback (date fork 실패 시 0).

**Gap**: 현재 우회 패턴이 0 — exec 실패는 그대로 panic 발생. claude_quantum / claude_bytes / claude_runtime 가 모두 동일 try 패턴 사용 → 셋 다 production 진입 차단.

**Proposed API** (둘 중 하나):
1. **try-expression**: `try expr catch ident block` — Rust-style. interp 측 토큰 추가 + AST.
2. **result type** (`exec_result<str>`): `exec()` 시그니처를 `exec(cmd) -> result<str, error>` 으로 변경하고 `unwrap_or(default)` 콤비네이터 도입. 하위호환 위해 `exec_safe()` alias.

또는 minimal: `exec_or(cmd, default)` builtin 1줄 추가 — try/catch grammar 변경 없이 동등 효과.

**Caller in airgenome**: `claude_quantum.hexa` line 204/213, `claude_bytes.hexa` line 137/143, `claude_runtime.hexa` line 20/200/284/300/311/320 (총 16+ site).

**Priority**: 🟢 **high** — own 5 site-list 의 3 필터 직접 차단막. 본 측정에서 surface 한 가장 큰 gap.

---

### A11 — hexa wrapper 의 BusyBox PATH 격리 (perl/printenv/nc 부재)

**Evidence**: E1/E2/E3 의 same cycle log 에서:
```
sh: perl: not found
sh: printenv: not found
nc: invalid option -- 'q'
BusyBox v1.35.0 (Debian 1:1.35.0-4+b7) multi-call binary.
```
현 GUI session 의 `which perl` = `/usr/bin/perl`, `which printenv` = `/usr/bin/printenv`. 그러나 hexa interp / airgenome spawn shell 의 PATH 가 BusyBox 만 포함.

**Gap**: 필터가 `perl -e 'alarm 120; exec @ARGV' /bin/sh -c ...` watchdog 패턴 사용 — perl 부재로 watchdog 무력. 또 `nc -q` (full netcat) 만 지원하던 코드 기존 path 가 BusyBox nc 로 fall-through 시 silent fail.

**Proposed action** (hexa-lang OR airgenome 측):
- hexa wrapper script 가 `PATH=/usr/bin:/bin:/usr/local/bin:$PATH` 명시 export — BusyBox 만 노출되는 spawn 환경 fix.
- 또는 hexa builtin `exec_with_timeout(cmd, sec)` 신설 — perl 의존 제거.

**Caller in airgenome**: 모든 `try { exec("perl -e 'alarm ..'") }` 패턴 사용 필터 (E1/E2/E3). 또 향후 watchdog 필요 모듈 일반.

**Priority**: 🟡 medium — A10 (try/catch) 해소 후에도 watchdog 자체는 동작해야 함. 현재는 silent (perl 없으니 timeout 무력).

---

### A12 — hexa runtime panic 의 자식 stderr 캡처 (A8 강화 evidence)

**Evidence**: 측정 중 cycle 2 log 에 표시:
```
sh: line 1:  8524 Killed: 9 ( '/Users/ghost/core/hexa-lang/.hexa-cache/345adc3a5b398a57/exe' 0<&3 2> '/tmp/.hexa-runtime/cache_err.28861113963000.tmp' )
```
hexa wrapper 가 자체 stderr redirect 를 자식 exe 에 적용 — Killed:9 (SIGKILL) 의 원인 (OOM? timeout?) 이 외부 log_path 에 도달 안 함. A8 ledger 의 가설 재확인.

**Note**: 본 측정은 A8 의 직접 추가 evidence — 새 후보 아니지만 priority **medium → high** 으로 escalate 권장.

---

## 5. 이전 측정 재현 일치성

| 항목 | 원래 측정 (commit 0037276b) | 본 측정 결과 | 일치성 |
|---|---|---|---|
| columnar_projection 2-9× | jq full-scan vs col grep 후속 쿼리 (perf_lab P3) | **재측정 불가** — run-once dispatch 가 jsonl path 인자 미전달 → entry 가 usage 출력 | **재현 0** — 경로 변경 (run-once vs 직접 `hexa run`) 으로 인한 측정 채널 부재 |
| result_cache 4.8-7.8× | jq x100 vs cache wc x100 (perf_lab P5) | **재측정 불가** — 동일 사유 | **재현 0** — 동일 |

**해석**: 원래 commit 0037276b 의 측정은 `hexa run path.jsonl` direct CLI 으로 수행 (filter 의 args() 가 jsonl path 직접 받음). airgenome production binary 의 `--mode=run-once` 채널은 추가 argv 전달 미지원 — A9 gap 이 정확히 이 분기. **own 5 enforcement** 상 production 채널 외 측정은 evidence 로 인정 불가 → 본 own 9 등록 시 P3/P5 는 A9 해소 후 재측정 필요.

**일치성 점수**: 0/5 production-validated. (E1/E2/E3 panic, P3/P5 dispatch gap.)

---

## 결론 요약

- **production-validated**: 0 / 5
- **panic**: 3 (E1/E2/E3 — try/catch grammar 미지원)
- **N/A (dispatch gap)**: 2 (P3/P5 — run-once arg 채널 부재)
- **own 9 등록**: 0 (모두 차단막 해소 선결)
- **신규 hexa-lang/airgenome upstream 후보**: 3 (A9 dispatcher arg, A10 try/catch grammar, A11 BusyBox PATH) + A12 = A8 강화 evidence
