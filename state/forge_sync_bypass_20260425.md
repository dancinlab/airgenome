# forge_sync_bypass — 2026-04-25

## problem
`launchd/com.airgenome.forge-sync-from-ubu1.plist` 작성은 됐지만 user 가 `launchctl load` 를 원치 않음.
결과: Mac `forge/genomes.ring` + `forge/labeled_anomaly.jsonl` 가 stale (ubu1 systemd 가 15min 주기로 생산).

## options
- **A**: 기존 `com.airgenome.ring-sync.plist` 확장 — 얘는 `genomes.ubu.ring` 등 alias 파일로 받음. 스키마 다름. skip.
- **B**: supervisor in-line pull. ← 채택
- **C**: ubu1 push (systemd `ExecStartPost`). 원격 수정 필요, fallback.
- **D**: sshfs. 너무 무거움. skip.

## B 구현
- `bin/airgenome` `cmd_run` 루프 매 tick 마다 `forge_pull_from_ubu1` 호출
- 15min cadence gate (`AIRGENOME_FORGE_PULL_INTERVAL=900`)
  - timestamp 파일: `~/.airgenome/forge_pull.last`
  - `now - last < interval` → skip
- env off: `AIRGENOME_FORGE_PULL_UBU1=0`
- `AIRGENOME_LOCAL_HARVEST=1` (로컬 harvest 롤백 모드) 이면 skip — 충돌 방지
- rsync: `ssh -o BatchMode=yes -o ConnectTimeout=5 -o ControlMaster=no` — mux 불가 환경 + hang 방지
- log: `~/.airgenome/forge_pull.stdout.log` / `forge_pull.stderr.log` / supervisor.log one-liner

## plist backup
- 원본 `com.airgenome.forge-sync-from-ubu1.plist` → `.disabled-supervisor-approach` rename
- launchctl 로 load 되지 않음. fallback 시 rename 복구 + `launchctl bootstrap` 으로 재활성 가능.

## 검증 (live)

### 시점
- supervisor restart: 2026-04-24T18:07:34Z (launchd 자동 respawn, new PID=15554)
- 첫 pull 로그: 18:07:57Z

### md5 match
| file                          | Mac                                | ubu1                               | match |
|-------------------------------|------------------------------------|------------------------------------|-------|
| forge/genomes.ring            | `d0d4483e3e84146046654faa2a28f828` | `d0d4483e3e84146046654faa2a28f828` | y     |
| forge/labeled_anomaly.jsonl   | `14ca401b93c57f73392f11b272fac6ab` | `14ca401b93c57f73392f11b272fac6ab` | y     |

### cadence verify
- `forge_pull.last = 1777054077` (unix ts, 18:07:57Z)
- 다음 pull candidate = `last + 900` = 18:22:57Z
- 중간 tick 들은 age gate 로 skip → `forge_pull_from_ubu1 ok` 로그 15min 주기 출현 예상

## commits
1. `f5bcea55` state(infra): forge pull — supervisor helper add
2. `ec22e648` state(infra): forge pull — plist 비활성화 + backup
3. (this) state(infra): forge pull — 검증 로그 + bypass doc

## rollback paths
- A: `AIRGENOME_FORGE_PULL_UBU1=0` → helper no-op
- B: plist rename 되돌리고 `launchctl bootstrap gui/$(id -u) launchd/com.airgenome.forge-sync-from-ubu1.plist`
- C: `AIRGENOME_LOCAL_HARVEST=1` 로 Mac 에서 harvest/label 다시 로컬 실행 (그러면 pull 도 자동 skip)
