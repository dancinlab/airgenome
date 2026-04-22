# airgenome docker/ — fat image build

단일 이미지로 `ubu1/ubu2/htz` 3호스트 커버 (linux/amd64). Mac (arm64) 은 가능하면 `--multiarch` 로 포함.

## 구성

| 파일 | 용도 |
|---|---|
| `Dockerfile` | 4-stage multi-stage build: base → node+claude → rust+hexa → final |
| `sshd_config` | 컨테이너 sshd port 2222, pubkey only |
| `build` | 빌드/push 래퍼 (Mac 에서 실행, 원격 ubu1 build default) |

## 포함 (fat = everything)

- **claude CLI** — `@anthropic-ai/claude-code@latest` + `@anthropic-ai/sdk` + `@anthropic-ai/bedrock-sdk`
- **hexa** — cargo self-built from `/opt/hexa-lang` (Apr19+ bitwise 지원)
- **nexus** — full tree at `/opt/nexus`, symlink `/root/.hx/packages/nexus`
- **airgenome** — full tree at `/opt/airgenome`
- **build toolchain** — gcc/clang/lld/lldb/gdb + cmake/ninja + cargo+rustup
- **debug** — strace/ltrace/htop/iotop/ncdu/tree/lsof
- **net** — iproute2/nc/dig/traceroute/tcpdump
- **editor** — vim-nox/neovim/tmux/screen

Uncompressed ~6-8 GB, compressed ~2-3 GB.

## Build context

Dockerfile 은 3 repo 의 병렬 context 를 사용:
```
/Users/ghost/core/
├── airgenome/
├── hexa-lang/
└── nexus/
```

build.sh 가 원격 호스트에 이 3 repo 를 rsync 후 `docker build -f airgenome/docker/Dockerfile -t airgenome:fat .` 실행.

## 사용

```bash
# 기본: ubu1 에서 amd64 빌드 + ghcr push
./build

# 태그 지정
./build --tag fat-v1

# 다른 host (htz) 에서 빌드 (/ 디스크 확보 후)
./build --host htz

# multi-arch (Mac arm64 포함 시도)
./build --multiarch

# Mac 로컬 빌드 (Docker Desktop 필요, QEMU 느림)
./build --local

# dry-run
./build --dry-run
```

## Push 대상

`ghcr.io/need-singularity/airgenome:fat`

push 전 원격 호스트에 ghcr 인증 필요:
```bash
gh auth token | ssh ubu1 'docker login ghcr.io -u dancinlife --password-stdin'
```

## 3호스트 배포 (빌드 후)

```bash
for h in ubu1 ubu2 htz; do
  airgenome offload $h 'docker pull ghcr.io/need-singularity/airgenome:fat'
done
# 각 host 에서 기존 컨테이너 stop → rm → 새 이미지로 재기동
# (airgenome-claude 컨테이너 기동 명령은 기존 airgenome-init 또는 host 쪽 launcher 참조)
```

## Mac (arm64) 지원 — "억지로 말고"

- Dockerfile 자체는 platform-neutral
- `./build --multiarch` 로 buildx multi-arch push 가능
- 단 cargo build (hexa) 는 cross-compile 시 QEMU emulation 으로 느림 (~2×)
- Mac 은 dispatcher only 라 **반드시 필요하진 않음**
- 나중 별도 tag `airgenome:fat-arm64` 로 분리하는 것도 옵션
