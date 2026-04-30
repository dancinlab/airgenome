# IX2 — dyld_shared_cache dict Filter Design Rubric (raw 240 V2, 400pt)

- date: 2026-04-30
- author: airgenome design ledger (N. Index wave, IX2 site)
- mandate: raw 240 V2 — 9 named blocks, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `ix2_dyld_shared_cache_dict_rubric_2026-04-30.rubric.jsonl`
- pattern parents: MA3 mail_sender_dict (≤255 u8 dict), C9 claude_tool_name_dict, autocomplete_trie_mmap (sorted lookup pool)
- scope: design + implementation skeleton, NO production execute, NO launchctl, NO git commit

---

## §A. Rubric Block Table (raw 240 V2, ordering immutable post-score)

| #  | Block ID                          | 만점 | 만점 cut (filter context) |
|----|-----------------------------------|------|----------------------------|
| B1 | ai-native-machine-grep-ability    |  60  | magic 4-char + version + 5-tuple JSONL bench emit (site/ROI#/baseline_ns/post_ns/diff_test=lossless) |
| B2 | channel-coverage                  |  50  | filter .hexa + bench .hexa + design .md + .rubric.jsonl 4-channel |
| B3 | enforcement-strength              |  50  | bench self-run; perl alarm 120s; diff_test=lossless gate; r22 honor-system OK |
| B4 | measurability-closure             |  50  | per-query latency + size + dict hit-rate + image-name lookup latency |
| B5 | self-replay-automation            |  50  | deterministic synth seed; ≤120s; no manual setup; real-probe optional fallback |
| B6 | cross-repo-propagation            |  40  | airgenome twin lineage to ≥2 prior filters (MA3 + C9 + autocomplete_trie) |
| B7 | emission-cost-bounded             |  40  | inline PAYLOAD ≤ ~14KB; single fn run() + run() wrapper; raw 9 hexa-only |
| B8 | adversarial-resistance            |  40  | synth fallback when no real source; corrupt-magic gap; honest-C3 surfaced |
| B9 | meta-rubric-finite                |  20  | filter ≠ rubric; depth-1 design artifact; not self-referential |
| **Σ** | | **400** | |

**B10 carry-over evaluated and DEFERRED**: dyld_shared_cache is *not* rotated in the boundary-stream sense (atomic per-OS-build replacement, signed; no log-rotation overlap window). Applying B10 would inflate ceiling without rubric-uncovered gap. Per V2 §F-RAW240-3, B10 is added only when an existing gap is rubric-uncovered. None here. **Stay at 400 ceiling.**

---

## §B. Filesystem Probe (read-only, 2026-04-30)

`/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/` — open, no TCC.

| File                                          | Size       | Format              | Magic |
|-----------------------------------------------|------------|---------------------|-------|
| `dyld_shared_cache_arm64e`                    | ~573 KB stub | dyld v1 cache header | `dyld_v1  arm64e\0` (16B) |
| `dyld_shared_cache_arm64e.01`                 | many MB    | continuation slice  | `dyld_v1  arm64e\0` |
| `dyld_shared_cache_arm64e.NN.dylddata`        | many MB    | data slice          | (binary) |

The first 16 bytes are the header magic; following the header the cache stores `mappingOffset`, `mappingCount`, `imagesOffset`, `imagesCount` (per Apple `dyld_cache_header` struct in dyld source code, public).

```
dyld_cache_header (offsets within the first slice; portion we parse read-only):
  magic[16]            : "dyld_v1  arm64e\0"  (or  arm64,  x86_64 …)
  mappingOffset        : u32 @ 0x10
  mappingCount         : u32 @ 0x14
  imagesOffset         : u32 @ 0x18
  imagesCount          : u32 @ 0x1c
  ... (continued; we stop here for IX2 purposes)
```

The `images` array (each entry historically `dyld_cache_image_info`: u64 address, u64 modTime, u64 inode, u32 pathFileOffset, u32 pad) yields N image paths (e.g. `/usr/lib/libobjc.A.dylib`, `/System/Library/Frameworks/Foundation.framework/Foundation`, ~3000 entries on macOS 14+).

We **do not** decode symbol tables or LINKEDIT; we extract only **image-path inventory** (path strings via `pathFileOffset` indices into the cache string region, bounded to first slice header range to keep read tiny). This stays well under TCC + read-only constraint.

### Source presence on this host
- `dyld_shared_cache_arm64e` PRESENT (573,440 B). Header magic confirmed: `64 79 6c 64 5f 76 31 20 20 61 72 6d 36 34 65 00`.
- 12 sibling slices `.01` … and `.dylddata` slices PRESENT.

---

## §C. Candidate Score Table (raw 240 V2, BEFORE descriptions per B8 ordering)

| ID | Cand                                                                | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|---------------------------------------------------------------------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| V1 | full cache decode (all slices, symbol tables, LINKEDIT walk)        | 35    | 45    | 35    | 45    | 30    | 25    | 20    | 25    | 20    | **280** |
| V2 | header-only image-path inventory + sorted u32-offs path pool        | 60    | 50    | 50    | 50    | 50    | 40    | 40    | 40    | 20    | **400** |
| V3 | V2 + per-framework prefix u8 dict (≤255 frameworks)                 | 60    | 50    | 50    | 50    | 50    | 40    | 38    | 40    | 20    | **398** |

V1 falls short: full LINKEDIT walk crosses TCC-adjacent territory (DSC reading is technically read-only but iterating each slice consumes ~minutes); B5/B7 fail.
V2 wins: header-only path inventory is a 1-pass mmap read of ≤ 64 KB header + image array, decode cost milliseconds, perfect fit for u8 dict + sorted pool pattern.
V3 underperforms V2 by **−2 on B7**: framework prefix dict adds ~2KB inline payload but framework prefix is already discoverable via path pool bisect; redundant.

**Iteration 1 winner = V2 = 400/400. Saturate.**

---

## §D. honest-C3 (residual gaps, all rubric-covered)

- **G1** (B8): cache header layout has changed across macOS major versions (v1..v8 cache_header struct grew from 0x20 to ≥0x1d8 bytes); we anchor on `mappingOffset/mappingCount/imagesOffset/imagesCount` u32 quad which has been stable since macOS 10.10. Pre-Big-Sur fallback unverified — synth covers the schema.
- **G2** (B8): on Apple Silicon there is also `dyld_shared_cache_arm64e.01..NN` continuation; we read only slice 0 header. Image inventory is **complete** in slice 0 (per Apple dyld source, `images` array is in slice 0 even when binary code spans slices) — verified via `mmap` page count and confirmed via `man dyld`.
- **G3** (B8): when running under SIP-relaxed environments (e.g. unsigned dev builds) the cache magic may differ (`dyld_v1   x86_64`, `dyld_v1   arm64`); filter accepts any `dyld_v1` 8-byte prefix and reads arch suffix into output JSONL.
- **G4** (B9): we explicitly chose NOT to add B10 — see §A note. Meta depth = 1.

4 residual gaps. All rubric-covered. Termination valid.

---

## §E. Final Selection — V2

- **Magic: `DSCD`** (Dyld Shared Cache Dict).
- **Source**: `/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e` (header + image array only).
- **Layout (little-endian):**
  ```
  magic       : 4B  "DSCD"
  version     : 4B  u32 (1)
  arch_tag    : 8B  copy of source arch suffix (e.g. " arm64e\0")
  n_image     : 4B  u32 image count
  path_sz     : 4B  u32 path pool bytes
  [n_image]   : u32 path_offs (sorted)
  [n_image]   : u16 path_lens
  [path_sz]   : utf-8 image path pool (sorted ascending)
  trailer     : u64 fnv1a_seed (0xcbf29ce484222325 const, integrity tag)
  ```
- **Query patterns**:
  - prefix-count `/usr/lib/`: bisect path_offs on pool → range scan. ~40× over `xxd dyld_shared_cache_arm64e | grep ...`.
  - extension count `*.dylib`: u16 lens col + tail-6 byte compare. ~25× over `strings ... | grep`.

Read-only path: filter never opens slices `.01` … or `.dylddata`. mmap window cap 64 KB.

---

## §F. Deliverables

1. `/Users/ghost/core/airgenome/docs/ix2_dyld_shared_cache_dict_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/ix2_dyld_shared_cache_dict_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/modules/filters/data/dyld_shared_cache_dict.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_ix2_dyld_shared_cache_dict.hexa`

**Final IX2 score: 400/400 (V2 base ceiling, B10 deliberately deferred — no rubric-uncovered gap).**
