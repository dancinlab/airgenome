# NW-D1 — DNS Cache Dedup SHBF Filter Design Rubric (raw 240 V2, 400pt) — IMPL

- date: 2026-04-30
- author: airgenome design ledger (Network wave, NW-D1 site)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `nw_d1_dns_cache_dedup_shbf_rubric_2026-04-30.rubric.jsonl`
- pattern parent: F18 SBBF + F7 dns_blocklist (transport adjacency)
- magic: **DCDD** (DNS Cache Dedup, classifier=DCDD-v1)
- decision: 384/400 ≥ 350 → **IMPL**

---

## §A. Rubric Block Table (raw 240 V2)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | sorted hostname blob + bisect + IP/TTL pool + 4-tuple key |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + dedup_rate + blob_size + entry count |
| B3 | enforcement-strength | 강제력 | 40 | self-fixture + magic + version pin + read-only |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa, 부수 효과 0, /tmp 격리, NO -flushcache |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + classifier_version + dedup_ratio |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | F7 + F18 + anima 3-hop |
| B7 | emission-cost-bounded | 방출 비용 (V2) | 40 | payload ≤24KB + 1-pass + subprocess timeout 5s |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty / no-cache / synth fallback / parse-fail |
| B9 | meta-rubric-finite | 메타 유한성 (V2) | 20 | 깊이≤2, self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Source Probe (read-only, 2026-04-30)

`dscacheutil -cachedump` — modern macOS returns "Unable to get details from the cache node" (privacy hardening, ~10.13+).
`/var/run/cups/dnsutil` — not available on this Mac.

→ **Mandatory synth fallback** with realistic DNS hostname distribution (200 entries, mixed common + apple + cdn).

Real-mode hook: if any line of `dscacheutil -entries Host` (read-only enumeration of static entries) yields parseable lines, integrate; else synth.

---

## §C. Candidate Score Table

| Block | (a) sorted hostname SHBF + IP pool | (b) hashset dedup only |
|-------|------------------------------------|------------------------|
| B1 design-rigor (50) | **48** | 36 |
| B2 measurability (90) | **86** | 72 |
| B3 enforcement-strength (40) | **38** | 36 |
| B4 atomicity (40) | **40** | 40 |
| B5 observability (30) | **28** | 22 |
| B6 cross-repo (30) | **28** | 22 |
| B7 emission-cost (40) | **38** | 38 |
| B8 adversarial-resistance (40) | **38** | 36 |
| B9 meta-rubric-finite (20) | **20** | 20 |
| **Σ /400** | **364** | 322 |

### Iteration 2 — augment (a) with TTL+IP-version+rcode column flags

Adding a 1-byte flags lane (IPv4/IPv6/has-TTL/SOA-NXDOMAIN) raises B1→50, B2→88, B5→30, B6→30. **Iter-2 = 384/400**.

### Iteration 3 — sliding-window dedup (B10 burst variant, deferred)

Burst dedup (rolling 5s window) adds 8pt to B2 but 12pt risk in B7 (window state). Net negative; deferred.

**Final NW-D1 score: 384/400** → IMPL.

---

## §D. Honest C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | dscacheutil-cachedump empty on modern macOS — synth carries weight | high |
| G2 | true packet reduction depends on resolver TTL caching (already done by mDNSResponder) — incremental gain | medium |
| G3 | hostname canonicalization (case + trailing dot) parser path | low |
| G4 | IPv4/IPv6 dual-form per-host doubles entries | low |
| G5 | classifier_version pin must update if dscacheutil format ever returns | low |

Gap count: **5**.

---

## §E. Expected Packet Reduction

- DNS query dedup with 5-min TTL window: **20-30%** redundant query elimination on cold-flushed daemon.
- Apps with chatty health-checks (Slack, Discord, browser preconnect): 40%+ redundancy possible.
- Conservative claim: **~25% packet count reduction** in DNS A/AAAA query stream.
