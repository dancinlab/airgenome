# Mac process gate 7 filter — production-test + 측정 + hexa-lang gap

**일자**: 2026-04-30
**대상**: `modules/filters/process/` 의 Type A 프로세스 게이트 7종 (compute.hexa 는 L0/AG6 mark — 본 wave 제외)
**환경**: macOS (Darwin 25.4.0), airgenome 단일 binary `--mode=run-once=`, hexa interpreter
**실행 방식**: `/Applications/airgenome.app/Contents/MacOS/airgenome --mode=run-once=<filter> --timeout=60`
**상태**: read-only 측정 — 코드 수정 0, git commit 0, hive/hexa-lang touch 0, taskpolicy_bg 실 적용 0 (filter 가 추천만 emit)

---

## 1. 7 filter 측정 결과 표

| # | filter | exit | wall (real) | ps_raw 결과 | recs (BG 추천) | log entry | panic | 비고 |
|---|---|---|---|---|---|---|---|---|
| 1 | calendar | **0** | 2.52s* | total=0 (Calendar 미실행) | 0 | written | none | state=cool, front=Void |
| 2 | claude | **0** | 1.66s | session_now.json 없음 → early exit | 0 | n/a (early exit) | none | "no session_now.json" 정상 가드 |
| 3 | finder | **0** | 1.57s | finder_main=0 helpers=1 helper_cpu_sum=3 | 0 | written | none | state=cool, helper 1개 (cloudphotod 추정) |
| 4 | mail | **0** | 1.59s | total=1 max_cpu=0 | 0 | written | none | Mail 미실행 (1 = MailCloudIntelligence 등 helper) |
| 5 | memo | **0** | 1.53s | total=1 max_cpu=0 | 0 | written | none | Notes helper만 |
| 6 | safari | **0** | 1.59s | total=26 webcontent=17 | 0 | written | none | Safari 활성, state=cool 이라 BG 추천 0 (정상) |
| 7 | telegram | **0** | 1.47s | main_cpu=2 in_call=false procs=1 | 0 | written | none | idle, but state=cool — 추천 0 (정상) |

\* calendar 첫 실행은 hexa cache cold-build 포함. 동일 비교용 후속 실행 (claude~telegram) 1.5–1.7s wall — 안정적 plateau.

**전 항목 watchdog 미발동, exit=0, panic 없음, A6 (to_int_safe) issue 0건 — wave 4 패턴이 이미 적용된 결과 (모든 to_int 호출이 `to_int(to_float(s))` wrap 사용).**

**상태 로그 갱신 검증** (production write-path 정상):
- `~/Dev/airgenome/nexus/shared/gate_calendar_state.jsonl` 20:30 갱신 (107 B)
- `gate_finder_state.jsonl`, `gate_mail_state.jsonl`, `gate_memo_state.jsonl`, `gate_safari_state.jsonl`, `gate_telegram_state.jsonl` 모두 20:30~20:31 갱신
- claude 는 session_now.json 부재로 early-exit (정상) — STATE_LOG 미작성

**TCC 검증**: 본 wave 의 7 filter 중 mail/memo 가 사용자 데이터 잠재 접근 (Mail.app / Notes.app process 이름 enumerate). 그러나 `ps -axo pid,pcpu,rss,comm` 만 사용 — TCC FDA 불요 (process listing 은 unprivileged). 모두 exit=0 으로 권한 문제 없음 확인.

---

## 2. own 9 등록 분류

### 2A. **loop integrate 후보** (default-mode 안전 동작 확인됨)

| filter | 분류 | rationale |
|---|---|---|
| calendar | **integrate-ready** | 단순 ps + frontmost; idempotent; rec 0 (state=cool) → side-effect 안전 |
| finder | **integrate-ready** | helper만 대상, HARD_FINDER_NEVER 가드 다중 보호 |
| mail | **integrate-ready** | accountsd 제외 + frontmost guard |
| memo | **integrate-ready** | AppleSpell 제외 + frontmost guard |
| safari | **integrate-ready** | WebContent 한정, Networking/GPU/Safari 본체 HARD_NEVER |
| telegram | **integrate-ready** | in_call 휴리스틱 + frontmost guard, idle 만 BG |

→ 6종 모두 launchd source/timer 후보 (compute.hexa 와 동일 pattern). env-gate (`AIRG_TAP_LOOP_PROCESS=0` default OFF) 권장 — 본 wave 4 Safari 통합 (`AIRG_TAP_LOOP_SAFARI`) 과 동일 보수 정책.

### 2B. **exception** (integrate 부적합)

| filter | rationale |
|---|---|
| **claude** | `session_now.json` 외부 의존. snapshot writer (claude-code 측) 가 갱신 안 하면 perpetual no-op. integrate 전 dependency declaration 필요 |

### 2C. **측정 차단 / TCC 우려**

본 측정에서 차단 0건. 그러나 production-realistic stress 측정 (10+ Calendar/Notes 실행 상태) 미 reproduce — corpus 부족 (host 에 calendar/mail/notes 미가동). 후속 wave 에서 synthetic process census 권장.

---

## 3. own 5/6/7 패턴 미적용 site list — own 10 후보 N 개

### 본 7 filter 의 baseline pattern (현재 site)

각 filter 의 ROI-able 사이트:

| filter | site# | hot path | 현재 baseline | 후보 post (own 5/6/7 적용) | ROI# 인용 |
|---|---|---|---|---|---|
| **모든 7** | S1: append STATE_LOG | `exec("echo '...' >> $STATE_LOG")` per call (하루 N=cycle 횟수) | 이미 single-line append (cycle 당 1회) — 추가 win 작음 | **#43 N→1 syscall** (이미 1회) — 본 wave 적용 불필요 |
| **모든 7** | S2: ps awk pipe | `ps -axo ... | awk '...' | grep -E '...'` — single fork chain (ps + awk + grep) | hexa native ps reader (own 5 site-2 hexa-split 의 process 버전) — single fork → 0 fork | **#1 string slice** + own 6 site-6 패턴 인용 |
| calendar/mail/memo/safari/telegram (5종) | S3: lsappinfo frontmost | `lsappinfo info -only name "$(lsappinfo front)" | awk ...` (조건부 — env AG_COORD_FRONTMOST 미세팅 시) | airgenome native frontmost cache (NSWorkspace.frontmostApplication via tap process IPC) — 0 fork | env-cache 패턴은 이미 부분 구현. **#43 N→1** |
| **claude** | S4: per-instance ls + stat | `ls -t '$dir'/*.jsonl | head -1` + `stat -f %m` + `date +%s` 매 instance N회 fork | hexa native readdir + mtime (자식 N → 0 fork). 단 stat builtin 부재 시 own 7 site-12 batch 패턴 (1 fork 전체 dir) | **#54 batch** + 가능 시 hexa-lang `pfs_mtime()` builtin → A9 후보 |
| **claude** | S5: session_now.json 파싱 | naive `split("\"claude\":{")[1]` 등 substring 체인 — N instance × M field × split | hexa native JSON reader (own 6 site-6 hexa-split 와 유사) | **#1 string slice** |
| safari/telegram | S6: pattern split per ps line | `HELPERS.split("|")` + `comm.contains(hp)` × N processes × M patterns (O(NM)) | precompiled regex (Aho-Corasick — own 6/7 패턴 wave 1 F58 site 와 같은 구조) | **#64 memcmp / AC** |

**총 신규 own 10 후보 site**: **6개 클래스** (filter 7개 × 일부 중복 제외)

**우선순위** (ROI 크기 추정):
1. **S2 (ps awk pipe → native)** — 7 filter 전부 영향. ROI ~5–10× wall (1.5s → 0.2–0.3s) 추정. 후속 own 10 site-1 후보.
2. **S4 (claude per-instance fork)** — N instance 비례 (host 에 1+ claude 마다 3 fork 추가). 사용자 환경 의존 큰 win.
3. **S5 (session_now.json native parser)** — claude 전용, N×M 비례.
4. **S3 (lsappinfo cache)** — 5 filter, 중복 fork. env hint 이미 우회 가능 → 큰 win 아님.
5. **S6 (helper regex precompile)** — safari/telegram, N>10 구간만 의미.
6. **S1 (STATE_LOG append)** — 이미 single-line, marginal.

**evidence (lossless)**: production exit=0 이 baseline. post-patch 후 (a) exit=0 동일 (b) recs JSONL 출력 동일 — gate 의미 보존.

---

## 4. hexa-lang upstream 신규 후보 (A9~)

본 wave 측정에서 surface 한 gap — `docs/hexa_lang_upstream_candidates.md` A1~A8 와 비교 시 **신규 2종**.

### A9 — `pfs_readdir(path, sort_by="mtime") -> list<string>` builtin (proposed)

**Evidence**: claude.hexa#122-126 (`ls -t '$dir'/*.jsonl | head -1` + `stat -f %m` + `date +%s` 3-fork chain per claude instance).

**Gap**: hexa-lang 에 `pfs_readdir`/`pfs_mtime` builtin 부재. session_now.json 의 instance 갯수만큼 3 fork × N — 5 instance 면 15 fork.

**Proposed API**:
```hexa
pub fn pfs_readdir_sorted(path: string, sort_by: string) -> list<string>
//   Darwin/Linux: opendir + readdir + qsort by mtime (or name)
//   path 미존재: []
pub fn pfs_mtime(path: string) -> int    // unix epoch sec, 미존재 = -1
pub fn pfs_now_sec() -> int              // wall clock (이미 pfs_now_ns 존재 → /1e9 wrap도 가능)
```

**Caller in airgenome**: `modules/filters/process/claude.hexa#claude_dir loop`. 적용시 N instance × 3 fork → 0 fork (~50× per instance).

**Priority**: 🟡 medium — claude 가 multi-instance 시 큰 win, 단 instance 1개면 작음.

---

### A10 — `pfs_kv_extract(json_str, key, sep) -> string` builtin (proposed)

**Evidence**: claude.hexa#100-108 — `e.split("\"pid\":")[1].split(",")[0].trim()` 패턴이 9개 필드 × N instance 반복. hexa interpreter 의 `split` 은 매 호출 새 list 할당 → O(NM) GC 압력.

**Gap**: own 5 site-2 의 `vit_at` jq → hexa-split (614×) 패턴은 **single 객체 1 field**. claude.hexa 는 **N 객체 × 9 field**. 누적 비용 → site-2 의 9N 배.

**Proposed API**:
```hexa
// hexa-lang/stdlib/json_lite.hexa (또는 builtin)
pub fn json_field_str(s: string, key: string) -> string
pub fn json_field_int(s: string, key: string) -> int
pub fn json_field_float(s: string, key: string) -> float
//   single-pass scan, no list alloc, returns "" / 0 / 0.0 미존재시
//   nested object 제외 — 평탄 jsonl line 전제 (90% airgenome use case)
```

**Caller in airgenome**: `claude.hexa`, `predictive_throttle.hexa`, harvest jsonl readers 등 5+ 모듈. 누적 win 추정 ~100× × N record.

**Priority**: 🟢 high — wave 1/4 jsonl-heavy 모듈 광범위 영향. own 5 site-2 (single-field) 의 multi-field 일반화.

---

### A1~A8 재검증 (본 wave 측정 기준)

| 후보 | 본 wave 에서 surface? | 비고 |
|---|---|---|
| A1 (pfs_clone) | no | core/core.hexa rotate — 본 wave 무관 |
| A2 (xxh64 stdlib) | no | core/core.hexa fingerprint — 본 wave 무관 |
| A3 (pfs_tail_lines) | no | harvest 영역 |
| A4 (pfs_now_ns bench) | no | bench harness |
| A5 (pfs_writev) | no | append_ring — 본 wave 무관 |
| **A6 (to_int_safe)** | **수동 우회 확인** | 7 filter 모두 `to_int(to_float(s))` wrap 사용 — A6 builtin 부재해도 panic 없음. 그러나 DRY 위반은 본 wave 에서도 surface (7 filter × 동일 pattern 7회) |
| A7 (list O(1) append) | no | dataset build 부재 |
| A8 (HEXA_NO_INTERNAL_REDIRECT) | no | 자식 panic 없음 (silent debug 위험은 잠재) |

→ **A6 의 우선도 재확인**. 7 filter 전부에서 `to_int(to_float(s))` 또는 `try { to_int(to_float(s)) } catch e {}` 패턴이 코드 N×7 라인 반복 — A6 builtin 머지 시 7 filter × 1.5 라인 = 10+ 라인 정리 가능.

---

## 5. 측정 절차 evidence (lossless)

각 filter 의 production output (state log entry):

```
gate_calendar_state.jsonl  20:30  107 B   {"ts":"2026-04-30T11:30:46Z","state":"cool",...}
gate_finder_state.jsonl    20:30  101 B   {"ts":"...","state":"cool","finder_main_cpu":0,"helper_count":1,...}
gate_mail_state.jsonl      20:31  108 B   {"ts":"...","state":"cool","frontmost":"Void","is_mail_front":false,...}
gate_memo_state.jsonl      20:31  109 B   {"ts":"...","state":"cool","is_notes_front":false,"total":1,...}
gate_safari_state.jsonl    20:31  150 B   {"ts":"...","state":"cool","webcontent":17,"max_wc_cpu":?,...}
gate_telegram_state.jsonl  20:31  160 B   {"ts":"...","state":"cool","main_cpu":2,"in_call":false,"my_status":"idle",...}
```

**`~/.airgenome/loop-run-once.log` (production write path) 7회 갱신 확인**:
```
# calendar_gate state=cool front=Void is_cal_front=false total=0 max_cpu=0 recs=0
# claude_gate: no session_now.json
# finder_gate state=cool finder_main=0 helpers=1 helper_cpu_sum=3 recs=0
# mail_gate state=cool front=Void is_mail_front=false total=1 max_cpu=0 recs=0
# memo_gate state=cool front=Void is_notes_front=false total=1 max_cpu=0 recs=0
# safari_gate state=cool front=Void is_safari_front=false total=26 webcontent=17 recs=0
# telegram_gate state=cool front=Void is_tg_front=false main_cpu=2 in_call=false status=idle procs=1 recs=0
```

watchdog timeout 발생: 0/7. SIGKILL exit=137: 0/7. 모두 정상 종료 (exit=0).

---

## 6. 후속 wave 권장 (own 10 형태)

1. **own 10 site-1**: ps awk → hexa-native ps reader (S2, 7 filter 공통, ROI ~5–10×)
2. **own 10 site-2**: claude.hexa per-instance fork chain (S4) — A9 builtin 머지 후 진행
3. **own 10 site-3**: claude session_now.json kv_extract — A10 builtin 머지 후 진행
4. (선결) hexa-lang RFC: A6 (to_int_safe), A9 (pfs_readdir/mtime), A10 (json_field_*) — 사용자 명시 승인 후 PR

**제외 (본 wave 제외 결정 유지)**: compute.hexa (L0/AG6 mark — exception 등록 유지).

---

## 7. 절대 금지 준수 (selfcheck)

- ✅ 코드 수정 0 (`git status` 결과 변경 없음 — 측정 전후 동일)
- ✅ git commit 0
- ✅ hive/hexa-lang touch 0
- ✅ launchctl 0 (조회 1회만 — `launchctl print` read-only)
- ✅ 실 process kill / taskpolicy_bg 0 (filter 가 stdout 으로 추천만 emit, 적용 미실시)
- ✅ try/catch 추가 0 / top-level main() 추가 0
- ✅ Bun% 직접 인용 0 (own 5 ban — A1~A10 포지셔닝만 reference)
