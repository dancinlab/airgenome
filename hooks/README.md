# airgenome self-hosted hook event bus

Manifest-driven, hexa-native event bus observing every Claude Code event. airgenome hooks are **not** wired into Claude Code's hook protocol — policy forbids per-project `.claude/settings.json`. Instead, a launchd-driven native binary tails session transcripts and dispatches compiled-in handlers.

## Design

- **SSOT:** `hooks/manifest.hook.json` — add an event = 1 line here + 1 handler file.
- **Single dispatcher:** `hooks/hook_entry.hexa` — no event names hard-coded.
- **Uniform handler interface:** stdin = event JSON, stdout = decision JSON.
- **Three patterns** (all supported):
  - `mode: "wildcard"` with key `"*"` → runs on EVERY event (audit).
  - `mode: "chain"` → multiple ordered phases with short-circuit on block.
  - `mode: "single"` → one phase (schema nicety; identical to 1-item chain).
- **Audit:** `.hook-audit` hash-chained TSV (SHA_CURR = sha256(SHA_PREV + line)).
  Verify with `hexa run hooks/hook_cli.hexa audit verify`.
- **Deterministic:** no LLM calls, no network; only regex / jq / string compares.

## Files

```
hooks/
  manifest.hook.json     — SSOT (all routing here)
  hook_main.hexa         — transcript-watcher entry (compiled → build/hook)
  hook_entry.hexa        — stdin-event dispatcher (for unit tests / dev)
  hook_cli.hexa          — admin CLI (audit verify | tail, manifest dump, events list)
  universal_audit.hexa   — "*" wildcard (runs on EVERY event)
  user_prompt.hexa       — UserPromptSubmit
  pre_tool.hexa          — PreToolUse
  post_tool.hexa         — PostToolUse
  stop_capture.hexa      — Stop (response capture via transcript tail)
  session_start.hexa     — SessionStart
  subagent_stop.hexa     — SubagentStop
  lib/
    event.hexa           — read_stdin + jq-based field extractors
    audit.hexa           — hash-chain append + verify
    manifest.hexa        — jq-based phase resolver (wildcard-first)
  test/
    run_tests.hexa       — 8 end-to-end cases + chain verification
    fixtures/*.json      — canonical payloads per event
```

## Install

Installed by `tool/airgenome_init.hexa`:

1. `hexa build hooks/hook_main.hexa -o build/hook` — compile the native watcher.
2. Write `~/Library/LaunchAgents/com.airgenome.hook-watch.plist` — runs `build/hook watch` every 5s (`StartInterval`).
3. `launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.airgenome.hook-watch.plist`.

The watcher tails `~/.claude/projects/<slug>/*.jsonl` from `.hook-cursor.json` offsets, appends dispatched events to `.hook-observe.jsonl`, and runs handlers in-process. **Observation-only** — never injects into Claude Code.

```
hexa run tool/airgenome_init.hexa      # idempotent; re-run anytime
launchctl list | grep com.airgenome.hook-watch   # verify loaded
tail -f .hook-observe.jsonl                       # verify triggering
```

Removal:
```
launchctl bootout gui/$UID com.airgenome.hook-watch
rm ~/Library/LaunchAgents/com.airgenome.hook-watch.plist
```

## Test

```
hexa run hooks/test/run_tests.hexa
```

Expected: 8 green + `audit_chain_verify PASS` + non-genesis row count ≥ 16 (wildcard + event-specific per case).

## Dry-run

`HOOK_DRY=1` environment variable makes the dispatcher audit each phase as `DRY` and skip handler execution — pass-through for safe wiring tests.

## Raw compliance

- raw#9 hexa-only: no `.sh` files in `hooks/`.
- raw#10 proof-carrying: `.hook-audit` exists + chain verifier ships.
- raw#11 ai-native-enforce: handlers are regex/jq only, no LLM.
- raw#13 ai-tool-ban: no per-project `.claude/settings.json`; trigger mechanism is airgenome's own launchd watcher.
- raw#28 gate-order: phases execute in manifest array order (deterministic).
