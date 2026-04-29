# airgenome.app Launcher Extension Design

Status: planning (raw 49 additive-first step 3, hive raw 209 reference impl scaffold)
Created: 2026-04-29 (UTC)
Target LIVE: 2026-05-30 (raw 209 proof-obligation closure)

## Purpose

Extend airgenome.app with a fuzzy app-name launcher: global hotkey (default `ctrl+s`) opens a popup search overlay; user types app name fragment; airgenome launches the matching app via NSWorkspace.

## Inherited foundational mandates (hive raw 209 composition)

Five hive raws form the foundation; this design composes them.

### raw 177 (cli-single-tcc-entry-per-project)

The launcher MUST reuse airgenome.app's existing single TCC grant entry (Accessibility / Input Monitoring). No new bundle, no new Privacy & Security row. Single CGEventTap callback dispatches by event type; per-feature env flags select active subsystems (mouse_remap / window_magnet / launcher).

### raw 178 (cli-stable-designated-requirement)

The launcher MUST inherit airgenome.app's existing stable Designated Requirement (cert-root-based, NOT cdhash). No re-grant per rebuild. setup_signing_cert.sh + Makefile codesign step already provision the per-user self-signed cert with a build-invariant DR.

### raw 179 (cli-multi-user-safe-runtime-path)

Installed launcher artifacts MUST resolve correctly on any user's Mac. No `/Users/<specific>/` literals baked into the bundle, plist, or config. Runtime paths use `/Applications/airgenome.app/...` (system-wide) and `~/Library/Application Support/airgenome/...` (per-user, expanded by NSHomeDirectory at startup).

### raw 180 (cli-system-state-capture-restore)

If the launcher mutates system state (e.g., registers a global hotkey via accessibility hook that sets a system default), it MUST capture the original tristate at startup and restore on exit. Signal handlers (SIGTERM / SIGINT / SIGHUP) call the restore routine; SIGKILL falls back to manual `airgenome launcher restore` subcommand.

### raw 181 (cli-uninstall-state-cleanup)

The launcher's install steps (config files at `~/Library/Application Support/airgenome/`, snippet store, hotkey map) MUST be paired with idempotent uninstall removal in airgenome's Makefile. Running `make uninstall` twice succeeds both times. System-state restoration delegates to raw 180's restore subcommand.

## Implementation channels (raw 209 realization-channels)

1. **CGEventTap global hotkey** + **NSPanel popup overlay** for the search UI.
2. **NSWorkspace** to enumerate installed apps (`NSWorkspace.shared.urlsForApplications(...)`) and launch the chosen one.
3. **dispatch_source_t SIGNAL handler** for graceful shutdown with state restore.
4. **Per-launcher config JSONL SSOT** at `~/Library/Application Support/airgenome/launcher.jsonl` (snippets, hotkey overrides, search history).

## Out of scope (raw 49 additive sister axes)

- `@`-prefix snippet expander (text template emit) — separate axis (future hive raw N)
- user-defined hotkey-action binder (custom shortcut → app/action) — separate axis (future hive raw M)

These two axes are deferred per raw 49 additive-first; the launcher composite mandate (raw 209) covers the app-name-fuzzy-search axis only.

## Verification (hive raw 117 5-check + raw 192 paired lint)

- `tool/cli_app_name_fuzzy_launcher_lint.hexa --selftest` PASS fixtures=3/3 (hive paired lint)
- airgenome.app reference impl LIVE on developer Mac with all 5 inherited mandates verified
- second-machine portability test (raw 179 cross-machine validation follow-up)

## Falsifiers (hive raw 209 F-RAW209-1..4)

- F-1: launcher impls < 50% citing >=3 inherited mandates over 30d
- F-2: production launcher missing >=3 cites without raw 91 C3 disclosure
- F-3: 3+ legitimate launcher impls cannot satisfy any single inherited mandate
- F-4: airgenome.app extension fails any of 5 mandates at LIVE deployment

## Cross-references

- hive raw 209 entry: `/Users/ghost/core/hive/.raw` (line ~9176-onwards)
- hive raw 177-181 entries: `/Users/ghost/core/hive/.raw` (search "raw 177" through "raw 181")
- hive paired lint: `/Users/ghost/core/hive/tool/cli_app_name_fuzzy_launcher_lint.hexa`
- hive audit ledger: `/Users/ghost/core/hive/state/cli_app_name_fuzzy_launcher_audit/audit.jsonl`
