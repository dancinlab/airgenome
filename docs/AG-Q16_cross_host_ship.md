# AG-Q16 — Cross-host Docker sshd + M15 Telegram + cx balance (Ship)

- status: shipped
- date: 2026-04-19
- branch: feat/m11a-cross-host
- supersedes: (none — accumulates on top of AG-Q14/Q15 design)
- depends: AG-Q14 (docker migration), AG-Q15 (managed agents design), AG7 (dispatch balancer), AG6 (Mac compute ZERO), M11e (cross-host claude)
- unlocks: Mac 입력렉 우회, iOS→claude (Telegram), drill OOM 격리, 3호스트 균등 dispatch

## 0. Executive summary

하루 안에 분산·안전망·원격접근성 3축을 동시에 밀어올린 골화. docker SSOT 배포에서 시작해 컨테이너 내부 sshd(port 2222) 직결로 host sshd 포화를 우회했고, drill/airgenome slice 계층으로 OOM 시에도 TUI가 살아남게 만들었다. Telegram 봇이 iOS → Mac/ubu claude 디스패치 경로를 열었고, cx 가 score-based 균등 분산으로 전환되면서 ubu/ubu2/htz 한쪽 쏠림이 사라졌다. CL_DOCKER 를 default 로 승격해 cl 실행이 컨테이너로 자동 라우팅되고, hexa_shim/hexa_heal 이 drift 자가복구를 담당한다. 푸시 완료, 작업 tree clean (문서/메모리 커밋 직전 기준).

## 1. 트랙별 성과

### A — Docker-sshd 직결 (host sshd bypass)

- **컨테이너 내부 sshd** — `docker/sshd_config` drop-in, port 2222, pubkey only, `--network=host` 전제. Dockerfile `ENTRYPOINT` 가 tini → ssh-keygen -A → sshd background → claude CMD foreground.
- **cx --docker-ssh / CX_DOCKER_SSH** — 2단계 probe (`<alias>-d` ssh config 우선, fallback `-p<port> -l root override`). 연결단계에서도 dssh_alias 재사용 (eedc39a2 수정).
- **hosts.json 스키마 확장** — `docker_ssh_port: 2222` (ubu/ubu2/htz), `docker_ssh_alias: htz-d` (htz), `max_claude_concurrent` (ubu/ubu2=2, htz=4, mac=8).
- **cx v4 score-based pick + slot 세마포어** — priority-first 에서 score-based 로 전환, per-host mkdir atomic 세마포어 (macOS flock 부재 대응), stale PID 회수.
- **bin/airgenome-claude-run** — authorized_keys 를 root:0600 복사본으로 bind (sshd StrictModes 통과), docker/sudo -n 분기, sshfs `allow_other` 감지로 MAC_HOME bind auto-enable.

### C — Host 보호 (sshd priority + slice 격리)

- **host sshd drop-in** — `shared/systemd/ssh.service.d/override.conf`: CPUWeight=10000 / IOWeight=10000 / Nice=-5 / OOMScoreAdjust=-900. 폭주 중에도 ssh 접속 보장.
- **drill.slice** — drill/blowup CPU 33% cap (CPUQuota=400%) + MemoryMax=12G + MemorySwapMax=0 + IOWeight=500 + TasksMax=512 + OOM 1순위. ubu1 필수 (drill 주 실행지).
- **airgenome.slice (umbrella) + airgenome-claude.slice** — claude TUI 전용: CPUWeight=10000, MemoryMin=4G, MemoryLow=6G, TasksMax=4096. `stress.slice` (CPUWeight=10, Nice=19) 와 100× 가중치 격차.
- **airgenome-claude.service** — `Slice=airgenome-claude.slice` 바인딩, `OOMScoreAdjust=-500`, `AIRGENOME_CPUSET=0,1`.
- **runaway whitelist 축소** — 26개 → 4개 (claude/tailscaled/hexa/sshd). fallback actions 가 실제 범인(containerd/dbus/systemd*/kworker*)을 타깃할 수 있게 됨.
- **runaway_guard D-state 스캐너** — iowait/sshfs stall 시 0% CPU 로 포착 안 되던 문제, D-state PID 전수 스캔 + self-test 6 synthetic.
- **actions_danger 게이트 완화** — Pass1 100→50% (partial-core 포착), Pass2 systemic fallback (pass1=0 && verdict=danger → top-3 non-protected renice+10/cpulimit50).

### M15 — Telegram bot (iOS → claude)

- **bin/tg_bot.hexa** (1005 lines) — ~/.airgenome/tg.json 로드 + `bot_token_file` 경로만 참조 (토큰 리터럴 코드/repo 부재).
- **단일 인스턴스 보장** — mkdir-atomic lock + 60s heartbeat stale detection + primary_host 가드 (Mac+ubu dual leader, standby 즉시 exit).
- **Long-poll 25s + chat_id whitelist + 4000자 chunk 분할**.
- **dispatch modes** — `claude -p` native / `cx --docker --force-host ubu` 컨테이너 경유.
- **Slash commands** — /status /logs /tail /drill /soak /deploy(confirm). ssh alias + service name whitelist 로 shell injection 차단.
- **배포** — `shared/launchagents/com.airgenome.tg-bot.plist` (Mac launchd KeepAlive), `shared/systemd/airgenome-tg.service` (ubu Slice=bkgnd, CPUQuota=10%, MemoryMax=128M).

### misc — 분산 + 자가복구 번들

- **modules/worker.hexa + worker_queue.hexa** — pending/claimed/running/done/failed atomic-mv claim + stale reclaim (kill -0 check). `AIRGENOME_DISPATCH_ROOT` env 지원.
- **daily build** — `bin/airgenome-build` + `airgenome-build.service/timer` 가 htz 04:00 KST buildx bake + GHCR push. 기존 5min cadence 에서 daily 로 전환.
- **bin/hexa_shim** — 모든 hexa 호출을 airgenome-claude 컨테이너로 라우팅. mac_home remap, `AIRGENOME_HEXA_INSIDE=1` / `NO_HEXA_SHIM=1` bypass.
- **bin/hexa_heal** — ubu golden sha256 drift 자동 탐지 + rsync 수리 (ubu2 깨진 binary 대응). `rm+cp` 패턴 (feedback_hexa_codesign_kill 준수).
- **run.hexa airgenome slots 서브커맨드** — JSON/human/reset/watch 모드. cx 세마포어 상태 가시화.
- **shared/config/docker_session_prompt.txt** — 컨테이너용 system prompt SSOT. cx --docker 가 `--append-system-prompt` 로 자동 주입.
- **cl → cx --docker default** — `/Users/ghost/Dev/airgenome/cl` 이 CL_DOCKER 무관하게 기본 docker 모드. opt-out 만 `CL_NO_DOCKER=1` / `CL_DOCKER=0`.

## 2. 검증 체크리스트

- [x] `docker ps` 3호스트 모두 `airgenome-claude` Up (ubu/ubu2/htz)
- [x] `ssh -p 2222 root@<host>` 컨테이너 내부 sshd 응답
- [x] `bin/cx --show` score-based pick 정상 (priority-first 폐기 확인)
- [x] `cat /proc/$(pgrep claude)/cgroup` → `airgenome-claude.slice` (ubu/ubu2)
- [x] `systemd-run --user --slice=drill --scope nexus-cli drill --seed "..."` → drill.slice 진입
- [x] `shared/systemd/ssh.service.d/override.conf` host sshd drop-in 적용 (`systemctl show ssh`)
- [x] `bin/runaway_guard.hexa --self-test` 6 synthetic D-state 통과
- [x] `whitelist.json` 4개 (claude/tailscaled/hexa/sshd) 만
- [x] `tg_bot.hexa self-test` dispatch dry-run 성공
- [x] `git push origin feat/m11a-cross-host` → 원격 sync (70b9081a..eedc39a2)
- [x] secret scan — repo 내 토큰 리터럴 없음 (AG-Q15 문서의 placeholder 경로 1건만, 실 키 없음)
- [ ] daily build 첫 실행 관찰 — **2026-04-20 04:00 KST 대기**
- [ ] airgenome slots 프로덕션 체감 테스트
- [ ] tg_bot launchctl load + slash command E2E 3/3 host

## 3. 남은 follow-up

| 트랙 | 작업 | 우선도 |
|---|---|:-:|
| 빌드 파이프라인 | htz daily build artifact 자동 배포 (ubu/ubu2 pull timer 재활성화) | P1 |
| Managed Agents mesh | AG-Q15 실측 (`bin/airgenome-managed --probe`) — API key 조달 후 | P2 |
| session_snapshot | `modules/session_snapshot_cmd.hexa` 완성 (현재 skeleton) + status.hexa 연결 | P2 |
| logs rotation | `airgenome-log-rotate.{service,timer}` 동작 검증 (~/.airgenome/*.jsonl 회전) | P2 |
| Telegram | launchctl load Mac + E2E slash commands + chat_id 별 권한 matrix | P1 |
| hexa_shim 3호스트 배포 | hexa_shim_deploy 스크립트 완성 + ubu2/htz 전개 | P1 |
| drill.slice | ubu2/htz 선택 배포 (ubu1 만 필수, 확장 관찰 후) | P3 |
| worker_queue | dispatch.hexa 와 연결, `airgenome dispatch -p "..." --managed` flag 통합 | P2 |
| hexa binary drift | ubu golden sha 정책 문서화 + hexa_heal cron 등록 | P2 |
| GHCR 공개 전환 여부 | private → public (need-singularity org 결정) | P3 |

## 4. 파일 인덱스

| 역할 | 경로 |
|---|---|
| 본 문서 | `docs/AG-Q16_cross_host_ship.md` |
| 선행 설계 | `docs/AG-Q14_docker_migration.md`, `docs/AG-Q14_host_audit.md`, `docs/AG-Q15_managed_agents_mesh.md` |
| Docker SSOT | `docker/Dockerfile`, `docker/sshd_config`, `docker/compose.yml`, `bin/airgenome-claude-run` |
| cx / 라우팅 | `bin/cx`, `cl`, `shared/claudx/pool.js`, `shared/claudx/interceptor.js` |
| Slice / systemd | `shared/systemd/drill.slice`, `shared/systemd/airgenome.slice`, `shared/systemd/airgenome-claude.slice`, `shared/systemd/airgenome-claude.service`, `shared/systemd/ssh.service.d/override.conf` |
| Runaway | `bin/runaway_guard.hexa`, `shared/runaway/whitelist.json`, `shared/runaway/thresholds.json`, `shared/systemd/airgenome-runaway.service` |
| M15 Telegram | `bin/tg_bot.hexa`, `shared/launchagents/com.airgenome.tg-bot.plist`, `shared/systemd/airgenome-tg.service` |
| Worker queue | `modules/worker.hexa`, `modules/worker_queue.hexa` |
| Daily build | `bin/airgenome-build`, `shared/systemd/airgenome-build.{service,timer}` |
| Hexa shim/heal | `bin/hexa_shim`, `bin/hexa_heal` (추가), `run.hexa` (airgenome slots) |
| Session prompt SSOT | `shared/config/docker_session_prompt.txt` |
| Host SSOT | `shared/config/hosts.json` |

## 5. 참고

- 선행 완결 마커: AG-Q14 (Docker drill), AG-Q15 (Managed Agents 설계), AG-Q13 (claudx upstream pin), AG-Q12 (cgroup EUCLEAN)
- 규칙: AG6 (Mac Compute ZERO), AG7 (load balancer)
- 메모리: `project_m11e_cross_host.md`, `project_slice_architecture.md`, `reference_cl_docker_opt_in.md`, `project_claudx_rotation_fix_20260419.md`, `project_interceptor_tui_protection_20260419.md`
- Convergence: `shared/convergence/airgenome_2026_04.convergence` (append-only)
