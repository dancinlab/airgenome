#!/usr/bin/env bash
# tests/auth-plane/test-doctor-drift.sh
# 실 계정 읽기만, 쓰기 없음. JSON 스키마 필드 존재 검증.
set -uo pipefail
AG=/Users/ghost/Dev/airgenome/bin/airgenome-auth
pass=0; fail=0

t() {
    local name="$1"; shift
    if "$@"; then
        echo "  ✓ $name"; pass=$((pass+1))
    else
        echo "  ✗ $name" >&2; fail=$((fail+1))
    fi
}

check_json_expr() {
    # $1 = expression, stdin = JSON
    jq -e "$1" >/dev/null 2>&1
}

echo "airgenome-auth doctor/drift schema tests"

drift_json=$("$AG" drift --json 2>/dev/null || true)
doctor_json=$("$AG" doctor --json 2>/dev/null || true)

t 'drift --json produces array' bash -c "echo \"\$1\" | jq -e 'type == \"array\"' >/dev/null" _ "$drift_json"
t 'drift --json length >= 1' bash -c "echo \"\$1\" | jq -e 'length >= 1' >/dev/null" _ "$drift_json"
t 'drift row has name/source/alive/drift' bash -c "echo \"\$1\" | jq -e '.[0] | .name and .source and has(\"alive\") and .drift' >/dev/null" _ "$drift_json"

t 'doctor --json produces array' bash -c "echo \"\$1\" | jq -e 'type == \"array\"' >/dev/null" _ "$doctor_json"
t 'doctor row has session_pct/week_pct/exh_active' bash -c "echo \"\$1\" | jq -e '.[0] | has(\"session_pct\") and has(\"week_pct\") and has(\"exh_active\")' >/dev/null" _ "$doctor_json"
t 'doctor row has drift field' bash -c "echo \"\$1\" | jq -e '.[0] | .drift' >/dev/null" _ "$doctor_json"

echo "doctor/drift: $pass pass, $fail fail"
exit $fail
