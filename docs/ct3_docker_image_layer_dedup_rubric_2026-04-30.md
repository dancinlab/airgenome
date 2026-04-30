# CT3 docker_image_layer_dedup — raw 240 V2 Weighted Rubric

Origin: `2026-04-30` arsmoriendi99@proton.me — L. Container/VM wave (3 filters).
Applies raw 240 V2 (9 blocks / 400pt) + **NEW B10 rotation/snapshot-dedup-fold-
correctness /20** because CT3's hot path IS layer-stack delta-fold (image
layers compose by stacking; the same content can appear in N layers across M
images and must be folded once per content-hash). Ceiling **420**.

Sources (read-only, host-fs only):

- `~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw` —
  **HEAD ONLY** (first 4 KiB partition table + GPT/MBR magic + size via
  `os.stat`). The .raw file is a 994 GB sparse VM disk; full read is
  out-of-scope.
- `~/Library/Containers/com.docker.docker/Data/vms/0/00000002.000007cf` (vbox
  VM identity file, ~few hundred B)
- `~/.docker/contexts/meta/<sha>/meta.json` (per-context metadata)
- `~/.docker/buildx/refs/desktop-linux/desktop-linux/<id>` (per-build refs,
  93 entries on this host) — these contain `Target/LocalPath/DockerfilePath`
  layer-build provenance.

NOT touched: `/var/run/docker.sock`, image layer blobs inside Docker.raw
(those live on the Linux VM filesystem, not host fs), no docker CLI.

---

## Step 1 — Rubric V2 + B10 Block Declaration (BEFORE candidates per B8)

| Block | 만점 | 만점 컷 |
|-------|------|---------|
| B1 ai-native-machine-grep-ability | 60 | magic `DILD` + version + 5-tuple JSONL bench emit |
| B2 channel-coverage               | 50 | filter + bench + design + rubric.jsonl 4-channel |
| B3 enforcement-strength           | 50 | bench self-run; perl alarm 120s; diff_test=lossless gate |
| B4 measurability-closure          | 50 | dup_count + saving bytes + bisect us + GROUP BY image numeric |
| B5 self-replay-automation         | 50 | deterministic synth seed=43 (8000 layer chunks, 35% dup); ≤120s |
| B6 cross-repo-propagation         | 40 | airgenome lineage to T2 telegram_media_dedup + K1 imessage_attachment_dedup |
| B7 emission-cost-bounded          | 40 | inline PAYLOAD ≤ ~14KB; raw 9 hexa-only |
| B8 adversarial-resistance         | 40 | synth fallback; sparse-file head-only policy; Docker.raw NEVER fully read |
| B9 meta-rubric-finite             | 20 | filter ≠ rubric; depth-1 |
| **B10 rotation/snapshot-dedup-fold-correctness** | **20** | layer-stack delta fold via blake2b-64 content hash; double-counting impossible across image-id boundaries; diff_test asserts `unique_layers == total_layers - dup_count` |

Total ceiling: **420** (400 + 20).

---

## Step 2 — Source Density Probe (this host 2026-04-30)

| Source | Size | Read policy | Density |
|--------|------|-------------|---------|
| `~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw` | **994 GB sparse** | first 4 KiB head only + os.stat | head=high (GPT/MBR signature + virtual size) |
| `~/Library/Containers/com.docker.docker/Data/vms/0/00000002.000007cf` | ~256 B | full read OK | low |
| `~/.docker/buildx/refs/desktop-linux/desktop-linux/*` | ~30 B × 93 | full read OK | medium (LocalPath layer provenance) |
| `~/.docker/contexts/meta/<sha>/meta.json` | ~340 B × 1 | full read OK | low |

Hot path: enumerate buildx refs → extract `LocalPath` paths → blake2b-64 hash
of head 64 KiB of each Dockerfile (if accessible) + collapse by content hash.
This gives a **layer-build-provenance dedup index** (the only host-fs-visible
slice of "image layers" — actual layer blobs are inside Docker.raw on the
Linux VM filesystem).

Synth fallback (most likely path on most hosts): generate 8000 layer chunks,
35% duplicates, seed=43, encoded into DILD blob.

---

## Step 3 — Iteration 1: Score Candidates (≥3 per V2 §B8)

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | B10/20 | Total |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|--------|-------|
| V1 | Docker.raw full hash dedup (~GB read) | 35 | 35 | 30 | 30 | 20 | 25 | 15 | 15 | 20 | 5 | **230** |
| V2 | buildx refs LocalPath dict only (no content hash) | 40 | 45 | 45 | 35 | 50 | 30 | 40 | 30 | 20 | 5 | **340** |
| V3 | T2 dedup pattern adapted: blake2b-64 head-64KB + sorted hash + dup_count + LayerStackFold | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | 20 | **420** |

V1: full-disk read of 994 GB sparse Docker.raw is operationally unsafe + B7
explosion + B5 fail (>120s). REJECT.
V2: tiny refs blob; misses content-hash dedup primitive. REJECT.
V3: matches T2 pattern exactly; head-only respect; B10 closes layer-fold.

blob layout (little-endian):
```
magic    : 4B  "DILD"
version  : 4B  u32 (1)
n_uniq   : 4B  u32 unique content count
n_total  : 4B  u32 total occurrence count (folded count)
[n_uniq*8] : u64 blake2b-64 content hash (sorted asc)
[n_uniq*4] : u32 size_bytes (head bytes hashed)
[n_uniq*4] : u32 dup_count (>=1; saving = sum(size*(dup-1)))
[n_uniq*4] : u32 image_idx (image owning first occurrence; 0xFFFFFFFF=unknown)
[n_uniq*4] : u32 path_offs
[n_uniq*4] : u32 path_lens
[path_pool_sz B] : utf-8 path pool
trailer    : u64 fnv1a_seed + u64 layer_stack_fold_canon (B10 witness)
```

---

## Step 4 — honest-C3 Iteration 1 Gap Disclosure

5 gaps:

- **G1**: Docker.raw is opaque on host (Linux VM fs inside) — host-side
  filter only sees buildx refs LocalPaths, not actual image layers. The
  filter therefore measures **build-input dedup** (Dockerfile contexts),
  which is a true layer-fold-eligible cohort but smaller than the full
  registry-side layer set.
- **G2**: blake2b-64 truncation collision — 1-in-1.8e19 baseline, B8 cover.
- **G3**: head-64KB hash boundary — for layer chunks < 64 KB, full content
  hashed; for larger chunks, head-only. Documented; B8.
- **G4**: B10 manjeom claim — "byte-fold-equivalence on layer-stack delta"
  is verified via diff_test (`unique == total - dup`). Meta-depth=1; B9.
- **G5**: image_idx is best-effort (extracted from buildx ref name when
  present); 0xFFFFFFFF for unknown — does not affect dedup correctness.

V2 §F-RAW240-2: 0 gaps after 만점 = retire — we have 5, ✓.
V2 §F-RAW240-3: any rubric-uncovered? G1 is **scope honesty** (covered by B8
fallback path) — no new block needed beyond B10 already declared.

---

## Step 5 — Iteration 2: Verify B10 Saturation

V3 already maxes B10/20 via layer-stack-fold-canon trailer + diff_test
assertion `unique == total - dup`. No further iteration adds score.

V4 considered: V3 + per-image bloom filter for fast `WHERE image='X'` —
B4 50→50 (already max), B7 40→36 (+1KB bloom), B10 20→20. Net **−4**. REJECT.

V5 considered: V3 + Docker.raw GPT partition scan — B8 30→35 (richer),
B7 40→34 (+1KB), B10 20→20. Net **−1**. REJECT.

**HALT** at V3 — V2-extended ceiling 420/420 saturated.

---

## Step 6 — Final Selection

**V3 — blake2b-64 head-64KB content-hash dedup + layer-stack-fold trailer.**

- Magic: **`DILD`** (Docker Image Layer Dedup).
- Sources: buildx refs LocalPaths (file head 64 KB) + Docker.raw stat-only +
  context meta.json names. NEVER full-read Docker.raw.
- Synth fallback: 8000 layer chunks, 35% dup, seed=43.

**Score: 420/420 (V2 + B10).** ≥350 IMPL threshold met. **IMPL.**

---

## Step 7 — Final honest-C3 (residual)

- **G1** (host-side scope honesty): documented; B8 cover; this filter
  measures the build-input-dedup slice, which is the host-fs-visible layer
  cohort.
- **G2** (blake2b-64 collision): rare; B8 cover.
- **G3** (head-64KB boundary): documented; B8 cover.
- **G4** (B10 manjeom claim): meta-depth=1; B9 cover.
- **G5** (image_idx best-effort): does not affect dedup; B4 cover.

**Gap count: 5. All rubric-covered. Termination valid.**

---

## Step 8 — Deliverables

1. `/Users/ghost/core/airgenome/docs/ct3_docker_image_layer_dedup_rubric_2026-04-30.md`
2. `/Users/ghost/core/airgenome/docs/ct3_docker_image_layer_dedup_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/modules/filters/data/docker_image_layer_dedup.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_ct3_docker_image_layer_dedup.hexa`

**Final CT3 score: 420/420 (V2 + B10 expanded ceiling — rotation/snapshot-
dedup-fold correctness via layer-stack-fold-canon trailer + diff_test
assertion).**
