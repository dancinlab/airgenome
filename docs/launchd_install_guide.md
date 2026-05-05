# launchd install / enable / uninstall — manual only

raw 240 § B.6 mandate: **자동 bootstrap / 자동 등록 함수 / 자동화 스크립트 작성 금지.** 본 문서의 모든 명령은 사용자가 한 번씩 직접 실행한다.

배경: hive-hexa-bin 폭주 사후 (2026-04-30) 18 서비스 bootout 컨텍스트 — 자동 등록 = 단일 버그가 다수 서비스 동시 발사 가능 패턴 의 재발 방지.

---

## 1. 신규 install (단일 plist)

flow:
  사용자 manual:
    cd /Users/ghost/core/airgenome/native
    make install
      → make build           (clang → build/airgenome 약 148KB)
      → make app             (codesign + bundle)
      → cp -R build/airgenome.app → /Applications/airgenome.app
      → sed __BIN_PATH__ + __LOG_DIR__ → ~/Library/LaunchAgents/com.airgenome.tap.plist
      → launchctl bootout  gui/$(id -u) (idempotent — 기존 등록 있으면 제거)
      → launchctl bootstrap gui/$(id -u) (재등록)

확인:
  launchctl print gui/$(id -u)/com.airgenome.tap | grep -E "(state|last exit|pid)"
  → state = running, pid = N
  → System Settings → Privacy & Security → Accessibility 에 airgenome 항목 enable

**TCC 단일 prompt** — 손쉬운 사용 / 입력 모니터링 등 권한은 codesign 의 stable designated requirement (`make setup-signing` 으로 자동 provisioning) 로 cdhash 무관하게 grant 유지. 재빌드 시 재승인 불필요.

---

## 2. loop dispatcher (default ON, 자동 활성화)

raw 240 § B C4 — harvest/forecast/label in-process timer dispatcher. **사용자 mandate "airgenome 시작시 바로 반영"** 에 따라 plist 와 source 양측 default 활성.

### default: ON
plist 의 `EnvironmentVariables.AIRG_TAP_LOOP=1` (기본값). `make install` 후 tap 시작 시 자동으로:
- `airgenome_loop_init()` 호출
- 3 timer (harvest 60s / label 300s / forecast 3600s) 등록
- 첫 cycle 부터 자식 spawn

### 비활성화 (선택)

`~/Library/LaunchAgents/com.airgenome.tap.plist` 에서 `<string>1</string>` → `<string>0</string>`. 그 후:

```
launchctl kickstart -k gui/$(id -u)/com.airgenome.tap
```

`-k` 가 기존 process 종료 후 재시작 — 새 EnvironmentVariables 로 entry.

### 확인

flow (활성화 후):
  process airgenome (com.airgenome.tap, --mode 인자 없음 = tap 모드)
    → main() argv parse + env_flag("AIRG_TAP_LOOP", 0) = 1
    → airgenome_loop_init()
      → dispatch_queue_create("com.airgenome.loop", SERIAL)
      → dispatch_source_t × 3 (harvest 60s / label 300s / forecast 3600s)
    → [NSApp run] (CGEventTap + AX + magnet + launcher 동시 실행)

stderr 로그:
  tail -f ~/Library/Logs/airgenome.app/airgenome.err
  → "airgenome_tap: loop=on (harvest 60s / label 300s / forecast 3600s)" 라인 확인

자식 로그:
  ls -lt ~/.airgenome/loop-*.log
  → loop-harvest.log / loop-label.log / loop-forecast.log
  → 60s / 300s / 3600s 마다 cycle entry append

### 비활성화

plist 의 `<string>1</string>` → `<string>0</string>`. 그 후 `launchctl kickstart -k`.

---

## 3. uninstall

flow:
  사용자 manual:
    cd /Users/ghost/core/airgenome/native
    make uninstall
      → launchctl bootout  gui/$(id -u) com.airgenome.tap (idempotent)
      → rm -f ~/Library/LaunchAgents/com.airgenome.tap.plist
      → rm -rf /Applications/airgenome.app
      → rm -f ~/Library/Application\ Support/airgenome/launcher.jsonl

추가 cleanup (loop 활성화 했었던 경우 — R27 graceful uninstall):

```
rm -f /tmp/airgenome-loop-*.lock
rm -f ~/.airgenome/loop-*.log
```

TCC 정리 (선택 — 권한 grant 흔적 제거):
- System Settings → Privacy & Security → Accessibility → airgenome 항목 제거

---

## 4. troubleshooting

### lock 충돌 (singleton-lock-held)
```
ls /tmp/com.airgenome.tap.lock        # exists?
ps -p $(cat /tmp/com.airgenome.tap.lock)  # pid alive?
# pid alive → 정상 동작. 중복 실행 시도 차단됨
# pid dead  → rm /tmp/com.airgenome.tap.lock
```

### Accessibility 권한 누락
- `airgenome_tap: armed` 라인 미출력 + `ax-permission-missing` sentinel
- 해결: System Settings → Privacy & Security → Accessibility → airgenome 항목 enable
- 그 후 `launchctl kickstart -k gui/$(id -u)/com.airgenome.tap`

### loop dispatch overlap skip (정상)
```
[airgenome_loop] harvest: previous cycle still running — skip
```
정상 — 이전 cycle 이 timeout 안에 끝나지 않은 경우 lockfile NB 가 차단. 누적 시 timeout 조정 검토.

### loop child timeout SIGTERM (안전망 발동)
```
[airgenome_loop] harvest pid=N: timeout 30s → SIGTERM
[airgenome_loop] harvest pid=N: SIGKILL after 3s grace
```
모듈 (harvest/module/harvest.hexa) hang 의심. 단발성 = 정상 (hexa runtime 일시 지연), 반복 = 모듈 버그. `~/.airgenome/loop-harvest.log` 확인.

### binary 업그레이드 후 TCC 재승인 필요
- 증상: `make install` 후 Accessibility 동작 안 함
- 원인: codesign 미설정 → ad-hoc sign → cdhash 변경 → TCC revoked
- 해결: `make setup-signing` 으로 stable cert 발급 → `make rebuild`

---

## 5. 설계 원칙 (변경 금지)

본 가이드는 § B.6 mandate 및 hive-hexa-bin 폭주 재발 방지 원칙을 반영. 다음 자동화는 **금지**:

- `tool/airgenome_init.hexa` 가 `launchctl bootstrap` 자동 호출하는 함수 추가
- KeepAlive=true 또는 KeepAlive 확장으로 dispatch 자동 respawn 도입
- StartInterval (cron-style) 도입
- watcher / supervisor / 자기복제 패턴 추가
- AIRG_TAP_LOOP=1 default 변경 (사용자 명시 enable 만 허용)

상기 항목 위반 PR 은 raw 240 § B.5 7 안전망 무효화 → reject.
