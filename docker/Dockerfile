# syntax=docker/dockerfile:1.6
# airgenome fat image — all-in-one dev/run environment.
# Design intent: host-zero dependency. claude CLI + hexa (cargo self-build) +
# nexus CLI + airgenome supervisor + full build toolchain + common CLI utils.
# Size is NOT optimized — explicit user requirement "docker size 는 최대한".
# Expected compressed: ~2-3 GB, uncompressed ~6-8 GB.

ARG BASE=ubuntu:24.04

# ═══════════════════════════════════════════════════════════════════
# Stage 1: base system — full dev/ops toolkit
# ═══════════════════════════════════════════════════════════════════
FROM ${BASE} AS base
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul LANG=C.UTF-8 LC_ALL=C.UTF-8

# apt cache mount — buildkit cache 로 재빌드 시 447MB 다운로드 hit.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git jq ripgrep fd-find yq \
    tini tmux screen vim-nox neovim less man-db bash-completion \
    openssh-client openssh-server sshfs fuse3 rsync \
    python3 python3-pip python3-venv python3-dev python3-setuptools \
    build-essential pkg-config cmake ninja-build \
    clang lld lldb gdb strace ltrace \
    libssl-dev zlib1g-dev libclang-dev \
    util-linux procps coreutils psmisc lsof \
    cpulimit schedtool htop iotop ncdu tree \
    locales tzdata \
    iproute2 netcat-openbsd dnsutils traceroute tcpdump \
    zip unzip xz-utils zstd \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && locale-gen en_US.UTF-8 ko_KR.UTF-8

# ═══════════════════════════════════════════════════════════════════
# Stage 2: Node 20 + @anthropic-ai/claude-code + sdk
# ═══════════════════════════════════════════════════════════════════
FROM base AS node
ARG CLAUDE_VERSION=latest
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g \
      @anthropic-ai/claude-code@${CLAUDE_VERSION} \
      @anthropic-ai/sdk \
      @anthropic-ai/bedrock-sdk \
 && npm cache clean --force

# ═══════════════════════════════════════════════════════════════════
# Stage 3: Rust toolchain + hexa (self-host, 사전 빌드된 linux ELF 복사)
# ═══════════════════════════════════════════════════════════════════
# hexa-lang 은 self-host 컴파일러 (Cargo 아님). 이미 빌드된 linux/amd64
# 바이너리 `hexa-lang/build/hexa_stage0.linux` (Apr19+ bitwise 지원) 를
# 직접 COPY. 이미지 내 재빌드는 `hexa build self/main.hexa` 로 가능.
FROM node AS rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
      sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}" CARGO_TERM_COLOR=always

# hexa source (full tree, 이미지 내 재빌드 가능)
COPY hexa-lang/ /opt/hexa-lang/
# 사전 빌드 바이너리 → /usr/local/bin/
COPY hexa-lang/build/hexa_stage0.linux /usr/local/bin/hexa_real
RUN chmod +x /usr/local/bin/hexa_real \
 && ln -sf /usr/local/bin/hexa_real /usr/local/bin/hexa \
 && ln -sf /usr/local/bin/hexa_real /usr/local/bin/hexa_stage0

# ═══════════════════════════════════════════════════════════════════
# Stage 4: final — repos + runtime
# ═══════════════════════════════════════════════════════════════════
FROM rust AS final

# airgenome + nexus full trees
COPY airgenome/ /opt/airgenome/
COPY nexus/     /opt/nexus/

# nexus package symlinks (run.hexa 호환 경로) + nexus CLI shim
RUN mkdir -p /root/.hx/bin /root/.hx/packages /workspace /root/.airgenome \
 && ln -sf /opt/nexus /root/.hx/packages/nexus \
 && ln -sf /usr/local/bin/hexa_real /root/.hx/bin/hexa_real \
 && ln -sf /usr/local/bin/hexa_real /root/.hx/bin/hexa \
 && if [ -f /opt/nexus/scripts/bin/nexus ]; then \
      ln -sf /opt/nexus/scripts/bin/nexus /usr/local/bin/nexus; \
    elif [ -f /opt/nexus/bin/nexus ]; then \
      ln -sf /opt/nexus/bin/nexus /usr/local/bin/nexus; \
    fi \
 && find /opt/airgenome/bin /opt/nexus/scripts/bin /opt/nexus/bin \
      -type f 2>/dev/null -exec chmod +x {} \; || true

# sshd config
COPY airgenome/docker/sshd_config /etc/ssh/sshd_config.d/airgenome.conf
RUN mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh

ENV PATH="/opt/airgenome/bin:/opt/nexus/bin:/opt/nexus/scripts/bin:/root/.hx/bin:/root/.cargo/bin:${PATH}" \
    HEXA_LANG=/opt/hexa-lang \
    NEXUS=/opt/nexus \
    AIRGENOME_ROOT=/opt/airgenome \
    HEXA=/usr/local/bin/hexa_real \
    HEXA_NO_LAUNCHD=1 \
    HEXA_LOCAL=1

WORKDIR /workspace

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD sh -c 'hexa_real --version >/dev/null 2>&1 && node --version >/dev/null 2>&1 || exit 1'

ENTRYPOINT ["/usr/bin/tini", "--", "/bin/sh", "-c", \
  "ssh-keygen -A >/dev/null 2>&1; /usr/sbin/sshd -f /etc/ssh/sshd_config.d/airgenome.conf -E /var/log/sshd-airgenome.log; exec \"$@\"", "--"]
CMD ["sleep", "infinity"]

ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.source="https://github.com/need-singularity/airgenome" \
      org.opencontainers.image.description="airgenome fat — claude CLI + hexa + nexus + airgenome + full build deps" \
      org.opencontainers.image.licenses="Proprietary" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      fat.includes.hexa="pre-built ELF from hexa-lang/build/hexa_stage0.linux" \
      fat.includes.claude="@anthropic-ai/claude-code@latest" \
      fat.includes.nexus="/opt/nexus (full tree)" \
      fat.includes.airgenome="/opt/airgenome (full tree)"
