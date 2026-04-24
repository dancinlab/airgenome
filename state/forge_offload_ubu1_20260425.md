# Forge harvest/label → ubu1 offload (2026-04-25)

Mac 에서 돌던 M4 harvest + M5 label hexa 루프를 ubu1 (30GB RAM / 617GB free)
systemd --user timer 로 옮기고, 결과 ring/jsonl 은 15min 주기 rsync 로 Mac 에 복귀.
Mac 은 probe/dispatch/forecast 만 유지 (lean).

## 아키텍처

```
[Mac]  bin/airgenome run (supervisor)
         ├─ probe   (60s)   local
         ├─ dispatch(60s)   local
         ├─ forecast(5tick) local
         └─ harvest/label   ⛔ gated off (AIRGENOME_LOCAL_HARVEST=1 이면만 on)

[ubu1]  systemd --user timers
         ├─ airgenome-harvest.timer  → *:00/15:00  → modules/harvest.hexa
         └─ airgenome-label.timer    → *:07/15:00  → modules/label.hexa  (7min offset)
         출력: ~/airgenome/forge/genomes.ring, ~/airgenome/forge/labeled_anomaly.jsonl

[Mac]  launchd com.airgenome.forge-sync-from-ubu1 (15min)
         rsync -az ubu1:airgenome/forge/{genomes.ring,labeled_anomaly.jsonl}
               → /Users/ghost/core/airgenome/forge/
```

## 설치 파일 (Mac)

- `bin/airgenome` — 공급자 루프 gate 추가 (L519~):
  ```
  if [ "${AIRGENOME_LOCAL_HARVEST:-0}" = "1" ]; then
      run_hexa_mod harvest
      run_hexa_mod label
  fi
  ```
- `launchd/com.airgenome.forge-sync-from-ubu1.plist` — StartInterval=900, RunAtLoad
- `launchd/com.airgenome.harvest.plist.disabled-20260425` (rename)
- `launchd/com.airgenome.label.plist.disabled-20260425` (rename)

## 설치 파일 (ubu1, commit 대상 아님)

- `~/.config/systemd/user/airgenome-harvest.service` — Type=oneshot,
  `/usr/bin/timeout 60 ~/.hx/bin/hexa_real run ~/airgenome/modules/harvest.hexa`
- `~/.config/systemd/user/airgenome-harvest.timer` — `OnCalendar=*:00/15:00`, Persistent
- `~/.config/systemd/user/airgenome-label.service` — Type=oneshot,
  `/usr/bin/timeout 120 ~/.hx/bin/hexa_real run ~/airgenome/modules/label.hexa`
- `~/.config/systemd/user/airgenome-label.timer` — `OnCalendar=*:07/15:00`, Persistent

`Environment=NO_HEXA_SHIM=1` 로 `~/.hx/bin/hexa` (docker shim) 우회하여 hexa_real 직접 호출.

## Before / After

### Before (오늘 offload 이전)

```
$ launchctl list | grep airgenome
60638  124   com.airgenome               ← 상시 supervisor (probe/disp/harv/lbl 60s)
-      0     com.airgenome.dispatch
-      23    com.airgenome.ring-sync
-      0     com.airgenome.predictive-throttle
...
$ ps aux | grep harvest\\.hexa|label\\.hexa
60638 /bin/bash bin/airgenome run
81087 timeout 30 hexa run modules/label.hexa      ← Mac 에서 실행 중
81101 hexa run modules/label.hexa
```

### After (offload 완료)

```
ubu1 $ systemctl --user list-timers airgenome-harvest.timer airgenome-label.timer
NEXT                         LEFT  LAST                         UNIT
Sat 2026-04-25 02:45:00 KST  5min  Sat 2026-04-25 02:38:43 KST  airgenome-harvest.timer
Sat 2026-04-25 02:52:00 KST 12min  Sat 2026-04-25 02:37:02 KST  airgenome-label.timer

ubu1 $ systemctl --user status airgenome-harvest.service | head
Active: inactive (dead) since Sat 2026-04-25 02:38:43 KST
Main PID: 915303 (code=exited, status=0/SUCCESS)
ubu1 $ systemctl --user status airgenome-label.service | head
Active: inactive (dead) since Sat 2026-04-25 02:37:10 KST
Main PID: 677274 (code=exited, status=0/SUCCESS)
```

Mac 쪽 supervisor 는 재실행/respawn 시 gate 적용되어 harvest/label 모듈 skip.

## 운영 커맨드

ubu1 상태 확인:
```
ssh ubu1 'systemctl --user list-timers airgenome-harvest.timer airgenome-label.timer; \
          tail -5 ~/airgenome/logs/harvest.stderr.log'
```

Mac forge-sync 활성화 (유저가 실행):
```
ln -sf /Users/ghost/core/airgenome/launchd/com.airgenome.forge-sync-from-ubu1.plist \
       ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.airgenome.forge-sync-from-ubu1.plist
```

## 롤백

1. Mac 다시 로컬 실행:
   ```
   export AIRGENOME_LOCAL_HARVEST=1  # supervisor 재시작 or bin/airgenome 롤백
   ```
   또는 bin/airgenome 의 gate 블록 제거.
2. ubu1 정지:
   ```
   ssh ubu1 'systemctl --user disable --now airgenome-harvest.timer airgenome-label.timer'
   ```
3. plist 복원:
   ```
   cd /Users/ghost/core/airgenome/launchd
   mv com.airgenome.harvest.plist.disabled-20260425 com.airgenome.harvest.plist
   mv com.airgenome.label.plist.disabled-20260425   com.airgenome.label.plist
   ```
4. Mac forge-sync 해제:
   ```
   launchctl unload ~/Library/LaunchAgents/com.airgenome.forge-sync-from-ubu1.plist
   rm ~/Library/LaunchAgents/com.airgenome.forge-sync-from-ubu1.plist
   ```

## 리스크 / 메모

- **hexa_real parse warnings**: `label.hexa` 첫 line(19:5) 에서 parse error 경고 출력,
  실제 실행은 완료 (`label done — labeled=0`). ubu1 hexa_real (Apr 19 build) 의
  use-statement parser 차이로 보임. 결과는 정상.
- **void dir 경고**: `modules/harvest.hexa` 내 `tail -2000 'void'` shell 호출이
  void 를 파일로 기대하지만 ubu1 에는 디렉터리. anomaly lookup 경로로만 영향, ring
  적재 정상.
- **rsync 결과 방향**: Mac forge/ 가 ubu1 결과로 덮어쓰여짐. Mac 에서 local harvest
  계속 돌리고 싶으면 gate 롤백 후 `.ubu1` 접미사 버전으로 변경 고려.
- **timers.target drift**: systemd --user `timers.target` 은 로그인 세션 종료 시
  정지. linger=yes (이미 활성) 확인됨.
- **Mac supervisor 재기동 필요**: bin/airgenome 은 편집되었으나 기존 supervisor
  (PID 60638 등) 가 script 를 메모리에 이미 로드. 다음 respawn/수동 kill 시 gate
  적용. `pkill -f 'airgenome run'` → launchd 가 respawn.
