#!/bin/sh
# cl — Claude Code 실행 약자 (M13h, 2026-04-19)
#
# claudx-loop 경유로 자동 rotation + watchdog + RC 등 전부 활성.
# zshrc 의 claude() 함수가 TUI → claudx-loop, -p → claudx 분기.
# 이전 hexa 기반 pool 로직 (modules/cl.hexa) 은 claudx 의 pool.js 에 흡수됨.
# 비상용 raw: `command claude` 또는 `NO_CLAUDX=1 claude`
#
# [AG-Q14, 2026-04-19] CL_DOCKER=1 opt-in:
#   ubu/ubu2/htz 의 airgenome-claude 컨테이너로 라우팅 → Mac 입력렉 우회.
#   cx --docker 경로 (priority-first probe + container exec).
#   rotation/watchdog 은 cx 내부에 통합된 claudx env 전달로 유지.

if [ "${CL_DOCKER:-0}" = "1" ]; then
    exec "$HOME/Dev/airgenome/bin/cx" --docker "$@"
fi

exec claude "$@"
