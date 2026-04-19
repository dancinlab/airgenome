# AG-Q14 — Docker 마이그레이션 + 폭주엔진 + 입력렉방지 통합 설계

- status: drill-drafted
- date: 2026-04-19
- supersedes: (none — P5 rollback hatch 로 기존 경로 병행)
- related: AG-Q10 (tailscale), AG-Q11 (sshfs), AG-Q12 (cgroup EUCLEAN), AG-Q13 (claudx pin)

## § 0. 문제 삼각형

입력렉 ↔ 싱크 ↔ 폭주 — 셋은 서로 악화. 한 엔진으로 세 꼭짓점 동시 수렴 목표.

```
      [입력렉]
       ▲   ▲
       │   │  ssh RTT + 경합 스케줄링
       │   │
    싱크 ─┼─ 폭주
       │   │
       │   │  install drift → 동작 달라짐 → 어디 폭주중인지 추적 불가
       ▼   ▼
```

## § 1. 아키텍처 최종 형태

```
                    Mac (SSOT, UI only)
                          │
       cl → cx → ssh -t  │
                          │
                    ┌─────┴─────┐
                    │           │
                ┌───▼───┐   ┌───▼───┐
                │  ubu  │   │  ubu2 │   priority-first, RTT 최소
                │systemd│   │systemd│
                │  ▼    │   │  ▼    │
                │docker │   │docker │
                │  ▼    │   │  ▼    │
                │claude │   │claude │   long-running, cold start 0
                │contain│   │contain│
                └───┬───┘   └───┬───┘
                    │           │
                    └─────┬─────┘
                          │ docker pull
                          ▼
                    ┌──────────┐
                    │ hetzner  │   image builder SSOT
                    │ buildx   │     (32t, 128GB, 10× 빠른 빌드)
                    │  bake    │
                    └────┬─────┘
                         │ push
                         ▼
                    ┌──────────┐
                    │ ghcr.io/ │   GitHub Container Registry
                    │airgenome │
                    └──────────┘
```

## § 2. 이미지 설계 — `ghcr.io/need-singularity/airgenome:*`

### 2.1 Tag

- `:base` — OS + node + hexa 런타임 (거의 불변)
- `:claude` — base + claude CLI + npm 의존
- `:dev` — claude + hexa 컴파일러 + blowup/training
- `:gitsha-<sha>` — 각 커밋 불변 tag (rollback)

### 2.2 Dockerfile 3-stage (재빌드 최소화)

```dockerfile
# ==== L1 base (거의 불변) ====
FROM ubuntu:24.04 AS base
RUN apt-get update && apt-get install -y \
    curl wget git jq ripgrep fd-find \
    ssh sshfs fuse3 tini \
    python3 python3-pip \
    build-essential pkg-config \
    util-linux procps coreutils \
    cpulimit schedtool \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash \
    && apt-get install -y nodejs

# ==== L2 claude (주 1~2회) ====
FROM base AS claude
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g @anthropic-ai/sdk
COPY --from=hexa-builder /out/hexa /usr/local/bin/hexa
RUN chmod +x /usr/local/bin/hexa

# ==== L3 dev (수시) ====
FROM claude AS dev
COPY bin/ /opt/airgenome/bin/
COPY shared/ /opt/airgenome/shared/
COPY forge/ /opt/airgenome/forge/
ENV PATH=/opt/airgenome/bin:$PATH
ENV HEXA_LANG=/opt/hexa-lang
ENTRYPOINT ["tini", "--"]
CMD ["claude"]
```

### 2.3 bind mount (이미지 밖)

| 경로 | 이유 |
|---|---|
| `~/.claude-claude*/` (12개) | credentials Keychain-synced, 호스트별 |
| `~/.airgenome/` | runtime state (claudx/exhausted, menubar_config) |
| `/Users/ghost/Dev/airgenome` → `/workspace/airgenome` | 코드 SSOT (sshfs) |
| `/tmp` | ssh-agent/socket |
| `/dev/fuse` | sshfs 필요시 |

## § 3. 폭주엔진 — `bin/runaway_guard.hexa`

### 3.1 루프 (5s)

```
loop every 5s:
  m = collect_metrics()    # /proc 직접, systemctl 안 거침
  v = verdict(m)           # ok | warn | danger | critical
  act = action_map[v]      # noop | renice | cpulimit | route_switch
  apply(act)
  log_jsonl(m, v, act)     # ~/.airgenome/runaway.jsonl
```

### 3.2 임계값 (16-thread 기준, SSOT: `shared/runaway/thresholds.json`)

| level | load1/nproc | iowait | mem_avail | D-state |
|---|---|---|---|---|
| ok | < 0.7 | < 10% | > 4GB | 0 |
| warn | 0.7~1.0 | 10~20% | 2~4GB | 1 |
| danger | 1.0~1.5 | 20~35% | 1~2GB | 2 |
| critical | ≥ 1.5 | ≥ 35% | < 1GB | ≥ 3 |

### 3.3 대응

| 조건 | 액션 |
|---|---|
| warn + 단일 PID ≥100% CPU 30s (non-whitelist) | renice +10 |
| danger + 동일 | cpulimit --limit 50 --pid |
| critical + claude RTT > 500ms | `cx --force-host ubu2` 자동 스위치 + 알림 |
| D-state ≥2 + sshfs | `systemctl --user restart mac-home.service` |
| RSS ≥ 4GB single non-whitelist PID | renice +15 + cpulimit 30 |
| claude RSS > 3GB 5분 | restart 권고 알림 (자동 kill 금지) |

### 3.4 화이트리스트 (건드리지 않음, SSOT: `shared/runaway/whitelist.json`)

- `claude`, `node`(claude 자식), `hexa`(claude 자식), `sshd`, `ssh-agent`
- `systemd*`, `dbus`, `tini`

### 3.5 SIGSTOP 금지 (메모리 `feedback_no_kill_claude_cli.md`) — renice/cpulimit 만

## § 4. 입력렉 방지 4-layer

- **L1 네트워크** — ControlMaster 재사용, ServerAliveInterval 10, ControlPersist 8h, mosh 옵션
- **L2 컨테이너 스케줄링** — `--cpu-shares=2048 --cpuset-cpus=0,1,8,9 --pids-limit=512 --memory=8g --memory-swap=8g` + 컨테이너 내부 `nice -n -10 claude`
- **L3 호스트 감시** — runaway_guard 가 claude 외 프로세스 억제. claude PID 절대 불가촉
- **L4 측정/fallback** — 매 tick RTT 측정 → 500ms 10s 지속 → 자동 호스트 스위치. menubar V5 blink 에 RTT bar 추가

## § 5. 전수조사 — 기존 설치물 제거/이미지화 대상

### 5.1 bootstrap tier 17 → 6개 이미지화 (60% drift 감소)

| tier | 현재 | 이미지화 | 비고 |
|---|---|---|---|
| 1 brew | Mac | ❌ | Mac 만 |
| 2 repo clone | 호스트 | ❌ | bind mount 로 대체 |
| 3 zshrc | 호스트 | ❌ | cl 함수 경로만 |
| 4 claude CLI | npm -g | ✅ L2 | 제거 |
| 5 ssh config/key | 호스트 | ❌ | 유지 |
| 6 ssh-copy-id | 호스트 | ❌ | 유지 |
| 7 tailscale | 호스트 | ❌ | 유지 (L2) |
| 8 gh auth | 호스트 | ❌ | 유지 |
| 9 loop skill | 호스트 | △ | ~/.claude 마운트 |
| 10 cl-refresh launchd | Mac | ❌ | Mac 만 |
| 11 LaunchAgents | Mac | ❌ | Mac 만 |
| 12 keychain_map | Mac | ❌ | Mac 만 |
| 13 accounts.json | 호스트 | ❌ | bind mount |
| 14 hexa-lang | 호스트 빌드 | ✅ L2 | 제거 |
| 15 node/npm | 호스트 | ✅ L1 | 제거 |
| 16 jq/rg/fd | 호스트 apt | ✅ L1 | 제거 |
| 17 cpulimit/schedtool | 없음 | ✅ L1 | 신규 |

### 5.2 3호스트 전수조사 (실행: P1 에이전트 ac801e41)

결과는 `docs/AG-Q14_host_audit.md` 로 집계.

## § 6. 싱크 엔진

### 6.1 htz builder (systemd timer)

- `airgenome-build.timer` — 5분마다 git HEAD 체크
- `airgenome-build.service` — HEAD 바뀌면 `docker buildx bake --push`, tag gitsha-X + 이동 tag `dev`

### 6.2 ubu/ubu2 puller (systemd timer)

- `airgenome-pull.timer` — 1분마다 manifest digest 체크
- `airgenome-pull.service` — digest 바뀌면 pull + graceful restart (claude idle 대기)

### 6.3 Rollback

```bash
docker buildx imagetools inspect ghcr.io/need-singularity/airgenome:dev
ssh ubu 'sudo systemctl set-environment AIRGENOME_TAG=gitsha-abc1234 && systemctl restart airgenome-claude'
```

## § 7. 런칭 순서 (순차 필수, 각 단계 골화)

| P | 작업 | 산출 |
|---|---|---|
| P0 | 설계 확정 | 이 문서 + AG-Q14 convergence |
| P1 | 전수조사 + 베이스라인 | `docs/AG-Q14_host_audit.md`, 1주 RTT 분포 |
| P2 | runaway_guard 단독 배포 | `bin/runaway_guard.hexa` + systemd on ubu, 24h 관찰, menubar V6 RTT bar |
| P3 | Docker 파일럿 (ubu2 만) | base+claude 이미지, 3일 비교 (ubu 대조군) |
| P4 | 전면 전환 | ubu 도, dev 이미지, bootstrap tier 6 제거 |
| P5 | rollback hatch | `AIRGENOME_USE_DOCKER=0` env 로 기존 경로 복원 |

## § 8. 수렴 테스트 (AG-Q14 골화 조건)

| 시나리오 | 측정 | 통과 |
|---|---|---|
| 정상 TUI | keystroke RTT | median < 80ms, p99 < 200ms |
| 입력 스트레스 100wpm | RTT | p99 < 250ms |
| load=1.5 | claude RTT | 유지 (guard 작동) |
| load=2.5 | claude RTT | 자동 switch to ubu2 |
| sshfs stall | 복구 | ≤30s 자동 remount |
| 이미지 업데이트 | 다운타임 | claude idle 시 restart, 무감 |
| credentials rotation | AG-Q13 동작 | 유지 |
| 1주 uptime | 크래시 | 0 |

## § 9. Risk + 완화

| Risk | 완화 |
|---|---|
| cgroup EUCLEAN 재발 (AG-Q12) | docker 는 system.slice — user-slice 피함 |
| GHCR auth 만료 | `gh auth refresh` cron + monitor |
| htz 빌드 다운 | Mac local `docker buildx` fallback |
| 이미지 용량 | multi-stage + `.dockerignore` + `prune` weekly |
| claude 업데이트 호환 | dev image version lock, 매뉴얼 bump |
| TUI TTY (docker exec -it) | tini + `--init` + TERM env + stty 복제 |
| accounts.json drift | bind mount + remote_account_sync 그대로 |

## § 10. 파일 트리 (신규)

```
airgenome/
├── docker/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── buildx.bake.hcl
│   └── compose.yml
├── bin/
│   ├── runaway_guard.hexa
│   ├── container_manage
│   └── rtt_probe
├── shared/
│   ├── runaway/
│   │   ├── thresholds.json
│   │   └── whitelist.json
│   └── systemd/
│       ├── airgenome-claude.service
│       ├── airgenome-pull.service
│       ├── airgenome-pull.timer
│       └── airgenome-build.service    # htz 만
└── docs/
    ├── AG-Q14_docker_migration.md     # 이 문서
    └── AG-Q14_host_audit.md           # P1 산출
```

## § 결론

**Docker = 싱크/설치 수렴**, **runaway_guard = 폭주 수렴**, **ControlMaster + cpuset + RTT 모니터 = 입력렉 수렴**. 셋이 서로 강화하는 단일 설계. htz = builder, ubu/ubu2 = puller, Mac = UI only.
