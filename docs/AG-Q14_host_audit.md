# AG-Q14 Host Audit — M14 Docker Migration P1

**Date**: 2026-04-19
**Scope**: ubu, ubu2, hetzner (htz) — 3호스트 전수조사 (읽기 전용)
**Inputs**: `/tmp/audit_{ubu,ubu2,hetzner}.txt`, `/tmp/apt_*.pkgs`
**Purpose**: Docker 이미지 레이어 설계 + 호스트 drift 식별

---

## § 1 호스트 하드웨어

| Host | OS | Kernel | CPU | RAM | Swap | Disk (/) | Node | Python | Load (1m) |
|---|---|---|---|---|---|---|---|---|---|
| **ubu** | Ubuntu 24.04.2 LTS | 6.17.0-20 | 12 | 30Gi (15G used) | 8Gi (8Gi used!) | 915G / 27% | 20.18.0 | 3.12.3 | 2.18 |
| **ubu2** | Ubuntu 24.04.2 LTS | 6.17.0-20 | 12 | 30Gi (2.8G used) | 8Gi (168M) | 915G / 3% | 20.18.0 | 3.12.3 | 1.02 |
| **htz** | Ubuntu 24.04.3 LTS | 6.8.0-100 | **32** | **124Gi** (29G) | 63Gi (33G) | **98G / 87%**  | **18.19.1** | 3.12.3 | **11.33** |

**Alerts**
- htz `/` 87% full (13G 여분) — 이미지 pull 여유 작음
- htz swap 33G 상시 사용, load 11+ 만성 → Docker 오버헤드 주의
- ubu swap 8G/8G 포화 — slice isolation 효과 확인 필요
- htz kernel 6.8 (LTS) vs ubu 6.17 — cgroup v2/systemd 기능 동일, Docker 호환 OK

---

## § 2 APT 패키지 — 공통/고유

| 분류 | 개수 | 비고 |
|---|---|---|
| 공통 (3호스트 모두) | **650** | 베이스 이미지 후보 |
| ubu-only | **208** | 대부분 `cuda-toolkit-12-8` 스택 (GPU) + `cmake` + `ca-certificates-java` |
| ubu2-only | **2** | `libgl1-amber-dri`, `libglapi-mesa` (노이즈) |
| htz-only | **541** | `intel-mkl`, `libblis*`, `gcc-10-base`, `finalrd`, `cryptsetup*`, `byobu`, `libjs-*` (apt-native node 생태계), `libmkl-*` |

**Drift-sensitive 런타임 존재 매트릭스** (1=있음, 0=없음)

| 패키지 | ubu | ubu2 | htz | 비고 |
|---|:-:|:-:|:-:|---|
| nodejs (apt) | 0 | 0 | **1** | ubu/ubu2 는 `/usr/local/bin/node` (NodeSource tarball 20.x) — htz 만 apt 18.x |
| npm (apt) | 0 | 0 | **1** | ubu/ubu2 는 tarball npm 10.8.2; htz apt 9.2.0 |
| build-essential | 1 | **0** | 1 | **ubu2 결손** — hexa-lang 빌드 불가 |
| gcc / g++ / make | 1 | **0** | 1 | 동일 (ubu2 dev 미설치) |
| clang | 1 | 1 | 1 | 공통 |
| cmake | **1** | 0 | 0 | ubu 에만 |
| tailscale | 1 | 1 | **0** | htz 는 직결 (tailscale 없음) |
| sshfs / fuse3 | 1/1 | 1/1 | 0/1 | htz 는 sshfs reverse-mount 미사용 |
| cpulimit / schedtool | 0 | 0 | 0 | 모두 `renice` 만 |
| docker* | 0 | 0 | 0 | **Docker 미설치 — P2 에서 설치** |
| jq / curl / git / zstd / rsync | 1 | 1 | 1 | 공통 |
| sysstat / strace / bpftrace / linux-tools-common | 1 | 1 | 1 | 진단 도구 공통 |
| htop | 0 | 0 | 1 | htz 만 |

---

## § 3 런타임 버전 drift (핵심)

| 항목 | ubu | ubu2 | htz | 심각도 |
|---|---|---|---|:-:|
| **Node** | 20.18.0 (tarball) | 20.18.0 (tarball) | **18.19.1** (apt) | HIGH |
| **npm** | 10.8.2 | 10.8.2 | **9.2.0** | HIGH |
| **@anthropic-ai/claude-code** | 2.1.112 | 2.1.112 | **2.1.114** | MED |
| **hexa binary** | sha `6f4cf2ed` **2.33 MB** (Apr19 05:51) | sha `c2941b03` 8.84 MB (Apr15) | sha `c2941b03` 8.84 MB (Apr14) | **HIGH** |
| hexa_stage0 | 2.21 MB (Apr14) | 2.21 MB (Apr17) | 2.21 MB (Apr16) | OK |
| tailscale | 1.96.4 | 1.96.4 | — | — |
| OS minor | 24.04.2 | 24.04.2 | **24.04.3** | LOW |

**hexa drift 근본 원인**: ubu 는 Apr19 05:51 최신 빌드 (size 2.33MB, stripped stage1?), ubu2/htz 는 Apr14-15 구 빌드 (8.84MB, unstripped). SSOT 배포 미흡 — `feedback_resource-sync-ssot.md` 의 hexa drift alert 해당.

---

## § 4 이미지화 권고 (Docker 레이어 매핑)

### L1 — base:common (공통 650 apt + 시스템 도구)
```
FROM ubuntu:24.04
RUN apt install -y \
  build-essential clang make gcc g++ \
  jq curl wget git rsync zstd xz-utils tar unzip \
  python3 python3-pip \
  sysstat strace bpftrace linux-tools-generic \
  openssh-client fuse3 \
  ca-certificates
```

### L2 — airgenome:runtime (claude + node + hexa)
```
FROM base:common
# Node 20.x (NodeSource tarball — htz 에서 drift 원인)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt install -y nodejs
RUN npm i -g @anthropic-ai/claude-code@2.1.114 corepack pnpm
# hexa-lang: SSOT sha c2941b03 (Apr15 안정판) 고정
COPY ./hexa /root/.hx/bin/hexa
RUN chmod +x /root/.hx/bin/hexa
ENV PATH=/root/.hx/bin:$PATH
ENV CLAUDE_EXEC=/usr/bin/claude
```

### L3 — airgenome:gpu (GPU 호스트 전용)
```
FROM airgenome:runtime
# CUDA 12.8 (ubu 전용 — cuda-toolkit-12-8 스택)
RUN apt install -y cuda-toolkit-12-8
```

**매핑**
- ubu → `airgenome:gpu` (CUDA + GPU dispatch)
- ubu2 → `airgenome:runtime` (compute only, build-essential 포함)
- htz → `airgenome:runtime` (compute+heavy, node/claude drift 자동 해결)

---

## § 5 호스트에 남겨야 할 항목 (이미지 금지)

| 범주 | 이유 |
|---|---|
| `openssh-server` + `/etc/ssh/` | Docker 호스트 외부 접속 경로 (LAN/tailscale) |
| `tailscale` + `tailscaled` (ubu/ubu2) | LAN mesh, Docker 밖 네트워크 layer |
| `systemd-user` services: `mac-home.service`, `mac-tmp.service` (ubu/ubu2) | sshfs reverse-mount. Docker 안에서 mount 불가/불편 → bind-mount 로 컨테이너에 주입 |
| `fuse3` (kernel-side) | sshfs 의존. Docker 내부 fuse 는 `--privileged` 필요 → host 측 권장 |
| `cgroup v2` + slice 정의 (`/etc/systemd/system/*.slice`) | `project_slice_architecture.md` 의 claude/stress/bkgnd/real slice → Docker `--cgroup-parent` 로 참조만 |
| `launchd` 대응 주기 서비스 (없음; systemd user unit 통일) | — |
| `renice` 권한 | `cpulimit`/`schedtool` 없어서 renice 로 대체. `--cap-add=SYS_NICE` 필요 |
| sshd `AuthorizedKeysFile`, `~/.ssh/authorized_keys` | keychain 이식 경로 (`reference_mac_keychain_port.md`) |
| `/home/$USER/mac_home` 마운트 포인트 | sshfs reverse-mount 의존 경로. 컨테이너에 bind-mount |
| host `/var/folders/...` 캐시 (ubu `mac-tmp`) | image-paste path resolve |

---

## § 6 Drift Hot-Spots (TOP 5)

1. **hexa binary (ubu vs ubu2/htz)** — ubu 만 Apr19 최신, 나머지 Apr14-15. size 2.33MB vs 8.84MB. SSOT 배포 브로큰. **P1 즉시 sync 필요**.
2. **Node 18 vs 20 (htz 만 apt, 나머지 tarball)** — claude CLI 호환성 리스크. htz 로의 dispatch 시 특정 npm 패키지 실패 가능. Docker 이미지화로 강제 20.x.
3. **claude-code 2.1.112 vs 2.1.114 (htz 선행)** — htz 는 자동 업데이트 됐지만 LAN 호스트는 지연. cl wrapper 경로 차이일 가능성. Docker pin 으로 통일.
4. **ubu2 의 build-essential/gcc/make 결손** — hexa-lang 원격 빌드 불가 → Apr15 stage 로 고정. 이미지화 시 자동 해결.
5. **htz 디스크 87% + load 11** — 이미지 pull/컨테이너 생성 전 정리 필요. `intel-mkl` (~1.5GB) 등 미사용 제거 후보.

---

## § 7 다음 단계 권고 (P2 진입)

1. **긴급 (P1 cleanup)**
   - [ ] hexa binary SSOT sync: ubu 의 `6f4cf2ed` 를 ubu2/htz 에 배포 OR ubu 를 `c2941b03` 으로 롤백 결정 (현재 `hexa default=remote dispatch` 가 ubu 우선 → ubu 쪽이 정답 가능성 높음)
   - [ ] htz `intel-mkl*`, `libblis*`, `libgcc-10-base` 등 미사용 제거 → 최소 2GB 확보
2. **이미지 빌드 (P2)**
   - [ ] `airgenome:base` (650 common apt) — GitHub Actions 또는 Mac buildx
   - [ ] `airgenome:runtime` (node20 + claude@2.1.114 + hexa c2941b03) — ENV pinning
   - [ ] `airgenome:gpu` (cuda-toolkit-12-8 FROM runtime) — ubu 전용
3. **배포 모델**
   - [ ] Docker daemon 설치: ubu → ubu2 → htz 순서 (htz 는 디스크 정리 후)
   - [ ] `systemd-run --slice=claude.slice docker run --cgroup-parent=claude.slice ...` 로 기존 slice 아키텍처 보존
   - [ ] sshfs / mac-home / mac-tmp 는 호스트 마운트 유지 → 컨테이너에 `-v /home/$USER/mac_home:/mac_home`
4. **검증**
   - [ ] claude CLI 버전 통일 확인: `cx claude --version` == 2.1.114 on all 3
   - [ ] hexa self-test: `hexa_selftest_remote` 로 3호스트 동일 sha 확인
   - [ ] cx dispatch 트래픽 shift: 점진 (ubu 만 먼저 → ubu2 → htz)
5. **회피 항목**
   - Docker-in-hexa 제어 도구는 기존 `bin/cx` 확장으로. 외부 앱 도입 금지 (`feedback_no_compromise.md`).
   - htz 의 Mac compute ban (AG6) 유지 — Docker 전환 후에도 동일.

---

**Appendix — 원본 dump**: `/tmp/audit_{ubu,ubu2,hetzner}.txt` (1294–1872 lines each), apt package lists `/tmp/apt_{ubu,ubu2,hetzner}.pkgs`.
