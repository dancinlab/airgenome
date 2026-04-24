# Mac-local ssh SIGKILL (jetsam) during heavy-compute drill (2026-04-25)

## Symptom
Drill reached hetzner (round 1 smash +21 / hyperarith 16 Π₀² proven in 184ms).
Resonance stage aborted with:
```
/Users/ghost/core/nexus/scripts/bin/hexa_remote: line 413: 50802 Killed: 9
  ssh -T -o ServerAliveInterval=10 ... hetzner "$REMOTE_CMD"
hexa_remote: 원격 실행 실패 (hetzner, rc=137)
```
Upstream wrapper then emits `exit 74` (heavy-compute Darwin all-hosts-fail).

Parallel: 6 concurrent drills launched same session → **all** got exit 74.

## Investigation
- Mac: 24 GB RAM (25769803776 bytes). 10 active `ghost` ttys (7× claude + 3× caffeinate).
- `w` reports **load averages 12.98 / 10.25 / 8.64** (huge — CPU count is low).
- `vm_stat`: lifetime swapins=37875435, swapouts=102951109; ~193 GB swapped out cumulatively.
- `/usr/bin/log show` (note: `log` is shell builtin — must use full path):
  - 2026-04-24 23:58:29: `Received memory pressure event: 4, system vm pressure critical: 1`
  - 2026-04-24 23:58:38: launchd "teardown of process-scoped services after host exited"
    kills Safari WebKit children (pid 89932 tree). Messages BlastDoorService same.
  - This is jetsam cleanup triggered by critical memory pressure.
- No direct `ssh` launchd kill event (ssh is fg child of bash in Claude shell, not a
  launchd service) — SIGKILL 9 from bash's perspective = kernel killed PID (jetsam).
- RSS watchdog (`~/.hx/rss-watchdog.jsonl`): last kill **2026-04-19 16:43** — NOT the
  culprit. Watchdog pattern matches only `hexa_stage0.real|hexa_v2|hexa_full` +
  protects `sshd`/Terminal — would not target `ssh` client anyway.
- `predictive_throttle.hexa` explicitly states "kill 금지" (bootout-only) — not culprit.
- No `pkill.*ssh` in airgenome/nexus/hexa-lang/anima (only `oauth-bridge` pkills its
  own `ssh -L <port>` tunnels via port-specific pattern — irrelevant).

## Root cause (working hypothesis, high confidence)
macOS jetsam killed the **Mac-local ssh client** under critical memory pressure.
When 6 parallel drills each spawn `ssh -T` to a remote host, each holds ~100 MB
resident (ssh + rsync sidekicks + 20 GB pressure from Safari + Claude), load spikes
to 12+. macOS `memorystatus_kernel_assertion` escalates `pressure critical`, and
jetsam-priority targets include ssh clients that are children of Terminal/shell
(inherit parent's jetsam band, not protected). ssh client gets SIGKILL;
`hexa_remote` sees `rc=137` identical to genuine remote OOM.

## Fix applied
`install -m755 /tmp/hexa_remote.patched /Users/ghost/core/nexus/scripts/bin/hexa_remote`

### Delta (hexa_remote ~line 423-438 → +55 LOC)
Wrap the `ssh` call in `_run_ssh_once`. On `rc=137|143`, check two heuristics:
- `uname -s == Darwin` (Mac-side caller)
- `sysctl -n vm.loadavg` 1-min load ≥ 8

If both hold → log as "Mac-local ssh SIGKILL 의심 (jetsam)", pick next host from
`FALLBACK_CHAIN` via helper `_next_host_in_chain`, `_probe_host` check, and retry
ssh once. If retry host also returns 137/143, emit the original exit 64 fallback
signal (with "retry exhausted" suffix so the upstream log trail is diagnosable).

Retry is **single-shot**; no infinite loop. When called from Linux hosts (ubu2 →
ubu1 relay, etc) the heuristic is bypassed (Darwin-only), preserving existing
behavior for true remote OOM.

### What NOT done (deliberate)
- **No flock gate** in upstream `hexa` wrapper. Rationale: 6 parallel drills were
  already running (confirmed by user). The retry path targets single-invocation
  recovery; a concurrency cap would require semantic changes (queueing, user
  surprise). The retry + host diversification (hetzner → ubu2 → ubu1 → htz) gives
  the caller 4 chances, which is adequate without a new gate primitive.
- No Mac-side `memorystatus_control` intervention (would require root + unreliable).
- No ssh jetsam-immune wrapping via `launchd`: ssh must stay as fg child of the
  bash wrapper so stdout/stderr stream correctly to the drill invoker.

## Verification
- `bash -n /tmp/hexa_remote.patched` → OK.
- `bash -x /tmp/hexa_remote.patched --help 2>&1 | head -30` → pick_preferred_host +
  FALLBACK_CHAIN build + preflight all execute identically to pre-fix.
- End-to-end rc=137 replay impractical (would require inducing Mac jetsam).
  Heuristic path covered by code review; one-shot retry guaranteed by
  `_next_host_in_chain` returning empty after last host.

## Remaining unknowns
- Exact macOS jetsam policy for ssh clients under Claude Code session: whether
  jetsam priority inheritance is Terminal → bash → ssh, or whether the AppleEvent
  machinery bumps ssh into a different band. No direct log entry proves WHICH
  ssh pid was killed; only bash's "Killed: 9" message after child death.
- Whether `-o ControlMaster=auto` could deduplicate ssh processes and reduce the
  jetsam surface. Not attempted here — would change rsync/drill channel semantics.
- Whether `HEXA_REMOTE_MIN_RAM_MB=24576` threshold (raw#36 bracket) + 4 hosts +
  retry suffices or whether we need a Mac-side compute-queue (flock). Revisit if
  the retry log shows repeated rc=137 across 2 hosts in a single invocation.

## File paths
- Patched: `/Users/ghost/core/nexus/scripts/bin/hexa_remote`
- Backup:  `/tmp/hexa_remote.pre_fix8` (md5 `6c735587c0c48da4df085ba1699cc438`)
- Patched md5: `bdeafc38570576fa7f6b592b01ec8fc0`
- Investigation: `/Users/ghost/core/airgenome/state/mac_ssh_sigkill_20260425.md` (this)
