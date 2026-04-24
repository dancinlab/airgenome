# hexa_v2 Mach-O → ELF Linux Bypass (2026-04-25)

## Problem

`/Users/ghost/core/hexa-lang/self/native/hexa_v2` is committed as **Mach-O
arm64** (built on Mac). On Linux hosts this fails with:

```
bash: .../self/native/hexa_v2: cannot execute binary file: Exec format error
```

Impact: `tool/build_stage0.hexa` transpile step on Linux fails when the
dedup4 fallback path (`self/native/hexa_cc_dedup4.c`) isn't present — so
ubu2's `hexa-build.service` hourly timer can't produce new stage0 binaries,
stalling the whole distribute-to-peers flow.

Upstream canonical fix tracked in hexa-lang proposal `hxa-20260424-010`
(arch-neutral native binary strategy). This is the **local workaround**
until that lands.

## Solution (Option C — auto-heal per tick)

`bin/hexa_build_tick.sh` now calls `prepare_linux_hexa_v2()` at tick start
**and** right before `build_stage0` (post git-reset, in case repo sync
restored the Mach-O). The helper is idempotent: on each Linux host with a
`~/hexa-lang` source tree, it detects Mach-O and swaps in a symlink to
`build/hexa_v2_linux` (the fresh ELF binary).

When hexa-lang lands the canonical fix, the helper becomes a permanent
no-op (reports `noop:not-mach-o` or `already-symlinked`).

## Per-Host Status

| Host    | Path                          | Before         | Action                    | After              |
|---------|-------------------------------|----------------|---------------------------|--------------------|
| ubu1    | `/home/aiden/hexa-lang`       | no hexa_v2     | skipped (no source tree)  | n/a                |
| ubu2    | `/home/summer/Dev/hexa-lang`  | unreachable    | deferred to next tick     | auto-heal on boot  |
| hetzner | `/root/hexa-lang`             | Mach-O arm64   | `mv → .macho.bak`, symlink| ELF (via symlink)  |

Backup file on hetzner: `self/native/hexa_v2.macho.bak.20260425`.

## Verification

Hetzner smoke (2026-04-25):

```
$ ssh hetzner '~/hexa-lang/self/native/hexa_v2 /tmp/smoke.hexa /tmp/smoke.c'
OK: /tmp/smoke.c
exit=0
```

ubu2 smoke test deferred — host unreachable during this fix window. Tick
script auto-heals on next reachable run.

## Why Not Option A (env override)?

`build_stage0.hexa:74` hardcodes `hexa_v2 = hexa_dir + "/self/native/hexa_v2"`
— no `env()` hook for the mainline path. Only the **dedup4 fallback**
honors `HEXA_V2_DEDUP_BIN`. Patching that is upstream work (covered by
`hxa-20260424-010`).

## Why ubu1 Skipped

`hexa_build_tick.sh` distributes the built `hexa_real` binary to ubu1 via
`scp → /home/aiden/.hx/bin/hexa_real`. ubu1 does **not** have a hexa-lang
source checkout (only `self/native/` skeleton for hxblas/hxlmhead). It
never runs `build_stage0.hexa`, so no hexa_v2 is needed there.

## Removal Criteria

When `hxa-20260424-010` lands and `self/native/hexa_v2` becomes either:
- a platform-specific artifact per build (not committed), or
- an arch-neutral bytecode/source form,

then `prepare_linux_hexa_v2()` can be removed from `hexa_build_tick.sh`
and the `.macho.bak.*` backups cleaned up.
