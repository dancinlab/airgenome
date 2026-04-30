# SL4 — /etc/hosts File mmap+bisect Filter Design Rubric (raw 240 V2, 400pt) — HOLD

- date: 2026-04-30
- author: airgenome design ledger (System Logs wave, SL4 site)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `sl4_hosts_file_mmap_rubric_2026-04-30.rubric.jsonl`
- pattern parent: raw 47 cross-repo high (small mmap + bisect)
- scope: design phase only — **HOLD verdict, NO implementation**
- decision: 226/400 < 350 cut → HOLD

---

## §A. Rubric Block Table (raw 240 V2)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | mmap+bisect + IP/host pool + read-only |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + blob_size + speedup + entry count |
| B3 | enforcement-strength | 강제력 | 40 | self-fixture + magic + version pin |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa, 부수 효과 0, /tmp 격리 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | raw 47 + airgenome filter + anima 3-hop |
| B7 | emission-cost-bounded | 방출 비용 (V2) | 40 | payload ≤16KB + 1-pass |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty / missing / synth fallback |
| B9 | meta-rubric-finite | 메타 유한성 (V2) | 20 | 깊이≤2, self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

`/etc/hosts`
- size: 339 B
- mode: 644 root:wheel — readable by any user
- line count: 12 (mostly comments + 4 active mappings: localhost / broadcasthost)

Active host entries (excluding comments/blank): **~3–4 rows** on this Mac. Even maximal user-augmented hosts files cap at ~50–500 rows.

---

## §C. Candidate Score Table (raw 240 V2)

| Block | (a) mmap + bisect | (b) full read + dict |
|-------|--------------------|----------------------|
| B1 design-rigor (50) | 28 | 26 |
| B2 measurability (90) | 30 | 32 |
| B3 enforcement-strength (40) | 22 | 22 |
| B4 atomicity (40) | 32 | 32 |
| B5 observability (30) | 20 | 22 |
| B6 cross-repo (30) | 22 | 24 |
| B7 emission-cost (40) | 28 | 30 |
| B8 adversarial-resistance (40) | 28 | 28 |
| B9 meta-rubric-finite (20) | 18 | 18 |
| **Σ /400** | **228** | **234** |

Hybrid: 226. Both candidates degenerate at n=12: linear `open().read()+split()` already takes <50 μs cold; bisect-on-12 saves ~5 μs at most. Speedup ratio < 2× — falls below B2 만점 cut.

### Synthesis
**HOLD**: 226 < 350. Root cause: file is too small for mmap+bisect to win (degenerate case of raw 47 pattern). The pattern shines at n>1000; /etc/hosts is structurally bounded. Re-evaluate if:
1. ad-blocker hosts file (Steven Black list, ~150K lines) is opted in → IMPL ceiling jumps to ~370.
2. user merges multiple hosts sources → re-score required.

Final SL4 score: **226/400** (cut ≥350 FAIL → HOLD).

---

## §D. Honest C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | n=12 is too small to amortize blob encode + mmap setup. | high |
| G2 | hosts comment vs entry parsing is non-trivial (inline `#`). | low |
| G3 | IPv4/IPv6 dual-form storage doubles entry count without ROI. | low |
| G4 | If ad-blocker list integrated, blob ROI flips to high (carve-out). | medium |
| G5 | hosts mtime is always-fresh; cache invalidation must check mtime. | low |

Gap count: **5**. HOLD verdict reflects intrinsic n smallness.

---

## §E. Cross-Repo Carve-Out (deferred)

raw 47 cross-repo high signal acknowledged, but axis maps to large-host-list scenarios (DNS blocklist filter F7 already covers this in airgenome). SL4 is redundant against F7 at typical n.
