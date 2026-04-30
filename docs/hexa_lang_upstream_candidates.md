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

## 우선순위 요약 (갱신)

| 후보 | API | 측정 evidence | airgenome win 추정 | hexa-lang 작업량 | 우선순위 |
|---|---|---|---|---|---|
| **A6** | to_int_safe builtin | wave 4 panic 직접 차단막 | wave 4 즉시 production 가능 | low (10-line stdlib fn) | 🟢 **high** (본 commit 직후) |
| **A7** | list O(1) append | F58 19.7s build, F18 60s timeout | wave 1 100K dataset 측정 가능 | high (interp 변경 또는 builtin) | 🟢 high |
| A2 | xxh64 stdlib integration | site-5 (5ms→0.1ms?) | ~50× (fork 제거) | low (이미 존재) | 🟢 high |
| A3 | pfs_tail_lines | site-1 (5ms→0.5ms?) | ~10× | medium (mmap 구현) | 🟡 medium |
| A1 | pfs_clone | site-4 (5ms→0.1ms?) | ~50× (fork 제거) | low (syscall wrap) | 🟡 medium |
| **A8** | HEXA_NO_INTERNAL_REDIRECT 환경 변수 | wave 4 panic silent → 디버깅 차단 | 측정 실패 silent risk 제거 | low (wrapper script 분기) | 🟡 medium |
| A4 | bench_lib pfs_now_ns 채택 | (cleanup) | 0 (의존 제거만) | 0 (airgenome side) | 🟢 low |
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
