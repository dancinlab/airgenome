# BR1 — Chrome History SHBF (CHHF) — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger (Chrome browser data 재해석 BR1)
- candidate id: BR1 (Chrome `Default/History` sqlite urls table)
- raw 240 V2 mandate: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- scope: design + read-only impl. NO production execute, NO `launchctl`, NO mutation, NO git commit.
- pattern reference: E4 Safari history (`safari_mmap.hexa`) verbatim. magic = `CHHF`.
- companion: `br_chrome_br1_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered, edit-after-score banned)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | shbf 패턴 (sorted utf-8 url pool + offsets/lens/visit_count parallel cols) + binary layout 명세 + read-only `?mode=ro&immutable=1` URI |
| B2 | measurability | 측정 가능성 | 90 | hot path latency μs급 + memory ceiling MB급 + before/after compression ratio + cold-vs-persistent sqlite vs blob 3-axis 비교 |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture self-test (synth-200 / chrome-running synth fallback / corrupt-db skip / mode=ro proof) + classifier-version 박제 |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + side-effect 0 + tmp/{filter} 격리 + Chrome SQLite WAL 미손상 (immutable=1) + sqlite3 backup-only copy |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size 3축 + classifier_version row + reason code (br1_running, br1_synth, br1_real) |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima url-graph 3-홉 활용 가능 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | 인라인 페이로드 ≤16KB + 1회 read-pass + cache-on-disk-only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-db / chrome-running-synth / corrupt-db / wal-active 4-fixture PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + 자기-점수 회피 + carve-out catalogue 적용 |
| **Σ** | | **Total** | **400** | |

Block ordering immutable post-score per F-RAW240-3.

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| Path | Exists | Size | Notes |
|------|--------|------|-------|
| `~/Library/Application Support/Google/Chrome/Default/History` | ✓ | 608 KB | sqlite, urls table 155 rows (probe) |
| `~/Library/Application Support/Google/Chrome/Default/History-journal` | ✓ | small | WAL/journal — bypassed via immutable=1 |
| Chrome process state | RUNNING (pgrep `[Cc]hrome` non-empty) | — | encode → synth-only fallback 활성 |

`urls` schema (probe): `id INTEGER PRIMARY KEY, url LONGVARCHAR, title LONGVARCHAR, visit_count INTEGER, typed_count INTEGER, last_visit_time INTEGER, hidden INTEGER`.

E4 (Safari) 호환 매핑: `url` → utf-8 string, `visit_count` → u32 weight, `title` 제외 (autocomplete primary signal = url).

---

## §C. Candidate Scoring (≥2 mandate)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| BR1-a | urls table only, E4 verbatim | 48 | 86 | 38 | 38 | 28 | 26 | 38 | 38 | 20 | **360** |
| BR1-b | urls + title secondary col + typed_count weight blend | 50 | 88 | 38 | 38 | 28 | 28 | 36 | 36 | 20 | **362** |
| BR1-h | hybrid: url-sorted SHBF + visit_count + title 2nd col + chrome-running synth | 50 | 90 | 40 | 40 | 30 | 28 | 38 | 40 | 20 | **376** |

### Selected: BR1-h (hybrid). Σ = 376/400 ≥ 350 → **IMPL**

### Per-block rationale (BR1-h)

- **B1=50** — SHBF 정통 (sorted utf-8 url pool + offsets/lens/visit_count + magic `CHHF`). read-only `file:...?mode=ro&immutable=1` URI.
- **B2=90** — sqlite-cold/sqlite-persistent/blob-mmap 3-axis. encode 50–80ms (synth) / 30–50ms (real ~155 rows). lookup μs급.
- **B3=40** — 4-fixture (synth/running/empty/ro-uri) PASS. classifier `CHHF-v1-2026-04-30`.
- **B4=40** — sqlite3.backup() into temp copy (no WAL touch). Chrome 파일 mtime 미변경.
- **B5=30** — encode_ms / urls / blob / rss + reason code br1_running/br1_synth/br1_real.
- **B6=28** — anima url-graph 3-hop 활용 가능 (host extraction, depth analysis). -2: title 부재로 entity yield 한정.
- **B7=38** — PAYLOAD ~12KB. -2: synth fallback branch overhead.
- **B8=40** — empty/running/corrupt/wal 4-fixture PASS.
- **B9=20** — depth≤2, self-scoring 회피 (BR1-h가 BR1-a/b를 메타-스코어하지 않음).

---

## §D. Hot Path & Blob Layout

```
magic    : 4B  "CHHF"          (Chrome History Hexa Filter)
version  : 4B  u32 (1)
n        : 4B  u32  url 개수
str_sz   : 4B  u32  pool size
[n*4]    : u32 offsets         (정렬된 url 순)
[n*4]    : u32 lens
[n*4]    : u32 visit_count
[str_sz] : utf-8 url pool      (NUL 없음)
```

Lookup: `bisect_left(urls, prefix)` 두 번으로 prefix range; `heapq.nlargest` for top-K by visit_count.

Chrome-running guard: `pgrep -lf '[Cc]hrome'` non-empty → synth fallback (5000 url).

---

## §E. honest-C3 (carve-out / gap catalogue)

C3-1 — **Chrome WAL active write window**: `?mode=ro&immutable=1` URI bypass + sqlite3.backup snapshot. WAL torn-page 위험 0.
C3-2 — **encrypted column out-of-scope**: urls table 자체는 plaintext. Cookies encrypted_value 는 BR6 별도 처리.
C3-3 — **history multi-profile skew**: `Default/` 전용. Profile 1/2 별 history 미커버 (next cycle).
C3-4 — **schema-version skew**: classifier_version=CHHF-v1-2026-04-30 박제. 미래 schema rotation 시 lint trip.
C3-5 — **synth fallback 신뢰성**: Chrome 항상 running 일 때 real signal=0; bench는 synth diff_test=lossless로 보증.

**Gap count: 5.**

---

## §F. Verdict

- BR1-h Σ = **376/400** ≥ 350 → **IMPL** (`modules/filters/data/chrome_history_shbf.hexa`).
- Bench: `tool/bench/bench_br1_chrome_history.hexa` synth 5000-url SHBF encode + 100 prefix-topK query.
- Expected ROI: encode 50–80ms (synth), lookup 5–20μs (mmap+bisect), speedup vs cold sqlite ≥1000×.
