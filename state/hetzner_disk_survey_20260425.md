# Hetzner disk survey — 2026-04-25

**Status:** `/dev/md1` 98G used 90G / free 2.9G (97%). Need to reclaim ~20G+ for comfort.

## 1. `/home/anima` — 74G (primary offender)

Breakdown:
- `checkpoints/decoder_cpu/` = **73G** (99% of anima)
  - 179 × `step_*.pt` (~417 MB each) from `step_500` → `step_89500` (every 500 steps)
  - `best.pt` (436 MB), `final.pt` (436 MB), `metrics.json` (2 MB)
  - mtime range: 2026-04-09 → 2026-04-14 (latest `final.pt` Apr 14 22:24)
  - **Run is complete** — `final.pt` exists, no active python/train process (checked `ps aux`)
- `data/` = 596M, `anima/` 17M, `models/` 15M, rest < 10M each

**Finding:** training finished Apr 14. 179 intermediate step checkpoints are residual; only `best.pt` + `final.pt` (+ metrics) need retention.

## 2. `/home/nexus` — 14G

- `shared/` = **4.2G** dominated by 51 × `discovery_archive_*.jsonl` totalling 3.4G (dated 2026-04-09 → 2026-04-10; most are uncompressed)
- `shared/discovery/` = 411M, `shared/n6/` = 175M
- `tecs-l/` 419M, `discovery/` 400M, `tools/` 101M, `archive/` 101M
- Rest < 70M each

**Finding:** 15-day-old discovery archives; sibling file `discovery_log.2026-04-12.jsonl.gz` shows gzip is standard for this data — uncompressed archives likely un-compacted.

## 3. `/tmp/ckpt_*` + `/tmp/anima_htz`

- `/tmp/ckpt_clm170m_r5a6/step_0.tmp` = 551M, mtime Apr 19 — `lsof` empty, no process holds it
- `/tmp/anima_htz` = 184M, mtime Apr 18 — stale worktree from a Claude-driven session (uid 501 = Mac)
- Also on disk: `/tmp/ckpt_r6_tiny` (Apr 22), `/tmp/ckpt_clm_r5_smoke_*`, `/tmp/ckpt_r6_htz_smoke`, `/tmp/ckpt_clm170m_smoke` — all stale smoke-test scratch
- **Finding:** all residual, no holders.

## 4. `/var/log/journal` — 270M

`journald.conf` is all defaults (commented `#SystemMaxUse=` etc.); no drop-in under `/etc/systemd/journald.conf.d/`. Not pathological now, but unbounded growth is possible. Recommend cap at 200M.

## 5. `/home/hexa-lang` — 3.7G

- `shared/` 100M, `build/` 57M, `self/` 41M, `.git` 83M
- `build/` contains 14 stage0 backup binaries (`hexa_stage0_backup_pre_rt32h`, `_pre_phase1_backup`, `_pre_rt32l`, `_pre_t30_revert`, `_variant_a/b`, `_with_multiline_bug`, etc.) — most ~1.1M each, totaling ~15M; plus `build/artifacts/` 23M
- `.git` 83M is modest; `git gc --aggressive` might shave ~30M but low ROI

**Finding:** hexa-lang is small potatoes relative to anima. Skip unless we need last-mile gains.

---

# Prioritized cleanup plan

| # | Path | Reclaim | Risk | Action |
|---|------|---------|------|--------|
| 1 | `/home/anima/checkpoints/decoder_cpu/step_*.pt` (keep `best.pt` + `final.pt`) | **~72G** | safe (run finished, no process, `final.pt` exists) | `sudo find /home/anima/checkpoints/decoder_cpu -maxdepth 1 -name 'step_*.pt' -delete` |
| 2 | `/home/nexus/shared/discovery_archive_*.jsonl` (gzip in-place) | ~2.6G saved (of 3.4G) | needs-owner-approval (nexus data — confirm retention policy before compressing) | `sudo gzip /home/nexus/shared/discovery_archive_*.jsonl` — or delete if redundant with `discovery_log.*.jsonl.gz` |
| 3 | `/tmp/ckpt_clm170m_r5a6` + `/tmp/ckpt_clm170m_smoke` + `/tmp/ckpt_clm_r5_smoke_*` + `/tmp/ckpt_r6_tiny` + `/tmp/ckpt_r6_htz_smoke` | ~800M+ | safe (no lsof, no procs) | `sudo rm -rf /tmp/ckpt_clm170m_r5a6 /tmp/ckpt_clm170m_smoke /tmp/ckpt_clm_r5_smoke_* /tmp/ckpt_r6_tiny /tmp/ckpt_r6_htz_smoke` |
| 4 | `/tmp/anima_htz` | 184M | needs-owner-approval (Mac-owned, uid 501 — user's stale worktree; confirm before deleting) | `rm -rf /tmp/anima_htz` (from Mac via ssh) |
| 5 | `/var/log/journal` cap at 200M | ~70M one-shot + future-proof | safe | `sudo journalctl --vacuum-size=200M` then add drop-in `/etc/systemd/journald.conf.d/size.conf` with `[Journal]\nSystemMaxUse=200M` |
| 6 | `/var/log/btmp` (72M binary failed-login log) | 72M | safe | `sudo truncate -s 0 /var/log/btmp` |
| 7 | `/home/hexa-lang/build/hexa_stage0_{backup_*,pre_*,variant_*,with_multiline_bug,shim_bak,prev}` | ~15M | needs-owner-approval (stage0 bootstrap artifacts; confirm none are live refs) | manual `ls /home/hexa-lang/build/` + selective `rm` |

## TL;DR recommended first pass

Running #1 + #3 + #5 + #6 reclaims **~73G** and is all safe (verified: no open handles, no running training, `final.pt` present). Brings root from 90G→17G used, ~85% free.

#2 (nexus archives) reclaims another ~2.6G but requires owner (nexus) to confirm archives are downstream-ingested. #4/#7 are minor; defer.
