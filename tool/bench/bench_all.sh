#!/bin/bash
# tool/bench/bench_all.sh — own 5 B 단계 bench 일괄 실행 + 회귀 가드
#
# 모든 tool/bench/bench_site*.hexa 를 순차 실행, 각 결과의 speedup% 추출 후 표 출력.
# 환경: HEXA_RESOLVER_NO_REROUTE=1 HEXA_SHIM_NO_DARWIN_LANDING=1 (bare Mac).
#
# 종료 코드:
#   0 — 모든 사이트 통과 (diff_test=0 + speedup 가능)
#   1 — 1개 이상 사이트 fail (lossless 위반 또는 panic)
#
# 사용:
#   tool/bench/bench_all.sh             # 모든 사이트 실행
#   tool/bench/bench_all.sh site1 site3 # 특정 사이트만

set -u
cd "$(dirname "$0")/../.."  # airgenome root

export HEXA_RESOLVER_NO_REROUTE=1
export HEXA_SHIM_NO_DARWIN_LANDING=1

if [ "$#" -gt 0 ]; then
    SITES="$@"
else
    SITES=$(ls tool/bench/bench_site*.hexa 2>/dev/null | sed 's|tool/bench/bench_||;s|\.hexa$||' | sort)
fi

FAILS=0
printf "%-10s | %-50s | %s\n" "site" "summary" "diff_test"
printf -- "----------|----------------------------------------------------|----------\n"

for site in $SITES; do
    f="tool/bench/bench_${site}.hexa"
    if [ ! -f "$f" ]; then
        printf "%-10s | %-50s | %s\n" "$site" "(missing $f)" "-"
        FAILS=$((FAILS + 1))
        continue
    fi
    out=$(hexa run "$f" 2>&1)
    rc=$?
    if [ $rc -ne 0 ]; then
        printf "%-10s | %-50s | %s\n" "$site" "FAIL rc=$rc" "-"
        FAILS=$((FAILS + 1))
        continue
    fi
    summary=$(echo "$out" | grep -E 'speedup=|saved=' | tail -1 | sed 's/^ *//')
    diff_line=$(echo "$out" | grep -E 'diff_test|diff_byte' | head -1 | sed 's/^ *//')
    if [ -z "$summary" ]; then summary="(no speedup line — see full output)"; fi
    printf "%-10s | %-50s | %s\n" "$site" "$summary" "$diff_line"
done

echo ""
if [ $FAILS -eq 0 ]; then
    echo "✅ all sites OK"
    exit 0
else
    echo "🔴 $FAILS site(s) failed"
    exit 1
fi
