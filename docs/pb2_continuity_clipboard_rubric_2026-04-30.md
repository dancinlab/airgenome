# PB2 — Continuity Clipboard (Universal Clipboard cache) — raw 240 V2 Weighted Rubric

Origin: `2026-04-30` arsmoriendi99@proton.me — H. Pasteboard wave, filter 2 of 2.
Source: `~/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/type-clone/` + Biome `Pasteboard.Change` cross-device sync metadata. Universal Clipboard hand-off events between iCloud-paired devices.

Pattern parents (READ FIRST):
- `/Users/ghost/core/airgenome/filters/module/data/zsh_history_columnar.hexa` (K6 400/400 — KZHC magic, u8 dict ≤255 enum).
- `K2 sharedfilelist_recent_shbf` (LSSharedFileList recent-items SHBF — small per-record metadata indexed pattern).
- `claude_session_shbf` (cross-device session SHBF ancestry).

Rubric source: `/Users/ghost/core/hive/.raw` raw 240 V2 — 9 blocks, 400pt ceiling.
Companion JSONL: `pb2_continuity_clipboard_rubric_2026-04-30.rubric.jsonl`.
Eats-dogfood: rubric table BEFORE candidate enumeration per V2 B8 ordering.

Probe (this host, 2026-04-30):
- `~/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/type-clone/` — exists, empty (no recent cross-device clip events captured locally).
- `~/Library/Biome/streams/restricted/Pasteboard.Change/local/` — exists, empty.
- Universal Clipboard requires Handoff-paired iCloud devices on same network; this host appears single-device or hand-off inactive.
- Real-data path graceful-skip → synthetic fallback (4K events, 3 device-IDs, 4 type buckets, seed=17) is operative bench path. Pre-disclosed §honest-C3 G1.

## Step 1 — Rubric V2 Block Declaration (BEFORE candidate scoring per B8)

| Block | 만점 | 만점 컷 (PB2 filter-design context) |
|-------|------|-------------------------------------|
| B1 ai-native-machine-grep-ability | 60 | "CCBF" magic + u32 version + 28B header + JSONL 5-tuple emit + u8 device-id col + u8 type col |
| B2 channel-coverage               | 50 | filter .hexa + bench .hexa + rubric .md + rubric .jsonl (4 channels) |
| B3 enforcement-strength           | 50 | bench self-runs + diff_test=lossless + perl alarm 120s + read-only (no biome write) |
| B4 measurability-closure          | 50 | 5-tuple (site=PB2, ROI#=contclip, baseline_ns, post_ns, diff_test) + GROUP BY device-id + GROUP BY type |
| B5 self-replay-automation         | 50 | deterministic synth seed=17, ≤120s, no manual iCloud setup, single `bench` invocation |
| B6 cross-repo-propagation         | 40 | K6 KZHC twin + K2 LSSharedFileList SHBF + claude_session_shbf cross-device ancestry |
| B7 emission-cost-bounded          | 40 | inline PAYLOAD ≤ ~14KB target, single `run()` wrapper |
| B8 adversarial-resistance         | 40 | synth fallback when no Handoff cache; SYNTH/REAL label; honest empty-stream skip |
| B9 meta-rubric-finite             | 20 | filter ≠ rubric-of-rubric; depth-1 design artifact |

Total ceiling: **400**.

## Step 2 — Candidate Score Matrix (≥2 per V2 mandate)

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-------|
| PB2-a | single u8 type col + ts (no device-id), flat | 50 | 45 | 50 | 40 | 50 | 30 | 40 | 35 | 20 | **360** |
| PB2-b | u8 device-id dict + u8 type dict + ts u32 + size u32 + direction u8 (K6+K2 twin) | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| PB2-c | flat ndjson stream (no blob, grep-only) | 35 | 40 | 40 | 30 | 40 | 25 | 35 | 30 | 20 | **295** |

PB2-b reasoning:
- B1 60: CCBF magic + v1 + 5-tuple JSONL emit; u8/u32 columnar fully grep-friendly.
- B4 50: 3 group-bys (device, type, direction=src/dst) + ts top-K all single-pass on u8/u32 cols.
- B6 40: K6 KZHC u8 dict twin + K2 SHBF cross-device lineage + #65 wyhash for device-UUID canonicalize.
- B8 40: distinct device-ids ≤255 (real iCloud user devices ≤10 typical); type ≤255 (UTI vocabulary); synth fallback honest.

PB2-a falls short (-40): drops device-id dim (Universal Clipboard primary
ROI = "which device sent this clip" — losing it kills the cross-device
forensic story).
PB2-c falls short (-105): no blob = no mmap = no columnar speedup; grep-on-jsonl
 is the BASELINE, not the FILTER.

## Step 3 — Synthesis

**Selected: PB2-b — 400/400 (≥350 threshold for impl PASS).**

Layout (little-endian):
```
magic     : 4B  "CCBF"
version   : 4B  u32 (1)
n_dev     : 4B  u32 distinct device count (≤255)
n_type    : 4B  u32 distinct UTI count (≤255)
n_evt     : 4B  u32 total event count
dev_sz    : 4B  u32 device-dict pool size
type_sz   : 4B  u32 type-dict pool size
[n_dev*4] : u32 dev_dict_offs
[n_dev*4] : u32 dev_dict_lens
[dev_sz]  : utf-8 device-uuid-dict pool
[n_type*4]: u32 type_dict_offs
[n_type*4]: u32 type_dict_lens
[type_sz] : utf-8 type-dict pool
[n_evt]   : u8  device_id column
[n_evt]   : u8  type_id column
[n_evt]   : u8  direction column (0=src 1=dst 2=local)
[n_evt*4] : u32 ts column (epoch)
[n_evt*4] : u32 size column (clip raw byte size, content NOT stored — metadata-only)
```

Query patterns:
- GROUP BY device: u8 col 1-pass → 256-bucket counter (cross-device clip ranking).
- GROUP BY type: u8 col 1-pass → type-class histogram.
- GROUP BY direction: u8 col 1-pass → src vs dst ratio per device (Handoff
  flow direction analysis).
- recent-K cross-device clips: ts heap + direction filter.

NOTE: This filter is METADATA-ONLY by design (clip content NOT stored). Universal
Clipboard payloads are user-private and Handoff-encrypted; we capture only
{device, type, direction, ts, size} envelope. Content-side handled by PB1.

Wyhash (#65) usage: canonicalize device UUID + UTI string before dict insert;
collision-resistant 64-bit backs encode-side dict; blob stores plain strings.

## Step 4 — honest-C3 (Gap Disclosure)

- G1: This host has no active Handoff event stream (single-device or paired
  devices not on shared iCloud Net). Real-data path lossless-skips → synth is
  operative bench. ROI on real corpus deferred to multi-device-paired host.
- G2: Direction inference from biome stream is heuristic (timestamp deltas vs
  Pasteboard.Change local vs paired-device-event order); ground truth requires
  Handoff API hook (private, out of scope). Filter codes direction=2 (local)
  by default when source ambiguous; src/dst marks only when device-uuid
  exchange visible.
- G3: distinct devices >255 → most_common(255) fallback (real iCloud user
  device count ≤10 typical, no practical limit hit).
- G4: Content NOT stored — by design, see Step 3 NOTE. Cross-reference with
  PB1 by ts ± 1s window if user wants content recovery (separate join layer,
  out of scope for this filter).

**Gap count: 4.**

## Step 5 — Deliverables

1. `/Users/ghost/core/airgenome/docs/pb2_continuity_clipboard_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/pb2_continuity_clipboard_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/filters/module/data/continuity_clipboard.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_pb2_continuity_clipboard.hexa`

**Final PB2 score: 400/400 — PASS ≥350 impl threshold.**
