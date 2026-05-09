#!/usr/bin/env bash
# overload_check.sh — load>50 또는 단일 PID CPU>50% × 5min 감지 시 알림.
# 절대 kill X. 14+ active claude 세션 보호.
# launchd StartInterval 60s 호출.
#
# 알림 경로: ~/.airgenome/notify_queue.jsonl 에 JSONL append.
# Airgenome.app (com.airgenome.tap) 이 10s 주기로 drain → NSUserNotification.
# osascript 미사용.
#
# State: ~/.airgenome/overload_check_state.txt (sliding window, pid|first_seen|notified).
# Log:   ~/.airgenome/overload_check.log
#
# Dry run: RUN_DRY=1 scripts/overload_check.sh

set -u

AIRG_DIR="${AIRGENOME_STATE_DIR:-$HOME/.airgenome}"
mkdir -p "$AIRG_DIR"

LOG="$AIRG_DIR/overload_check.log"
STATE="$AIRG_DIR/overload_check_state.txt"
QUEUE="$AIRG_DIR/notify_queue.jsonl"
NOW=$(date +%s)
TS=$(date '+%Y-%m-%dT%H:%M:%S%z')

log() { echo "$TS $*" >> "$LOG"; }

# JSON string escape — backslash 와 double-quote 만. control char 미발생 가정.
_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

notify() {
    local title="$1" subtitle="${2:-}" info="${3:-}"
    local t s i
    t=$(_json_escape "$title")
    s=$(_json_escape "$subtitle")
    i=$(_json_escape "$info")
    printf '{"title":"%s","subtitle":"%s","info":"%s"}\n' "$t" "$s" "$i" >> "$QUEUE"
}

# --- load avg (1min) ---
LOADAVG_RAW=$(/usr/sbin/sysctl -n vm.loadavg 2>/dev/null || echo "{ 0.00 0.00 0.00 }")
# format: { 1.23 4.56 7.89 }
LOAD1=$(echo "$LOADAVG_RAW" | awk '{print $2}')
LOAD1_INT=$(printf '%.0f' "$LOAD1" 2>/dev/null || echo 0)

# --- dry run: force notification, no state mutate ---
if [[ "${RUN_DRY:-0}" == "1" ]]; then
    notify "macOS load watcher (dry run)" "" "load1=$LOAD1 — test fire"
    log "DRY_RUN load1=$LOAD1 notification queued"
    exit 0
fi

log "tick load1=$LOAD1"

# --- load>50 alert ---
if [[ "$LOAD1_INT" -gt 50 ]]; then
    notify "macOS overload" "" "load1=$LOAD1 (>50)"
    log "ALERT load1=$LOAD1 notification queued"
fi

# --- runaway PID detection (sliding 5min) ---
# ps -Ao pid=,%cpu=,comm= → top consumers > 50% CPU.
RUNAWAY=$(/bin/ps -Ao pid=,%cpu=,comm= | /usr/bin/awk '$2 > 50.0 {print $1"|"$2"|"$3}' | /usr/bin/head -5)

# Load existing state (lines: pid|first_seen|notified)
declare -A FIRST_SEEN
declare -A NOTIFIED
if [[ -f "$STATE" ]]; then
    while IFS='|' read -r pid first notified; do
        [[ -z "$pid" ]] && continue
        FIRST_SEEN["$pid"]="$first"
        NOTIFIED["$pid"]="$notified"
    done < "$STATE"
fi

# Track currently-runaway PIDs
declare -A SEEN_NOW
if [[ -n "$RUNAWAY" ]]; then
    while IFS='|' read -r pid cpu comm; do
        [[ -z "$pid" ]] && continue
        SEEN_NOW["$pid"]=1
        first="${FIRST_SEEN[$pid]:-$NOW}"
        notified="${NOTIFIED[$pid]:-0}"
        age=$((NOW - first))
        FIRST_SEEN["$pid"]="$first"
        NOTIFIED["$pid"]="$notified"
        if (( age >= 300 )) && [[ "$notified" == "0" ]]; then
            notify "macOS runaway PID" "" "PID $pid ($comm) cpu=$cpu% for ${age}s"
            log "ALERT runaway pid=$pid cpu=$cpu comm=$comm age=${age}s"
            NOTIFIED["$pid"]=1
        fi
    done <<< "$RUNAWAY"
fi

# Persist sliding window (drop PIDs not seen this tick — they recovered or died)
: > "$STATE"
for pid in "${!FIRST_SEEN[@]}"; do
    if [[ -n "${SEEN_NOW[$pid]:-}" ]]; then
        echo "$pid|${FIRST_SEEN[$pid]}|${NOTIFIED[$pid]}" >> "$STATE"
    fi
done

exit 0
