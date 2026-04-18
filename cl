#!/bin/sh
# cl — Claude Code 실행 약자 (M13h, 2026-04-19)
#
# claudx-loop 경유로 자동 rotation + watchdog + RC 등 전부 활성.
# zshrc 의 claude() 함수가 TUI → claudx-loop, -p → claudx 분기.
# 이전 hexa 기반 pool 로직 (modules/cl.hexa) 은 claudx 의 pool.js 에 흡수됨.
# 비상용 raw: `command claude` 또는 `NO_CLAUDX=1 claude`

exec claude "$@"
