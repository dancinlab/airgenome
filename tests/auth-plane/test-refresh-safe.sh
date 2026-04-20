#!/usr/bin/env bash
# tests/auth-plane/test-refresh-safe.sh
# refresh-safe 의 lock + event 분류 검증. fake claude 를 AIRGENOME_CLAUDE_CMD 로 주입.
set -uo pipefail
AG=/Users/ghost/Dev/airgenome/bin/airgenome-auth
TESTDIR=$(mktemp -d -t ag-refresh-safe-XXXX)
export CLAUDX_STATE="$TESTDIR/claudx"
mkdir -p "$CLAUDX_STATE"

ACCT="ag-test-rs-$$"
ACCT_DIR="$HOME/.claude-$ACCT"
LOCK_DIR="$HOME/.airgenome/claudx/locks/refresh-${ACCT}.lockd"

cleanup() {
    rm -rf "$ACCT_DIR" "$LOCK_DIR" "$TESTDIR"
}
trap cleanup EXIT

pass=0; fail=0
t() {
    local name="$1"; shift
    if "$@"; then
        echo "  ✓ $name"; pass=$((pass+1))
    else
        echo "  ✗ $name" >&2; fail=$((fail+1))
    fi
}

# 1. fake claude 준비
FAKE="$TESTDIR/fake-claude"
cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
mode="${FAKE_CLAUDE_MODE:-ok}"
cred="$CLAUDE_CONFIG_DIR/.credentials.json"
case "$mode" in
    ok)   exit 0 ;;
    fail) exit 1 ;;
    rotate)
        if [ -f "$cred" ]; then
            jq --arg new_rt "rotated-$(date +%s%N)-$RANDOM" '.claudeAiOauth.refreshToken = $new_rt' "$cred" > "${cred}.tmp" && mv "${cred}.tmp" "$cred"
        fi
        exit 0
        ;;
    sleep)
        sleep "${FAKE_CLAUDE_SLEEP:-2}"
        exit 0
        ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$FAKE"

# 2. fake account
mkdir -p "$ACCT_DIR"
now_ms=$(($(date +%s) * 1000 + 3600000))
cat > "$ACCT_DIR/.credentials.json" <<EOF
{
  "claudeAiOauth": {
    "accessToken": "fake-at",
    "refreshToken": "fake-rt-initial",
    "expiresAt": $now_ms
  }
}
EOF

echo "refresh-safe event classification tests"

last_event() {
    tail -1 "$CLAUDX_STATE/token-health.jsonl" | jq -r .event
}

# case 1: ok + rt unchanged → event=refresh
FAKE_CLAUDE_MODE=ok AIRGENOME_CLAUDE_CMD="$FAKE" "$AG" refresh-safe "$ACCT" >/dev/null 2>&1
t "ok + unchanged rt → event=refresh" test "$(last_event)" = "refresh"

# case 2: fail → event=revoke
FAKE_CLAUDE_MODE=fail AIRGENOME_CLAUDE_CMD="$FAKE" "$AG" refresh-safe "$ACCT" >/dev/null 2>&1
t "fail → event=revoke" test "$(last_event)" = "revoke"

# case 3: rotate (fake claude 가 rt 수정) → event=rotate
FAKE_CLAUDE_MODE=rotate AIRGENOME_CLAUDE_CMD="$FAKE" "$AG" refresh-safe "$ACCT" >/dev/null 2>&1
t "rotate → event=rotate" test "$(last_event)" = "rotate"

# case 4: lock — 진행 중이면 두번째 호출 skip (rc=2)
FAKE_CLAUDE_MODE=sleep FAKE_CLAUDE_SLEEP=2 AIRGENOME_CLAUDE_CMD="$FAKE" "$AG" refresh-safe "$ACCT" >/dev/null 2>&1 &
bg_pid=$!
sleep 0.5
FAKE_CLAUDE_MODE=ok AIRGENOME_CLAUDE_CMD="$FAKE" "$AG" refresh-safe "$ACCT" >/dev/null 2>&1
second_rc=$?
wait "$bg_pid"
t "concurrent → second call rc=2" test "$second_rc" = "2"

# case 5: stale lock (age > 300s) → reclaim
mkdir -p "$LOCK_DIR"
# touch to set mtime 400초 전
python3 -c "import os,time; os.utime('$LOCK_DIR', (time.time()-400, time.time()-400))" 2>/dev/null || \
    touch -t "$(date -v -400S +%Y%m%d%H%M.%S 2>/dev/null || echo 202604200000.00)" "$LOCK_DIR" 2>/dev/null
FAKE_CLAUDE_MODE=ok AIRGENOME_CLAUDE_CMD="$FAKE" "$AG" refresh-safe "$ACCT" >/dev/null 2>&1
reclaim_rc=$?
t "stale lock reclaimed → rc=0" test "$reclaim_rc" = "0"

echo "refresh-safe: $pass pass, $fail fail"
exit $fail
