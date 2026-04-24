# ubu2 Docker isolation check — 2026-04-25

## TL;DR
**ubu2 의 drill / hexa workload 는 docker 격리되어 있지 않다. 전부 host systemd --user 서비스로 실행 중.** `airgenome-claude` 컨테이너 (8 GB cap) 는 떠 있지만 Claude CLI sandbox 용도일 뿐, drill/forecast/harvest/label workload 는 우회. 이번 세션 OOM-kill 폭주의 근본 원인.

## Phase 1 — reachability
- 처음: alive (08:47:44 KST), `summer-B650M-K`, `up 2 days 14:01`, **load avg 26.64 / 33.56 / 24.58** — 이미 OOM 폭주 중
- Phase 2/3 도중 SSH banner timeout 으로 unreachable 전환 (조사 중에 OOM-kill 재발)
- 본 보고서는 첫 30 초 수집 데이터 기반

## Phase 2 — docker presence
| 항목 | 값 |
|---|---|
| docker.service | active running, 2 days uptime |
| 컨테이너 | `airgenome-claude` Up 2 days (healthy), network=host |
| Memory cap | 8 589 934 592 (8 GiB) / Swap = 8 GiB |
| CPU | cpu-shares=4096, cpuset=0,1, pids-limit=512 |
| Image | `ghcr.io/need-singularity/airgenome:fat` (4.72 GB) |
| Bind mounts | `~/.hx/bin/hexa_real` ro, `~/.airgenome`, `mac_home/Dev/airgenome` 등 |
| Container 내 hexa | `/usr/local/bin/hexa_real` (symlink: `/root/.hx/bin/hexa` → 동일) |

→ docker exec 경유 drill **이론적으로 가능** 하지만 현재 사용 안 됨.

## Phase 3 — drill execution path
### Host binary (격리 X)
```
/home/summer/.hx/bin/hexa_real
  ELF 64-bit LSB pie executable, x86-64, dynamically linked, 1.6 MB
  → host process. systemd --user 가 직접 fork.
```
실시간 host process snapshot 중 발견:
```
PID 503234 hexa_real run runaway_guard.hexa
+ 다수 systemd --user scope (status=failed):
  - run-r72e30f99...scope  drill --seed "LoRa mesh offline learning..."
  - run-ra408c760...scope  drill --seed "섹션 2026-04-25— dispatch완전복구..."
  - run-rf6b33cd6...scope  drill --seed "nxs-20260424-002 EVO-P10-1..."
```

### systemd --user services (host, no cap)
`airgenome-forecast.service`, `airgenome-harvest.service`, `airgenome-label.service` 가 hexa_stage0/hexa fork → MemoryMax 미설정 → host RAM 30 GB 전체 점유.

### OOM journal (kernel) 발췌 (4월 25 08:44 ~ 08:47)
```
hexa_stage0 invoked oom-killer ... task_memcg=airgenome-forecast.service
  Killed process 1044271 (hexa_stage0) anon-rss:13 432 248 kB  ← 13 GB
systemd-oomd invoked oom-killer ... task_memcg=airgenome-harvest.service
  Killed process 1043531 (hexa_stage0) anon-rss:27 196 028 kB  ← 27 GB
sh invoked oom-killer ... task_memcg=airgenome-label.service
  Killed process 1019603 (hexa)        anon-rss:19 919 496 kB  ← 19 GB
... global_oom 반복 (4초 간격)
```

### sshd 보호 상태 (good news)
| pid | role | oom_score_adj | oom_score |
|---|---|---|---|
| 1598 | host sshd listener | **-1000** | 0 |
| 310746 | container sshd | 0 | 666 |
| 1111123 | host sshd session priv | 0 | 666 |

→ host listener 는 이미 hardening 적용되어 있으나, **session priv (forked child)** 는 보호 안 됨. OOM 폭주 시 listener 자체는 살아도 신규 세션 fork 가 메모리 경합으로 banner timeout. 본 조사 도중 발생한 timeout 이 이 패턴.

## Drill execution path 도식
```
nexus drill 요청
  ├─ ubu1 host  → docker exec airgenome-claude ... (격리 OK, 8 GB cap)
  └─ ubu2 host  → systemd-run --user --scope hexa_real ...
                  ↑ host process. cap 없음. 30 GB 점유 가능.
                  ↑ airgenome-{forecast,harvest,label}.service 도 동일.
                  → global_oom → sshd session OOM thrash.
```

## 권고
### Short-term (P0, hardening drop-in 즉시)
1. **systemd --user 서비스에 MemoryMax 강제**:
   ```ini
   # ~/.config/systemd/user/airgenome-forecast.service.d/memcap.conf
   [Service]
   MemoryMax=4G
   MemoryHigh=3G
   ```
   forecast/harvest/label/runaway_guard 4종 모두 적용. 합계 ≤ 16 GB 로 host 보호.
2. **sshd OOMScoreAdjust=-1000 drop-in** 은 이미 listener 에 적용된 상태로 보이나, session priv 로 전파 안 됨 → `/etc/systemd/system/ssh.service.d/oom.conf` 확인 필요.
3. systemd-oomd 를 user.slice 에 더 공격적 swap pressure 로 — already running but late-fire.

### Mid-term (Wave 21 후보)
- **ubu2 drill 도 docker exec airgenome-claude 경유로 routing** 하도록 hexa_remote 패치.
  - 현재 `airgenome-claude` 는 sleep infinity 이므로 `docker exec airgenome-claude /usr/local/bin/hexa_real run ...` 로 dispatch 가능.
  - bind mount 이미 갖춰져 있음 (`~/.hx/bin/hexa_real:/root/.hx/bin/hexa:ro`, `~/.airgenome:/root/.airgenome`).
  - patch point: `nexus/cli/run.hexa` 의 host dispatch branch 또는 ubu2 의 `~/.hx/bin/hexa` shim 을 docker exec wrapper 로 교체.
  - 효과: drill 폭주가 8 GB 컨테이너 cgroup 안에 갇혀 host sshd 무영향.

### Decision
**Wave 21 후보로 등록하되, 즉시는 P0 systemd memcap drop-in 으로 출혈 멈춤** — docker exec routing 은 hexa_remote 변경 + ubu1 회귀 검증 필요해 ≥ 1 wave 소요.

## 사용자 행동 항목
- ubu2 현재 SSH banner timeout (08:47 부터 unreachable). 물리 리부트 또는 콘솔 접근 후:
  1. `loginctl terminate-user summer` 또는 `systemctl --user stop airgenome-{forecast,harvest,label}.service`
  2. 위 P0 memcap drop-in 적용 후 재기동
  3. `ssh ubu2` 회복되면 본 agent 재실행으로 검증

## Cross-ref
- 동시 진행 agent: a1a767277b7e68330 (Mac stabilize), a4bc05e56778ca338 (remote stabilize) — 본 조사와 영역 분리됨
- 관련 인벤: hexa_build_agent_ubu2_20260425.md, ag_dsl_ubu2_ring_liveness.json
