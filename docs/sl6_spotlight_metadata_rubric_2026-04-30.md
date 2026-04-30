# SL6 — Spotlight Metadata Filter Design Rubric (raw 240 V2, 400pt) — HOLD

- date: 2026-04-30
- author: airgenome design ledger (System Logs wave, SL6 site)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `sl6_spotlight_metadata_rubric_2026-04-30.rubric.jsonl`
- pattern parent: F18 SBBF + columnar projection (column-oriented metadata blob)
- scope: design phase only — **HOLD verdict, NO implementation** (TCC denied; synth-only fallback is policy-permitted but ROI-poor)
- decision: 242/400 < 350 cut → HOLD

---

## §A. Rubric Block Table (raw 240 V2)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | columnar metadata + path/kind/size pool + read-only |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + blob_size + speedup + entry count |
| B3 | enforcement-strength | 강제력 | 40 | self-fixture + magic + version pin |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa, 부수 효과 0, /tmp 격리 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version + tcc_denied flag |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome + anima 3-hop |
| B7 | emission-cost-bounded | 방출 비용 (V2) | 40 | payload ≤16KB + 1-pass |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty / TCC-denied / synth fallback PASS |
| B9 | meta-rubric-finite | 메타 유한성 (V2) | 20 | 깊이≤2, self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

| Path | Result |
|------|--------|
| `/.Spotlight-V100/` | **DOES NOT EXIST** at root (Sequoia firmlinks moved data volume) |
| `/System/Volumes/Data/.Spotlight-V100` | **PERMISSION DENIED** (TCC/SIP) |
| `/Volumes/Macintosh HD/.Spotlight-V100` | symlinked to `/`; same denial |
| `/Volumes/Game Porting Toolkit/.Spotlight-V100` | not visible |
| `mdfind` subprocess | available but spawns subprocess + breaks B4 atomicity |

TCC-denied confirmed. Per spec: synth-only fallback permitted.

---

## §C. Candidate Score Table (raw 240 V2)

| Block | (a) raw store_db parse | (b) mdfind subprocess | (c) synth-only |
|-------|------------------------|------------------------|----------------|
| B1 design-rigor (50) | 36 | 30 | 26 |
| B2 measurability (90) | 50 | 42 | 32 |
| B3 enforcement-strength (40) | 26 | 22 | 22 |
| B4 atomicity (40) | 32 | 26 | 36 |
| B5 observability (30) | 24 | 22 | 22 |
| B6 cross-repo (30) | 22 | 20 | 16 |
| B7 emission-cost (40) | 30 | 26 | 32 |
| B8 adversarial-resistance (40) | 32 | 28 | 34 |
| B9 meta-rubric-finite (20) | 18 | 18 | 18 |
| **Σ /400** | **270** | **234** | **238** |

Hybrid: (a) blocked by TCC; (b) violates B4; (c) synth-only contributes near-zero real-world ROI. Effective hybrid score = **242/400** (TCC-aware c with marginal a-design preserved for future opt-in).

### Synthesis
**HOLD**: 242 < 350. Re-evaluate when:
1. user grants Full Disk Access to the hexa runner (TCC opt-in) → score ~310, still below cut without store_db schema reverse-engineer.
2. user opts into the mdfind-subprocess B4 carve-out → score ~310, atomicity warning.
3. an indexed-attribute subset (mdls per-file) becomes the real workload — different filter design.

Final SL6 score: **242/400** (cut ≥350 FAIL → HOLD). Synth fallback policy preserved but not implemented.

---

## §D. Honest C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | TCC-denied at all readable paths; only mdfind subprocess works. | high |
| G2 | store_db / store.db schema is undocumented Apple-internal — reverse-engineer cost very high. | high |
| G3 | mdfind subprocess violates B4 atomicity (subprocess + non-deterministic output). | medium |
| G4 | Synth-only filter would mislead consumers (no real Spotlight content). | high |
| G5 | Spotlight kind enum is large (~200+ UTI types); column-dict cardinality is heavy. | medium |

Gap count: **5**. HOLD verdict.

---

## §E. Cross-Repo Carve-Out (deferred)

Defer hive `.raw` ledger. anima 3-hop (Spotlight kMDItemPath → recent file → session) is intriguing but predicated on TCC opt-in.
