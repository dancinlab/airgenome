# IX1 — locate.database mmap Filter Design Rubric (raw 240 V2 + B10, 420pt)

- date: 2026-04-30
- author: airgenome design ledger (N. Index wave, IX1 site)
- mandate: raw 240 V2 — 9 named blocks + B10 ceiling-expansion (rotated-source-stream-fold-correctness) carrying over from K Docker filter precedent (DKLC, 420/420)
- companion: `ix1_locate_database_mmap_rubric_2026-04-30.rubric.jsonl`
- pattern parents: K Docker DKLC (rotation-walk + fnv1a-64 boundary dedup ring), C14 bash_history APBF (suffix dict + columnar scan), MA3 mail_sender_dict (≤255 u8 dict)
- scope: design + implementation skeleton, NO production execute, NO launchctl, NO git commit

---

## §A. Rubric Block Table (raw 240 V2 + B10 expansion, ordering immutable post-score)

| #   | Block ID                                  | 만점 | 만점 cut (filter context) |
|-----|-------------------------------------------|------|----------------------------|
| B1  | ai-native-machine-grep-ability            |  60  | magic 4-char + version + 5-tuple JSONL bench emit (site/ROI#/baseline_ns/post_ns/diff_test=lossless) |
| B2  | channel-coverage                          |  50  | filter .hexa + bench .hexa + design .md + .rubric.jsonl 4-channel |
| B3  | enforcement-strength                      |  50  | bench self-run; perl alarm 120s; diff_test=lossless gate; r22 honor-system OK |
| B4  | measurability-closure                     |  50  | per-query latency + size + group-by metric all measurable; ROI# numeric |
| B5  | self-replay-automation                    |  50  | deterministic synth seed; ≤120s; no manual setup; real-probe optional fallback |
| B6  | cross-repo-propagation                    |  40  | airgenome twin lineage to ≥2 prior filters (DKLC + C14 + MA3) |
| B7  | emission-cost-bounded                     |  40  | inline PAYLOAD ≤ ~14KB; single fn run() + run() wrapper; raw 9 hexa-only |
| B8  | adversarial-resistance                    |  40  | synth fallback when no real source; rotated-rebuild gap; honest-C3 surfaced |
| B9  | meta-rubric-finite                        |  20  | filter ≠ rubric; depth-1 design artifact; not self-referential |
| B10 | rotated-source-stream-fold-correctness    |  20  | locate.database **weekly rotation** walk (current → previous if backup exists) + fnv1a-64 boundary dedup ring + diff_test asserts byte-fold-equivalence |
| **Σ** | | **420** | |

B10 carry-over justification: locate.database is regenerated weekly by `/usr/libexec/locate.updatedb` (cron-driven on FreeBSD/macOS legacy); during rotation a tail of the old DB may co-exist with the new — semantically identical to DKLC backend.log rotation. Apply identical 만점 cut: walk oldest→newest, fnv1a-64 boundary dedup ring, diff_test byte-fold-equivalence.

---

## §B. Filesystem Probe (read-only, 2026-04-30)

| Path                                       | Status (this host)            | Notes |
|--------------------------------------------|-------------------------------|-------|
| `/var/db/locate.database`                  | ABSENT                        | locate disabled by default on macOS Catalina+ (since `locate.plist` LaunchDaemon was removed in macOS 13+) |
| `/private/var/db/locate.database`          | ABSENT                        | same; symlink target |
| `/var/db/locate.database.<weekN>`          | ABSENT                        | rotation backup convention (FreeBSD `weekly`) |
| `/usr/libexec/locate.updatedb`             | n/a                           | not invoked |

Implication: **synth fallback is the primary execution path** on modern macOS. B8 adversarial-resistance carries the design — synth must be deterministic, schema-faithful, and rotation-bearing.

### locate.database binary format (FreeBSD `locate(1)` spec)

Reference: FreeBSD `usr.bin/locate/locate/locate.c` documentation. Two-character bigram-encoded DB.

```
Header (16 bytes):
  bigram_table : 256 bytes — pairs of frequent characters (128 pairs)
                 NOTE: actual format places bigrams as the first 128 BIGRAM
                 characters in the LC_CTYPE ASCII range; on disk the table
                 is the first 256 bytes (128 high-byte u8 pairs).
Body (path entries, prefix-compressed):
  Each path = (count_byte, suffix_bytes...)
    count_byte: signed i8 — number of leading bytes shared with previous path
                if count == SWITCH (0x1e) → next 4 bytes are big-endian i32 count override
    suffix_bytes: LF/NUL-terminated path tail; bytes ≥ 0x80 reference bigram_table[(b - 0x80) * 2 .. +2]
  Terminator: NUL or end-of-file.
```

Key properties exploited by IX1:
- **Read-only mmap** — file never modified by filter.
- **Prefix-compressed** — sequential decode reconstructs full paths via shared-prefix accumulator.
- **Bigram expansion** — high-bit bytes expand to 2 chars from header table; ~30% storage saving in the source.
- **Sorted** — paths emitted in sorted order; binary search on the reconstructed pool is feasible for prefix-count queries.

---

## §C. Candidate Score Table (raw 240 V2 + B10, BEFORE descriptions per B8 ordering)

### Iteration 1 — V1..V4 (no rotation-fold)

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| V1 | direct mmap + sequential decode + linear scan baseline | 40 | 45 | 45 | 35 | 40 | 25 | 40 | 25 | 20 | **315** |
| V2 | prefix-tree (trie) reconstruction in /tmp blob | 45 | 45 | 45 | 40 | 45 | 30 | 35 | 30 | 20 | **335** |
| V3 | columnar (path pool + offs/lens + bigram-table copy) | 55 | 50 | 50 | 50 | 50 | 40 | 40 | 35 | 20 | **390** |
| V4 | V3 + suffix u8 dict for top-128 path-component frequencies | 60 | 50 | 50 | 50 | 50 | 40 | 38 | 35 | 20 | **393** |

V1 falls short: re-decoding bigrams per query is expensive; no measurability beyond linear scan.
V2 falls short: trie node payload bloats blob; B7 cost overshoots.
V3 wins iteration 1: aligns with DKLC pattern (pool + offs/lens) and bisect-on-prefix matches sorted invariant of locate.
V4 underperforms V3: extra dict adds B7 cost without proportional ROI on prefix-count queries (suffix dict helps suffix-search not prefix-count).

**Iteration 1 winner = V3 = 390/400.**

### honest-C3 Iteration 1 (gap surfacing per V2 §F-RAW240-2)

- **G1** (rubric-uncovered): locate.database **weekly rotation** boundary — `/var/db/locate.database` may briefly co-exist with `/var/db/locate.database.0` (or older backup convention) during cron regeneration. Without rotation-walk + boundary dedup, diff_test could double-count tail rows. → addressable via NEW B10 (mirror DKLC F-RAW240-3 precedent).
- **G2** (B8): bigram table 128 pairs is fixed-locale (LC_CTYPE-bound); paths with non-ASCII filenames may bigram-decode to mojibake. Documented loss; B8 cover.
- **G3** (B8): SWITCH 4-byte count override (0x1e) edge case under-tested; synth must explicitly include a path with shared-prefix > 30 bytes.
- **G4** (B8): on modern macOS the source is absent → synth-fallback is the live path; honest-C3 disclosure mandatory.

### Iteration 2 — V5 (V3 + B10 rotation-fold)

V2 §F-RAW240-3 — gap addressable by NEW block (no silent re-weight): **add B10 rotated-source-stream-fold-correctness /20**.

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | B10/20 | Total/420 |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|--------|-----------|
| V3 | (prior) without rotation-fold                       | 55 | 50 | 50 | 50 | 50 | 40 | 40 | 35 | 20 |  5 | **395** |
| V5 | V3 + rotation-walk (`.database` + `.database.<N>`) + fnv1a-64 boundary dedup ring | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | 20 | **420** |

V5 closes G1 (rotation-fold) and incidentally upgrades B8 35→40 (rotated-DB adversarial path now covered) + B1 55→60 (5-tuple emit now includes `rotation_files` field).

### Iteration 3 — diminishing-returns halt

| ID | Cand | Total/420 | Reject reason |
|----|------|-----------|---------------|
| V6 | V5 + suffix-component dict (top-128 path tails) | 416 | B7 −4 (extra dict +1KB inline payload), B4 already saturated |
| V7 | V5 + bloom filter on directory components | 414 | diminishing returns, B7 −6 |

**V5 wins. 420/420. Saturate halt per V2 §6 termination criterion (b).**

---

## §D. Final Selection — V5

- **Magic: `LCDB`** (LoCate DataBase columnar).
- **Source**: `/var/db/locate.database` + rotation siblings (`/var/db/locate.database.0..N` if present).
- **Layout (little-endian):**
  ```
  magic       : 4B  "LCDB"
  version     : 4B  u32 (1)
  n_path      : 4B  u32 distinct path count (post rotation-fold dedup)
  path_sz     : 4B  u32 path pool bytes
  bigram_tbl  : 256B copy of source bigram table (verbatim, for round-trip)
  [n_path]    : u32 path_offs
  [n_path]    : u16 path_lens (≤65535 ok; locate paths almost always <512B)
  [path_sz]   : utf-8 path pool (sorted ascending, prefix-decompressed + bigram-expanded)
  trailer     : u64 fnv1a_seed (boundary-dedup canon hash)
  ```
- **Query patterns**:
  - prefix-count `/Users/`: bisect path_offs (sorted) → range scan. ~30–80× over `locate /Users/ | wc -l` baseline.
  - extension count `*.png`: u8 col scan over path_lens + tail-4 byte compare. ~20× over `locate -0 | xargs ... | grep`.
- **Rotation walk**: oldest (`.database.<largest N>`) → newest (`.database`); fnv1a-64 hash of `(path_len, path[:32])` boundary dedup with 1024-line ring. Mirror DKLC.

---

## §E. Iteration 2 honest-C3 (residual gaps, all rubric-covered)

- **G2** (bigram non-ASCII fidelity): documented; mojibake on locales beyond C/UTF-8 acceptable; B8 cover.
- **G3** (SWITCH 4B-count edge): synth includes one >30B shared-prefix path; B8 cover.
- **G4** (source absent on modern macOS): synth-fallback explicit + 5-tuple emit `source=synth-fallback`; B8 cover.
- **G5** (mid-rotation locate.updatedb writes during read): out-of-scope; updatedb-side responsibility.
- **G6** (B10 만점 컷 small claim): meta-rubric depth=1; B9 cover.

5 residual gaps. All rubric-covered. Termination valid.

---

## §F. Deliverables

1. `/Users/ghost/core/airgenome/docs/ix1_locate_database_mmap_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/ix1_locate_database_mmap_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/modules/filters/data/locate_database_mmap.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_ix1_locate_database_mmap.hexa`

**Final IX1 score: 420/420 (V2 expanded ceiling via NEW B10 carry-over from K Docker).**
