# hexa-lang upstream candidates — own 5 A 단계

C (modules/harvest.hexa 5 사이트) + B (tool/bench/) 측정에서 surface 한 hexa-lang 자체 개선 후보. own 5 enforcement: C+B 측정 후에만 escalate. Bun% 직접 인용 금지 (own 5 ban).

본 ledger 는 **airgenome 측 evidence + 제안 API** 만 정리. hexa-lang repo PR 은 사용자 명시 승인 후.

---

## A1 — `core.fs.clone(src, dst)` builtin (clonefile syscall)

**Evidence**: `tool/bench/bench_site4.hexa` (597KB ring × K=5)
- `cp -c` (CLI fork): 4,670,800 ns/op
- `cp` (CLI fork): 4,990,800 ns/op
- 차이 6% — fork 비용이 cp 비용 압도

**Hypothesis**: 직접 syscall (clonefile / linkat / ioctl FICLONE) 호출 시 fork ~3ms 제거 → 0.05-0.1ms 추정 (75-95% 절감 예상). 40MB Bun 측정 7.06× 와 비교 가능 스케일 도달.

**Proposed API**:
```hexa
// stdlib/portable_fs.hexa 확장
pub fn pfs_clone(src: string, dst: string) -> int
//   Darwin: clonefile(2) — APFS 0-time block share
//   Linux: ioctl(FICLONE) — BTRFS/XFS reflink
//   기타: cp fallback
//   반환: 0=success, -1=fail, -2=fallback used
```

**Caller in airgenome**: `core/core.hexa#rotate_if_full` (현재 shell `cp -c` exec). PR 후 1-line 변경.

**Priority**: 🟡 medium — 안전망 가치 + airgenome 외 BTRFS 사용처 일반화.

---

## A2 — `core.hash.xxh64(path or bytes)` native binding

**Evidence**:
- `tool/bench/bench_site5.hexa`: `xxh64sum` CLI 4.9ms (1KB) / 6.9ms (10MB) / 33-46% vs sha256
- `/Users/ghost/core/hexa-lang/stdlib/hash/xxhash.hexa` — **pure-hexa xxh32/xxh64 already exists** (Stage0 P30, no unsigned int)

**Gap**: airgenome `core/core.hexa#fingerprint()` 가 stdlib 무시하고 `xxh64sum` CLI fork — 5ms/op 중 4.5ms 이상 fork 오버헤드.

**Action**: 
1. stdlib import 경로 확인 (`use "$HEXA_LANG/stdlib/hash/xxhash"` 또는 hexa 빌트인 path resolver)
2. airgenome `fingerprint()` 를 `xxh64()` 호출로 변경
3. 재측정 → fork 제거시 ~5-50× 추가 가속 추정

**Caller in airgenome**: `core/core.hexa#fingerprint()` (forward-looking, 현 callers 0).

**Priority**: 🟢 high — 이미 존재하는 stdlib, gap 은 airgenome integration 만.

---

## A3 — `core.fs.tail(path, n_lines or n_bytes)` builtin

**Evidence**:
- `tool/bench/bench_site1.hexa` post-fix: `last_for_pid` 의 5ms/call 중 대부분이 `exec("tail -2000 RING")` fork
- 30 procs × 5ms = 150ms 매 cycle, fork 제거 시 ~10× 추가 가속 가능

**Hypothesis**: native tail (mmap + line scan from end) → fork 제거. madvise SEQUENTIAL 자동 적용.

**Proposed API**:
```hexa
pub fn pfs_tail_lines(path: string, n: int) -> string
pub fn pfs_tail_bytes(path: string, n: int) -> string
//   Darwin/Linux: mmap path, scan back from end, return last n lines/bytes
//   path 미존재: ""
```

**Caller in airgenome**: `modules/harvest.hexa#last_for_pid` — 현재 shell `tail -2000` exec.

**Priority**: 🟡 medium — site-1 이미 큰 win 달성 (2.49×); 추가 native tail 은 ~10× 더 가능.

---

## A4 — `pfs_now_ns()` 확장 — bench harness 표준화

**Evidence**: `tool/bench/bench_lib.hexa` 의 `bench_now_ns()` 가 `gdate +%s%N` 의존. macOS 의 BSD `date` 는 ns 미지원 → homebrew coreutils 필수.

**Existing**: `stdlib/portable_fs.hexa#pfs_now_ns()` 이미 cross-platform fallback 보유 (Mac 의 ns 정밀도 손실 명시).

**Action**: bench_lib.hexa 가 `pfs_now_ns()` 사용하도록 변경. coreutils 의존 제거. airgenome A 단계 외 hexa-lang 변경 없음 — A1-A3 이 진행되는 동안 airgenome 측 cleanup.

**Priority**: 🟢 low — pure airgenome side cleanup.

---

## A5 — `pfs_writev(path, chunks: list)` builtin

**Evidence**: `tool/bench/bench_site3.hexa` — append_file builtin 으로 30 fork → 0 fork 달성, but list-of-strings 을 single string buffer 로 join 하는 비용은 hexa 측 (매 cycle 30 + 누적). N→1 syscall 수준에서 chunks list 직접 `writev(2)` 가능시 추가 메모리 재할당 0.

**Hypothesis**: list join 회피 → ~5-15% 추가 절감 (memcpy 비용 제거).

**Proposed API**:
```hexa
pub fn pfs_writev_append(path: string, chunks: array) -> int
//   POSIX writev(2) — list 의 각 element 를 하나의 syscall 로 append
```

**Caller in airgenome**: `modules/harvest.hexa#append_ring_batch` — 현재 hexa 측 string concat + append_file. 

**Priority**: 🔴 low — append_file 으로 이미 0 fork. 추가 win 작음 (메모리 차원만).

---

## A6 — `to_int_safe(s) -> int` builtin (decimal-tolerant)

**Evidence**: 본 세션 wave 4 (F45/F64-66 airgenome 통합) 모듈 4종에서 panic:

```
error: to_int: invalid integer literal "0.0"
```

원인: `ps -axo` 가 CPU% 를 decimal 문자열 ("0.0", "5.7" 등) 으로 출력. 현 hexa builtin `to_int()` 는 strict — decimal/empty/non-digit 입력 시 panic. wave 4 가 ps cpu 컬럼을 raw `to_int()` 로 처리해서 production 측정 차단.

**Existing workaround** (predictive_throttle.hexa, label.hexa 등):
```hexa
fn to_int_safe(s: str) -> int {
    if s == "" { return 0 }
    let parts = s.split(".")
    if len(parts) == 0 { return 0 }
    if parts[0] == "" { return 0 }
    return to_int(parts[0])
}
```

**Gap**: 5+ airgenome 모듈이 동일 helper 를 각자 정의 — DRY 위반, 누락 가능성. hexa-lang 에 builtin 또는 stdlib 으로 올리면:
- 모든 sister repo (anima/n6/nexus/hive) 가 자동 inherit
- 누락-위험 0 (raw 12 silent-error-ban 강화)
- airgenome wave 4 즉시 fix (각 파일 helper 정의 제거, builtin 호출)

**Proposed API**:
```hexa
// hexa-lang/stdlib/parse.hexa (또는 builtin)
pub fn to_int_safe(s: string) -> int
//   "0.0" → 0
//   "5.7" → 5 (truncate)
//   ""    → 0
//   "abc" → 0
//   "5"   → 5
//   "  5  " → 5 (trim)
```

**Caller in airgenome**: F45/F64/F65/F66 (4 wave 4 모듈) + label.hexa#to_int_safe + predictive_throttle.hexa#to_int_safe (이미 local 정의) + 다른 ps/jsonl parser.

**Priority**: 🟢 high — wave 4 production 차단막 직접 해소. 본 가이드의 wave 4 commit (62d7041f) 의 follow-up.

---

## A7 — `list` 의 O(1) append builtin (현 O(n²) concat)

**Evidence**: 본 세션 wave 1 bench (F58/F18) timeout:
- F58 100K URLs: build_dataset 자체 19.7초 (`urls = urls + [next]` × 100K = O(n²))
- F18 5000 bookmarks: 전체 60s timeout

```
let mut urls = []
let mut i = 0
while i < N {
    urls = urls + [item]   // O(n) — copies entire list each iteration
    i = i + 1
}
// total O(n²)
```

**Gap**: hexa list 의 `a + [x]` concat 패턴이 인터프리터에서 list 전체 copy 발생. 100K element 빌드 시 5×10⁹ byte copy 누적 → 19.7초.

**Proposed API**:
```hexa
// hexa-lang/stdlib/list.hexa (또는 builtin)
pub fn list_push(lst: list, item: any) -> list
//   in-place append (mutation via reference) — O(1) amortized
//   또는: list builtin 자체에 .push() 메서드
```

또는 인터프리터 측: `list = list + [x]` 패턴을 in-place mutation 으로 optimize (compiler/interp 선택).

**Caller in airgenome**: F58/F18/bench_f7 (10K 패턴 빌드)/대부분의 jsonl parser/ring loader. 대형 데이터셋 처리 가능해짐.

**Priority**: 🟢 high — pure-hexa filter framework 가 catalog #41/#5/#1 estimate 도달 위한 필수 선결. native binding 대안 (#6 byte struct view) 보다 일반화 더 큼.

---

## A8 — hexa runtime panic stderr 의 자식 process 캡처

**Evidence**: 본 세션 airgenome `--mode=run-once` 자식 spawn 시 hexa runtime panic 이 log file 에 캡처 안 됨:

```
posix_spawn_file_actions_addopen(&actions, 1, log_path, ...)
posix_spawn_file_actions_addopen(&actions, 2, log_path, ...)
// → 자식 stdout/stderr 가 log_path 로 redirect

// BUT: hexa wrapper 가 자체 stderr redirect:
// "( hexa_interp ... 2>'/tmp/.hexa-runtime/run_err.<ts>.tmp' )"
// → 자식 stderr 가 hexa wrapper 의 tmp file 로 갇혀 log_path 에 안 도달
```

F45 panic 진단 시 log_path 0 byte (silent). direct `hexa run` 으로 재현 후 비로소 panic 메시지 surface.

**Gap**: hexa wrapper script 의 internal stderr redirect 가 외부 spawn 의 file_actions 보다 우선. hexa-lang 에 환경 변수 (예: `HEXA_NO_INTERNAL_REDIRECT=1`) 또는 raw `hexa.real` 호출 옵션 으로 우회 가능해야.

**Proposed API**:
```bash
# hexa-lang/bin/hexa (wrapper)
if [ "$HEXA_NO_INTERNAL_REDIRECT" = "1" ]; then
    exec hexa_interp "$@"   # stderr 내려놓지 않음
else
    # 기존 wrapper 동작
fi
```

**Caller in airgenome**: airgenome_loop.m 의 `loop_spawn_with_watchdog` — 자식 panic 캡처 시 환경 변수 inject 하여 stderr 가 log_path 로 직접 redirect.

**Priority**: 🟡 medium — wave 4 panic 디버깅 시간 5× 단축. 측정 실패 시 silent → 잘못된 결과 commit 위험 (raw 12 silent-error-ban 위반 위험).

---

---

## A9 — airgenome `--mode=run-once` 추가 argv pass-through

**Evidence**: 본 세션 wave 1 측정 (commit 5ef190b6 follow-up)
- columnar_projection.hexa: args() 빈 list → usage 출력. 원래 perf_lab P3 의 2-9× 측정 재현 불가
- result_cache.hexa: 동일 dispatch gap. 4.8-7.8× 재현 불가

**Cause**: `airgenome_loop.m#airgenome_loop_run_once` 가 `{HEXA_BIN, "run", module_path, NULL}` 하드코드 — extra argv 전달 부재.

**Proposed**:
```c
int airgenome_loop_run_once(const char *module_path, int timeout_s, int extra_argc, char *const extra_argv[]);
// CLI: airgenome --mode=run-once=<path> --timeout=N -- <args...>
```

**Caller**: P3 (columnar) needs jsonl + field arg. P5 (result_cache) needs jsonl path.

**Priority**: 🟢 **high** — P3/P5 즉시 unblock + 모든 args-needed filter 측정 가능.

---

## A10 — hexa `try { } catch e { }` syntax 미지원 / `exec_or` builtin

**Evidence**: 본 세션 wave 1 + wave 3 동시 surface
- E1 claude_quantum.hexa: try/catch line 204/213 → parse PANIC
- E2 claude_bytes.hexa: try/catch line 137/143 → parse PANIC
- E3 claude_runtime.hexa: try/catch 6 sites (line 20/200/284/300/311/320) → parse PANIC
- modules/filters/transport/anomaly.hexa: parse-warn (try/catch 4건)
- modules/filters/transport/client.hexa: parse-warn

**Gap**: hexa runtime 이 `try { } catch e { }` 차단 — 5 filter 직접 production 측정 불가.

**Proposed alternatives**:
- Option A: hexa-lang 에 try/catch syntax 정식 도입 (large change)
- **Option B**: `exec_or(cmd: str, default: str) -> str` builtin — try/catch 패턴의 90% 가 exec wrapper. grammar 변경 없이 동등 가능. 1 builtin 추가
- Option C: Result<T, E> stdlib

**Caller**: 5 filter 위 + 본 세션 fix 한 safari_bench/safari_mmap (이미 try/catch 제거)

**Priority**: 🟢 **high** — 5 filter unblock, 가장 큰 ROI.

---

## A11 — hexa wrapper spawn shell BusyBox PATH 격리

**Evidence**: wave 1 측정 시 surface
- `sh: perl: not found` (perl alarm wrapper fail)
- `sh: printenv: not found`
- `nc -q invalid` (BusyBox vs GNU netcat)

**Cause**: hexa wrapper spawn 의 `sh -c "..."` 가 PATH 정상 inherit 못함. `/usr/bin/perl` 같은 absolute path 사용 우회 가능 (본 세션 safari_bench 적용함).

**Proposed**: hexa wrapper 가 user PATH inherit 보장 또는 bench 시 PATH 자동 augment.

**Priority**: 🟡 medium — workaround 가능 (absolute path) 이지만 bench 작성 부담 ↑.

---

## A12 — A8 강화: hexa wrapper internal stderr redirect 직접 evidence

**Evidence**: wave 1 측정 cycle log 에서 직접 surface:
```
sh: line 1: 29304 Killed: 9 ( '/Users/ghost/core/hexa-lang/.hexa-cache/<hash>/exe' 0<&3 2> '/tmp/.hexa-runtime/cache_err.<ts>.tmp' )
```

→ A8 의 가설 ("hexa wrapper 가 자체 stderr 를 tmp file 로 redirect") 직접 증명. 자식 panic 이 ~/.airgenome/loop-run-once.log 에 안 잡힘.

**Priority escalate**: 🟡 medium → 🟢 **high**. F45 panic, F18/F58 timeout 등 silent 디버깅 차단 직접 영향.

**Proposed (A8 그대로 유지)**: `HEXA_NO_INTERNAL_REDIRECT=1` 환경 변수 또는 hexa.real 직접 호출 path.

---

## A13 — `pfs_readdir_sorted` / `pfs_mtime` / `pfs_now_sec` builtin

**Evidence**: wave 2 측정 (process gate 7종)
- claude.hexa: per-instance `ls + stat + date` 3-fork 호출 chain
- 7 process filter 가 lsappinfo / ls + stat + date 패턴 반복

**Proposed**:
```hexa
pub fn pfs_readdir_sorted(dir: str, pattern: str) -> list  // glob + sort
pub fn pfs_mtime(path: str) -> int                          // file mtime epoch
pub fn pfs_now_sec() -> int                                 // monotonic seconds (vs pfs_now_ns)
```

**Caller**: claude.hexa per-instance + process gate filters.

**Priority**: 🟡 medium — process gate own 10 site-S4 (per-instance 3-fork → 0 fork) 의 핵심 unblock.

---

## A14 — `json_field_str` / `json_field_int` / `json_field_float` builtin

**Evidence**: wave 2 측정 (process gate 7종)
- claude.hexa session_now.json 에서 substring 체인 으로 field 추출
- own 5 site-2 의 `vit_at` 패턴 (single field hexa-split) 의 multi-field 일반화

**Proposed**:
```hexa
pub fn json_field_str(line: str, key: str) -> str
pub fn json_field_int(line: str, key: str) -> int
pub fn json_field_float(line: str, key: str) -> float
// own 7 site-9 의 jq_field 패턴 hexa builtin 화
// (현재 5+ 모듈 local 정의 — DRY 위반)
```

**Caller**: own 5/6/7/8 의 jq_field local helper 5+ 정의, wave 1 jsonl-heavy filter 광범위.

**Priority**: 🟢 **high** — jsonl 처리 모든 filter 의 광범위 영향. own 5 site-2 614× 의 일반화. A6 (to_int_safe) 와 짝.

---

## A15 — `core.net.unix_socket(path, payload)` builtin

**Evidence**: wave 3 측정 (transport)
- modules/filters/transport/client.hexa 의 `nc -U <socket>` 쉘 우회 → BusyBox `nc -q invalid` 직접 fail

**Proposed**:
```hexa
pub fn unix_socket_send(path: str, payload: str) -> str  // SOCK_STREAM connect + send + read
pub fn unix_socket_recv(path: str, max_bytes: int) -> str
```

**Caller**: client.hexa + 미래 IPC filter.

**Priority**: 🟢 high (transport filter 작동 차단 직접 해소) / 🟡 medium (workaround `socat` 가능).

---

## 우선순위 요약 (갱신 — 16 후보)

| 후보 | API | 측정 evidence | airgenome win 추정 | 작업량 | 우선순위 |
|---|---|---|---|---|---|
| **A10** | try/catch / exec_or builtin | 5 filter parse PANIC | 5 filter unblock | low (1 builtin) | 🟢 **highest** |
| **A14** | json_field_* builtin | 5+ local jq_field | 모든 jsonl filter | low (3 builtin) | 🟢 high |
| **A6** | to_int_safe builtin | wave 4 panic | wave 4 + jsonl | landed (3ea7fe69) | 🟢 done |
| **A9** | run-once argv pass-through | P3/P5 unblock | 2 filter | low (airgenome) | 🟢 high |
| **A12** | A8 강화 stderr redirect | silent panic 차단 | 디버깅 5× | low | 🟢 high |
| **A2** | xxh64 stdlib integration | site-5 (5ms→0.1ms) | ~50× | low | 🟢 high |
| **A7** | list O(1) append | F58 19.7s build | 100K dataset | high | 🟢 high |
| **A15** | unix_socket builtin | client.hexa BusyBox fail | 1 filter | medium | 🟡 medium |
| **A13** | pfs_readdir / mtime / now_sec | claude per-instance | own 10 S4 | medium | 🟡 medium |
| **A3** | pfs_tail_lines | site-1 추가 | ~10× | medium | 🟡 medium |
| **A1** | pfs_clone | site-4 fork 제거 | ~50× | low | 🟡 medium |
| **A8** | HEXA_NO_INTERNAL_REDIRECT | (A12 와 통합) | (A12 참고) | low | 🟡 → 🟢 (A12) |
| **A11** | wrapper PATH inherit | bench 작성 부담 | bench DRY | low | 🟡 medium |
| A4 | bench_lib pfs_now_ns | (cleanup) | 0 | 0 | 🟢 low |
| A5 | pfs_writev | site-3 추가 | ~5-15% | medium | 🔴 low |

---

## hexa-lang repo PR 절차 (사용자 승인시)

1. `hexa-lang/proposals/rfc_NNN_<topic>.md` 작성 — 본 ledger 의 단일 항목 (A2 권장)
2. `hexa-lang/stdlib/...` 구현 + test
3. airgenome 측 caller 변경 (별도 PR)
4. 각 PR 에 own 5 5-tuple 명시 (사이트, ROI #, baseline, post, lossless)

**현재 deliverable**: 본 ledger. 사용자 승인 시 A2 부터 RFC 초안 작성.

---

## own 5 ban 재확인

- ❌ Bun 1.3.12 측정값 (`docs/gate_filter_bench_results.md`) 직접 인용 금지 — 본 ledger 는 airgenome hexa env 측정만 evidence 로 사용
- ❌ 가설 ROI 만으로 PR 머지 — A2-A5 모두 baseline ns 측정 후 PR
- ✅ Bun 측정값을 **참고/검증용 reference** 로 명시 인용 (e.g., A1 의 "40MB Bun 7.06× 와 비교 가능" 은 hexa 측정이 그 스케일 도달 가능성 추정)
