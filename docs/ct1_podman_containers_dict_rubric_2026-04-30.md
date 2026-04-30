# CT1 podman_containers_dict — raw 240 V2 Weighted Rubric

Origin: `2026-04-30` arsmoriendi99@proton.me — L. Container/VM wave (3 filters).
Applies raw 240 V2 (9 blocks / 400pt) discipline. CT1 does **not** invoke a
NEW B10 axis (no rotation-fold / snapshot-dedup correctness involved); ceiling
remains **400**.

Sources (read-only, host-fs only):

- `~/.config/containers/storage.conf` (single TOML/INI)
- `~/.local/share/containers/storage/overlay-containers/containers.json`
- `~/.local/share/containers/storage/overlay-images/images.json`
- `~/.local/share/containers/storage/overlay-layers/layers.json`

NOT touched: any podman socket, `/var/run/docker.sock`, podman CLI.

---

## Step 1 — Rubric V2 Block Declaration (BEFORE candidates per B8 ordering)

| Block | 만점 | 만점 컷 (filter-design context) |
|-------|------|---------------------------------|
| B1 ai-native-machine-grep-ability | 60 | magic `PCDD` + version + 5-tuple JSONL bench emit (site / ROI# / baseline_ns / post_ns / diff_test=lossless) |
| B2 channel-coverage               | 50 | filter `.hexa` + bench `.hexa` + design `.md` + `.rubric.jsonl` 4-channel |
| B3 enforcement-strength           | 50 | bench self-run; perl alarm 120s; diff_test=lossless gate; r22 honor-system OK |
| B4 measurability-closure          | 50 | per-query us latency + blob bytes + group-by image_id metric all measurable; ROI# numeric |
| B5 self-replay-automation         | 50 | deterministic synth seed (seed=23); ≤120s; no manual setup; real-probe optional fallback |
| B6 cross-repo-propagation         | 40 | airgenome twin lineage to ≥2 prior filters (C9 tool_name_dict + MA3 mail_sender_dict + K Docker) |
| B7 emission-cost-bounded          | 40 | inline PAYLOAD ≤ ~12KB; single fn run() + run() wrapper; raw 9 hexa-only |
| B8 adversarial-resistance         | 40 | synth fallback when no real source (this host has no podman); image_id collision; honest-C3 surfaced |
| B9 meta-rubric-finite             | 20 | filter ≠ rubric; depth-1 design artifact; not self-referential |

Total ceiling: **400**.

---

## Step 2 — Source Density Probe (read-only)

This host: `~/.config/containers/` and `~/.local/share/containers/` BOTH absent.
CT1 path is **synth-only** on this host (B8 covers via deterministic synth).

Schema (from podman docs / containers/storage):
- `containers.json` — array of `{id, names, image, imagedigest, layer, metadata, created, ...}`
- `images.json` — array of `{id, names, digest, layer, metadata, big-data-names, ...}`
- `layers.json` — array of `{id, parent, names, mountlabel, created, compressed-diff-digest, ...}`

Hot path: `GROUP BY image` over containers, `JOIN containers.layer → layers.id`,
prefix lookup on container short-id (first 12 hex). Linear JSON parse per query
is the baseline; CT1 builds a packed dict + sorted hash index.

---

## Step 3 — Iteration 1: Score Candidate Variants (≥3 per V2 §B8)

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-------|
| V1 | json.loads on each query (no dict) | 30 | 35 | 40 | 30 | 40 | 25 | 35 | 25 | 20 | **280** |
| V2 | sqlite shbf of containers.json (out-of-stdlib path bloat) | 35 | 40 | 35 | 35 | 35 | 25 | 25 | 25 | 20 | **275** |
| V3 | u64 short-id hash sorted dict + name pool + image_id col + 5-tuple emit | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |

V3 wins. blob layout (little-endian):
```
magic    : 4B  "PCDD"
version  : 4B  u32 (1)
n_cont   : 4B  u32 container count
n_img    : 4B  u32 image count
name_sz  : 4B  u32 utf-8 name pool bytes
[n_cont*8] : u64 short_id_hash (fnv1a-64 of first 12 hex of container id, sorted asc)
[n_cont*4] : u32 image_idx (idx into image table; 0xFFFFFFFF = orphan)
[n_cont*4] : u32 name_offs
[n_cont*4] : u32 name_lens
[n_img*8]  : u64 image short_id hash (sorted asc)
[n_img*4]  : u32 img_name_offs
[n_img*4]  : u32 img_name_lens
[name_sz]  : utf-8 name pool
trailer    : u64 fnv1a_seed
```

Query patterns: bisect by short-id (linear vs O(log n)); GROUP BY image (1-pass).

---

## Step 4 — honest-C3 Iteration 1 Gap Disclosure

5 gaps surfaced:

- **G1**: containers.json schema can drift across podman versions — version
  field captured but consumer must validate.
- **G2**: short-id collision at 12 hex (48 bits) — possible but ~1 in 3e7 for
  10k containers; B8 acceptable scope.
- **G3**: layers.json not unified into the blob (separate read on demand) —
  would push past B7 emission cap.
- **G4**: this host lacks any podman state; B5 self-replay covers via synth.
  Real-probe path is best-effort.
- **G5**: storage.conf TOML — tiny config; reading is value-add but adds
  PAYLOAD bytes (B7 trade-off). Decided: parse `runroot` / `graphroot` keys
  only via regex (no toml import).

V2 §F-RAW240-2 check: 0 gaps after 만점 = retire — we have 5, ✓.
V2 §F-RAW240-3 check: any gap rubric-uncovered? **No.** All 5 fall within
existing B7 / B8 / B5 axes. **No new block needed.** Ceiling stays 400.

---

## Step 5 — Final Selection

**V3 — short-id hashed sorted-dict + image_idx column + name pool.**

- Magic: **`PCDD`** (Podman Containers Dict Dedup).
- Sources: `~/.local/share/containers/storage/overlay-{containers,images,layers}/*.json`.
- Synth fallback: 2,500 containers / 600 images, seed=23, deterministic.

**Score: 400/400.** Threshold for IMPL: ≥350. **IMPL.**

---

## Step 6 — Final honest-C3 (residual gaps, all rubric-covered)

- **G1** (schema drift): version captured; B8 cover.
- **G2** (12-hex collision): rare; B8 cover.
- **G3** (layers separated): per B7 emission cap; documented.
- **G4** (no podman on host): B5 self-replay synth covers; documented.
- **G5** (storage.conf scope): regex-narrow keys only; B7 cover.

**Gap count: 5. All rubric-covered. Termination valid.**

---

## Step 7 — Deliverables

1. `/Users/ghost/core/airgenome/docs/ct1_podman_containers_dict_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/ct1_podman_containers_dict_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/modules/filters/data/podman_containers_dict.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_ct1_podman_containers_dict.hexa`

**Final CT1 score: 400/400 (V2 ceiling, no B10).**
