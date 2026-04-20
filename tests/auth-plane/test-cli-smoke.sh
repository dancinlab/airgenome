#!/usr/bin/env bash
# tests/auth-plane/test-cli-smoke.sh
# 비-destructive CLI smoke. 모든 서브커맨드 help/status/자가진단 수준 호출.
set -uo pipefail
AG=/Users/ghost/Dev/airgenome/bin/airgenome-auth
pass=0; fail=0

t() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ $name"; pass=$((pass+1))
    else
        echo "  ✗ $name" >&2; fail=$((fail+1))
    fi
}

echo "airgenome-auth CLI smoke"
t "help exits 0"        "$AG" help
t "list exits 0"        "$AG" list
t "drift --json exit 0" "$AG" drift --json
t "doctor --json exit 0" "$AG" doctor --json
t "self-test pass"      "$AG" self-test

# token-core CLI
TC=/Users/ghost/Dev/airgenome/shared/claudx/token-core.js
t "token-core probe-all" node "$TC" probe-all
t "token-core sha8"      node "$TC" sha8 test

# token-health CLI
TH=/Users/ghost/Dev/airgenome/shared/claudx/token-health.js
t "token-health tail"    node "$TH" tail 1

echo "cli-smoke: $pass pass, $fail fail"
exit $fail
