# Mac emergency stabilize — 2026-04-25

## Trigger
- Mac 폭주, jetsam SIGKILL 위험. ubu2 동시 OOM 됐던 직후.
- 사용자 직접 emergency 명령 (autonomous).

## Before snapshot (08:46Z)
- Pages free: **4529** (~70MB, 24GB 중 critical)
- Pages compressor: 252241 (~4.0GB compressed)
- Swapouts: 102,951,109 cumulative
- Load Avg: (was high, 다수 stuck drill)
- drill/hexa_remote procs: **17**

## Actions

### 1. drill / hexa orphan kill
- pkill -9 패턴 매칭 실패 (특수문자 깨진 한국어 seed 때문에 -f 매칭 안 됨)
- PID 직접 kill: 18369 18488 18504 18506 18507 30916 49944 50033 50044 50045 50046 51594
- 12 PIDs hard-killed. ssh htz / ssh hetzner 양쪽 stuck remote drill 포함.
- drill-kill --all helper 실행 → Mac/hetzner/ubu1/ubu2 모두 cleanup, locks/blacklists 클리어.

### 2. supervisor 보존 결정
- airgenome status 확인:
  - LaunchAgent supervisor PID **79427** RUNNING (single instance)
  - runtime-guard PID 79475 RUNNING (dry-run mode)
- 단일 정상 인스턴스 → **건드리지 않음** (Forge offload 의존).

### 3. 메모리 회수
- `sudo -n purge` → **rc=0** (cached sudo creds).
- `sync && sudo -n sysctl -w kern.memorystatus_purge_on_warning=1` → 2 → 1.

### 4. drill.live.log
- 파일 부재 (이미 정리됨/미생성). truncate 불필요.

## After snapshot (08:47Z)
- Pages free: **154758** (~2.4GB, +34x improvement)
- Pages speculative: 40222 (회수된 캐시)
- PhysMem unused: 3966M (top)
- drill/hexa_remote orphans: **0**
- Load Avg: 58→27→16 (1m/5m/15m, 빠르게 하강)

## Side-effects
- Claude Code 자기 세션 (PID 11319, 13708) **건드리지 않음**.
- ssh / 사용자 ttys000 / ttys003 세션 유지.
- supervisor + runtime-guard 정상 가동 유지.

## Verdict
✅ Mac 안정화 완료. jetsam 추가 흔적 없음. 시스템 정상화.
