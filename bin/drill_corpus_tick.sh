#!/usr/bin/env bash
# drill_corpus_tick.sh — hetzner idle-capacity drill corpus builder (2h cadence).
#
# Picks the next seed from config/drill_corpus_seeds.jsonl (round-robin via
# state/drill_corpus_cursor.json), runs `nexus drill` on hetzner (host-side),
# appends full stdout+stderr to /home/drill_corpus/drill_corpus.jsonl on
# hetzner, then rsyncs the tail back to forge/drill_corpus.jsonl.
#
# Safety:
#   - aborts if another `nexus drill` is running locally on Mac (user interactive)
#   - respects airgenome offload offline pre-check (uses existing wrapper)
#   - probe preset + max-rounds cap + server-side timeout — light load
#   - /home is 1.7T 2% used; / is tight, write path uses /home only
#   - stop/disable: unload com.airgenome.drill-corpus plist or rm cursor file
#
# Install: user decides when to `launchctl load` the plist.

set -u
LC_ALL=C.UTF-8 2>/dev/null || true

AG_ROOT="${AIRGENOME_ROOT:-/Users/ghost/core/airgenome}"
SEEDS_FILE="$AG_ROOT/config/drill_corpus_seeds.jsonl"
CURSOR_FILE="$AG_ROOT/state/drill_corpus_cursor.json"
FORGE_CORPUS="$AG_ROOT/forge/drill_corpus.jsonl"
LOG_DIR="${HOME}/.airgenome"
TICK_LOG="$LOG_DIR/drill_corpus_tick.log"

REMOTE_CORPUS_DIR="/home/drill_corpus"
REMOTE_CORPUS_FILE="$REMOTE_CORPUS_DIR/drill_corpus.jsonl"
REMOTE_TIMEOUT_SEC="${DRILL_CORPUS_TIMEOUT:-600}"
TAIL_LINES="${DRILL_CORPUS_TAIL:-200}"

AIRGENOME_BIN="$AG_ROOT/bin/airgenome"
SSH_HOST="hetzner"

mkdir -p "$LOG_DIR" "$(dirname "$CURSOR_FILE")" "$(dirname "$FORGE_CORPUS")"

log() {
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '[%s] %s\n' "$ts" "$*" >> "$TICK_LOG"
}

abort() {
    log "ABORT: $*"
    exit 1
}

# ---- preconditions ----------------------------------------------------------

[ -f "$SEEDS_FILE" ] || abort "seeds file missing: $SEEDS_FILE"
[ -x "$AIRGENOME_BIN" ] || abort "airgenome bin missing: $AIRGENOME_BIN"

# don't run during interactive drill: more than 1 nexus drill process locally
# means user has one open; corpus worker waits for next tick.
local_drill_count=$(pgrep -f 'nexus drill' 2>/dev/null | wc -l | tr -d ' ')
if [ "${local_drill_count:-0}" -gt 1 ]; then
    log "skip tick: local 'nexus drill' processes=$local_drill_count (>1) — interactive run suspected"
    exit 0
fi

# ---- cursor ----------------------------------------------------------------

SEEDS_COUNT=$(grep -c '^{' "$SEEDS_FILE" 2>/dev/null || echo 0)
[ "$SEEDS_COUNT" -gt 0 ] || abort "no seeds parsed from $SEEDS_FILE"

if [ -f "$CURSOR_FILE" ] && command -v jq >/dev/null 2>&1; then
    IDX=$(jq -r '.next // 0' "$CURSOR_FILE" 2>/dev/null)
    [ -z "$IDX" ] && IDX=0
else
    IDX=0
fi
# normalize
IDX=$((IDX % SEEDS_COUNT))

# sed is 1-indexed; pick line IDX+1
LINE_NO=$((IDX + 1))
SEED_JSON=$(sed -n "${LINE_NO}p" "$SEEDS_FILE")
[ -n "$SEED_JSON" ] || abort "failed to read seed at line $LINE_NO"

if command -v jq >/dev/null 2>&1; then
    SEED_ID=$(printf '%s' "$SEED_JSON" | jq -r '.id // "unknown"')
    SEED_TEXT=$(printf '%s' "$SEED_JSON" | jq -r '.seed')
    SEED_PROBLEM=$(printf '%s' "$SEED_JSON" | jq -r '.problem // empty')
    SEED_PRESET=$(printf '%s' "$SEED_JSON" | jq -r '.preset // "probe"')
    SEED_ROUNDS=$(printf '%s' "$SEED_JSON" | jq -r '.rounds // 3')
else
    abort "jq not available"
fi

[ -n "$SEED_TEXT" ] && [ "$SEED_TEXT" != "null" ] || abort "empty seed text at idx=$IDX"

TS_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "tick start idx=$IDX id=$SEED_ID preset=$SEED_PRESET rounds=$SEED_ROUNDS problem=${SEED_PROBLEM:-none}"

# ---- build remote command ---------------------------------------------------

# single-quote escape for remote shell wrapping
seed_escaped=$(printf '%s' "$SEED_TEXT" | sed "s/'/'\\\\''/g")

PROBLEM_FLAG=""
if [ -n "$SEED_PROBLEM" ] && [ "$SEED_PROBLEM" != "null" ]; then
    PROBLEM_FLAG="--problem $SEED_PROBLEM"
fi

# NB: /root is 87% full — write corpus to /home/drill_corpus (md2, 2% used)
# Use jq to build the corpus line with real JSON escaping, then append.
REMOTE_CMD=$(cat <<REMOTE_EOF
set -u
mkdir -p '$REMOTE_CORPUS_DIR'
TMP=\$(mktemp -t drill_corpus.XXXXXX)
trap "rm -f \$TMP" EXIT
START=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
T0=\$(date +%s)
timeout --kill-after=10 $REMOTE_TIMEOUT_SEC /root/.hx/bin/nexus drill \\
    --seed '$seed_escaped' \\
    --preset $SEED_PRESET \\
    --max-rounds $SEED_ROUNDS \\
    $PROBLEM_FLAG \\
    > \$TMP 2>&1
RC=\$?
T1=\$(date +%s)
ELAPSED=\$((T1 - T0))
# ensure jq exists; else bail
command -v jq >/dev/null 2>&1 || { cat \$TMP; exit 77; }
# emit single-line corpus entry
jq -cn --arg id '$SEED_ID' --arg seed_text '$SEED_TEXT' --arg problem '${SEED_PROBLEM:-}' \\
       --arg preset '$SEED_PRESET' --argjson rounds $SEED_ROUNDS \\
       --arg start "\$START" --argjson elapsed_s \$ELAPSED --argjson rc \$RC \\
       --rawfile output \$TMP \\
       '{ts:\$start, elapsed_s:\$elapsed_s, rc:\$rc, seed_id:\$id, seed:\$seed_text, problem:(\$problem // null | if . == "" then null else . end), preset:\$preset, rounds:\$rounds, host:"hetzner", output:\$output}' \\
       >> '$REMOTE_CORPUS_FILE'
tail -n 1 '$REMOTE_CORPUS_FILE'
REMOTE_EOF
)

# ---- dispatch ---------------------------------------------------------------

REMOTE_OUT=$(mktemp -t drill_corpus_remote.XXXXXX)
"$AIRGENOME_BIN" offload htz "$REMOTE_CMD" > "$REMOTE_OUT" 2>&1
RC=$?

if [ "$RC" -ne 0 ]; then
    log "remote exec rc=$RC — snippet: $(head -c 400 "$REMOTE_OUT" | tr '\n' ' ')"
    rm -f "$REMOTE_OUT"
    # still advance cursor so a stuck seed doesn't block rotation
    NEXT=$(( (IDX + 1) % SEEDS_COUNT ))
    printf '{"next":%d,"last_idx":%d,"last_ts":"%s","last_rc":%d}\n' "$NEXT" "$IDX" "$TS_UTC" "$RC" > "$CURSOR_FILE"
    exit 0
fi

# ---- pull tail back to forge -----------------------------------------------

# Append the just-emitted entry (tail -n 1 output from remote) to local forge file.
if [ -s "$REMOTE_OUT" ]; then
    cat "$REMOTE_OUT" >> "$FORGE_CORPUS"
    log "appended 1 line to $FORGE_CORPUS ($(wc -l < "$FORGE_CORPUS" | tr -d ' ') total)"
fi
rm -f "$REMOTE_OUT"

# ---- advance cursor ---------------------------------------------------------

NEXT=$(( (IDX + 1) % SEEDS_COUNT ))
printf '{"next":%d,"last_idx":%d,"last_id":"%s","last_ts":"%s","last_rc":%d}\n' \
    "$NEXT" "$IDX" "$SEED_ID" "$TS_UTC" "$RC" > "$CURSOR_FILE"
log "tick end idx=$IDX next=$NEXT id=$SEED_ID rc=$RC"
exit 0
