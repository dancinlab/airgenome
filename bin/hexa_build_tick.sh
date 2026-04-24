#!/usr/bin/env bash
# hexa_build_tick.sh — hexa-lang hourly build/test/distribute tick.
#
# Canonical entry point for the hexa-lang build agent. Runs on ubu2
# (hourly via systemd --user timer), and can also be invoked manually
# on the Mac with HEXA_BUILD_REMOTE=ubu2 to trigger a remote build.
#
# When invoked locally on ubu2 the script performs the full
# pull→build→test→distribute pipeline. When invoked on the Mac it
# SSHes into ubu2 and runs the same script there (manual trigger
# ergonomics; remote timer keeps running regardless).
#
# Flow (ubu2 local mode):
#   1. git pull origin main on /home/summer/Dev/hexa-lang
#   2. toolchain preflight: hexa bootstrap + clang + git
#   3. build: ./hexa run tool/build_stage0.hexa  →  build/hexa_stage0.real
#   4. smoke test: `println("ok")` round-trip via the new binary
#   5. test suite: ./hexa run tool/run_tests.hexa (best-effort,
#      degrades to smoke-only if runner itself fails)
#   6. sha256 compare against previous distributed binary; skip if same
#   7. distribute to ubu1 (aiden), hetzner (root), ubu2 (summer)
#      — Mac is arm64, never receives Linux x86_64 binary (skip by design)
#   8. append JSON report to ~/.airgenome/hexa_build.jsonl
#
# Exit codes: 0 = ok (distributed OR no-change), 1 = toolchain gap,
#   2 = build failed, 3 = tests failed (no distribution), 4 = partial
#   distribution failure.
#
# Env:
#   HEXA_BUILD_REMOTE=ubu2    # trigger on remote; else runs locally
#   HEXA_BUILD_SKIP_TESTS=1   # dangerous; smoke-only
#   HEXA_BUILD_FORCE=1        # re-distribute even if sha matches

set -u
LC_ALL=C.UTF-8 2>/dev/null || true

# ── Mac-side manual trigger: SSH into ubu2 and re-exec there ────────
if [[ -n "${HEXA_BUILD_REMOTE:-}" ]]; then
    echo "[hexa_build_tick] remote trigger → ${HEXA_BUILD_REMOTE}" >&2
    exec ssh -o BatchMode=yes "${HEXA_BUILD_REMOTE}" \
        "bash -lc 'HEXA_BUILD_SKIP_TESTS=${HEXA_BUILD_SKIP_TESTS:-} \
                   HEXA_BUILD_FORCE=${HEXA_BUILD_FORCE:-} \
                   ~/bin/hexa_build_tick.sh'"
fi

# ── Local (ubu2) mode ────────────────────────────────────────────────
HEXA_SRC="${HEXA_SRC:-$HOME/Dev/hexa-lang}"
HEXA_BOOTSTRAP="${HEXA_BOOTSTRAP:-$HOME/.hx/bin/hexa_real}"
LOG_DIR="$HOME/.airgenome"
REPORT="$LOG_DIR/hexa_build.jsonl"
RUN_LOG="$LOG_DIR/hexa_build_tick.log"
mkdir -p "$LOG_DIR"

ts_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] %s\n' "$(ts_utc)" "$*" >> "$RUN_LOG"; }

report() {
    # $1=status $2=commit $3=tests_passed $4=tests_failed $5=binary_sha
    # $6=distributed_csv $7=toolchain_status $8=notes
    local status="$1" commit="$2" tp="$3" tf="$4" sha="$5"
    local dist="$6" tc="$7" notes="${8:-}"
    # convert CSV to JSON array
    local dist_json="[]"
    if [[ -n "$dist" ]]; then
        dist_json="[$(printf '%s' "$dist" | awk -F, '{for(i=1;i<=NF;i++){printf "\"%s\"%s", $i, (i<NF?",":"")}}')]"
    fi
    printf '{"ts":"%s","status":"%s","commit":"%s","tests_passed":%s,"tests_failed":%s,"binary_sha":"%s","distributed":%s,"toolchain_status":"%s","notes":"%s"}\n' \
        "$(ts_utc)" "$status" "$commit" "${tp:-0}" "${tf:-0}" "$sha" "$dist_json" "$tc" "$notes" >> "$REPORT"
}

die() {
    log "FATAL: $*"
    report "error" "" 0 0 "" "" "error" "$*"
    exit "${2:-1}"
}

log "=== tick start host=$(hostname) pid=$$ ==="

# ── 1. Toolchain preflight ──────────────────────────────────────────
toolchain_gap=""
for bin in clang git; do
    command -v "$bin" >/dev/null 2>&1 || toolchain_gap+="${bin} "
done
[[ -d "$HEXA_SRC" ]] || toolchain_gap+="src:${HEXA_SRC} "
[[ -x "$HEXA_BOOTSTRAP" ]] || {
    # fallback: local repo's hexa shim
    if [[ -x "$HEXA_SRC/hexa" ]]; then
        HEXA_BOOTSTRAP="$HEXA_SRC/hexa"
    else
        toolchain_gap+="hexa_bootstrap "
    fi
}

if [[ -n "$toolchain_gap" ]]; then
    log "toolchain gap: $toolchain_gap"
    report "toolchain_gap" "" 0 0 "" "" "gap:${toolchain_gap% }" \
        "need to install missing tools before build can run"
    exit 1
fi
log "toolchain ok (hexa=$HEXA_BOOTSTRAP)"

# ── 2. git pull (best-effort) ───────────────────────────────────────
cd "$HEXA_SRC" || die "cd $HEXA_SRC failed"
if ! git fetch --quiet origin 2>>"$RUN_LOG"; then
    log "WARN: git fetch failed; using local HEAD"
fi
# only fast-forward; no merge conflicts from timer
git reset --hard origin/main >>"$RUN_LOG" 2>&1 || {
    log "WARN: git reset origin/main failed; continuing with local state"
}
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
log "src commit=$COMMIT"

# ── 3. Build stage0 ─────────────────────────────────────────────────
# The build script writes into the repo itself (build/hexa_stage0.real).
# We keep a lockfile to prevent concurrent runs (interactive + timer).
LOCK_DIR="/tmp/hexa_build_tick.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    lpid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "?")
    if [[ "$lpid" != "?" ]] && kill -0 "$lpid" 2>/dev/null; then
        log "another tick running (pid=$lpid); skipping"
        report "skipped_lock" "$COMMIT" 0 0 "" "" "ok" "concurrent tick pid=$lpid"
        exit 0
    fi
    log "stale lock (pid=$lpid); reclaiming"
    rm -rf "$LOCK_DIR" && mkdir "$LOCK_DIR"
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT

BUILD_START=$(date +%s)
log "build start"
BUILD_STDERR=$(mktemp /tmp/hexa_build_err.XXXX)
if ! timeout 600 "$HEXA_BOOTSTRAP" run tool/build_stage0.hexa \
        >"$BUILD_STDERR" 2>&1; then
    log "BUILD FAILED"
    cat "$BUILD_STDERR" >> "$RUN_LOG"
    # Detect known upstream regression patterns
    tc_status="ok"
    notes="build script exit nonzero; see $RUN_LOG"
    if grep -q "SSOT missing: /tmp/self/hexa_full.hexa" "$BUILD_STDERR"; then
        tc_status="gap:upstream_build_stage0_argv_regression"
        notes="build_stage0.hexa computes hexa_dir=/tmp (argv[1]=AOT exe path); upstream fix needed"
    elif grep -qE "undefined function: scratch_stable" "$BUILD_STDERR"; then
        tc_status="gap:bootstrap_too_old"
        notes="bootstrap hexa_real missing scratch_stable; newer stdlib required"
    fi
    report "build_failed" "$COMMIT" 0 0 "" "" "$tc_status" "$notes"
    rm -f "$BUILD_STDERR"
    exit 2
fi
rm -f "$BUILD_STDERR"
BUILD_SEC=$(( $(date +%s) - BUILD_START ))
log "build ok in ${BUILD_SEC}s"

NEW_BIN="$HEXA_SRC/build/hexa_stage0.real"
[[ -x "$NEW_BIN" ]] || die "new binary missing: $NEW_BIN" 2
NEW_SHA=$(sha256sum "$NEW_BIN" | awk '{print $1}')
log "new sha=$NEW_SHA"

# ── 4. Smoke test (always) ──────────────────────────────────────────
SMOKE=$(mktemp /tmp/hexa_smoke.XXXX.hexa)
echo 'println("ok")' > "$SMOKE"
SMOKE_OUT=$(timeout 30 "$NEW_BIN" "$SMOKE" 2>&1 | tr -d '[:space:]' || true)
rm -f "$SMOKE"
if [[ "$SMOKE_OUT" != "ok" ]]; then
    log "smoke test failed (got: $SMOKE_OUT)"
    report "smoke_failed" "$COMMIT" 0 1 "$NEW_SHA" "" "ok" "smoke out: ${SMOKE_OUT:-<empty>}"
    exit 3
fi
log "smoke ok"

# ── 5. Test suite (best-effort) ─────────────────────────────────────
TESTS_PASSED=1  # smoke counts as 1
TESTS_FAILED=0
if [[ -z "${HEXA_BUILD_SKIP_TESTS:-}" ]] && [[ -f "$HEXA_SRC/tool/run_tests.hexa" ]]; then
    log "running tool/run_tests.hexa (time-limited)"
    TEST_LOG="$LOG_DIR/hexa_build_tests.log"
    # 8 minute cap; runner prints summary at end
    if timeout 480 "$HEXA_BOOTSTRAP" run tool/run_tests.hexa \
            > "$TEST_LOG" 2>&1; then
        # try to parse pass/fail counts; fall back to 1/0
        parsed_pass=$(grep -oE '[Pp]ass[a-z]*[[:space:]:=]+[0-9]+' "$TEST_LOG" | tail -1 | grep -oE '[0-9]+' || echo "")
        parsed_fail=$(grep -oE '[Ff]ail[a-z]*[[:space:]:=]+[0-9]+' "$TEST_LOG" | tail -1 | grep -oE '[0-9]+' || echo "")
        [[ -n "$parsed_pass" ]] && TESTS_PASSED="$parsed_pass"
        [[ -n "$parsed_fail" ]] && TESTS_FAILED="$parsed_fail"
        log "tests parsed: pass=$TESTS_PASSED fail=$TESTS_FAILED"
    else
        log "run_tests.hexa timed out or errored (exit $?); counting as failure"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
fi

if [[ "$TESTS_FAILED" -gt 0 ]]; then
    log "tests failed; aborting distribution"
    report "tests_failed" "$COMMIT" "$TESTS_PASSED" "$TESTS_FAILED" \
        "$NEW_SHA" "" "ok" "see $LOG_DIR/hexa_build_tests.log"
    exit 3
fi

# ── 6. sha compare vs last-distributed ──────────────────────────────
LAST_SHA_FILE="$LOG_DIR/hexa_build_last_sha"
LAST_SHA=$(cat "$LAST_SHA_FILE" 2>/dev/null || echo "")
if [[ "$NEW_SHA" == "$LAST_SHA" ]] && [[ -z "${HEXA_BUILD_FORCE:-}" ]]; then
    log "sha unchanged; skipping distribution"
    report "no_change" "$COMMIT" "$TESTS_PASSED" "$TESTS_FAILED" \
        "$NEW_SHA" "" "ok" "sha matches last-distributed"
    exit 0
fi

# ── 7. Distribute ────────────────────────────────────────────────────
# Targets: ubu2 (local), ubu1 (aiden), hetzner (root)
# Mac SKIPPED: arm64 vs x86_64 arch mismatch (Linux binary won't run).
distributed=()

# 7a. ubu2 local
LOCAL_TARGET="$HOME/.hx/bin/hexa_real"
if install -m 0755 "$NEW_BIN" "$LOCAL_TARGET" 2>>"$RUN_LOG"; then
    distributed+=("ubu2")
    log "deployed → ubu2:$LOCAL_TARGET"
else
    log "FAIL ubu2 deploy"
fi

# 7b. ubu1 (aiden user)
if scp -o BatchMode=yes -o ConnectTimeout=10 "$NEW_BIN" \
        ubu1:/tmp/hexa_real.new >>"$RUN_LOG" 2>&1 \
    && ssh -o BatchMode=yes ubu1 \
        "install -m 0755 /tmp/hexa_real.new /home/aiden/.hx/bin/hexa_real && rm -f /tmp/hexa_real.new" \
        >>"$RUN_LOG" 2>&1; then
    distributed+=("ubu1")
    log "deployed → ubu1:/home/aiden/.hx/bin/hexa_real"
else
    log "FAIL ubu1 deploy"
fi

# 7c. hetzner (root user)
if scp -o BatchMode=yes -o ConnectTimeout=15 "$NEW_BIN" \
        hetzner:/tmp/hexa_real.new >>"$RUN_LOG" 2>&1 \
    && ssh -o BatchMode=yes hetzner \
        "install -m 0755 /tmp/hexa_real.new /root/.hx/bin/hexa_real && rm -f /tmp/hexa_real.new" \
        >>"$RUN_LOG" 2>&1; then
    distributed+=("hetzner")
    log "deployed → hetzner:/root/.hx/bin/hexa_real"
else
    log "FAIL hetzner deploy"
fi

# Mac arch-skip is reported in notes but never counted as a failure.
dist_csv=$(IFS=,; echo "${distributed[*]}")
log "distributed to: ${dist_csv:-<none>}"

if [[ ${#distributed[@]} -eq 0 ]]; then
    report "distribute_failed" "$COMMIT" "$TESTS_PASSED" "$TESTS_FAILED" \
        "$NEW_SHA" "" "ok" "all 3 linux deploys failed"
    exit 4
fi

echo "$NEW_SHA" > "$LAST_SHA_FILE"

partial="ok"
[[ ${#distributed[@]} -lt 3 ]] && partial="partial"
report "$partial" "$COMMIT" "$TESTS_PASSED" "$TESTS_FAILED" \
    "$NEW_SHA" "$dist_csv" "ok" "mac skipped by design (arch mismatch)"

log "=== tick end status=$partial ==="
exit 0
