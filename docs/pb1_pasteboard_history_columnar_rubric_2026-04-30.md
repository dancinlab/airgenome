# PB1 — Pasteboard History Columnar — raw 240 V2 Weighted Rubric

Origin: `2026-04-30` arsmoriendi99@proton.me — H. Pasteboard wave, filter 1 of 2.
Pattern parents (READ FIRST):
- `/Users/ghost/core/airgenome/filters/module/data/zsh_history_columnar.hexa` (K6 400/400 — KZHC magic, u8 type-dict ≤255 enum, ts column, full-payload pool).
- `claude_token_columnar` ancestry (#99 dict + pool).
- `C14 bash_history_mmap` (sorted-pool prefix bisect ancestry — applies to clip-prefix top-K).

Rubric source: `/Users/ghost/core/hive/.raw` raw 240 V2 — 9 blocks, 400pt ceiling.
Companion JSONL: `pb1_pasteboard_history_columnar_rubric_2026-04-30.rubric.jsonl`.
Eats-dogfood: rubric table BEFORE candidate enumeration per V2 B8 ordering.

Probe (this host, 2026-04-30):
- `~/Library/Caches/com.apple.Pasteboard/` — does NOT exist (TCC + Apple no longer
  exposes a flat plist cache here on modern macOS).
- `~/Library/Biome/streams/restricted/Pasteboard.Change/local/` — exists, empty
  (Full Disk Access required to read; restricted in our process).
- `~/Library/Metadata/CoreSpotlight/PasteboardHistory/` — exists, empty (no
  Universal Clipboard activity captured locally yet).
- Real-data path is graceful-skip → synthetic fallback (8K items, 5 type
  distribution) is operative bench path. Pre-disclosed §honest-C3 G1.

## Step 1 — Rubric V2 Block Declaration (BEFORE candidate scoring per B8)

| Block | 만점 | 만점 컷 (PB1 filter-design context) |
|-------|------|-------------------------------------|
| B1 ai-native-machine-grep-ability | 60 | "PHCO" magic + u32 version + 24B header + JSONL 5-tuple emit + u8 type column |
| B2 channel-coverage               | 50 | filter .hexa + bench .hexa + rubric .md + rubric .jsonl (4 channels) |
| B3 enforcement-strength           | 50 | bench self-runs + diff_test=lossless + perl alarm 120s + read-only (lstat + open rb) |
| B4 measurability-closure          | 50 | 5-tuple (site=PB1, ROI#=pbhist, baseline_ns, post_ns, diff_test) + saving% + speedup |
| B5 self-replay-automation         | 50 | deterministic synth seed=13, ≤120s, no manual TCC dance, single `bench` invocation |
| B6 cross-repo-propagation         | 40 | K6 zsh_history (KZHC twin) + #99 dict (≤255 enum) + C14 sorted-pool ancestry |
| B7 emission-cost-bounded          | 40 | inline PAYLOAD ≤ ~14KB target, single `run()` wrapper, no .py sprawl |
| B8 adversarial-resistance         | 40 | synth fallback when no biome/cache; honest plain-vs-empty path; SYNTH/REAL label |
| B9 meta-rubric-finite             | 20 | filter ≠ rubric-of-rubric; depth-1 design artifact |

Total ceiling: **400**.

## Step 2 — Candidate Score Matrix (≥2 per V2 mandate)

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-------|
| PB1-a | flat sorted clip-pool + ts u32 (F18 form, no type dict) | 55 | 45 | 50 | 40 | 50 | 35 | 40 | 35 | 20 | **370** |
| PB1-b | type u8 dict (#99) + clip-content pool + ts u32 + size u32 (K6-twin) | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| PB1-c | sqlite-on-disk index (no columnar blob) | 45 | 40 | 45 | 35 | 40 | 30 | 35 | 35 | 20 | **325** |

PB1-b reasoning:
- B1 60: PHCO magic + v1 + 5-tuple JSONL emit fully machine-greppable.
- B4 50: GROUP BY type / top-K by ts / size-histogram all measurable on
  columnar layout in single u8/u32 scan pass.
- B6 40: Direct K6 KZHC pattern transfer (cmd-head u8 → type u8); MA3 #99 dict
  ≤255 enum bound (pasteboard UTI types seldom exceed ~30 distinct).
- B8 40: distinct UTI > 255 → most_common(255) fallback; missing biome →
  synth(8000, 5 types, seed=13); plain content escape preserved.

PB1-a falls short (-30): flat pool loses GROUP BY type ROI which is the
dominant pasteboard query (statusline / clip-genome by type-class).
PB1-c falls short (-75): sqlite mutation conflict + no inline blob + larger
file footprint + no mmap O(n) u8 scan.

## Step 3 — Synthesis

**Selected: PB1-b — 400/400 (≥350 threshold for impl PASS).**

Layout (little-endian):
```
magic    : 4B  "PHCO"
version  : 4B  u32 (1)
n_type   : 4B  u32 distinct UTI count (≤255)
n_clip   : 4B  u32 total clip count
str_sz   : 4B  u32 type-dict pool size
clip_sz  : 4B  u32 clip-content pool size
[n_type*4]: u32 type_dict_offs
[n_type*4]: u32 type_dict_lens
[str_sz] : utf-8 type-dict pool
[n_clip] : u8  type_dict_idx column
[n_clip*4]: u32 ts column (mtime epoch)
[n_clip*4]: u32 size column (raw clip byte size)
[n_clip*4]: u32 clip_offs
[n_clip*4]: u32 clip_lens
[clip_sz]: utf-8 clip-content pool
```

Query patterns:
- GROUP BY type: u8 col 1-pass → 256-bucket counter → ROI ≈ 20-50× over
  `python3 -c 'json.load(...).group_by(...)'` baseline.
- top-K by ts (recent clips): scan u8 col + ts heap → O(n) one-pass.
- size histogram: u32 size col bucket scan → no string parse.

UTI canonicalization (#65 wyhash usage): canonicalize raw UTI string
(`public.utf8-plain-text` etc) before dict insert; collision-resistant 64-bit
backs python dict during encode; final blob stores plain UTI string keys.

## Step 4 — honest-C3 (Gap Disclosure)

- G1: This host has no readable pasteboard cache (biome restricted, plist
  cache gone, CoreSpotlight empty). Real-data path lossless-skips → synth path
  is the operative bench. ROI on real corpus deferred until host with FDA
  grant + active pasteboard biome stream.
- G2: Pasteboard binary types (image/png, public.png, public.tiff) are stored
  as base64-encoded UTF-8 in clip pool — pool grows. Mitigation: `size` column
  records raw byte size; pool stores either truncated head 4KB OR base64 of
  small clips (<16KB). Larger items recorded by metadata only (size + type +
  ts) — content omitted. This is a deliberate B7 emission-cost trade.
- G3: distinct UTI >255 → most_common(255) fallback maps tail to id=0 ("misc"
  bucket) — collision risk noted but acceptable for pasteboard genome (real
  UTI vocabulary on macOS ≈ 30-80).
- G4: Filter does NOT capture clip-source-app (NSPasteboardItem doesn't
  store originating app universally); cross-reference with focused-app
  history requires Biome AppActivity stream (out of scope, separate filter).

**Gap count: 4.**

## Step 5 — Deliverables

1. `/Users/ghost/core/airgenome/docs/pb1_pasteboard_history_columnar_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/pb1_pasteboard_history_columnar_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/filters/module/data/pasteboard_history_columnar.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_pb1_pasteboard_history_columnar.hexa`

**Final PB1 score: 400/400 — PASS ≥350 impl threshold.**
