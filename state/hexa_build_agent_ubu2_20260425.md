# hexa-lang Build Agent — ubu2 (2026-04-25)

## Goal
Use ubu2's ~30 GB idle RAM as a continuous hexa-lang build/test/distribute
agent so the stale-binary class of issue (e.g. hetzner's Apr-16 binary from
the 2026-04-24/25 session) is auto-prevented. ubu2 already ran a working
Apr-19 `hexa_real` (`~/.hx/bin/hexa_real`, BuildID
`697cf4120c...453ce7`) — same BuildID as hetzner + ubu1, so ubu2 is the
natural builder for the Linux x86-64 fleet.

## Architecture

```
  +---------+        rsync/git pull       +------------------------+
  |   Mac   | <-- canonical source -----> | ubu2 /home/summer/Dev/ |
  | arm64   |   (git origin github)       |   hexa-lang (git clone)|
  +---------+                             +------------------------+
                                                    |
                                                    v
                                    +-------------------------------+
                                    | hexa_build_tick.sh (hourly)   |
                                    |   1. git fetch + reset        |
                                    |   2. toolchain preflight      |
                                    |   3. ./hexa run               |
                                    |        tool/build_stage0.hexa |
                                    |   4. smoke + test suite       |
                                    |   5. sha compare vs last      |
                                    |   6. scp+install to 3 linux   |
                                    |   7. append JSONL report      |
                                    +-------------------------------+
                                                    |
                       +------------+---------------+--------------+
                       v            v               v              v
                     ubu2        ubu1 (aiden)   hetzner (root)    Mac
                  (local cp)  scp+install      scp+install     SKIPPED
                                                            (arm64 ≠ x86_64)
```

## Files Installed

On **ubu2**:
- `~/bin/hexa_build_tick.sh` — the tick script (copy of Mac
  `airgenome/bin/hexa_build_tick.sh`)
- `~/.config/systemd/user/hexa-build.service` — oneshot service
- `~/.config/systemd/user/hexa-build.timer` — `OnCalendar=hourly`,
  `RandomizedDelaySec=300`
- `~/.airgenome/hexa_build.jsonl` — structured report log (append-only)
- `~/.airgenome/hexa_build_tick.log` — run log (append-only)
- `~/.airgenome/hexa_build_last_sha` — sha256 of last distributed binary
- `~/.ssh/config` — added `ubu1`, `hetzner` aliases (direct IP)

On **Mac** (this repo):
- `bin/hexa_build_tick.sh` — same script; runs locally OR re-execs on
  `$HEXA_BUILD_REMOTE` (e.g. `HEXA_BUILD_REMOTE=ubu2 bin/hexa_build_tick.sh`)
- `state/hexa_build_agent_ubu2_20260425.md` — this doc

## Build Command Discovered

```
cd /home/summer/Dev/hexa-lang
./hexa run tool/build_stage0.hexa
```

Produces: `build/hexa_stage0.real` (Linux x86-64 ELF on ubu2, Mach-O
arm64 on Mac). Bootstrap: `$HOME/.hx/bin/hexa_real` (falls back to the
in-repo `./hexa` shim).

External deps: `clang`, `git`. No cargo, no rust, no zig.

## Distribution Paths

| target  | user   | path                            | method         |
|---------|--------|---------------------------------|----------------|
| ubu2    | summer | `~/.hx/bin/hexa_real`           | `install -m755`|
| ubu1    | aiden  | `/home/aiden/.hx/bin/hexa_real` | scp → install  |
| hetzner | root   | `/root/.hx/bin/hexa_real`       | scp → install  |
| Mac     | ghost  | `/Users/ghost/.hx/bin/hexa_real`| **SKIPPED**    |

Mac is arm64 Mach-O; the Linux x86-64 binary ubu2 produces cannot run
there. Mac stays on its own arm64 build (Mac developer runs the build
locally when needed; not covered by this agent).

## Timer Cadence

- `OnCalendar=hourly` (fires on every top-of-hour)
- `RandomizedDelaySec=300` (jitter 0-5 min so the 4 boxes never build
  simultaneously when we add builders on other boxes)
- `Persistent=true` (catches up if ubu2 was asleep at fire time)
- Service `TimeoutStartSec=1800` (30 min hard cap per build)
- Service `MemoryMax=6G`, `Nice=15`, `IOSchedulingClass=idle` (bounded
  impact on ubu2 — still leaves ~24 GB free for other agents)

## Report JSONL Schema

```json
{
  "ts": "2026-04-25T02:45:00Z",
  "status": "ok|partial|no_change|build_failed|tests_failed|smoke_failed|distribute_failed|skipped_lock|toolchain_gap|error",
  "commit": "abcd1234",
  "tests_passed": 1,
  "tests_failed": 0,
  "binary_sha": "sha256…",
  "distributed": ["ubu2","ubu1","hetzner"],
  "toolchain_status": "ok|gap:<detail>",
  "notes": "…"
}
```

## Rollback

1. Disable timer: `systemctl --user disable --now hexa-build.timer`
2. Remove units: `rm ~/.config/systemd/user/hexa-build.{service,timer}`
3. Remove tick: `rm ~/bin/hexa_build_tick.sh`
4. State can stay (`~/.airgenome/hexa_build.jsonl` is pure history).
5. Deployed binaries (`*/.hx/bin/hexa_real`) stay in place — the agent
   never touches them on rollback; replace by manually rsyncing a known
   good binary if needed.

Selective disable: `systemctl --user stop hexa-build.timer` (pause,
leave enabled); `HEXA_BUILD_SKIP_TESTS=1` env to smoke-only; the
script honors a `/tmp/hexa_build_tick.lock` mkdir-lock so concurrent
invocations just skip.

## Current Status (2026-04-25 install smoke)

- Toolchain preflight: OK (clang + git + hexa_real found).
- Build: **FAIL** with `toolchain_status=gap:bootstrap_too_old`.
  `tool/build_stage0.hexa` calls `scratch_stable()` which the Apr-19
  bootstrap `hexa_real` doesn't know yet. Mac reproduces the same
  failure from clean (`error: SSOT missing: /tmp/self/hexa_full.hexa`) —
  the script also has an argv regression where `_av[1]` returns the AOT
  cache exe path, breaking `hexa_dir` computation.
- **This is an upstream regression, not an infra gap.** The
  infrastructure is in place and reporting cleanly; next tick at hourly
  + 5-min jitter. Once upstream fixes `build_stage0.hexa` (or we bump
  the bootstrap), the agent will start producing + distributing.

## Timer Next Trigger

From install (`systemctl --user list-timers hexa-build.timer`): first
fire within ~20 min after install (top-of-hour + 0-5 min jitter). Every
hour thereafter.

## Manual Trigger

- From ubu2: `systemctl --user start hexa-build.service` or
  `~/bin/hexa_build_tick.sh` directly.
- From Mac: `HEXA_BUILD_REMOTE=ubu2 bin/hexa_build_tick.sh` (SSHes into
  ubu2 and runs the same script).

## Known Gaps to Fix (Upstream hexa-lang)

1. `tool/build_stage0.hexa` argv[1] computation — returns AOT cache path
   instead of the script path, so `hexa_dir` ends up `/tmp`.
2. Bootstrap Apr-19 `hexa_real` missing `scratch_stable()` — need a
   newer bootstrap or a compatibility shim in `tool/tmp_scratch`.

Both of these show up as `toolchain_status=gap:…` in the JSONL report —
user can track fix landing by watching for the first
`status=ok` entry.
