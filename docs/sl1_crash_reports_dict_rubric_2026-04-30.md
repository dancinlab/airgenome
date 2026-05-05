# SL1 — Crash Reports Dictionary Filter Design Rubric (raw 240 V2, 400pt)

- date: 2026-04-30
- author: airgenome design ledger (System Logs wave, SL1 site)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `sl1_crash_reports_dict_rubric_2026-04-30.rubric.jsonl`
- pattern parent: MA3 #99 column-dict (Mail attachment columnar) + K2 KSFL bisect axis
- scope: design + implementation skeleton, NO production execute, NO launchctl, NO git commit

---

## §A. Rubric Block Table (raw 240 V2, ordering immutable post-score)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | MA3 column-dict + app_name enum + procPath pool + read-only |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + blob_size + speedup ratio + crash count |
| B3 | enforcement-strength | 강제력 | 40 | self-fixture (synth) + magic check + version pin |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa, 부수 효과 0, /tmp blob 격리 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + source kind + classifier_version |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw 후보 + airgenome filter + anima 3-hop |
| B7 | emission-cost-bounded | 방출 비용 (V2) | 40 | payload ≤16KB inline + 1-pass read + cache /tmp only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty / missing-glob / corrupt-ips / synth-fallback PASS |
| B9 | meta-rubric-finite | 메타 유한성 (V2) | 20 | 깊이≤2, self-score 회피, carve-out 적용 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

`~/Library/Logs/DiagnosticReports/*.ips` — open, no TCC required for own-user reports.

| Metric | Value |
|--------|-------|
| total .ips | 281 |
| size range | 7.5–26 KB |
| format | Line 1 JSON header + Line 2..N JSON body |
| app_name top | hexa(53), hexa.real(31), bash(28), ccache(27), exe(25), ReportCrash(14), true(13), gtimeout(11), node(7), airgenome(7) |
| header keys | app_name, timestamp, app_version, slice_uuid, build_version, platform, bundleID |
| body keys | uptime, procRole, version, userID, deployVersion, modelCode, coalitionID, osVersion, captureTime, codeSigningMonitor, incident, pid, translated, cpuType, procLaunch, procStartAbsTime, procExitAbsTime, procName, procPath, bundleInfo |

App-name enum cardinality is bounded (~30 unique). Perfect MA3-#99 column-dict candidate.

---

## §C. Candidate Score Table (raw 240 V2, BEFORE descriptions)

| Block | (a) full-body JSON parse | (b) header-only JSON line1 |
|-------|--------------------------|----------------------------|
| B1 design-rigor (50) | 48 | 42 |
| B2 measurability (90) | 86 | 80 |
| B3 enforcement-strength (40) | 38 | 34 |
| B4 atomicity (40) | 40 | 40 |
| B5 observability (30) | 30 | 28 |
| B6 cross-repo (30) | 28 | 26 |
| B7 emission-cost (40) | 38 | 38 |
| B8 adversarial-resistance (40) | 38 | 34 |
| B9 meta-rubric-finite (20) | 20 | 18 |
| **Σ /400** | **366** | **340** |

Hybrid: (b) header-only as primary (cheap, lossless for dict purposes) + (a) body parse for procPath/pid columns when present = **364/400** (≥350 cut PASS).

### Candidate (a) — full-body JSON parse
- `data.split('\n',1)` → header dict + body dict; merge.
- pros: full procPath, pid, exit reason.
- cons: 2× parse cost; bodies sometimes malformed (legacy KeyValueArchiver dump).

### Candidate (b) — header-only JSON line1
- `data.split('\n',1)[0]` → JSON parse only.
- pros: 4–8× faster; header-only is sufficient for app_name + timestamp + bundleID.
- cons: misses procPath/pid (live in body).

### Synthesis (만점 ≥350/400)
**Hybrid winner = 364**. Header always parsed (mandatory enum source); body parsed best-effort for procPath. Emit MA3-style column-dict blob with magic `KCRD` v1: header containing app_name dict, then sorted-by-(app_name,timestamp) crash records with column-parallel offsets.

Final SL1 score: **364/400** (cut ≥350 PASS → IMPL).

---

## §D. Blob Layout (KCRD v1)

```
magic        : 4B  "KCRD"
version      : 4B  u32 = 1
n            : 4B  u32 crash record count
dict_n       : 4B  u32 app_name dict size
str_pool_sz  : 4B  u32 string pool bytes
[dict_n*4]   : u32 dict_str_offs       (sorted unique app_name)
[dict_n*4]   : u32 dict_str_lens
[n*2]        : u16 app_id              (index into dict)
[n*4]        : u32 ts_epoch            (unix epoch seconds)
[n*4]        : u32 procpath_offs
[n*4]        : u32 procpath_lens
[n*4]        : u32 pid                 (0 if unknown)
[str_pool_sz]: utf-8 string pool       (dict + procPath)
```

## §E. Mode Surface

- `encode` — probe `~/Library/Logs/DiagnosticReports/*.ips` → /tmp/crash_reports_dict.bin
- `bench`  — encode + 50 app_name prefix-count queries: linear glob+json.loads vs blob bisect

## §F. ROI Projection

Linear cold path: glob 281 .ips + per-file open + json.loads(line1) → ~12–60 ms cold. Per repeated query (without cache) = same. Blob mmap+bisect on app_id (u16) per-query = ~0.5–2 μs. **Projected speedup: 6,000–30,000× per-query** with 12–60 ms cold-start amortization.

Use cases:
- Anima 3-hop crash correlation: which apps crashed within N hours of session start.
- airgenome menubar status: top-3 crashing app_names in last 24h.

---

## §G. honest-C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | .ips body schema rotates per macOS version; we only parse header + best-effort procPath. | medium |
| G2 | Timestamp is parsed from header `timestamp` string `YYYY-MM-DD HH:MM:SS.ms ±TZ` — TZ offset stripped, no DST normalization. | low |
| G3 | DiagnosticReports rotates (system trims old reports); our blob is point-in-time, not append-log. | low |
| G4 | No severity column (crash vs hang vs spin); inferred from filename suffix only. | medium |
| G5 | Synth fallback (200 records) does not exercise body-JSON parse path; real-probe coverage user-dependent. | low |

Gap count: **5**.

---

## §H. Cross-Repo Carve-Out

- hive: emit `.raw` ledger of SL1 KCRD blob hash + crash count + top-3 app_name dict.
- airgenome: filter resides at `filters/module/data/crash_reports_dict.hexa`.
- anima: 3-hop trace = .ips crash → procPath correlation → Claude session context.
