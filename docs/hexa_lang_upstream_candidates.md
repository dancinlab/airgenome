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

## 우선순위 요약

| 후보 | API | 측정 evidence | airgenome win 추정 | hexa-lang 작업량 | 우선순위 |
|---|---|---|---|---|---|
| A2 | xxh64 stdlib integration | site-5 (5ms→0.1ms?) | ~50× (fork 제거) | low (이미 존재) | 🟢 high |
| A3 | pfs_tail_lines | site-1 (5ms→0.5ms?) | ~10× | medium (mmap 구현) | 🟡 medium |
| A1 | pfs_clone | site-4 (5ms→0.1ms?) | ~50× (fork 제거) | low (syscall wrap) | 🟡 medium |
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
