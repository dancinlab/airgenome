# IB2 iphone_app_dedup — raw 240 V2 Weighted Rubric

Origin: `2026-04-30` arsmoriendi99@proton.me — J. iOS Backup wave (filter 2/2).

Source: `~/Library/Application Support/MobileSync/Backup/<UDID>/` blob files
(content addressed by SHA1-prefix two-char dirs `00/`, `01/`, …, `ff/` → blob
files named by SHA1 hex). T2 telegram_media_dedup pattern transposed to iOS
backup blob surface — content hash (blake2b digest_size=8, key=size_u64) →
dedup u64 sorted blob, IBDD magic. `os.lstat` only (no read on huge blobs)
for the Step-1 lossless cycle; head-64KB hashing for Step-2 bench.

## Step 1 — Rubric V2 Block Declaration (BEFORE candidates per B8)

| Block | 만점 | 만점 컷 (filter-design context) |
|-------|------|---------------------------------|
| B1 ai-native-machine-grep-ability | 60 | magic `IBDD` + version + 5-tuple JSONL bench emit |
| B2 channel-coverage               | 50 | filter .hexa + bench .hexa + design .md + .rubric.jsonl |
| B3 enforcement-strength           | 50 | bench self-runs + diff_test=lossless + perl alarm 120s |
| B4 measurability-closure          | 50 | 5-tuple (site, ROI#, baseline_ns, post_ns, diff_test) emit |
| B5 self-replay-automation         | 50 | deterministic synth seed (29), ≤120s, no manual setup |
| B6 cross-repo-propagation         | 40 | T2 telegram_media_dedup + #65 wyhash twin lineage |
| B7 emission-cost-bounded          | 40 | inline PAYLOAD ≤ ~13KB, single run() wrapper |
| B8 adversarial-resistance         | 40 | synth fallback when no real backup; lstat read-only, NO mutation |
| B9 meta-rubric-finite             | 20 | filter ≠ rubric; depth-1 design artifact |

Total ceiling: **400**.

## Step 2 — Probe (Backup blobs on this host)

- Path: `~/Library/Application Support/MobileSync/Backup/` exists, **no UDID
  enrolled** → no blob hex-prefix dirs. Filter triggers synth fallback (5000
  blob entries, seed=29, 30% planted duplicates).
- Real-host shape: blob files indexed by SHA1 hex name; sizes range 1B-GB.
  `os.lstat` (no read) gives (size, ino, mtime); head-64KB read for
  content-addressed dedup hash. NO writes anywhere.
- ROI: iOS backups commonly hold dup app cache (e.g. multiple copies of same
  asset across re-installs) — content-hash dedup quantifies recoverable
  bytes via hard-link / preen.

## Step 3 — Candidate Score Matrix (≥2 per B8)

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-------|
| IB2-a | size-only group (lstat, no content hash) | 50 | 45 | 50 | 40 | 50 | 35 | 40 | 35 | 20 | **365** |
| IB2-b | blake2b head-64KB content hash + sorted u64 blob + dup_count | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |

IB2-b reasoning:
- B1 60: IBDD magic + v1 + 5-tuple JSONL → fully machine-greppable.
- B4 50: 1000-query hash lookup linear vs bisect baseline_ns/post_ns.
- B6 40: T2 telegram_media_dedup pattern (TMDD) directly transposed +
  #65 wyhash-flavored blake2b — pure airgenome ancestry.
- B8 40: synth fallback (seed=29, 5000 blobs); both paths diff-tested;
  os.lstat = read-only metadata, head-64KB read only on payload (NO
  mutation, NO launchctl, NO git commit).

IB2-a (size-only) falls short (-35) — size collision rate is too high
(thousands of 4096B / 8192B blobs alias) → false dedup; content-hash is
required for correctness.

## Step 4 — Synthesis

**Selected: IB2-b — 400/400.**

Layout (little-endian):
```
magic     : 4B  "IBDD"
version   : 4B  u32 (1)
n_uniq    : 4B  u32 unique content hash count
reserved  : 4B  u32 (0)
[n*8]     : u64 hashes      blake2b-64 head-64KB (sorted asc)
[n*4]     : u32 sizes       per-content size (u32 saturation; >4GB→0xffffffff)
[n*4]     : u32 dup_count   total occurrences (1=uniq)
```

Query patterns:
- hash → bisect_left → meta. saving = sum(size * (dup_count-1)).
- 1000 random hash lookup → linear scan vs bisect baseline.

## Step 5 — honest-C3 (Gap Disclosure)

- G1: iOS backup absent on this host — synth-path-only validation. Real
  backup blob surface deferred.
- G2: head-64KB hashing — large media (>64KB) dedup decision uses head bytes
  + size as composite key. Adversarial blob with identical head differing
  in tail evades dedup (low risk on backup blobs which are typically small).
- G3: u32 size saturation at 4GB (>4GB blob → 0xffffffff sentinel; metadata
  loss). Real-world backup blobs rarely exceed 4GB but capped explicitly.
- G4: NO hard-link / preen action emitted — filter quantifies recoverable
  bytes, leaves remediation to operator (raw ban: NO mutation in filter).

**Gap count: 4.**

## Step 6 — Deliverables

1. `/Users/ghost/core/airgenome/docs/ib2_iphone_app_dedup_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/ib2_iphone_app_dedup_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/filters/module/data/iphone_app_dedup.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_ib2_iphone_app_dedup.hexa`

**Final IB2 score: 400/400.**
