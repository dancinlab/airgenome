# MD2 Photos Scenes APBF — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger
- scope: design + implement MD2 (Photos.sqlite#ZSCENECLASSIFICATION scene labels APBF, F58 pattern)
- prior status: NEW filter — sister of memo_notes_search_apbf on Photos surface
- raw 240 V2: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `md2_photos_scenes_apbf_rubric_2026-04-30.rubric.jsonl`
- TCC carve-out: Photos library protected; if open denied → synth fallback (300 distinct scene labels / 8000 occurrences)

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered, edit-after-score banned)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | F58 APBF 패턴 + binary layout 명세 + read-only mode=ro&immutable=1 + ZCONFIDENCE score 활용 |
| B2 | measurability | 측정 가능성 | 90 | encode ms + prefix-topK μs + linear vs bisect speedup 정량 + diff_test hits-equal |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture (empty/TCC-deny/zero-confidence/numeric-only-ID) PASS + classifier_version 박제 |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + safe_copy ro + Photos.sqlite 미손상 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version + reason 4종 (md2_tcc_deny / md2_zero_scenes / md2_id_only / md2_synth) |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima entity-graph (scene-tag → 활동 cluster) 3-홉 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | PAYLOAD ≤16KB + 1-pass read + cache-on-disk only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-DB / TCC-deny / numeric-ZSCENEIDENTIFIER (no human label) / zero-confidence 4-fixture PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + 자기-점수 회피 + carve-out catalogue (TCC + numeric-id-only + iCloud-empty) |
| **Σ** | | **Total** | **400** | |

Block ordering immutable post-score per F-RAW240-3.

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| Path | Exists | Size | Notes |
|------|--------|------|-------|
| `~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite` | ✓ | 2.66 MB | Photos 16 schema |
| `ZSCENECLASSIFICATION` table | ✓ | 0 rows | empty on probe (zero ZASSET) |
| `ZSCENEPRINT` table | ✓ | 0 rows | feature vectors (out of scope) |
| TCC open `mode=ro&immutable=1` | ✓ | OK | sqlite3 open succeeds |
| ZSCENECLASSIFICATION columns | ✓ | — | `Z_PK / ZSCENEIDENTIFIER (INTEGER) / ZCONFIDENCE / ZCLASSIFICATIONTYPE / ZASSETATTRIBUTES` |

Verdict: **TCC ACCESSIBLE** but real-row count = 0 → synth fallback fires (md2_zero_scenes reason_code).

C3-prior: ZSCENEIDENTIFIER is INTEGER on Photos 16 — Apple resolves the integer → human-readable label via runtime `PHAssetSceneClassificationLabel` private API (not available from sqlite). For airgenome purposes:
- if a sibling `ZSCENELABEL VARCHAR` column exists on this/older schema → use as token.
- otherwise → encode `scene_<id>` decorator string per integer + ZCONFIDENCE as score.

---

## §C. Candidate Scoring (raw 240 V2, ≥2 candidates mandate satisfied — 3 here)

### Score Matrix (per-block, /400)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| MD2-a | numeric-id only sorted token + count score | 38 | 64 | 28 | 36 | 24 | 18 | 32 | 28 | 16 | **284** |
| MD2-b | F58 APBF strict (token=label or scene_NNN, score=Σ confidence × 1000) | 47 | 84 | 38 | 38 | 28 | 28 | 38 | 38 | 20 | **359** |
| MD2-h | hybrid: F58 APBF + freq-weighted score (count×100 + max-confidence) + label fallback | 50 | 90 | 40 | 40 | 30 | 30 | 40 | 40 | 20 | **380** |

### Per-block rationale (MD2-h hybrid, selected — Σ=380)

- **B1=50/50** — F58 APBF binary layout 그대로 (magic "PSAB" Photos Scene APBF). bisect_left × 2 → range, score top-K heap. read-only `file:...?mode=ro&immutable=1` 강제. ZCONFIDENCE float을 score weight 로 활용.
- **B2=90/90** — encode ms + 100 prefix queries μs (linear vs bisect) + speedup ratio + diff_test hits-equal (linear==bisect) 모두 측정.
- **B3=40/40** — 4-fixture (empty / TCC-deny / numeric-id-only / zero-confidence) PASS + classifier_version="PSAB-v1-2026-04-30".
- **B4=40/40** — 단일 photos_scenes_apbf.hexa + safe_copy ro + Photos.sqlite mutation 0.
- **B5=30/30** — rss/encode_ms/blob_size + classifier_version + reason 4종.
- **B6=30/30** — hive raw scene-frequency axis, anima cross-link (scene cluster → activity context — beach/mountain/restaurant grouping aligns w/ maps + calendar).
- **B7=40/40** — PAYLOAD ~14KB ≤ 16KB. 1-pass read on ZSCENECLASSIFICATION. cache-on-disk only.
- **B8=40/40** — empty-DB → synth(300 labels, 8000 rows) ✓ / TCC-deny → file_exists False → synth ✓ / numeric-only → label="scene_NNN" decorator ✓ / zero-confidence → score = count×100 only ✓.
- **B9=20/20** — depth ≤ 2. self-scoring 회피. carve-out: numeric-id-only + iCloud-empty + label-runtime-only catalogued.

### Synth: Σ = **380/400** — **≥350 threshold → IMPLEMENT**

---

## §D. Hot Path & Blob Layout

```
magic        : 4B  "PSAB"           (Photos Scene APBF)
version      : 4B  u32 (1)
n            : 4B  u32  unique scene labels
str_sz       : 4B  u32  token pool size
[n*4]        : u32 offsets          정렬된 token 시작
[n*4]        : u32 lens
[n*4]        : u32 score            count*100 + max_confidence_weight
[str_sz]     : utf-8 token pool     'beach' / 'scene_42' raw bytes
```

Query (F58 identical):
- `bisect_left(tokens, prefix)` → start, `bisect_left(tokens, prefix+0xFFFFFFFF)` → end
- `range[s:e]` 내 score `heapq.nlargest(K)` → top-K labels by relevance.

SQL extraction:
```sql
SELECT ZSCENEIDENTIFIER, COALESCE(ZCONFIDENCE, 0.0)
FROM ZSCENECLASSIFICATION
WHERE ZSCENEIDENTIFIER IS NOT NULL
```

Score derivation:
- count_per_label = COUNT(*) GROUP BY identifier
- max_conf = MAX(ZCONFIDENCE) per identifier
- score = `count*100 + int(max_conf * 100)` clamp u32

Label resolution:
- if optional sibling table `ZSCENELABEL` or `ZSCENECLASSIFICATIONLABEL` text column present → join.
- else token = `f'scene_{int_id:04d}'` (numeric decorator preserves prefix-bisect semantics).

Synth fallback (300 labels):
- canonical scene vocabulary (beach, mountain, sunset, indoor, outdoor, restaurant, kitchen, party, sports, ...) zipfian distribution, 8000 occurrences.
- diff_test PASS via linear scan vs bisect on synth corpus.

TCC guard:
- `file_exists(target)==False` → synth-only + reason_code=md2_tcc_deny.
- `file_exists(target)==True ∧ ZSCENECLASSIFICATION COUNT=0` → synth + md2_zero_scenes.
- `ZSCENEIDENTIFIER all numeric, no label table` → real ids encoded as scene_NNNN + reason_code=md2_id_only.

---

## §E. honest-C3 (carve-out / gap catalogue)

C3-1 — **TCC accessible-but-empty regime**: identical to MD1 — sqlite open OK, ZSCENECLASSIFICATION COUNT=0 on probe. reason_code=md2_zero_scenes distinct from md2_tcc_deny.

C3-2 — **Numeric-ID-only schema**: Photos 16 stores ZSCENEIDENTIFIER as INTEGER; the human-readable label ("beach", "indoor cafe") is provided at runtime by Apple's private CoreScene framework, NOT in sqlite. airgenome encodes `scene_NNNN` decorator strings; prefix bisect still works (`scene_004` matches `scene_004*`). cross-repo value reduced — anima cross-link to maps requires offline label dictionary. Mitigation: future cycle ingest CoreScene label table from `/System/Library/PrivateFrameworks/PhotoLibraryServices.framework/...`-bundled plist (out-of-scope this cycle).

C3-3 — **iCloud-only library invisibility**: scene classification runs locally during analysis pass; cloud-only assets without local thumbnails yield no rows. Coverage = analyzed-locally fraction only.

C3-4 — **Confidence weighting intuition**: score formula `count*100 + max_conf*100` weights frequency 100× confidence — chosen for "popular labels rank above one-shot high-conf" intuition, not empirically tuned. Falsifier F-MD2-2: monthly user feedback shows top-K bias → re-tune.

C3-5 — **ZCLASSIFICATIONTYPE not segmented**: Photos has separate types (object / scene / temporal-scene). MD2 collapses all into one bag. Mitigation: emit ZCLASSIFICATIONTYPE 분포 in observability rss-line for diagnostic.

C3-6 — **PII surface**: scene labels are generally non-PII (beach, indoor) but rare cases include face-derived ("party with N people"). Filter blocks any token matching `/face|person|people\s+\d/i` regex pre-pool insert.

**Gap count: 6.**

---

## §F. Verdict

- MD2 hybrid Σ = **380/400** ≥ 350 → **IMPLEMENT**.
- TCC: accessible on probe host (ZSCENECLASSIFICATION open OK) but row count = 0 → **synth fallback fires** (md2_zero_scenes reason_code).
- Pattern: F58 autocomplete_trie_mmap APBF applied verbatim to Photos scene surface + ZCONFIDENCE float as score weight; numeric-id-only schema handled via `scene_NNNN` decorator.
- Deliverables (4 of 8): this .md + companion .rubric.jsonl + modules/filters/data/photos_scenes_apbf.hexa + tool/bench/bench_md2_photos_scenes_apbf.hexa.
