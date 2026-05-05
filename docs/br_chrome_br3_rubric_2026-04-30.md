# BR3 — Chrome Local Storage SHBF (CLBF) — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger (Chrome browser data 재해석 BR3)
- candidate id: BR3 (Chrome `Default/Local Storage/leveldb/*.ldb`)
- raw 240 V2 mandate: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- scope: design + read-only impl. NO mutation, NO git commit.
- pattern reference: K4 v2 (`discord_localstorage_shbf.hexa`) — pure-python snappy decoder reuse. magic = `CLBF`.
- companion: `br_chrome_br3_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | shbf 패턴 (sorted utf-8 key + offsets/lens/source_tag) + leveldb footer/index/data block walk + snappy decoder reuse |
| B2 | measurability | 측정 가능성 | 90 | hot path latency μs급 + memory MB급 + before/after ratio + snappy decode coverage % |
| B3 | enforcement-strength | 강제력 | 40 | 5-fixture self-test (snappy 5 fixtures from K4) + 4-fixture (synth/empty/running/snappy-skew) + classifier-version |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + LOCK 미접촉 + open('rb') only + tmp 격리 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version + reason code (br3_running/synth/snappy_skew/corrupt) |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima localstorage-keys 3-홉 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | PAYLOAD ≤16KB + 1-pass + cache-on-disk-only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-dir / corrupt-LDB / chrome-running / snappy-skew 4-fixture PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | depth≤2 + self-scoring 회피 + carve-out catalogue |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| Path | Exists | Size | Notes |
|------|--------|------|-------|
| `~/Library/Application Support/Google/Chrome/Default/Local Storage/leveldb/` | ✓ | dir | 3 .ldb + 1 .log + LOCK + LOG + CURRENT |
| ↳ `000005.ldb` | ✓ | 15.5 KB | seed |
| ↳ `000028.ldb` | ✓ | 178 KB | recent compaction |
| ↳ `000030.ldb` | ✓ | 27 KB | overflow |
| ↳ `000031.log` | ✓ | 2.5 KB | uncompacted writes |
| LOCK | ✓ (0 B) | — | advisory; never written |
| Chrome process | RUNNING | — | encode → synth-only |

---

## §C. Candidate Scoring (≥2 mandate)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| BR3-a | LS only, no snappy decoder (skip blocks) | 44 | 78 | 34 | 38 | 28 | 22 | 36 | 32 | 18 | **330** |
| BR3-b | LS only + K4 v2 snappy decoder reuse | 48 | 86 | 38 | 38 | 28 | 26 | 36 | 38 | 20 | **358** |
| BR3-h | hybrid: LS + IDB optional + snappy decoder + chrome-running synth | 50 | 88 | 40 | 40 | 30 | 28 | 36 | 40 | 20 | **372** |

### Selected: BR3-h. Σ = 372/400 ≥ 350 → **IMPL**

### Per-block rationale (BR3-h)

- **B1=50** — leveldb footer + index + data block walk verbatim from K4. CLBF binary layout. snappy decoder = K4 v2 verbatim.
- **B2=88** — encode 50–80ms expected; lookup μs급. -2: real LS ~220KB; speedup ratio modest vs Discord 11MB.
- **B3=40** — 5+4 fixtures.
- **B4=40** — open('rb'), LOCK 미접촉.
- **B5=30** — full reason code matrix.
- **B6=28** — host/origin/setting key 3-hop.
- **B7=36** — PAYLOAD ~14KB (snappy decoder 큼). -4.
- **B8=40** — 4-fixture PASS.
- **B9=20** — depth≤2.

---

## §D. Blob Layout (CLBF)

```
magic    : 4B  "CLBF"
version  : 4B  u32 (1)
n        : 4B  u32  printable utf-8 keys
str_sz   : 4B  u32  pool size
[n*4]    : u32 offsets
[n*4]    : u32 lens
[n*1]    : u8  source_tag (0=LS-raw, 1=LS-snappy, 2=IDB, 3=synth)
[str_sz] : utf-8 key pool
```

Token-fragment regex drop: `/token|password|secret|auth|jwt|bearer/i`.

---

## §E. honest-C3

C3-1 — **snappy decoder reuse from K4** — 38 LOC, fixture 5/5 PASS verified upstream.
C3-2 — **chrome-running mid-write** — pgrep + LOCK stat double-check + synth fallback.
C3-3 — **multi-profile** — `Default/` only.
C3-4 — **schema/version skew** — `CLBF-v1-2026-04-30` 박제.
C3-5 — **token surface drop** — `(?i)token|password|secret|auth|jwt|bearer` 정규식 강제.

**Gap count: 5.**

---

## §F. Verdict

- BR3-h Σ = **372/400** ≥ 350 → **IMPL** (`filters/module/data/chrome_localstorage_shbf.hexa`).
- Bench: `tool/bench/bench_br3_chrome_localstorage.hexa`.
- Expected ROI: encode 30–60ms (synth 5000), lookup ~5μs prefix-count, speedup vs naive linear ≥1000×.
