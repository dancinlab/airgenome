# Wave 21 — hexa_remote docker exec 격리 (2026-04-25)

## TL;DR
ubu2 OOM 폭주 근본 원인 (drill 이 host systemd-run --user --scope fork → forecast/harvest/label
service MemoryMax 미설정 → 13/27/19GB anon-rss OOM 연쇄 → sshd forked session banner timeout)
을 차단하기 위해, `nexus@1b6a6684` `scripts/bin/hexa_remote` 에 docker exec dispatch 경로를
opt-in 추가. `HEXA_REMOTE_DOCKER=1` 시 ssh 후 `docker exec airgenome-claude bash -lc '...'`
경유 → 8GB cap 컨테이너 안에서 drill 실행 → host RAM 무관, sshd 안전.

검증: hetzner + ubu1 모두 docker exec drill rc=0 (1834 absorptions, 6-stage chain).
preset=standard heavy drill 시 컨테이너가 8GiB cap pegged + 99% CPU 인 상태에서도
host hetzner 124GB 중 9.8GB 만 사용 (115GB free 유지) — 격리 성공.

## 배경

### ubu2 OOM 진단 (`state/ubu2_docker_isolation_check_20260425.md`)
- drill 이 `systemd-run --user --scope` 로 host 직접 fork (cgroup MemoryMax=20G)
- airgenome-{forecast,harvest,label}.service MemoryMax 미설정 → 무제한 anon-rss
- 13/27/19GB OOM 연쇄 → host 전역 OOM-kill
- sshd listener oom_score_adj=-1000 (보호) but forked session = 0 (취약) → banner timeout

### docker container 가용성
ubu1 + ubu2 + hetzner 모두 `airgenome-claude` (image=`ghcr.io/need-singularity/airgenome:fat`,
8GB Memory + 8GB MemorySwap, network=host, healthy) 떠있음.
컨테이너 내부:
- `HOME=/root`
- `/root/.hx/bin/hexa_real` (image-baked binary, ELF)
- `/root/.hx/packages/nexus/cli/run.hexa` (image-baked nexus self-contained CLI)

→ 컨테이너 내 drill 실행에 모든 dependency 충족. project tree 마운트 불요.

## Wave 21 변경 (`nexus@1b6a6684`)

### 패치 위치
`scripts/bin/hexa_remote` +25 / -1.

### 동작
- `HEXA_REMOTE_DOCKER=1` 시:
  1. `HEXA_REMOTE_NO_SYNC=1` 자동 set → rsync 생략 (project tree 컨테이너에 없으니)
  2. `REMOTE_ROOT='$HOME'`, `REL=""` 강제
  3. `REMOTE_CMD = "$REMOTE_TRAP; docker exec -i $_DOCKER_CONTAINER bash -lc <inner>"`
     (`_DOCKER_CONTAINER` default = `airgenome-claude`, override = `HEXA_REMOTE_DOCKER_CONTAINER`)
  4. inner: `cd /tmp && export HEXA=$HOME/.hx/bin/hexa_real HEXA_LOCAL=1 HEXA_NO_LAUNCHD=1 && $HOME/.hx/bin/hexa_real <args>`
- 기존 `_SD_WRAP` (systemd-run scope) 분기는 docker mode 미사용 시 그대로 유지

### 안전성
- **opt-in**: env 미설정 시 기존 systemd-run 경로 100% 그대로 (회귀 0)
- container down 시 drill 동시 down 한계 — opt-in 단계라 영향 없음
- ubu2 unreachable: 직접 검증 skip, 리부트 후 default ON 전환 전 검증 필요

## 검증 (2026-04-25)

### Container 상태
| host | container | uptime | health |
|------|-----------|--------|--------|
| hetzner | airgenome-claude | Up 2 days | healthy |
| ubu1 | airgenome-claude | Up 9 hours | healthy |
| ubu2 | (unreachable, banner timeout) | — | — |

### Probe drill rc=0
```
HEXA_REMOTE_DOCKER=1 HEXA_REMOTE_HOST=hetzner \
  hexa_remote run $HOME/.hx/packages/nexus/cli/run.hexa \
    drill --seed 'wave21 docker exec verify' --preset probe --max-rounds 1 --timeout 120s
→ rc=0, 1834 absorptions, NEXUS_DRILL_VALIDATION verdict=PASS

HEXA_REMOTE_DOCKER=1 HEXA_REMOTE_HOST=ubu1 \
  hexa_remote ... drill --seed 'wave21 ubu1 docker probe' --preset probe ...
→ rc=0, 1834 absorptions
```

### bash -x trace (dispatch 경로 확인)
```
+ HEXA_REMOTE_NO_SYNC=1   # 자동
+ REMOTE_CMD='trap ... ; docker exec -i airgenome-claude bash -lc \
              cd /tmp && export HEXA="$HOME/.hx/bin/hexa_real" ... \
              && $HOME/.hx/bin/hexa_real run "$HOME/.hx/packages/nexus/cli/run.hexa" \
              drill --seed wave21\\ docker\\ exec\\ verify ...'
+ ssh -T ... hetzner '<REMOTE_CMD>'
```
`systemd-run` 호출 없음, `rsync` 호출 없음, `docker exec` 한 줄로 dispatch.

### 격리 검증 (preset=standard heavy drill)
```
hetzner host (during drill):
  드릴 시작 전:  Mem 8.7Gi/124Gi used, free 116Gi
  드릴 중:      Mem 9.8Gi/124Gi used, free 115Gi   ← +1.1GB only (existing services)
  컨테이너:     mem=7.999GiB/8GiB cpu=99.92%       ← cap pegged

스냅샷 (10+ samples over 90s heavy compute window):
  7.623Gi → 8Gi → 7.999Gi → 7.998Gi → 7.994Gi → 7.997Gi → 7.999Gi → 8Gi → ...
  cpu 99.21% ~ 108.36% (1 core saturated)
```
- 컨테이너 RSS 가 8GB cap 에 정확히 pegged → cgroup 강제 동작 확인
- host RSS 변화량은 ~1.1GB (다른 서비스 동시 변동 추정), 드릴 RAM 누출 0
- `docker inspect`: `Memory=8589934592 MemorySwap=8589934592` → swap 도 격리 (host swap 사용 0)

### sshd 영향
드릴 폭주 중에도 hetzner ssh login 정상 (`docker stats` 폴링 + `free -h` 모두 즉시 응답).
banner timeout 없음.

## 다음 단계

1. **Wave 21b (default ON)**: 안정성 회귀 0 확인 후 `HEXA_REMOTE_DOCKER=1` 기본화.
   조건: ubu2 리부트 + 직접 검증, ubu1/hetzner 1주 무사고 운용, 컨테이너 healthcheck
   alerts 부착.
2. **컨테이너 healthcheck monitor**: container down 시 drill 도 down — opt-out 시
   automatic fallback to systemd-run (HEXA_REMOTE_DOCKER_FALLBACK=1) 검토.
3. **컨테이너 cap tuning**: 8GB 가 일부 heavy drill (preset=standard 6-stage) 에서
   cap pegging → 일부 stage 결과 변형 가능성. 현재는 회귀 검증 우선.

## References

- nexus commit: `1b6a6684 fix(hexa_remote): Wave 21 docker exec 격리`
- nexus convergence: `convergence/drill_stability.convergence` Wave 21 entry (`83b7022a`)
- 선행 진단: `state/ubu2_docker_isolation_check_20260425.md`
