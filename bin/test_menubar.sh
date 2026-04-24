#!/usr/bin/env bash
# bin/test_menubar.sh — airgenome menubar V5 (ObjC launcher) 스모크 테스트.
#
# 2026-04-24 V5 전환 후 새 구조 (bin/menubar_launcher.m 가 NSApp 메인,
# hexa 는 데이터 미사용) 에 맞춰 테스트 재작성.
#
# 검증:
#   1. binary executable 존재
#   2. (Aqua 세션이면) 직접 실행 → 3초 후 KILL → 그 사이 heartbeat 파일 touch
#      (ObjC NSTimer onTick 이 정상 동작했는지 확인)
#
# 이전 V4 harness 는 AIRGENOME_MENUBAR_TEST=1 + hexa println 마커 의존이었으나
# V5 launcher 가 hexa main 진입 안 함 → 마커 발화 불가 → 새 구조로 교체.
#
# build_app.sh 의 deploy gate 로 사용. exit 0 = 통과.

set -uo pipefail

ROOT="${AIRGENOME_ROOT:-$HOME/core/airgenome}"
BIN="${1:-$ROOT/build/artifacts/airgenome-menubar}"
HB="$ROOT/state/menubar_heartbeat"

C_OK=$'\033[0;32m'
C_FAIL=$'\033[0;31m'
C_INF=$'\033[0;33m'
C_END=$'\033[0m'
ok()   { echo "${C_OK}PASS${C_END} $*"; }
fail() { echo "${C_FAIL}FAIL${C_END} $*"; exit 1; }
inf()  { echo "${C_INF}...${C_END} $*"; }

# 1. binary
[ -x "$BIN" ] || fail "binary missing or not executable: $BIN"
ok "binary present: $BIN"

# Aqua 세션 감지 — non-Aqua (예: ssh) 면 GUI 검증 skip 하고 통과.
if ! launchctl managername 2>/dev/null | grep -q Aqua; then
    inf "non-Aqua session — GUI 검증 skip (OK)"
    exit 0
fi

# 2. heartbeat refresh — onTick 이 5s 마다 touch. spawn → 6s 대기 → kill.
inf "spawning binary (6s)..."
hb_before=$(stat -f %m "$HB" 2>/dev/null || echo 0)
"$BIN" >/dev/null 2>&1 &
PID=$!
sleep 6
kill -9 "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
hb_after=$(stat -f %m "$HB" 2>/dev/null || echo 0)
[ "$hb_after" -gt "$hb_before" ] || fail "heartbeat 미갱신 (before=$hb_before after=$hb_after) — main loop 미동작"
ok "heartbeat refreshed ($hb_before → $hb_after)"

echo "${C_OK}✅ test_menubar smoke PASS${C_END}"
exit 0
