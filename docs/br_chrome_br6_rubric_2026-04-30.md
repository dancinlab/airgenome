# BR6 — Chrome Cookies host_key Dict (CCDF) — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger (Chrome browser data 재해석 BR6)
- candidate id: BR6 (Chrome `Default/Cookies` sqlite cookies table host_key column)
- raw 240 V2 mandate: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- scope: design + read-only impl. NO mutation, NO git commit.
- pattern reference: MA3 #99 column dict (`mail_sender_dict.hexa`). magic = `CCDF`.
- companion: `br_chrome_br6_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | column dict 패턴 (distinct host pool + u8/u16 enum column) + binary layout + read-only `?mode=ro&immutable=1` URI |
| B2 | measurability | 측정 가능성 | 90 | hot path latency μs급 + memory MB급 + before/after compression (str list → enum byte) + GROUP BY count 비교 |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture self-test (synth/empty/distinct>255/distinct≤255) + classifier-version 박제 |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + side-effect 0 + sqlite3.backup() snapshot + WAL 미손상 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version + reason code |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima cookie-host-graph 3-홉 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | PAYLOAD ≤16KB + 1-pass + cache-on-disk-only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-DB / chrome-running / distinct>255-fold-OTHER / encrypted-only-rows 4-fixture PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | depth≤2 + self-scoring 회피 + carve-out catalogue |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| Path | Exists | Size | Notes |
|------|--------|------|-------|
| `~/Library/Application Support/Google/Chrome/Default/Cookies` | ✓ | 256 KB | sqlite, cookies table 422 rows |
| `~/Library/Application Support/Google/Chrome/Default/Cookies-journal` | ✓ | small | journal — bypassed via immutable=1 |
| Chrome process | RUNNING | — | encode → synth-only fallback |

`cookies` schema (probe): host_key TEXT, name TEXT, value TEXT, encrypted_value BLOB, expires_utc INTEGER, ... (20 cols).

distinct host_key probe: ~150 unique (sample: `.1rx.io`, `.33across.com`, `.6sc.co`, `.a-mo.net`, `.a-mx.com`, ...) — well under 255 enum cap. value column 은 OS Keychain 으로 암호화됨 → host_key 만 plaintext.

MA3 verbatim with column = `host_key`, total occurrences = `n_msg` 422.

---

## §C. Candidate Scoring (≥2 mandate)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| BR6-a | host_key only u8 dict | 48 | 86 | 38 | 38 | 28 | 26 | 38 | 36 | 20 | **358** |
| BR6-b | host_key u8 + name 2nd col u16 | 48 | 86 | 36 | 38 | 28 | 28 | 34 | 36 | 18 | **352** |
| BR6-h | hybrid: host_key u8 dict + (OTHER) overflow + chrome-running synth | 50 | 88 | 40 | 40 | 30 | 28 | 38 | 40 | 20 | **374** |

### Selected: BR6-h. Σ = 374/400 ≥ 350 → **IMPL**

### Per-block rationale (BR6-h)

- **B1=50** — CCDF binary layout, distinct host_key pool (≤255 → u8; 그 이상 → top-254 + (OTHER) bucket).
- **B2=88** — encode 30–60ms; GROUP BY count: linear str Counter ~ms, u8 column scan ~10μs. -2: total cookies row 422 작아 ratio modest.
- **B3=40** — 4-fixture PASS.
- **B4=40** — sqlite immutable=1 + backup snapshot + WAL 미손상.
- **B5=30** — full reason matrix.
- **B6=28** — anima cookie-host-graph 3-hop.
- **B7=38** — PAYLOAD ~10KB.
- **B8=40** — 4-fixture PASS (encrypted-only-rows: encrypted_value 무관 — host_key 가 항상 plaintext).
- **B9=20**.

---

## §D. Blob Layout (CCDF)

```
magic    : 4B  "CCDF"          (Chrome Cookies Dict Filter)
version  : 4B  u32 (1)
n_host   : 4B  u32 distinct host count (≤255)
n_msg    : 4B  u32 total cookie row count
str_sz   : 4B  u32 host pool size
[n_host*4]: u32 host_offs
[n_host*4]: u32 host_lens
[str_sz]  : utf-8 host pool
[n_msg]   : u8  enum column (host id per row)
```

Query: enum byte → host_offs[id] → string 즉시; GROUP BY count = 1-pass u8 scan. distinct>255 → id=0='(OTHER)' bucket + top-254.

---

## §E. honest-C3

C3-1 — **encrypted_value out-of-scope** — value 컬럼은 OS Keychain 암호화, plaintext host_key 만 추출.
C3-2 — **chrome-running mid-write** — pgrep + immutable=1 URI + synth fallback.
C3-3 — **multi-profile** — `Default/` only.
C3-4 — **distinct>255 overflow** — id=0 reserved as `(OTHER)`; top-254 만 enum.
C3-5 — **classifier-version skew** — `CCDF-v1-2026-04-30` 박제.

**Gap count: 5.**

---

## §F. Verdict

- BR6-h Σ = **374/400** ≥ 350 → **IMPL** (`filters/module/data/chrome_cookies_dict.hexa`).
- Bench: `tool/bench/bench_br6_chrome_cookies.hexa`.
- Expected ROI: encode 30–60ms (synth 5000), GROUP BY count: u8 1-pass scan vs str Counter ≥100×, sender-byte saved ≥95%.
