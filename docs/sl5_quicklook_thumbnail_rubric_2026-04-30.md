# SL5 — QuickLook Thumbnail T2 Hash Dedup Filter Design Rubric (raw 240 V2, 400pt) — HOLD

- date: 2026-04-30
- author: airgenome design ledger (System Logs wave, SL5 site)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `sl5_quicklook_thumbnail_rubric_2026-04-30.rubric.jsonl`
- pattern parent: T2 hash dedup pattern (Tool result dedup C2 axis)
- scope: design phase only — **HOLD verdict, NO implementation**
- decision: 250/400 < 350 cut → HOLD

---

## §A. Rubric Block Table (raw 240 V2)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | T2 SHA-256 dedup + thumbnail row dict + read-only |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + blob_size + speedup + dedup ratio |
| B3 | enforcement-strength | 강제력 | 40 | self-fixture + magic + version pin |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa, 부수 효과 0, /tmp 격리 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome + anima 3-hop |
| B7 | emission-cost-bounded | 방출 비용 (V2) | 40 | payload ≤16KB + 1-pass |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty / missing / synth fallback |
| B9 | meta-rubric-finite | 메타 유한성 (V2) | 20 | 깊이≤2, self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

`~/Library/Caches/com.apple.QuickLook.thumbnailcache/`
- **DIRECTORY DOES NOT EXIST** on this Mac (current user has no QuickLook cache; macOS Sequoia may have moved the path or never populated it).
- alternate paths probed: `~/Library/Caches/com.apple.quicklook.*` — none found.
- system-level cache likely under `/private/var/folders/*/T/com.apple.QuickLook.*` (sip + 700 dir, root cap_mac required).

---

## §C. Candidate Score Table (raw 240 V2)

| Block | (a) sqlite QuickLook index parse | (b) raw thumbnail file enum |
|-------|----------------------------------|-----------------------------|
| B1 design-rigor (50) | 32 | 28 |
| B2 measurability (90) | 42 | 38 |
| B3 enforcement-strength (40) | 24 | 22 |
| B4 atomicity (40) | 32 | 30 |
| B5 observability (30) | 22 | 20 |
| B6 cross-repo (30) | 20 | 18 |
| B7 emission-cost (40) | 30 | 28 |
| B8 adversarial-resistance (40) | 30 | 28 |
| B9 meta-rubric-finite (20) | 18 | 16 |
| **Σ /400** | **250** | **228** |

Hybrid: 250 (a primary). Path absent → synth-only. T2 SHA-256 dedup pattern needs real per-thumbnail bytes; synth simulates content but not real workload distribution.

### Synthesis
**HOLD**: 250 < 350. Path-absent on probe target. Re-evaluate when:
1. user manually triggers QuickLook (e.g. spacebar preview) to populate the cache.
2. macOS reverts to user-readable cache directory.
3. `/private/var/folders/*/T/com.apple.QuickLook*` path becomes accessible.

Final SL5 score: **250/400** (cut ≥350 FAIL → HOLD).

---

## §D. Honest C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | Cache directory does not exist on this Mac — no real-probe possible. | high |
| G2 | Thumbnail bytes are PNG/JPEG; SHA-256 dedup is meaningful but resource-heavy. | medium |
| G3 | sqlite index in `index.sqlite` requires WAL-aware reader; readonly open of WAL is OK but parsing schema may rotate per macOS. | medium |
| G4 | Synth fallback over-represents uniformity (real workloads have heavy duplicate concentration in screenshots/icons). | medium |
| G5 | T2 dedup pattern parent is in-memory tool-result; disk-backed thumbnail dedup is cousin not sibling — pattern transfer is partial. | medium |

Gap count: **5**. HOLD verdict.

---

## §E. Cross-Repo Carve-Out (deferred)

Defer hive `.raw` ledger entry. Anima 3-hop (thumbnail hash → file path → recent doc) is interesting but predicated on real cache.
