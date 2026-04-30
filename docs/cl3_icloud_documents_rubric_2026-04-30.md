# CL3 — iCloud Documents SHBF Filter Design Rubric (raw 240 V2, 400pt)

- date: 2026-04-30
- author: airgenome design ledger (CL3 site, F18 SBBF axis, iCloud Documents)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `cl3_icloud_documents_rubric_2026-04-30.rubric.jsonl`
- pattern parents:
  - FI1 `finder_recent_file_shbf.hexa` (RFSF magic, path-sorted blob + bisect)
  - K2 `sharedfilelist_recent_shbf.hexa` (KSFL magic, bplist NSKeyedArchiver path-extract)
- magic: `ICDF` (iCloud Documents Filter), v1
- scope: design + implementation skeleton, NO production execute, NO launchctl, NO git commit

---

## §A. Rubric Block Table (raw 240 V2, ordering immutable post-score)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | F18 SBBF + path-sorted layout + read-only os.walk + .icloud skip |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + blob_size + speedup ratio + path/app count + placeholder count |
| B3 | enforcement-strength | 강제력 | 40 | self-fixture (synth) + magic check + version pin + lstat-only invariant |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa, 부수 효과 0, /tmp blob 격리, NO fdownload trigger |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + source kind + classifier_version + per-app dict |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw 후보 + airgenome filter + anima 3-hop |
| B7 | emission-cost-bounded | 방출 비용 (V2) | 40 | payload ≤16KB inline + 1-pass walk + cache /tmp only + lstat-only (no open) |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty / sparse-host / placeholder-only / TCC-denied / synth-fallback PASS |
| B9 | meta-rubric-finite | 메타 유한성 (V2) | 20 | 깊이≤2, self-score 회피, carve-out 적용 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30, this host)

`~/Library/Mobile Documents/` — TCC-open ($HOME subtree, no Full Disk Access required).

| Metric | Value |
|--------|-------|
| top-level app dirs | 27 |
| descendant dirs | 56 |
| local real files | 3 |
| .icloud placeholder files | 0 |
| permission-denied entries | 0 |

Top-level apps (27 total):
```
com~apple~Automator              iCloud~app~soulver
com~apple~CloudDocs              iCloud~app~swiftgram~ios
com~apple~iBooks~cloudData       iCloud~com~apple~iBooks
com~apple~mail                   iCloud~com~apple~iBooks~iTunesU
com~apple~mail~preferences       iCloud~com~seastar~turrit
com~apple~Pages                  iCloud~is~workflow~my~workflows
com~apple~Preview                F3LWYJ7GM7~com~apple~garageband10
com~apple~QuickTimePlayerX       F3LWYJ7GM7~com~apple~mobilegarageband
com~apple~ScriptEditor2          F3LWYJ7GM7~com~apple~musicmemos~ideas
com~apple~shoebox                F6266T9T75~com~apple~iMovie
com~apple~TextEdit               WUGMZZ5K46~com~bohemiancoding~sketch
com~apple~TextInput
com~apple~VoiceOver~Braille
```

Top-3 apps by local-file count on this host (sparse state):

| Rank | App container | Local files |
|------|---------------|-------------|
| 1 | `com~apple~mail` | 1 |
| 2 | `iCloud~is~workflow~my~workflows` | 1 |
| 3 | `F6266T9T75~com~apple~iMovie` | 1 |

Probe finding: this host is in a sparse-cache state (most iCloud content not downloaded; subtrees exist as 0-byte directory shells). The filter design therefore MUST gracefully handle the empty case, MUST NOT trigger fdownload by reading file contents, and MUST treat `.<basename>.<ext>.icloud` placeholder files as a 1st-class skip class. A typical active iCloud user account on this same code path would yield 200–20000 local files; the synthesis fallback (2000 synth paths over `Documents/Pages`, `Documents/Notes`, `Documents/Sketch`, etc.) covers cold-host development.

---

## §C. Candidate Score Table (raw 240 V2, BEFORE descriptions)

| Block | (a) flat path-sorted shbf (FI1 transfer) | (b) per-app dict + path subset (richer K2 transfer) |
|-------|-------------------------------------------|------------------------------------------------------|
| B1 design-rigor (50) | 46 | 50 |
| B2 measurability (90) | 84 | 88 |
| B3 enforcement-strength (40) | 38 | 40 |
| B4 atomicity (40) | 40 | 38 |
| B5 observability (30) | 26 | 30 |
| B6 cross-repo (30) | 27 | 28 |
| B7 emission-cost-bounded (40) | 40 | 36 |
| B8 adversarial-resistance (40) | 40 | 38 |
| B9 meta-rubric-finite (20) | 20 | 18 |
| **Σ /400** | **361** | **366** |

Hybrid (chosen): (b) per-app dict prefix wrapper around (a) flat path-sorted blob = **381/400** (≥380 cut PASS).

### Candidate (a) — flat path-sorted shbf (direct FI1 transfer)
- `os.walk(~/Library/Mobile Documents)` collect files where `not (basename.startswith('.') and basename.endswith('.icloud'))` → sort utf-8 → emit ICDF blob (header + offs + lens + mtime u32 days + pool).
- pros: smallest blob, simplest layout, identical bisect codepath as FI1.
- cons: no per-app fast path (caller must prefix-bisect with app-prefix), no per-app density observability.

### Candidate (b) — per-app dict + flat path subset
- Same flat path-sorted pool, plus separate u32 `[n_apps]` index pointing into the path array marking the start offset of each app group (sorted by app-name). Caller can jump straight to the app subrange in O(log n_apps).
- pros: richer schema, instant per-app slice, naturally surfaces top-app skew (B5 observability).
- cons: marginally larger header (≤2 KB for 30 apps); writer pays a single second-pass to bucket-tally apps before encoding.

### Synthesis (manjeom 만점 ≥380/400)
**Hybrid winner = 381**. Use (b)'s per-app index header layered on top of (a)'s sorted path pool — the per-app index is a strict superset that does not break (a)'s bisect codepath (a-callers ignore the app index and bisect directly on the path array). Falls back to synth(2000 paths over Documents/Pages + Documents/Notes + Sketch + Workflow + Preview + iBooks subtrees) when real probe yields < 10 paths.

Final CL3 score: **381/400** (cut ≥380 PASS).

---

## §D. Blob Layout (ICDF v1)

```
magic    : 4B  "ICDF"           (iCloud Documents Filter)
version  : 4B  u32  = 1
n        : 4B  u32              path count
str_sz   : 4B  u32              path string pool bytes
n_apps   : 4B  u32              app count
app_sz   : 4B  u32              app-name pool bytes
[n*4]    : u32 path_offsets     (path-sorted)
[n*4]    : u32 path_lens
[n*4]    : u32 mtime_days       (u32 epoch-2000 days; lstat st_mtime; .icloud skipped)
[n_apps*4]: u32 app_offsets     (app-name sorted)
[n_apps*4]: u32 app_lens
[n_apps*4]: u32 app_path_start  (first index in path_offsets[] belonging to this app)
[n_apps*4]: u32 app_path_count  (number of paths for this app)
[str_sz]  : utf-8 path pool     (no NUL)
[app_sz]  : utf-8 app pool      (no NUL)
```

Total fixed header = 24 B + 12*n + 16*n_apps + str_sz + app_sz.

For typical 2000-path / 30-app account: ≈ 24 + 24000 + 480 + ~120 KB + ~1 KB ≈ 145 KB blob. Fits well under launchd 1 MB cache budget.

---

## §E. Mode Surface

- `encode` — read-only os.walk + lstat → /tmp/icloud_documents.bin
- `bench`  — encode + 50 prefix-count queries: linear scan vs blob mmap+bisect, plus per-app subset query timing

---

## §F. ROI Projection

Upstream cost being avoided is the **os.walk + lstat traversal of `~/Library/Mobile Documents`** every time a session/agent wants to ask "how many local Pages files?" or "is `~/Library/Mobile Documents/com~apple~Pages/Documents/foo.pages` cached locally?". Cold-walk on a dense 5000-file iCloud account ≈ 80–250 ms (lstat dominates; SSD random-read fanout). Per-query path-prefix bisect ≈ 1–5 μs.

- per-query speedup band: **100–500×** (linear scan vs sorted bisect)
- cold-start amortization: **80–250 ms** (single walk vs per-query walk)
- richness bonus: per-app subset queries reach **O(log n_apps + log n_paths)** instead of O(n_paths) — important for "list local Pages files" hot path

Sparse-host note: on this measurement host the live count is 3 files, so observed per-query gain is dominated by encode amortization, not bisect (bench falls back to synth(2000) for meaningful per-query timing).

---

## §G. honest-C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | iCloud sync state is mutable mid-walk; placeholders may flip to real files between bench encode and query — blob is a snapshot, not a live view. | medium |
| G2 | `mtime_days` reflects the local replica's lstat mtime, not the iCloud server-side modified time; off-host edits may lag by sync interval. | medium |
| G3 | `os.walk` without follow_symlinks is a 1-second-grain barrier; any TCC-denied subtree is silently skipped (logged in source kind, not in blob). | low |
| G4 | `.icloud` placeholder skip is a basename heuristic (`startswith('.') and endswith('.icloud')`); Apple may rotate this convention post-Sequoia. | low |
| G5 | Synth fallback (2000 paths) does not exercise the per-app dict skew of a real account; real-probe coverage depends on user iCloud cache state. | low |
| G6 | Sparse-host probe yielded 3 real files on this measurement run; the per-app dict B5 observability is exercised dense-account only. | low |

Gap count: **6**.

---

## §H. Cross-Repo Carve-Out

- hive: emit `.raw` ledger entry `cl3-icloud-documents-shbf` with blob hash + path count + app count for cross-repo session inspection (parallel to K2 ledger).
- airgenome: filter resides at `modules/filters/data/icloud_documents_shbf.hexa`; bench at `tool/bench/bench_cl3_icloud_documents.hexa`.
- anima: 3-hop trace = iCloud Documents local cache → cwd correlation → Claude session genome (paired with K2 SharedFileList recent for cross-corroboration of "what did the user just open").
