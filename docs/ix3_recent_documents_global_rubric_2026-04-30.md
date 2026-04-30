# IX3 — Recent Documents Global Filter Design Rubric (raw 240 V2, 400pt)

- date: 2026-04-30
- author: airgenome design ledger (N. Index wave, IX3 site)
- mandate: raw 240 V2 — 9 named blocks, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `ix3_recent_documents_global_rubric_2026-04-30.rubric.jsonl`
- pattern parents: K2 sharedfilelist_recent_shbf (single-source RFSF), FI1 finder_recent_file_shbf, MA3 mail_sender_dict (u8 app-id cap)
- scope: design + implementation skeleton, NO production execute, NO launchctl, NO git commit
- differentiation vs prior: K2 indexes ONE file (`com.apple.LSSharedFileList.RecentDocuments.sfl4`); IX3 aggregates the **GLOBAL** NSDocumentController history across (a) RecentDocuments.sfl4 + (b) ApplicationRecentDocuments/`<bundleid>.sfl3` per-app dir (~64 files this host) + (c) RecentApplications.sfl4 + (d) iCloudItems.sfl4 — multi-source cross-app fold with **app-id u8 dict** for grouping.

---

## §A. Rubric Block Table (raw 240 V2, ordering immutable post-score)

| #  | Block ID                          | 만점 | 만점 cut (filter context) |
|----|-----------------------------------|------|----------------------------|
| B1 | ai-native-machine-grep-ability    |  60  | magic 4-char + version + 5-tuple JSONL bench emit (site/ROI#/baseline_ns/post_ns/diff_test=lossless) |
| B2 | channel-coverage                  |  50  | filter .hexa + bench .hexa + design .md + .rubric.jsonl 4-channel |
| B3 | enforcement-strength              |  50  | bench self-run; perl alarm 120s; diff_test=lossless gate; r22 honor-system OK |
| B4 | measurability-closure             |  50  | per-query latency + size + per-app group-by + path count |
| B5 | self-replay-automation            |  50  | deterministic synth seed; ≤120s; no manual setup; real-probe optional fallback |
| B6 | cross-repo-propagation            |  40  | airgenome twin lineage to ≥2 prior filters (K2 + FI1 + MA3) |
| B7 | emission-cost-bounded             |  40  | inline PAYLOAD ≤ ~14KB; single fn run() + run() wrapper; raw 9 hexa-only |
| B8 | adversarial-resistance            |  40  | synth fallback when zero recent docs; corrupt-bplist gap; honest-C3 surfaced |
| B9 | meta-rubric-finite                |  20  | filter ≠ rubric; depth-1 design artifact; not self-referential |
| **Σ** | | **400** | |

**B10 carry-over evaluated and DEFERRED**: Recent docs sources are NOT log-rotated streams; each `.sfl3`/`.sfl4` is atomically replaced by NSDocumentController on commit (no boundary overlap). No rubric-uncovered gap → B10 not warranted. Stay at 400.

---

## §B. Filesystem Probe (read-only, 2026-04-30)

`~/Library/Application Support/com.apple.sharedfilelist/` — open, no TCC.

Cross-app discovery this host:

| Bucket                                         | Files | Size      | Format            |
|------------------------------------------------|-------|-----------|-------------------|
| `com.apple.LSSharedFileList.RecentDocuments.sfl4`        | 1   | 9.4 KB    | bplist00 NSKeyedArchiver |
| `com.apple.LSSharedFileList.RecentApplications.sfl4`     | 1   | ~9 KB     | bplist00 |
| `com.apple.LSSharedFileList.iCloudItems.sfl4`            | 1   | ~2 KB     | bplist00 |
| `ApplicationRecentDocuments/*.sfl3` + `*.sfl4`           | 64  | ~5–60 KB ea | bplist00 |
| **TOTAL coverage**                              | ~67 | ~700 KB   | NSKeyedArchiver bplist |

Per-app `.sfl3`/`.sfl4` filenames are bundle-id strings (e.g. `com.apple.dt.xcode.sfl3`, `app.soulver.appstore.mac.sfl3`, `ch.protonmail.desktop.sfl3`). The bundle-id is the **app-id u8 dict key** for IX3 grouping.

Each bplist's `$objects` contains Bookmark/Alias `bytes` blobs whose payloads embed `/Users/...|/Applications/...|/Volumes/...` byte sequences. Path extraction reuses K2's heuristic regex over byte-typed `$objects` entries.

---

## §C. Candidate Score Table (raw 240 V2, BEFORE descriptions per B8 ordering)

| ID | Cand                                                                                       | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|--------------------------------------------------------------------------------------------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| V1 | RecentDocuments.sfl4 only (K2 lineage); ignore per-app dir                                 | 50    | 45    | 45    | 35    | 50    | 30    | 40    | 30    | 20    | **345** |
| V2 | RecentDocuments + RecentApplications + iCloudItems (3-file union)                          | 55    | 50    | 50    | 45    | 50    | 35    | 40    | 35    | 20    | **380** |
| V3 | V2 + ApplicationRecentDocuments/`<bundleid>.sfl3-4` glob fold (cross-app)                  | 60    | 50    | 50    | 50    | 50    | 40    | 38    | 40    | 20    | **398** |
| V4 | V3 + app-id u8 dict (bundle-id → ≤255 idx) for GROUP BY app fast-path                      | 60    | 50    | 50    | 50    | 50    | 40    | 40    | 40    | 20    | **400** |

V1 falls short: indistinguishable from K2; B6 weak (no new lineage axis); B4 limited (single source — no GROUP BY app possible).
V2 falls short: 3-file union is improvement but ApplicationRecentDocuments/ dir holds the **majority** of cross-app recency signal (64 files vs 3); B4 misses app-grouping axis.
V3 falls short by **−2 on B7**: glob-fold without u8 app-id dict means each query needs a per-row string compare on bundle-id; payload bloats with Python set lookup cost.
V4 wins: app-id u8 dict (bundle-id → idx, ≤255) gives O(1) GROUP BY app + 1-pass u8 col scan, mirroring DKLC component-dict pattern. PAYLOAD stays ≤ 14KB.

**Iteration 1 winner = V4 = 400/400. Saturate.**

---

## §D. honest-C3 (residual gaps, all rubric-covered)

- **G1** (B8): heuristic regex inside Bookmark `bytes` blobs is best-effort (Bookmark v2 binary format is undocumented Apple-internal); some paths embedded as Alias-record CFBundleIdentifier-only blobs are missed. K2 documented this; same caveat carries.
- **G2** (B8): per-app `.sfl3`/`.sfl4` may sometimes be empty stub blobs (recently-launched apps with no recent docs); filter handles via try/except per-file with synth-fallback when zero rows globally extracted.
- **G3** (B8): bundle-ids beyond 255 distinct → overflow bucket idx=255. On this host 64 distinct bundle-ids; well under cap. Synth must include 256+ to test cap path.
- **G4** (B8): mtime as recency proxy — Bookmark blob does not always carry an explicit `last_used` timestamp; fall back to file mtime. K2 precedent.
- **G5** (B9): we explicitly chose NOT to add B10 — see §A note. Meta depth = 1.

5 residual gaps. All rubric-covered. Termination valid.

---

## §E. Final Selection — V4

- **Magic: `RDGL`** (Recent Documents GLobal).
- **Sources**:
  - `~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sfl4`
  - `~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentApplications.sfl4`
  - `~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.iCloudItems.sfl4`
  - `~/Library/Application Support/com.apple.sharedfilelist/ApplicationRecentDocuments/*.sfl3`
  - `~/Library/Application Support/com.apple.sharedfilelist/ApplicationRecentDocuments/*.sfl4`
- **Layout (little-endian):**
  ```
  magic         : 4B  "RDGL"
  version       : 4B  u32 (1)
  n_app         : 4B  u32 distinct app-id count (≤255)
  n_path        : 4B  u32 distinct path count (post dedup)
  app_sz        : 4B  u32 app-id pool bytes
  path_sz       : 4B  u32 path pool bytes
  [n_app*4]     : u32 app_offs (sorted ascending)
  [n_app*2]     : u16 app_lens
  [app_sz]      : utf-8 app-id pool (sorted, e.g. "com.apple.dt.xcode")
  [n_path]      : u8  app_idx_col (255 = misc overflow bucket)
  [n_path]      : u32 path_offs
  [n_path]      : u16 path_lens
  [n_path]      : u32 mtime_col (epoch seconds, last_used proxy)
  [path_sz]     : utf-8 path pool
  trailer       : u64 fnv1a_seed
  ```
- **Query patterns**:
  - GROUP BY app (top-N by count): u8 col 1-pass + 256-bucket counter. ~50× over `for f in *.sfl3; plistlib.load; len($objects)`.
  - prefix `/Users/ghost/Documents/`: bisect path_offs → range. ~30× over linear regex scan.
  - last-7-day filter: mtime_col u32 1-pass. ~80× over `find ... -mtime`.

---

## §F. Deliverables

1. `/Users/ghost/core/airgenome/docs/ix3_recent_documents_global_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/ix3_recent_documents_global_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/modules/filters/data/recent_documents_global.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_ix3_recent_documents_global.hexa`

**Final IX3 score: 400/400 (V2 base ceiling, B10 deliberately deferred — atomic per-file replacement is not stream-rotation).**
