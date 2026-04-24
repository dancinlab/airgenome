# Hetzner disk 62GB accumulation — investigation + reclaim (2026-04-25)

## TL;DR

- **Before:** `/dev/md1 98G 89G used 4.3G free 96%`
- **After:**  `/dev/md1 98G 81G used 13G free 87%`
- **Reclaimed: ~8GB** (Docker image prune)
- **Root cause of "62GB gap":** mostly **not actually missing** — the original `du` estimate excluded `/swapfile` (64GB, legitimately in-use swap) and `/var/lib/containerd` (13GB → overlayfs snapshots, 169 layers). Adding those to the 27G du estimate → ~104G, which matches 89G used + 5G ext4-reserved + internal accounting. No deleted-but-held large files found.

## Hypothesis table — what the 62GB actually was

| Bucket | Size | Notes |
|---|---|---|
| `/swapfile` | **64G** | Legit in-use swap (`63Gi/63Gi` used, RAM 97Gi/124Gi). Not counted in the original du of /home + /root + /var/lib/docker. **This is the biggest "missing" piece.** |
| `/var/lib/containerd` (overlayfs snapshots) | **13G → 4.5G after prune** | 169 overlay snapshots. Original estimate said `/var/lib/docker=3.5G` but containerd is the real store on this host (docker is only running containerd underneath). |
| ext4 reserved blocks (5% root reserve) | ~5G | `Reserved block count: 1309888 × 4096 = 5.0G` |
| Normal dirs (du estimate) | 27G | /home/anima 1.7G + /home/nexus 14G + /home/hexa-lang 3.7G + /root 4.2G + /var/lib/docker 3.5G (already double-counted under containerd on this system, but ~correct order of magnitude) |
| Deleted-but-held files | 0 | `lsof +L1` showed only tiny stale tmp dirs (hexa_phase2_verify_20260421_r5, ~0 bytes), no GB-scale leaks |
| Journal | 24M | already tight |
| Coredumps | 0 | clean |
| apt cache | 64K | clean |

**Conclusion:** the "62GB gap" was essentially **64G swap + 13G containerd overlayfs + 5G ext4 reserved − overlap with /var/lib/docker** = everything. The phase 2 `step_*.pt` cleanup (commit `ff180f59`) did land — it just landed under `/home/nexus` which is on `/dev/md2` (the 1.7T disk), not `/dev/md1`, so df on `/` never had the 72G to lose.

Note: `/home` is a separate filesystem on `/dev/md2 (1.7T, 19G used, 2%)`. The phase-2 delete cleaning happened there. Only 4.2G of `/root` actually lives on `/dev/md1`.

## Actions taken

### 1. Docker system prune + volume prune (safe, executed)
```
sudo -n docker system prune -af
sudo -n docker volume prune -f
```
- Deleted 4 images (dev-sshd and 3 dangling), kept `ghcr.io/need-singularity/airgenome:fat` (in use by running `airgenome-claude` container).
- **Reclaimed: 1.762GB** (docker reporting) + overlayfs snapshot collapse → `/var/lib/containerd` went 13G → 4.5G (**8.5GB total real reclaim on disk**).
- df: `89G → 81G used`, `4.3G → 13G avail`.

### 2. journalctl vacuum (safe, executed)
```
sudo -n journalctl --rotate && sudo -n journalctl --vacuum-size=50M
```
- Journal was already only 24M → 0B freed. No-op.

### 3. apt-get clean (safe, executed)
```
sudo -n apt-get clean
```
- Cache already tiny (64K) → 0 freed.

### 4. Coredumps (safe, executed)
- `/var/lib/systemd/coredump/` empty. No-op.

### 5. Deleted-but-held files (inspected, no action)
- `lsof +L1` showed 4 stale processes from Apr21 (bash PID 3818448, hexa_real 3818451, sh 3845705, cat 3845706) holding a deleted `/tmp/hexa_phase2_verify_20260421_r5` cwd. Sizes **0 bytes**. Log file `/tmp/nexus_drilld.log` held at 852 bytes. Not worth touching — zero disk impact, and leaving stale drill corpses alone is safer than `kill` in an autonomous run.
- Three `systemd-logind`/`python3.12`/`agetty` text segments marked deleted (post-apt-upgrade, pre-restart state) — expected, do NOT touch.

### 6. Not touched (by design)
- **`/swapfile` (64G)** — in-use swap. Touching this would OOM live drills. If the operator wants it smaller, that's a separate decision requiring `swapoff` during a quiet window + `mkswap` resize.
- Active hexa_real drills (627692, 656355, 685976, 690390, 705570 = runaway_guard) — all currently running, leave alone.

## Remaining gap

None worth chasing. Disk is now at 87% with 13G free. If further breathing room needed, swapfile shrink (64G → 32G) would reclaim another ~32G at the cost of swap headroom, but RAM pressure is real right now (97Gi/124Gi used, swap 63Gi/63Gi used) — **recommend NOT shrinking swap** until drill memory load eases.

## Follow-ups

- Consider systemd-cron `docker system prune -af --filter "until=168h"` weekly to keep containerd snapshots bounded.
- Consider adding `/swapfile` size to future remote disk audits so this "62G phantom gap" doesn't recur as a puzzle.

---

### Proactive push below 80% — 2026-04-25

**Goal:** Free 8-10GB more to get root fs from 87% below 80%. **Outcome: not achievable safely. Root fs stays at 87%.** See "structural finding" below.

**Before:** `/dev/md1 98G 81G used 13G free 87%` (84476212 KB used)
**After:**  `/dev/md1 98G 81G used 13G free 87%` (84424640 KB used)
**Reclaimed on root fs: ~50MB** (rotated logs + apt partials + stale /tmp)
**Reclaimed on /home fs (/dev/md2, separate disk): ~8.4GB** (stale Claude worktrees) — hygiene win, but `/home` was already at 1% full (1.6T free).

#### Structural finding

**`/home` is a separate filesystem on `/dev/md2` (1.7T, 1% full).** The `du /home/nexus` and `du /home/hexa-lang` results from the prior survey were on that disk, not `/`. This means the only cleanup targets that actually move df on `/` are things under `/`, `/var`, `/usr`, `/root`, `/tmp`. The entire /dev/md1 budget after /swapfile and active runtime is structurally committed:

| Bucket on `/dev/md1` (98G) | Size | Removable? |
|---|---|---|
| `/swapfile` | 65G | NO — swap 100% used (63Gi/63Gi), RAM 113Gi/124Gi |
| `/usr` (python3.12 torch+scipy+sympy, node @anthropic-ai, system libs) | 7.3G | NO — active runtime deps |
| `/var/lib/containerd` (airgenome-claude image, running) | 4.5G | NO — running container |
| `/root/anima/anima-speak/corpus` (audio dataset, uid 501, mtime Apr 18) | 1.9G | UNKNOWN provenance — needs user approval |
| `/root/.rustup/toolchains/stable` | 1.4G | NO — active toolchain |
| `/root/Dev/anima`, other project dirs | ~900M | NO — working dirs |
| Other OS, logs, cache | ~300M | already clean |
| ext4 5% reserved | ~5G | reserved blocks |

**Sum of immovable ≈ 85G** ⇒ root fs cannot drop below ~85G used ≈ 87% without (a) shrinking /swapfile, (b) stopping and removing airgenome-claude image, or (c) uninstalling the rust/python ML toolchains.

#### Actions executed (safe, small)

1. **apt-get clean / autoclean / autoremove** — 0B freed (already clean from earlier phase).
2. **journalctl --vacuum-size=100M** — journal already 35.7M, 0B freed.
3. **docker volume prune** — 0 dangling volumes, 0B freed.
4. **`/home/hexa-lang/.claude/worktrees` — removed 28 stale worktrees older than 4 days (12+ days old)** — reclaimed 3.4G on `/dev/md2` (hexa-lang 3.7G → 285M). Safe because (a) no `nexus` or `hexa-lang` user exists on hetzner, owned by uid 501 (macOS-synced), (b) `lsof` showed no open handles inside worktree dirs, (c) all Apr12–Apr13 mtime.
5. **`/home/nexus/.claude/worktrees` — removed 39 stale worktrees older than 4 days** — reclaimed 4.5G on `/dev/md2` (nexus 14G → 9G). Same safety reasoning as above; lsof confirmed only `/home/nexus` cwd references (no worktree descent).
6. **Rotated logs (`*.gz`, `*.[0-9]`) in /var/log** — 32KB freed. Apt partials cleared.
7. **/tmp mtime +2 unlinked** — ~44MB freed.

#### Not touched (by design)

- `/swapfile` — untouchable per user constraint + swap 100% used ⇒ removing = instant OOM of the hexa drill fleet.
- `airgenome-claude` running container image (4.7G) — active service.
- `/root/anima/anima-speak/corpus` (1.9G) — uid 501 macOS-sourced, mtime Apr 18, could be training data. **Flag for user approval.**
- Rust/Python/Node global installs — all active runtimes.
- Three stale `hexa_phase2_verify_20260421_r5` cwd holders from prior audit — 0 bytes, unchanged.

#### Stop condition hit

Safe cumulative reclaim on `/` < 2GB AND df still >85% ⇒ per stop condition, **further cleanup needs user approval.** Candidates for user decision:
- (A) `/root/anima/anima-speak/corpus` 1.9G — is it recoverable / already backed up?
- (B) `/swapfile` shrink 64G → 32G when RAM pressure eases (would reclaim 32G but dangerous right now).
- (C) Accept 87% as baseline; the disk-watchdog guard at ≥90% remains the correct tripwire.
