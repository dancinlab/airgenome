# Load balancing — Wave 11/12 (2026-04-25)

## Situation

User alarm: "ubu2 혼자 터질라그래 로드밸런싱 제대로 안되구요".

Evidence (gathered 2026-04-25 pre-fix):
- hetzner: 1min loadavg 1.06, 15min 8.22 (heavy past, calming), 105G avail
- ubu1: loadavg 0.11, 27G avail, idle
- ubu2: **SSH banner timeout** (unreachable — sshd likely OOM-killed by piled drills)

## Root cause

`/Users/ghost/core/nexus/scripts/bin/hexa_remote` (pre-fix line 214):

```bash
for cand in hetzner ubu2 ubu1 htz; do
```

Wave 4 fixes PREFERRED=hetzner for heavy-compute. Chain order placed **ubu2
second** — so when hetzner probe failed (busy / RAM<24576MB), fallback
landed on ubu2 rather than ubu1. Repeated drills piled on ubu2 → resource
exhaustion → sshd crash → unreachable state. ubu1 (no sshfs overhead, idle)
was only tried after ubu2.

No "load-aware" picking — even among probed-healthy hosts, selection was
"first in chain order" (Wave 10 era).

## Fix — 2 waves, 2 nexus commits

### Wave 11 (nexus `bf8b7e10`) — immediate safety

A. **Chain reorder** (1 LOC). `for cand in hetzner ubu1 ubu2 htz` —
   ubu1 promoted above ubu2 in fallback. Hetzner busy → ubu1 next (idle,
   no sshfs), ubu2 relegated to last unix candidate before htz alias.

B. **Blacklist-on-unreachable** (~25 LOC insert into `_probe_host`).
   - probe fail (SSH/DNS/RAM-low) → `/tmp/hexa_remote.blacklist.<host>` touch
   - next invocation: if mtime <300s (HEXA_REMOTE_BLACKLIST_TTL), skip probe
     (fast stderr notice, no SSH round-trip)
   - mtime >300s → delete file + retry (self-heal — host recovery reabsorbed)
   - macOS `stat -f %m` + Linux `stat -c %Y` both supported
   - `HEXA_REMOTE_HOST` env override unaffected (probe is chain-only)
   - Overrides: `HEXA_REMOTE_BLACKLIST_TTL=N`, `HEXA_REMOTE_NO_BLACKLIST=1`

### Wave 12 (nexus `01e38b2c`) — structural LB

C. **Probe-all + argmax(avail)** (~40 LOC).
   - `_probe_host` success writes `HEXA_REMOTE_LAST_AVAIL` global (reuses
     existing `awk '/^OK/ {print $2}'` parsing — zero added probe cost).
   - Chain selection block splits on `HEXA_REMOTE_LB`:
     - `first` → Wave 11 behavior (first-healthy short-circuit) for debug
     - `avail` (default) → probe entire chain + pick healthy host with
       largest avail MB. Tie-break: chain order (PREFERRED stability).
   - stderr log: `LB=avail pick=<host> (avail=NNNNMB) among: <list>`.
   - Synergy with Wave 11: failed hosts skip via blacklist on next invocation
     → amortized probe cost ≈ N_healthy (not N_chain).

## Verification — 3-drill isolated harness

Cleared `/tmp/hexa_remote.blacklist.*`, ran live probes (hetzner/ubu1
healthy, ubu2 banner timeout):

```
=== Drill 1 ===
  probe: ubu2 실패 (Connection to 192.168.50.60 port 22 timed out)
  PICK: hetzner (avail=108540MB) among: hetzner(avail=108540MB) ubu1(avail=26990MB) htz(avail=108533MB)
=== Drill 2 ===
  probe: ubu2 blacklisted 6s ago — skip
  PICK: htz (avail=108539MB) among: hetzner(avail=108533MB) ubu1(avail=26895MB) htz(avail=108539MB)
=== Drill 3 ===
  probe: ubu2 blacklisted 13s ago — skip
  PICK: htz (avail=108528MB) among: hetzner(avail=108522MB) ubu1(avail=26806MB) htz(avail=108528MB)
Blacklist after: /tmp/hexa_remote.blacklist.ubu2
```

Result:
- **Never ubu2** in 3 consecutive drills (blacklist cache honored 2x).
- hetzner/htz (same physical host, ssh alias) picked 3/3 — correct argmax.
- ubu1 healthy but de-prioritized (avail ≈27GB « avail ≈108GB).
- Expected log line `hexa_remote: <host> 에서 원격 실행 중` (inside real dispatch)
  would show 2 distinct names (hetzner, htz) across 3 invocations — both
  same machine but exercised as independent chain entries, matching brief.

## ubu2 recovery plan

ubu2 is SSH-unreachable (banner timeout = TCP connect OK but sshd handshake
never completes; typical OOM-killed sshd pattern). Cannot reboot remotely
(no sudo reachable — same banner wall).

**Required action (human):** physical power cycle of ubu2 host
(192.168.50.60). After reboot:
1. Blacklist file `/tmp/hexa_remote.blacklist.ubu2` remains on Mac but will
   expire within 300s — auto-reprobed + re-absorbed into chain.
2. No nexus-side action required; Wave 11+12 self-heals.
3. Recommend post-reboot verify: `ssh ubu2 'uptime; free -h'` from Mac —
   confirm load <1 and free RAM >24GB before next heavy drill.

## Compatibility

- Wave 1-10 preflight JSON schema unchanged (hosts_tried array format intact).
- `HEXA_REMOTE_HOST` explicit host env bypasses all LB/blacklist (unchanged).
- Wave 9 concurrency gate orthogonal (gate entry → LB pick → blacklist check).
- `HEXA_REMOTE_LB=first` restores Wave 10 selection if rollback needed.

## Files touched

- `/Users/ghost/core/nexus/scripts/bin/hexa_remote` (Wave 11 + Wave 12)
- `/Users/ghost/core/nexus/convergence/drill_stability.convergence`
  (Wave 11 + Wave 12 sections)
- `/Users/ghost/core/airgenome/state/atlas_convergence_witness.jsonl`
  (Wave 11/12 combined witness line)
- `/Users/ghost/core/airgenome/state/load_balancing_wave11_12_20260425.md`
  (this file)

## Commits

- nexus `bf8b7e10` fix(hexa_remote): Wave 11 chain reorder + blacklist
- nexus `01e38b2c` feat(hexa_remote): Wave 12 load-aware selection
- airgenome (pending): witness + this doc

## Remaining open

- ubu2 physical power cycle (human action).
- hetzner/htz ssh alias duplication: both probed as distinct chain entries
  (same physical box). Cosmetic only; not LB concern. Could dedupe later by
  resolving `ssh -G` hostname inside `pick_preferred_host`.
- avail_mb is a probe-time snapshot — long drills (>60s) may experience
  staleness. Out of scope (resonance-round single-host assumption).
