#!/usr/bin/env bash
# tests/auth-plane/run-all.sh
# @convergence: auth-plane-test-suite-36-45
# 전 테스트 러너. node + bash 파일 자동 실행, PASS/FAIL 집계.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

# 2026-04-21: 호출 shell 의 NODE_OPTIONS/BUN_OPTIONS 는 claudx interceptor +
# oauth-monitor 를 --require 로 주입해 둔 상태일 수 있음. preload 는 테스트
# 모듈이 process.env 를 재설정하기 **전에** 실행되므로, 경로/상태 캐시가
# 테스트의 temp dir 과 어긋나 ENOENT 같은 환경 누출 발생. 테스트 프로세스는
# preload 없이 깨끗하게 띄운다.
unset NODE_OPTIONS BUN_OPTIONS

total_pass=0
total_fail=0
suites_fail=0

run_suite() {
    local f="$1" cmd="$2"
    local name
    name=$(basename "$f")
    echo "─── $name ───"
    local out rc
    out=$("$cmd" "$f" 2>&1) || rc=$?
    rc=${rc:-0}
    printf '%s\n' "$out"
    # 마지막 라인에서 "N pass, M fail" 추출
    local last
    last=$(printf '%s\n' "$out" | grep -E '[0-9]+ pass.*[0-9]+ fail' | tail -1 || true)
    if [ -n "$last" ]; then
        local p f_
        p=$(echo "$last" | sed -E 's/.*: ([0-9]+) pass.*/\1/')
        f_=$(echo "$last" | sed -E 's/.* ([0-9]+) fail.*/\1/')
        total_pass=$((total_pass + p))
        total_fail=$((total_fail + f_))
    fi
    [ "$rc" -ne 0 ] && suites_fail=$((suites_fail + 1))
    echo
}

echo "═══ airgenome auth-plane test suite ═══"
for f in "$DIR"/test-*.js; do
    [ -f "$f" ] || continue
    run_suite "$f" node
done
for f in "$DIR"/test-*.sh; do
    [ -f "$f" ] || continue
    run_suite "$f" bash
done

echo "═══ summary ═══"
echo "total:    ${total_pass} pass / ${total_fail} fail"
echo "suites:   $suites_fail failed"
[ "$suites_fail" -eq 0 ] && { echo "ALL GREEN"; exit 0; }
echo "FAIL"
exit 1
