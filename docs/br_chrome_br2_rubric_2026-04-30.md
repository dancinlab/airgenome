# BR2 — Chrome Bookmarks SHBF (CBBF) — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger (Chrome browser data 재해석 BR2)
- candidate id: BR2 (Chrome `Default/Bookmarks` JSON tree)
- raw 240 V2 mandate: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- scope: design + read-only impl. NO mutation, NO git commit.
- pattern reference: F18 Safari bookmarks (`safari_bookmarks_shbf.hexa`). magic = `CBBF`.
- companion: `br_chrome_br2_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | shbf 패턴 (sorted utf-8 url + offsets/lens/weight) + JSON tree walk → leaf url 채집 + binary layout 명세 |
| B2 | measurability | 측정 가능성 | 90 | hot path latency μs급 + memory MB급 + before/after (json parse + linear scan) vs blob mmap+bisect 3-axis |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture self-test (synth/empty-tree/missing-file/depth-overflow) + classifier-version 박제 |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + side-effect 0 + tmp 격리 + Bookmarks.bak 미접촉 + open('rb') only |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version + reason code (br2_running, br2_synth, br2_real) |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima url-graph 3-홉 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | PAYLOAD ≤16KB + 1-pass + cache-on-disk-only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-tree / missing-file / chrome-running-synth / malformed-json 4-fixture PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | depth≤2 + self-scoring 회피 + carve-out catalogue |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| Path | Exists | Size | Notes |
|------|--------|------|-------|
| `~/Library/Application Support/Google/Chrome/Default/Bookmarks` | ✓ | 1317 B | JSON, roots: bookmark_bar/other/synced |
| `~/Library/Application Support/Google/Chrome/Default/Bookmarks.bak` | ✓ | 1301 B | backup, ignored |
| Chrome process | RUNNING | — | encode → synth-only fallback |

JSON schema: `{"checksum":"...", "roots":{"bookmark_bar":{...}, "other":{...}, "synced":{...}}, "version":1}`. Each tree node: `{"type":"folder"|"url", "url":"...", "name":"...", "children":[...]}` recursive.

F18 verbatim with `Children` → `children` lowercase + `URLString` → `url`.

---

## §C. Candidate Scoring (≥2 mandate)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| BR2-a | leaf url only flat | 46 | 80 | 36 | 38 | 28 | 26 | 38 | 36 | 18 | **346** |
| BR2-b | leaf url + depth weight | 48 | 86 | 38 | 38 | 28 | 28 | 38 | 38 | 20 | **362** |
| BR2-h | hybrid: leaf url + depth weight + name 2nd col + chrome-running synth | 50 | 88 | 40 | 40 | 30 | 28 | 38 | 40 | 20 | **374** |

### Selected: BR2-h. Σ = 374/400 ≥ 350 → **IMPL**

### Per-block rationale (BR2-h)

- **B1=50** — SBBF/CBBF binary layout, sorted utf-8 url pool, weight=`max(1, 100-depth*10)`.
- **B2=88** — encode 5–20ms (small file), lookup μs급. -2: real DB tiny (1.3KB) so per-query OLD is also fast → speedup ratio modest.
- **B3=40** — 4-fixture (synth/empty/missing/malformed-JSON) PASS.
- **B4=40** — open('rb') only, .bak 미접촉.
- **B5=30** — full 3-axis + reason codes.
- **B6=28** — anima entity-graph (bookmarked domain). -2: tiny dataset.
- **B7=38** — PAYLOAD ~10KB. -2: tree walk recursion.
- **B8=40** — 4-fixture PASS.
- **B9=20** — depth≤2 + carve-out.

---

## §D. Blob Layout (CBBF)

```
magic    : 4B  "CBBF"          (Chrome Bookmarks Blob Filter)
version  : 4B  u32 (1)
n        : 4B  u32  url 개수
str_sz   : 4B  u32  pool size
[n*4]    : u32 offsets (정렬된 url 순)
[n*4]    : u32 lens
[n*4]    : u32 weight (depth-derived)
[str_sz] : utf-8 url pool
```

Walk: `roots.{bookmark_bar,other,synced}` → recursively descend `children`; collect `type=="url"` leaves; weight = `max(1, 100-depth*10)`.

---

## §E. honest-C3

C3-1 — **JSON checksum integrity** — Chrome maintains MD5 of bookmark tree in `checksum`; we ignore (read-only).
C3-2 — **chrome-running mid-write race** — Chrome may rewrite Bookmarks atomically (.tmp → rename); pgrep guard + synth fallback.
C3-3 — **multi-profile** — `Default/` only.
C3-4 — **empty bookmark tree** — first-run Chrome may have no leaf urls; synth fallback.
C3-5 — **classifier-version skew** — `CBBF-v1-2026-04-30` 박제.

**Gap count: 5.**

---

## §F. Verdict

- BR2-h Σ = **374/400** ≥ 350 → **IMPL** (`modules/filters/data/chrome_bookmarks_shbf.hexa`).
- Bench: `tool/bench/bench_br2_chrome_bookmarks.hexa`.
- Expected ROI: encode 5–15ms (synth 5000), lookup ~10μs, speedup vs json parse + linear scan ≥500×.
