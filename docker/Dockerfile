# airgenome — claude CLI + hexa runtime container
# 3-stage: base (OS) → claude (CLI + npm) → dev (hexa + project code)
# 빌드: docker buildx bake -f docker/buildx.bake.hcl --push
# 빌더: hetzner (32t/128GB) — airgenome-build.timer 5min cadence

ARG HEXA_BASE=busybox:stable

# ═════════════════════════════════════════════════════════
# L1 base — OS + 런타임 (거의 불변)
# ═════════════════════════════════════════════════════════
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Seoul \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget git \
        jq ripgrep fd-find \
        openssh-client openssh-server sshfs fuse3 \
        tini \
        python3 python3-pip \
        build-essential pkg-config \
        util-linux procps coreutils \
        cpulimit schedtool \
        locales tzdata \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && locale-gen en_US.UTF-8 ko_KR.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Node 20 LTS (claude 요구사항) — NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# /workspace = bind mount target (Mac SSOT → sshfs → container)
RUN mkdir -p /workspace /opt/airgenome /opt/hexa-lang /root/.airgenome

# sshd runtime dirs + sshd_config (port 2222, pubkey only, root login allowed —
# 컨테이너는 --network=host 하에 외부격리 전제, Mac host sshd 포화 시 우회 경로)
RUN mkdir -p /var/run/sshd /root/.ssh \
    && chmod 700 /root/.ssh
COPY docker/sshd_config /etc/ssh/sshd_config.d/airgenome.conf

# ═════════════════════════════════════════════════════════
# L2 claude — CLI + SDK + hexa 바이너리 (주 1~2회)
# ═════════════════════════════════════════════════════════
FROM base AS claude

ARG CLAUDE_VERSION=latest
RUN npm install -g \
        @anthropic-ai/claude-code@${CLAUDE_VERSION} \
        @anthropic-ai/sdk \
    && npm cache clean --force

# hexa-lang 바이너리 (buildx bake 가 `hexa-builder` stage 로 주입)
# 개발중엔 Mac 에서 scp 한 바이너리 직접 COPY 가능
ARG HEXA_BIN_PATH=./build/artifacts/hexa
COPY ${HEXA_BIN_PATH} /usr/local/bin/hexa
RUN chmod +x /usr/local/bin/hexa

# airgenome bin 을 PATH 에 — runaway_guard.hexa, cx, claudx 등 공용
ENV PATH=/opt/airgenome/bin:${PATH}
ENV HEXA_LANG=/opt/hexa-lang

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e 'process.exit(0)' || exit 1

# ═════════════════════════════════════════════════════════
# L3 dev — 프로젝트 코드 (수시). bind mount 우선, 이미지 copy 는 fallback
# ═════════════════════════════════════════════════════════
FROM claude AS dev

# 이미지 내장 사본 (bind mount 실패 시 fallback + cold start)
COPY bin/       /opt/airgenome/bin/
COPY shared/    /opt/airgenome/shared/
COPY core/      /opt/airgenome/core/
# forge/ 는 데이터 적재용 — bind mount 로만 연결 (이미지에 포함 X)

# entrypoint: tini 로 PID 1 문제 해결 + signal 전파.
# sshd (port 2222) 를 background 로 띄우고 원래 CMD 를 foreground 유지.
# authorized_keys 는 runtime bind mount (/root/.ssh/authorized_keys) 로 주입 →
# 이미지에 키 포함 금지. host keys 는 컨테이너 startup 때 생성 (ephemeral OK).
#   run 스크립트가 CMD 에 `sleep infinity` 를 내리므로 아래 CMD 는 compose 로컬용.
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/sh", "-c", "ssh-keygen -A >/dev/null 2>&1; mkdir -p /Users && ln -sfn /mac_home /Users/ghost; /usr/sbin/sshd -f /etc/ssh/sshd_config.d/airgenome.conf -E /var/log/sshd-airgenome.log; exec \"$@\"", "--"]
CMD ["claude"]

LABEL org.opencontainers.image.source="https://github.com/need-singularity/airgenome" \
      org.opencontainers.image.description="airgenome — claude CLI + hexa runtime (AG-Q14)" \
      org.opencontainers.image.licenses="Proprietary"
