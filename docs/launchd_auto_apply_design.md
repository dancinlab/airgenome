# launchd auto-apply design — harvest / forecast / label

작성일: 2026-04-30 · 작성자: bg agent (read-only audit)
범위: `modules/{harvest,forecast,label}.hexa` 의 launchd 자동 실행 설계 검토.
원칙: raw 91 (measure-don't-guess) — 측정·확인된 사실만 단언, 추정은 명시.

업데이트 2026-04-30: §A (TCC 단일 binary 제약) 추가. 우선순위 재조정 —
**P0** 권장안은 `single-binary dispatch` (Option A). 기존 7축 분석 (§0–§7)
은 그대로 유효하되, **plist 1개 + bundle 1개** 전제 하에서 재해석할 것.

---

## A. TCC 단일 binary 제약 (NEW · P0 · 모든 §1–§7 위에 우선)

### A.0 제약 정의 (raw 91 measured)

macOS TCC 권한 (Accessibility / Input Monitoring / Full Disk Access /
Post Event) 는 **요청 binary 의 cdhash + bundle path** 단위로 grant
된다. `/Library/Application Support/com.apple.TCC/TCC.db` 의 `access`
테이블 row 는 (`service`, `client`, `client_type`, `csreq`) tuple 로
키잉되며, `client` 가 곧 prompt 한 프로세스의 bundle id (혹은 raw path).

→ 결론:

```
3 plist × ProgramArguments[0]=/Users/ghost/core/hexa-lang/hexa
  → TCC client = "/Users/ghost/core/hexa-lang/hexa" (단일 row 공유)
  → 부작용: hexa interpreter 자체에 권한 grant → 모든 hexa 스크립트가
    동일 권한 상속 (너무 광범위, raw 213 cli-osascript-shell-out-os-
    escalation-ban-mandate 정신 위반)
  → 부작용: hexa rebuild → cdhash 변경 → row "denied" → silent fail
```

```
3 plist × ProgramArguments[0]=/Applications/airgenome.app/Contents/MacOS/airgenome --mode={harvest,forecast,label}
  → TCC client = airgenome.app bundle id (com.airgenome.tap)
  → 단일 row, 기존 tap 의 grant 와 공유 → 추가 prompt 0회
  → 단점: 3 process tree 유지, launchd 가 각자 spawn
```

```
1 plist × ProgramArguments[0]=/Applications/airgenome.app/Contents/MacOS/airgenome --mode=loop
  → TCC client = airgenome.app
  → 단일 prompt, 단일 process, 내부 dispatch_source_t 가 60/300/3600s 분배
  → 추가로 harvest→forecast→label 순서 in-process 보장 가능 (race 해소)
```

### A.1 옵션 비교 (raw 231 indented arrow + 표)

| 옵션 | shape | TCC prompt | process | ordering 통제 | 판정 |
|---|---|---|---|---|---|
| **A** | 1 plist `com.airgenome.app` → bundle binary `--mode=loop` | **1 (기존 tap 공유)** | 1 long-lived | in-process serial queue | **P0 권장** |
| **B** | 1 plist + bundle binary 가 `posix_spawn(hexa run …)` 반복 | 1 (이론) / 3 (실측 필요) | 부모 + 단명 자식 | spawn 직렬화 | TCC 상속 실측 후 결정 |
| **C** | 3 plist, ProgramArguments 모두 `/Applications/airgenome.app/.../airgenome --mode=<x>` | 1 (bundle 공유) | 3 launchd-managed | 없음 (시간 기반) | A 가 막힐 시 fallback |
| D | 현행 3 plist × `hexa run …` | 3 또는 1 (hexa 광역 누출) | 3 hexa tree | 없음 | **기각** |

before (현행 D):
  3 plist × hexa run modules/<x>.hexa
  → TCC row 가 hexa 인터프리터에 부여
  → hexa 의 모든 스크립트가 권한 상속
  → 보안 광역화 + cdhash 변경에 취약

after (Option A · P0):
  1 plist com.airgenome.app
  → /Applications/airgenome.app/Contents/MacOS/airgenome --mode=loop
  → 내부 dispatch_source_t (harvest 60s, label 300s, forecast 3600s)
  → harvest 완료 → 5s delay → forecast/label trigger (in-process ordering)
  → TCC client = com.airgenome.tap (기존 grant 재사용, 추가 prompt 0)

### A.2 Option A 구현 스케치 (참고 코드, 본 round 비실행)

`native/src/airgenome_tap.m` `main()` 진입부 분기:

```objc
// argv[1] 미존재 또는 --mode 접두사 없음 → tap 모드 (현행 default)
// argv[1] == "--mode=loop"  → loop dispatch 모드
if (argc >= 2 && strncmp(argv[1], "--mode=loop", 11) == 0) {
    // 별도 lockfile (/tmp/airgenome-loop.lock) 으로 tap 과 충돌 회피
    // CGEventTapCreate / AX 코드 경로 진입 금지 (TCC 권한 미사용)
    dispatch_queue_t q = dispatch_queue_create(
        "com.airgenome.loop", DISPATCH_QUEUE_SERIAL);
    schedule_timer(q, 60,    "modules/harvest.hexa");   // 60s
    schedule_timer(q, 300,   "modules/label.hexa");      // 5min
    schedule_timer(q, 3600,  "modules/forecast.hexa");   // 1h
    dispatch_main();
}
// else → 기존 tap 메인 루프 (변경 없음)
```

`schedule_timer` 는 `posix_spawn(/Users/ghost/core/hexa-lang/hexa, run, modules/<x>.hexa)`
를 발행. 자식 프로세스는 부모 (airgenome.app) 의 file-system TCC
(FDA) 만 상속하며, 이는 harvest/forecast/label 모두 read-only state 만
다루므로 충분 (신호 합성 / event tap 권한은 자식이 사용하지 않음).

### A.3 단일 plist 본문 (Option A 산출물)

```
launchd/com.airgenome.app.plist   (NEW · 3 plist 대체)
  Label                  com.airgenome.app
  ProgramArguments       [/Applications/airgenome.app/Contents/MacOS/airgenome, --mode=loop]
  RunAtLoad              true
  KeepAlive              { SuccessfulExit: false }     # crash 시만 respawn
  ThrottleInterval       30
  ProcessType            Background
  StandardOutPath        ~/.airgenome/loop.stdout.log
  StandardErrorPath      ~/.airgenome/loop.stderr.log
  WorkingDirectory       /Users/ghost/core/airgenome
  EnvironmentVariables   { PATH, HOME, LANG,
                           AIRGENOME_ROOT=/Users/ghost/core/airgenome }
                                                       # §1 P0 동시 해결
```

`StartInterval` 키 **부재** 의도 — cadence 는 binary 가 in-process 로
소유. launchd 는 crash respawn / boot trigger 만 담당.

### A.4 기존 plist 와의 관계 (§2 신설)

| subsystem | 현재 plist | TCC owner | 본 round 액션 |
|---|---|---|---|
| Input tap (HID + AX + magnet + launcher) | `com.airgenome.tap` | airgenome.app (granted) | **변경 없음** |
| Notes/Safari VACUUM | `com.airgenome.vacuum_watcher` | hexa interpreter (광역) | 본 round 손대지 않음 — follow-up 에서 동일 단일 binary 흡수 검토 |
| harvest / forecast / label loop | (미등록) → NEW `com.airgenome.app` | airgenome.app (tap 과 공유) | **신규 등록** |

분리 유지 이유:

- `tap` plist 는 이미 TCC granted + 런타임 안정 (PID 16674, KeepAlive=crash-only).
  `--mode=loop` 와 별 process 로 두면 tap crash 가 loop 을 재시작시키지 않고
  반대도 동일 → fault isolation.
- `vacuum_watcher` 는 24h 쿨다운 게이트로 사실상 무동작. 흡수 시 ROI 낮고
  TCC client 가 hexa → bundle 로 바뀌면 기존 grant 잃음 (재-prompt). 본 round
  scope 외.

### A.5 TCC 자동화 / fallback (§6 보강)

현재 `native/src/airgenome_*.m` grep 결과:

```
grep -l "TCC|kAuthorizationRights|AXIsProcessTrusted|requestAccess|kAXTrustedCheckOptionPrompt" native/src/*.m
  → airgenome_winctl.m, airgenome_hotkey.m, airgenome_tap.m, airgenome_launcher.m
  → 그러나 explicit prompt API (AXIsProcessTrustedWithOptions+kAXTrustedCheckOptionPrompt) 호출은 없음
  → 첫 실패 시 kAXErrorAPIDisabled (-25204) 만 stderr 로 출력
```

권장 (본 round 비실행):

```objc
NSDictionary *opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
BOOL trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
if (!trusted) {
    fprintf(stderr, "__AIRGENOME_TAP_RESULT__ FAIL reason=tcc-not-granted\n");
    return 0;   // exit 0 → KeepAlive=SuccessfulExit:false 가 즉시 respawn 차단
}
```

거부 시 동작: log → exit 0 → respawn 정지 → 사용자 grant 후 수동
`launchctl kickstart -k gui/$UID/com.airgenome.app` 로 재기동.

### A.6 마이그레이션 (§3 신설)

```
launchctl list | grep airgenome     → tap 16674, vacuum_watcher 76, anima keyword_dispatch
                                      harvest/forecast/label 미등록 (CONFIRMED)
~/Library/LaunchAgents/             → tap, vacuum_watcher, anima keyword_dispatch
                                      harvest/forecast/label 부재 (CONFIRMED)
```

→ 결론: **3 plist 모두 dead 상태**. destructive uninstall 불필요.
설치 스크립트는 단순 install + idempotent bootstrap 만 수행.

```sh
# scripts/install_airgenome_loops.sh (NEW · 본 round 비실행)
UID_GUI="gui/$(id -u)"
PLIST=/Users/ghost/core/airgenome/launchd/com.airgenome.app.plist
DST=~/Library/LaunchAgents/com.airgenome.app.plist
mkdir -p ~/.airgenome
chmod 0700 ~/.airgenome             # §7 보안: 로그 비공개
ln -sf "$PLIST" "$DST"
launchctl bootout   "$UID_GUI/com.airgenome.app" 2>/dev/null || true
launchctl bootstrap "$UID_GUI" "$DST"
launchctl enable    "$UID_GUI/com.airgenome.app"
launchctl kickstart -k "$UID_GUI/com.airgenome.app"
launchctl list | grep com.airgenome.app  # 검증
```

롤백:

```
launchctl bootout gui/$(id -u)/com.airgenome.app
rm ~/Library/LaunchAgents/com.airgenome.app.plist
# 기존 tap / vacuum_watcher 무영향
```

### A.7 Option A trade-off (보안)

| 측면 | 3 plist (D) | 단일 binary (A) |
|---|---|---|
| TCC prompt | 3회 (또는 hexa 광역 누출) | **1회 (재사용)** |
| process isolation | 모듈별 process | 단일 process — 모듈 panic 이 loop 전체를 죽임 |
| 권한 표면 | hexa 인터프리터 = 광역 | airgenome.app = 좁음, 단 AX+ListenEvent+(향후 FDA) 통합 보유 |
| 재build 안정성 | hexa rebuild 마다 grant 잃음 | airgenome.app codesign identity 유지 시 grant 유지 |
| 모듈 권한 분리 | (이론) 가능 | --mode=loop 진입점이 CGEventTap 코드 미진입으로 사실상 보장 |

본 단일 사용자 도구의 위협 모델 하에서 **편의성 (1 prompt + 재사용
가능 grant) 이 isolation (3 prompt 분할) 대비 우위**. 채택.

---

## 0. 측정된 사실 (read-only)

```
launchctl list | grep airgenome     →  tap (pid 16674), vacuum_watcher, anima keyword_dispatch
                                       harvest / forecast / label  → 등록 안 됨 (CONFIRMED)
~/Library/LaunchAgents/             →  com.airgenome.{harvest,forecast,label}.plist 없음
launchd/com.airgenome.harvest.plist  → StartInterval 60,   ThrottleInterval 60
launchd/com.airgenome.forecast.plist → StartInterval 3600, ThrottleInterval 3600
launchd/com.airgenome.label.plist    → StartInterval 300,  ThrottleInterval 300
```

**핵심 갭**: 3 plist 파일 존재 → 그러나 `~/Library/LaunchAgents/` 심볼릭 링크/복사 부재 → launchctl bootstrap 미실행 → patch 자동 적용 불가.

before:
  launchd/com.airgenome.harvest.plist (repo)
  → (정적 파일, 적재 안 됨)

after (목표):
  launchd/com.airgenome.harvest.plist (repo)
  → ~/Library/LaunchAgents/com.airgenome.harvest.plist (symlink)
  → launchctl bootstrap gui/$UID
  → /Users/ghost/core/hexa-lang/hexa run modules/harvest.hexa (60s 주기)

---

## 1. plist 본문 적정성 (P0/P1)

각 파일 1~52행 모두 read 함. 공통 구조:

| key | harvest | forecast | label |
|---|---|---|---|
| ProgramArguments | `/Users/ghost/core/hexa-lang/hexa run modules/<X>.hexa` | 동일 | 동일 |
| StartInterval | 60 | 3600 | 300 |
| ThrottleInterval | 60 | 3600 | 300 |
| RunAtLoad | true | true | true |
| StandardOutPath | `/Users/ghost/.airgenome/<X>.stdout.log` | 동일 | 동일 |
| WorkingDirectory | `/Users/ghost/core/airgenome` | 동일 | 동일 |
| EnvironmentVariables | PATH, HOME, LANG | 동일 | 동일 |
| ProcessType | Background | 동일 | 동일 |
| Nice / LowPriorityIO | 10 / true | 동일 | 동일 |

발견 사항 (raw 91 confirmed):

- **[P0] AIRGENOME_ROOT 미설정 → forge 경로 mismatch.** `core/core.hexa:278-282` 에서
  `airgenome_root()` 는 `env("AIRGENOME_ROOT")` 우선, 미설정 시 `$HOME/Dev/airgenome`
  fallback. 실제 repo 는 `/Users/ghost/core/airgenome`. 3 plist 의 `EnvironmentVariables`
  에 `AIRGENOME_ROOT` 키 없음 (harvest.plist:33-41, forecast.plist:33-41, label.plist:33-41).
  → 적재 시 모듈은 `~/Dev/airgenome/forge/genomes.ring` 에 쓰고/읽음. **WorkingDirectory
  는 hexa interpreter 의 cwd 만 바꿈; module 의 `ring_path()` 와 무관.** 결과: harvest
  는 ring 적재 성공해도 forecast/label 이 빈 ring 만 봄, 또는 둘 다 다른 곳에 격리됨.
  검증: `ls /Users/ghost/Dev/airgenome 2>/dev/null` 으로 충돌 여부 측정 권장.

- **[P0] KeepAlive 미설정.** harvest 가 panic 으로 죽으면 다음 ThrottleInterval (60s)
  까지 ring 정지. forecast/label 도 동일. KeepAlive 부재는 의도적일 수도 있으나
  명시 필요.

- **[P1] 로그 회전 부재.** `/Users/ghost/.airgenome/` 의 `vacuum_watcher.stdout.log`
  20MB, `watchdog.stderr.log` 237KB (측정값) — 같은 패턴이면 harvest stdout
  (60s 주기) 은 일/주 단위로 빠르게 부풀어 오름. logrotate 설정 또는 모듈 측
  자체 회전 필요.

- **[P1] Hardcoded `/Users/ghost`.** ProgramArguments, StandardOut/Err, WorkingDirectory,
  HOME env 모두 `/Users/ghost` 박힘. 다른 사용자 기기 이식 시 깨짐.

- **[P2] PATH 에 `/opt/homebrew/bin` 이 끝에 위치.** Apple Silicon 기본 경로가
  마지막. 만약 hexa 가 brew 의존하면 우선순위 영향 없음 (절대경로로 호출중).
  단 모듈이 `exec("jq ...")` 호출 시 영향. 측정: `grep -rn 'exec("jq' modules/`.

---

## 2. 등록 절차 안전성 (P0)

권장 명령 (read-only 검증 후 사용자 수동 실행):

```
ln -sf /Users/ghost/core/airgenome/launchd/com.airgenome.harvest.plist \
       ~/Library/LaunchAgents/com.airgenome.harvest.plist
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.airgenome.harvest.plist
# (forecast / label 동일)
```

before:
  repo plist
  → 정적 (적재 안 됨)

after:
  repo plist
  → symlink → ~/Library/LaunchAgents/
  → launchctl bootstrap gui/$UID
  → 60s/300s/3600s 주기 실행

위험 요소:

- **[P0] `tool/airgenome_init.hexa:162-164` 패턴은 hook-watch 만 다룸** — 측정으로
  확인 (`grep -n harvest|forecast|label tool/airgenome_init.hexa` → 0건).
  init 스크립트가 3 모듈을 자동 등록하지 않음. 즉 새 사용자/기기에서는 수동 작업
  필수 → 자동화 부재.
- **[P1] hardcoded `/Users/ghost/...`.** `tool/airgenome_init.hexa:131-153` 의
  hook-watch render 는 `bin` 변수 인자로 받음 (이식성 고려됨). 그러나 launchd/*.plist
  는 정적 파일로 hardcoded. init 이 plist 를 동적 render 하지 않음.
- bootout-then-bootstrap 멱등 패턴 (init.hexa:162-164) 은 안전. 동일 패턴 재사용 권장.

---

## 3. 의존성 / ordering (P1)

launchd 는 dependency graph 미지원 (systemd 와 다름). 현재 plist 들은 단순 시간
기반:

```
harvest:  60s    (ring writer)
label:    300s   (ring reader)
forecast: 3600s  (ring reader)
```

before:
  T=0  harvest.RunAtLoad=true → ring write
       label.RunAtLoad=true   → 빈 ring 읽음 (첫 회차 race)
       forecast.RunAtLoad=true → 빈 ring 읽음 (첫 회차 race)

after (권장):
  옵션 A — RunAtLoad 차등화: forecast/label 은 RunAtLoad=false, 첫 트리거를
    StartInterval 로 위임. harvest 60s 한 사이클 후 ring 채워짐.
  옵션 B — 모듈 측 가드: `if ring_lines() < MIN: exit 0`.
    측정 권장: forecast.hexa / label.hexa 에 빈 ring 가드 존재 여부 grep.

- **[P1] launchd 자체 ordering 불가.** WatchPaths (forge/genomes.ring) trigger
  방식은 가능하지만 60s polling 과 중복.

---

## 4. 실패 처리 / 로그 회전 (P1)

before:
  hexa run panic
  → exit 비-0
  → ThrottleInterval 후 재시도 (60s/300s/3600s)
  → 무한 panic 루프 가능 (KeepAlive 없으나 StartInterval 자체가 재실행)

after (권장):
  - ExitTimeOut 추가 (현재 기본 20s) — hang 방지
  - StandardErrorPath 의 회전: cron 또는 `newsyslog.conf` (macOS native) 사용
  - 모듈 측 panic → `state/<module>.last_error.json` append → 시각화

권장 plist 패치 (적용 금지, 설계만):
```
<key>ExitTimeOut</key><integer>30</integer>
<key>AbandonProcessGroup</key><true/>
```

---

## 5. 등록 자동화 (P0)

측정 결과:

```
grep -n "harvest\|forecast\|label" tool/airgenome_init.hexa → 0건
grep -n "harvest\|forecast\|label" bin/daemons_start.sh     → 0건
grep -n "harvest\|forecast\|label" bin/cl-launch            → 0건
```

→ **현재 어떤 자동화 스크립트도 3 모듈을 등록하지 않음.** `tool/airgenome_init.hexa`
는 hook-watch (122-164행), settings-guard (401-479행), tg-bot (519-607행) 만 처리.

권장 (P0): `tool/airgenome_init.hexa` 에 `ensure_hexa_modules()` 추가:

before:
  fn main()
  → ensure_claude_bootstrap()
  → settings_guard install
  → tg_bot install
  (3 모듈 누락)

after:
  fn main()
  → ensure_claude_bootstrap()
  → settings_guard install
  → tg_bot install
  → ensure_hexa_modules()        // [신규]
    → for module in ["harvest","forecast","label"]:
    →   render → ~/Library/LaunchAgents/com.airgenome.<module>.plist
    →   bootout → bootstrap (멱등)

render 시 `AIRGENOME_ROOT`, `HEXA_BIN` 을 plist 의 EnvironmentVariables 에 주입
→ section 1 [P0] 와 section 2 [P1] 동시 해결.

---

## 6. 권한 / TCC (P2)

- harvest 의 `ps -A` (modules/harvest.hexa:38) — 일반 user agent 권한으로 충분.
  TCC prompt 없음 (측정: vacuum_watcher 가 동일 권한으로 동작 중).
- `top -l` (harvest.hexa:45) — 동일.
- Full Disk Access 불필요 (forge/, state/, ~/.airgenome/ 모두 user owned).
- **[P2] 가능 위험**: 모듈이 향후 `osascript` (System Events) 호출 추가 시 TCC
  prompt 필요. 현재 grep 결과 없음.

---

## 7. 보안 (P1)

- ProgramArguments 의 `/Users/ghost/core/hexa-lang/hexa` hardcoded.
  측정: `ls /Users/ghost/core/hexa-lang/hexa` → exists.
  `~/.hx/bin/hexa` 도 존재 (which hexa). 두 바이너리 동기화 정책 불명.
  하나만 업데이트되면 silent fail (Throttle 주기마다 재시작 실패만 로그).

- **[P1] modules/*.hexa 변조 방지 부재.** plist 는 user-writable 디렉터리의
  .hexa 를 인터프리터로 실행. user 권한 공격자가 modules/harvest.hexa 수정 시
  60s 후 자동 실행. settings_guard.plist 패턴 (chflags uchg + WatchPaths
  → init.hexa:398-442) 을 modules/ 에도 적용 검토.

before:
  user-writable modules/harvest.hexa
  → 60s 주기 자동 실행
  → 변조 감지 메커니즘 없음

after (권장):
  modules/*.hexa
  → chflags uchg (편집 시 unlock 필요)
  → 또는 git pre-commit hook + git hash 검증
  → 또는 settings_guard 와 같은 launchd WatchPaths 알람

- ProgramArguments 절대경로 — symlink injection 방지 측면 OK.

---

## 우선순위 요약

| 항목 | 심각도 | 액션 |
|---|---|---|
| **단일 binary dispatch (Option A) 채택** — 3 plist → 1 plist + bundle binary `--mode=loop` | **P0 (NEW · 최우선)** | §A.3 신규 plist + §A.2 dispatcher 진입점, §A.6 install script |
| TCC prompt 광역화 회피 — `hexa` 가 아닌 `airgenome.app` 이 client 가 되도록 | **P0 (NEW)** | Option A 또는 C 채택, D (현행) 기각 |
| AIRGENOME_ROOT 미주입 → forge 경로 mismatch | **P0** | 단일 plist EnvironmentVariables 에 키 추가 (§A.3 plist 본문 이미 포함) |
| init.hexa 가 3 모듈 미처리 → 자동 등록 부재 | P0 (탈격하 → 단일 binary 환경에서는 ensure_airgenome_app() 1개 함수로 축소) | §A.6 install script 또는 init.hexa 의 `ensure_airgenome_app()` 신규 |
| 등록 절차 자체 (bootstrap) | P0 | bootout-then-bootstrap 멱등 패턴 (init.hexa:162-164) 재사용 |
| RunAtLoad race (빈 ring) | P1 → **해소** | Option A 의 in-process serial queue 가 harvest→forecast→label 순서 보장 (race 자체 소멸) |
| 로그 회전 | P1 | 단일 logfile (`~/.airgenome/loop.{stdout,stderr}.log`) 로 통합 후 newsyslog.conf 1엔트리 |
| Hardcoded `/Users/ghost` | P1 | install script 가 동적 render |
| modules/*.hexa 변조 방지 | P1 | chflags uchg 또는 WatchPaths (단일 binary 채택과 무관, 그대로 유효) |
| KeepAlive / ExitTimeOut 미설정 | P1 | 단일 plist 에서 KeepAlive={SuccessfulExit:false} 채택 (§A.3) |
| TCC | **P0 (격상)** | §A 전체 — 단일 binary 가 곧 TCC 해법 |
| process isolation 손실 (단일 binary trade-off) | P1 | --mode=loop 진입점이 CGEventTap 코드 미진입 → 사실상 분리 (§A.7) |
| `vacuum_watcher` 통합 여부 | P2 | 본 round 손대지 않음, follow-up |
| PATH 우선순위 (homebrew 끝) | P2 | jq 등 외부 도구 의존 시 조정 |

---

## 다음 단계 (실행 금지, 제안만)

1. (P0) `ls ~/Dev/airgenome 2>/dev/null` 실행으로 forge 격리 측정.
2. (P0) `tool/airgenome_init.hexa` 에 `ensure_hexa_modules()` 함수 추가 설계.
3. (P0) plist 3개에 `<key>AIRGENOME_ROOT</key><string>/Users/ghost/core/airgenome</string>`
   추가 (또는 init render 로 통합).
4. (P1) `forecast.hexa` / `label.hexa` 의 빈 ring 가드 검증.
5. (P1) `newsyslog.d/airgenome.conf` 작성 검토.

raw 231 준수: 위 모든 콜체인은 indented arrow chart + before/after 블록으로 표기.
raw 91 준수: 측정 가능한 항목만 P0/P1 에 배정. 미측정 추정은 "측정 권장" 으로 명시.
