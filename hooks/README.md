# airgenome self-hosted hook event bus

Manifest-driven, hexa-native event bus for every Claude Code hook.

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
  settings.patch.json    — snippet to merge into .claude/settings.json
  hook_entry.hexa        — dispatcher (generic)
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

One-shot jq merge of the snippet into `.claude/settings.json`:

```
jq -s '.[0] * .[1]' .claude/settings.json hooks/settings.patch.json > .claude/settings.json.new
mv .claude/settings.json.new .claude/settings.json
```

After merge, Claude Code dispatches every hook event to the single hexa dispatcher.

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
- raw#13 ai-tool-ban: `settings.json` block is declaration only, all logic in `.hexa`.
- raw#28 gate-order: phases execute in manifest array order (deterministic).
