#!/bin/sh
# cl — Claude Code 실행 약자 (M13h, 2026-04-19)
#
# claudx-loop 경유로 자동 rotation + watchdog + RC 등 전부 활성.
# zshrc 의 claude() 함수가 TUI → claudx-loop, -p → claudx 분기.
# 이전 hexa 기반 pool 로직 (modules/cl.hexa) 은 claudx 의 pool.js 에 흡수됨.
# 비상용 raw: `command claude` 또는 `NO_CLAUDX=1 claude`
#
# [AG-Q14, 2026-04-19] CL_DOCKER default=1 (2026-04-19 승격):
#   ubu/ubu2/htz 의 airgenome-claude 컨테이너로 기본 라우팅 → Mac 입력렉 우회.
#   cx --docker 경로 (priority-first probe + container exec).
#   rotation/watchdog 은 cx 내부에 통합된 claudx env 전달로 유지.
#
#   - 이전(opt-in)  : CL_DOCKER=1 set 해야 container 경유
#   - 현재(default) : container 경유가 기본, CL_NO_DOCKER=1 로 native 강제
#
#   연관 안전망 (별도 레이어):
#     * cx v5 는 host sshd 포화 시 docker-ssh (port 2222) 로 이미 bypass 경로 활성.
#     * CL_DOCKER=1 은 추가로 `docker exec airgenome-claude` wrap → 컨테이너 isolation.
#     * cx 는 docker-ssh probe / docker exec 실패 시 native host ssh 로 graceful fallback.
#
#   opt-out:
#     CL_NO_DOCKER=1 cl        # 이번 세션만 native
#     export CL_NO_DOCKER=1    # 지속 native
#     command claude           # 완전 raw

# ─── default 승격: 명시적으로 disable 안 했으면 docker 모드 ────────────────
cl_docker_enabled=1
if [ "${CL_NO_DOCKER:-0}" = "1" ]; then
    cl_docker_enabled=0
fi
# 하위호환: CL_DOCKER=0 명시 시에도 native 로 (기존 사용자 습관 보호)
if [ "${CL_DOCKER:-unset}" = "0" ]; then
    cl_docker_enabled=0
fi

# 첫 실행 1회 notice — ~/.airgenome/cl_docker_notice 마커로 중복 방지
_cl_notice_marker="${HOME}/.airgenome/cl_docker_notice"
if [ "$cl_docker_enabled" = "1" ] && [ ! -f "$_cl_notice_marker" ]; then
    mkdir -p "${HOME}/.airgenome" 2>/dev/null
    : > "$_cl_notice_marker" 2>/dev/null
    printf '%s\n' \
        "cl: CL_DOCKER default → container routing (ubu/ubu2/htz airgenome-claude)" \
        "cl: opt-out → CL_NO_DOCKER=1 cl ...   (또는 command claude)" \
        >&2
fi
unset _cl_notice_marker

if [ "$cl_docker_enabled" = "1" ]; then
    exec "$HOME/Dev/airgenome/bin/cx" --docker "$@"
fi

exec claude "$@"
