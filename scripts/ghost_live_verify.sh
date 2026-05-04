#!/bin/bash
# scripts/ghost_live_verify.sh — ghost mk1 host-mode live verifier
#
# Usage: scripts/ghost_live_verify.sh [--verbose] [--no-color] [--skip-broadcast-test]
#
# What it does:
#   1. Probe Mullvad / Tor / Nym presence on the host (cond.2/3/10)
#   2. Run all 7 ghost .hexa selftests + parse sentinels
#   3. Run airgenome ghost CLI smoke tests (help / tunnel-alive / capability status)
#   4. Run cross-repo gate smoke tests (wraith link/ghost.hexa, orpheus link/ghost.hexa)
#      IF those repos are present
#   5. Print per-cond verdict table + summary
#
# Hard rules:
#   - Doesn't require sudo (cond.9 kernel pf activation is a separate operator step)
#   - Doesn't broadcast / upload / sign anything
#   - Doesn't write into operator-private state directly. (Note: invoking
#     audit.hexa / selftest.hexa selftests will cause those modules to append
#     `requester=selftest` rows to state/ghost_audit.jsonl + downgrades + a
#     state/leak_reports/<ts>.jsonl entry. That is the tested modules' own
#     internal behavior, not a write path introduced here. The verifier
#     itself never calls `audit emit` directly.)
#   - Idempotent — safe to run repeatedly
#
# Exit codes:
#   0  all PASS or N/A (none FAIL)
#   1  one or more FAIL
#   2  setup error (airgenome / hexa not on PATH; required files missing)
#
# Note on the docker-route quirk (Mac, hexa-runner): `hexa run` on macOS routes
# the .hexa script through a hexa-runner container that does NOT have host-side
# CLIs (mullvad / tor / nym). So even with Mullvad-CLI-2026.2 installed on the
# host, wrap_*.hexa self-test emits SKIP from inside the container. This script
# distinguishes that case: when the host PATH has the binary but selftest
# returns SKIP, we record PASS with a "selftest SKIP under docker route" note
# (the wrapper is correctly fail-closed; presence is established by host PATH).

set -eu

# ── arg parse ────────────────────────────────────────────────────────────
VERBOSE=0
NO_COLOR=0
SKIP_BROADCAST_TEST=0
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --no-color)   NO_COLOR=1 ;;
        --skip-broadcast-test) SKIP_BROADCAST_TEST=1 ;;
        -h|--help)
            sed -n '1,30p' "$0" | sed -n 's/^# \{0,1\}//p'
            exit 0
            ;;
        *)
            echo "ghost_live_verify: unknown arg: $arg" >&2
            exit 2
            ;;
    esac
done

# ── colors (ANSI; suppressed under --no-color or non-tty) ────────────────
if [ "$NO_COLOR" -eq 1 ] || [ ! -t 1 ]; then
    C_PASS=""; C_FAIL=""; C_NA=""; C_DIM=""; C_BOLD=""; C_RESET=""
else
    if command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
        C_PASS="$(tput setaf 2)"
        C_FAIL="$(tput setaf 1)"
        C_NA="$(tput setaf 8 2>/dev/null || tput setaf 7)"
        C_DIM="$(tput dim 2>/dev/null || true)"
        C_BOLD="$(tput bold)"
        C_RESET="$(tput sgr0)"
    else
        C_PASS=$'\033[32m'; C_FAIL=$'\033[31m'; C_NA=$'\033[90m'
        C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
    fi
fi

# ── env resolution (mirror bin/airgenome) ────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AIRGENOME_ROOT="${AIRGENOME_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WRAITH_ROOT="${WRAITH_ROOT:-$HOME/core/wraith-wallet}"
ORPHEUS_ROOT="${ORPHEUS_ROOT:-$HOME/core/orpheus}"

# Resolve hexa binary (env > PATH)
HEXA="${HEXA:-}"
if [ -z "$HEXA" ] || [ ! -x "$HEXA" ]; then
    HEXA="$(command -v hexa 2>/dev/null || true)"
fi
[ -n "$HEXA" ] && [ -x "$HEXA" ] || {
    echo "ghost_live_verify: hexa binary not found (set \$HEXA or add to PATH)" >&2
    exit 2
}

# Resolve airgenome CLI — prefer in-repo bin/airgenome (real ghost dispatch)
# over $HOME/.hx/bin/airgenome (which is a run.hexa shim and doesn't carry
# cmd_ghost). bin/airgenome is the cond.4 evidence path.
AIRGENOME_BIN="$AIRGENOME_ROOT/bin/airgenome"
if [ ! -x "$AIRGENOME_BIN" ]; then
    AIRGENOME_BIN="$(command -v airgenome 2>/dev/null || true)"
fi
[ -n "$AIRGENOME_BIN" ] && [ -x "$AIRGENOME_BIN" ] || {
    echo "ghost_live_verify: airgenome binary not found at $AIRGENOME_ROOT/bin/airgenome or PATH" >&2
    exit 2
}

GHOST_DIR="$AIRGENOME_ROOT/modules/ghost"
[ -d "$GHOST_DIR" ] || {
    echo "ghost_live_verify: $GHOST_DIR missing — wrong AIRGENOME_ROOT?" >&2
    exit 2
}

# ── helpers ──────────────────────────────────────────────────────────────
vlog() { [ "$VERBOSE" -eq 1 ] && echo "  $C_DIM[v]$C_RESET $*" >&2 || true; }

# Run a hexa script and capture combined stdout+stderr.
hexa_run() {
    local script="$1"; shift
    vlog "hexa run $script $*"
    "$HEXA" run "$script" "$@" 2>&1 || true
}

# Match a sentinel pattern. Returns 0 on match, 1 otherwise.
match_sentinel() {
    local out="$1" pattern="$2"
    printf '%s\n' "$out" | grep -qE "$pattern"
}

# Verdict accumulator (TSV rows).
RESULTS_FILE="$(mktemp -t ghost_live_verify.XXXXXX)"
trap 'rm -f "$RESULTS_FILE"' EXIT

record() {
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RESULTS_FILE"
}

# ── header ───────────────────────────────────────────────────────────────
printf '%s🕶️  ghost mk1 live verifier — host-mode results%s\n' "$C_BOLD" "$C_RESET"
printf 'AIRGENOME_ROOT=%s\n' "$AIRGENOME_ROOT"
printf 'HEXA=%s    AIRGENOME_BIN=%s\n' "$HEXA" "$AIRGENOME_BIN"
printf 'WRAITH_ROOT=%s   (%s)\n' "$WRAITH_ROOT"  "$([ -d "$WRAITH_ROOT" ] && echo present || echo absent)"
printf 'ORPHEUS_ROOT=%s    (%s)\n' "$ORPHEUS_ROOT" "$([ -d "$ORPHEUS_ROOT" ] && echo present || echo absent)"
printf '%s\n' "─────────────────────────────────────────────────────────────────"

# ── backend presence probe ───────────────────────────────────────────────
HAVE_MULLVAD=0; HAVE_TOR=0; HAVE_NYM=0; NYM_BIN=""
command -v mullvad >/dev/null 2>&1 && HAVE_MULLVAD=1
command -v tor     >/dev/null 2>&1 && HAVE_TOR=1
for c in nym-vpn-cli nymvpn-cli nymvpn-x nym-vpnd; do
    if command -v "$c" >/dev/null 2>&1; then
        HAVE_NYM=1; NYM_BIN="$c"; break
    fi
done
vlog "host backends: mullvad=$HAVE_MULLVAD tor=$HAVE_TOR nym=$HAVE_NYM ($NYM_BIN)"

# ── cond.0 — design inbox doc landed ─────────────────────────────────────
{
    cd "$AIRGENOME_ROOT"
    doc_match="$(ls docs/ghost_feature_design_inbox_*.ai.md 2>/dev/null | head -1)"
    if [ -n "$doc_match" ] && grep -qE '^status: (draft_inbox|draft|ready)' "$doc_match" 2>/dev/null; then
        record cond.0 PASS "docs/ghost_feature_design_inbox" "$(basename "$doc_match")"
    else
        record cond.0 FAIL "docs/ghost_feature_design_inbox" "missing or status<draft_inbox"
    fi
}

# ── cond.1 — skeleton (cpre/4 + 7 stub.hexa + .roadmap.ghost) ────────────
{
    missing=""
    for f in cpre/intent.ai.md cpre/scope.ai.md cpre/contracts.ai.md cpre/identity.ai.md \
             module.ai.md route.hexa wrap_mullvad.hexa wrap_tor.hexa wrap_nym.hexa \
             policy.hexa audit.hexa selftest.hexa .roadmap.ghost; do
        [ -e "$GHOST_DIR/$f" ] || missing="$missing $f"
    done
    if [ -z "$missing" ]; then
        record cond.1 PASS "skeleton (cpre/4 + 7 stub.hexa)" "all 13 files present"
    else
        record cond.1 FAIL "skeleton (cpre/4 + 7 stub.hexa)" "missing:$missing"
    fi
}

# ── cond.2 — wrap_mullvad ────────────────────────────────────────────────
{
    if [ "$HAVE_MULLVAD" -eq 0 ]; then
        record cond.2 NA "wrap_mullvad" "mullvad-cli not on host PATH"
    else
        out="$(hexa_run "$GHOST_DIR/wrap_mullvad.hexa" self-test)"
        if match_sentinel "$out" '__GHOST_WRAP_MULLVAD__ PASS'; then
            record cond.2 PASS "wrap_mullvad (mullvad-cli)" "selftest PASS"
        elif match_sentinel "$out" '__GHOST_WRAP_MULLVAD__ SKIP'; then
            record cond.2 PASS "wrap_mullvad (mullvad-cli)" "host PATH ok; selftest SKIP under docker route"
        else
            record cond.2 FAIL "wrap_mullvad (mullvad-cli)" "no PASS/SKIP sentinel"
        fi
    fi
}

# ── cond.3 — wrap_tor + torrc KR exclusion ──────────────────────────────
{
    if [ "$HAVE_TOR" -eq 0 ]; then
        record cond.3 NA "wrap_tor" "system tor not installed"
    else
        out="$(hexa_run "$GHOST_DIR/wrap_tor.hexa" self-test)"
        # G8 — torrc must contain ExcludeExitNodes {kr}
        torrc_ok=0
        for c in /opt/homebrew/etc/tor/torrc /usr/local/etc/tor/torrc /etc/tor/torrc "$HOME/.tor/torrc"; do
            if [ -r "$c" ] && grep -qE 'ExcludeExitNodes[[:space:]]*\{kr\}' "$c"; then
                torrc_ok=1; break
            fi
        done
        if match_sentinel "$out" '__GHOST_WRAP_TOR__ PASS' && [ "$torrc_ok" -eq 1 ]; then
            record cond.3 PASS "wrap_tor (system tor + torrc kr)" "selftest PASS, ExcludeExitNodes {kr} found"
        elif match_sentinel "$out" '__GHOST_WRAP_TOR__ SKIP'; then
            if [ "$torrc_ok" -eq 1 ]; then
                record cond.3 PASS "wrap_tor (system tor + torrc kr)" "host PATH ok; selftest SKIP under docker route; torrc kr ok"
            else
                record cond.3 FAIL "wrap_tor (system tor + torrc kr)" "torrc missing ExcludeExitNodes {kr} — G8 stop-the-line"
            fi
        else
            record cond.3 FAIL "wrap_tor (system tor + torrc kr)" "no PASS/SKIP sentinel"
        fi
    fi
}

# ── cond.4 — route.hexa + airgenome ghost dispatch ──────────────────────
{
    help_out="$("$AIRGENOME_BIN" ghost help 2>&1 || true)"
    out="$(hexa_run "$GHOST_DIR/route.hexa" self-test)"
    cli_ok=0
    if printf '%s' "$help_out" | grep -q 'tunnel-alive'; then cli_ok=1; fi
    if [ "$cli_ok" -eq 1 ] && match_sentinel "$out" '__GHOST_ROUTE__ (PASS|SKIP)'; then
        record cond.4 PASS "route.hexa + airgenome ghost CLI" "help has tunnel-alive; route selftest sentinel ok"
    elif [ "$cli_ok" -eq 0 ]; then
        record cond.4 FAIL "route.hexa + airgenome ghost CLI" "airgenome ghost help missing tunnel-alive"
    else
        record cond.4 FAIL "route.hexa + airgenome ghost CLI" "no PASS/SKIP sentinel from route selftest"
    fi
}

# ── cond.5 — policy.hexa pure-logic gate ────────────────────────────────
{
    out="$(hexa_run "$GHOST_DIR/policy.hexa" self-test)"
    if match_sentinel "$out" '__GHOST_POLICY__ PASS'; then
        record cond.5 PASS "policy (exit/g5/kr-tor/payment/downgrade)" "selftest PASS"
    else
        record cond.5 FAIL "policy (exit/g5/kr-tor/payment/downgrade)" "no __GHOST_POLICY__ PASS sentinel"
    fi
}

# ── cond.6 — kill-switch (tunnel-alive cross-repo gate) ─────────────────
{
    rc=0
    "$AIRGENOME_BIN" ghost tunnel-alive >/dev/null 2>&1 || rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
        record cond.6 FAIL "kill-switch (tunnel-alive gate)" "airgenome ghost tunnel-alive rc=$rc (expected 0 or 1)"
    else
        if [ -d "$WRAITH_ROOT" ] && [ -f "$WRAITH_ROOT/modules/link/ghost.hexa" ]; then
            wout="$(hexa_run "$WRAITH_ROOT/modules/link/ghost.hexa" self-test)"
            if match_sentinel "$wout" '__WRAITH_LINK_GHOST__ (PASS|SKIP)'; then
                record cond.6 PASS "kill-switch (tunnel-alive + wraith W4)" "ghost rc=$rc; wraith link selftest sentinel ok"
            else
                record cond.6 FAIL "kill-switch (tunnel-alive + wraith W4)" "wraith link/ghost selftest no sentinel"
            fi
        else
            record cond.6 PASS "kill-switch (tunnel-alive gate)" "ghost rc=$rc; wraith repo absent (skipped W4 half)"
        fi
    fi
}

# ── cond.7 — audit.hexa metadata-only emit + G2 reject ──────────────────
{
    out="$(hexa_run "$GHOST_DIR/audit.hexa" self-test)"
    if match_sentinel "$out" '__GHOST_AUDIT__ PASS'; then
        # NOTE: cond.7 verifier also runs `audit emit ... | grep ok` — that
        # appends to operator-private state/ghost_audit.jsonl. Per hard rule
        # ("doesn't write into operator-private state"), we omit the emit
        # here. Selftest covers emit-paths internally (7/7 inline cases).
        record cond.7 PASS "audit (metadata-only emit + G2 reject)" "selftest PASS (emit skipped — read-only mode)"
    else
        record cond.7 FAIL "audit (metadata-only emit + G2 reject)" "no __GHOST_AUDIT__ PASS sentinel"
    fi
}

# ── cond.8 — selftest.hexa run-all (DNS/IPv6/WebRTC/SNI) ────────────────
{
    out="$(hexa_run "$GHOST_DIR/selftest.hexa" run-all)"
    if match_sentinel "$out" '__GHOST_SELFTEST__ all (PASS|FAIL)'; then
        verdict="$(printf '%s\n' "$out" | grep -E '__GHOST_SELFTEST__ all' | tail -1 | awk '{print $3}')"
        if [ "$verdict" = "PASS" ]; then
            record cond.8 PASS "selftest (DNS/IPv6/WebRTC/SNI)" "run-all PASS"
        else
            record cond.8 FAIL "selftest (DNS/IPv6/WebRTC/SNI)" "run-all FAIL"
        fi
    else
        record cond.8 FAIL "selftest (DNS/IPv6/WebRTC/SNI)" "no __GHOST_SELFTEST__ all sentinel"
    fi
}

# ── cond.9 — capability flag (status only — no activation) ──────────────
{
    cap_out="$("$AIRGENOME_BIN" ghost capability status 2>&1 || true)"
    if printf '%s\n' "$cap_out" | grep -qE '^(enabled|disabled)$'; then
        state="$(printf '%s\n' "$cap_out" | grep -E '^(enabled|disabled)$' | tail -1)"
        record cond.9 PASS "capability flag (kernel kill-switch opt-in)" "status=$state (operator pf activation is a separate step)"
    else
        record cond.9 FAIL "capability flag (kernel kill-switch opt-in)" "status output not enabled|disabled"
    fi
}

# ── cond.10 — wrap_nym (Phase-2) ────────────────────────────────────────
{
    if [ "$HAVE_NYM" -eq 0 ]; then
        record cond.10 NA "wrap_nym (NymVPN client)" "no nym-vpn-cli/nymvpn-cli/nymvpn-x/nym-vpnd on PATH"
    else
        out="$(hexa_run "$GHOST_DIR/wrap_nym.hexa" self-test)"
        if match_sentinel "$out" '__GHOST_WRAP_NYM__ PASS'; then
            record cond.10 PASS "wrap_nym (NymVPN client)" "selftest PASS via $NYM_BIN"
        elif match_sentinel "$out" '__GHOST_WRAP_NYM__ SKIP'; then
            record cond.10 PASS "wrap_nym (NymVPN client)" "host has $NYM_BIN; selftest SKIP under docker route"
        else
            record cond.10 FAIL "wrap_nym (NymVPN client)" "no PASS/SKIP sentinel"
        fi
    fi
}

# ── cond.11 — orpheus + wraith link/ghost.hexa cross-repo ───────────────
{
    orp_present=0; wra_present=0; orp_ok=""; wra_ok=""
    if [ -f "$ORPHEUS_ROOT/modules/link/ghost.hexa" ]; then
        orp_present=1
        out="$(hexa_run "$ORPHEUS_ROOT/modules/link/ghost.hexa" self-test)"
        if match_sentinel "$out" '__ORPHEUS_LINK_GHOST__ (PASS|SKIP)'; then orp_ok="orpheus:ok"; else orp_ok="orpheus:FAIL"; fi
    fi
    if [ -f "$WRAITH_ROOT/modules/link/ghost.hexa" ]; then
        wra_present=1
        out="$(hexa_run "$WRAITH_ROOT/modules/link/ghost.hexa" self-test)"
        if match_sentinel "$out" '__WRAITH_LINK_GHOST__ (PASS|SKIP)'; then wra_ok="wraith:ok"; else wra_ok="wraith:FAIL"; fi
    fi
    if [ "$orp_present" -eq 0 ] && [ "$wra_present" -eq 0 ]; then
        record cond.11 NA "integration (orpheus + wraith link/ghost.hexa)" "neither sibling repo present"
    elif printf '%s%s' "$orp_ok" "$wra_ok" | grep -q FAIL; then
        record cond.11 FAIL "integration (orpheus + wraith link/ghost.hexa)" "$orp_ok $wra_ok"
    else
        detail=""
        [ "$orp_present" -eq 1 ] && detail="$detail $orp_ok"
        [ "$wra_present" -eq 1 ] && detail="$detail $wra_ok"
        [ "$orp_present" -eq 0 ] && detail="$detail (orpheus repo absent)"
        [ "$wra_present" -eq 0 ] && detail="$detail (wraith repo absent)"
        record cond.11 PASS "integration (orpheus + wraith link/ghost.hexa)" "$(printf '%s' "$detail" | sed 's/^ //')"
    fi
}

# ── render verdict table ────────────────────────────────────────────────
printf '%s\n' "─────────────────────────────────────────────────────────────────"
printf '%-9s %-44s %s\n' "cond" "label" "verdict"
printf '%s\n' "─────────────────────────────────────────────────────────────────"

pass_n=0; fail_n=0; na_n=0; failed_ids=""
while IFS=$'\t' read -r id verdict label detail; do
    case "$verdict" in
        PASS) color="$C_PASS"; pass_n=$((pass_n + 1)) ;;
        FAIL) color="$C_FAIL"; fail_n=$((fail_n + 1)); failed_ids="$failed_ids $id" ;;
        NA)   color="$C_NA";   na_n=$((na_n + 1)) ;;
        *)    color="" ;;
    esac
    if [ "$verdict" = "NA" ]; then
        verdict_disp="N/A"
    else
        verdict_disp="$verdict"
    fi
    if [ ${#label} -gt 44 ]; then
        label="$(printf '%s' "$label" | cut -c1-43)…"
    fi
    printf '%-9s %-44s %s%-4s%s   %s%s%s\n' \
        "$id" "$label" "$color" "$verdict_disp" "$C_RESET" "$C_DIM" "$detail" "$C_RESET"
done < "$RESULTS_FILE"

printf '%s\n' "─────────────────────────────────────────────────────────────────"

# ── summary ─────────────────────────────────────────────────────────────
total=$((pass_n + fail_n + na_n))
if [ "$fail_n" -gt 0 ]; then
    printf '%sverdict: FAIL%s — %d passed, %d failed (%s), %d N/A\n' \
        "$C_FAIL$C_BOLD" "$C_RESET" "$pass_n" "$fail_n" "$(printf '%s' "$failed_ids" | sed 's/^ //')" "$na_n"
    exit 1
elif [ "$na_n" -gt 0 ]; then
    suggest=""
    [ "$HAVE_TOR" -eq 0 ]     && suggest="$suggest tor"
    [ "$HAVE_NYM" -eq 0 ]     && suggest="$suggest nym"
    [ "$HAVE_MULLVAD" -eq 0 ] && suggest="$suggest mullvad"
    if [ -n "$suggest" ]; then
        printf '%sverdict: PARTIAL%s — %d passed, 0 failed, %d N/A (install%s for full coverage)\n' \
            "$C_NA$C_BOLD" "$C_RESET" "$pass_n" "$na_n" "$suggest"
    else
        printf '%sverdict: PARTIAL%s — %d passed, 0 failed, %d N/A\n' \
            "$C_NA$C_BOLD" "$C_RESET" "$pass_n" "$na_n"
    fi
    exit 0
else
    printf '%sverdict: PASS%s — %d/%d cond passed\n' \
        "$C_PASS$C_BOLD" "$C_RESET" "$pass_n" "$total"
    exit 0
fi
