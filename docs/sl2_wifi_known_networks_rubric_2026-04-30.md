# SL2 — Wi-Fi Known Networks Filter Design Rubric (raw 240 V2, 400pt) — HOLD

- date: 2026-04-30
- author: airgenome design ledger (System Logs wave, SL2 site)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `sl2_wifi_known_networks_rubric_2026-04-30.rubric.jsonl`
- pattern parent: K2 KSFL bisect axis (one-shot enumeration)
- scope: design phase only — **HOLD verdict, NO implementation**
- decision: 241/400 < 350 cut → HOLD per raw 240 V2 design discipline

---

## §A. Rubric Block Table (raw 240 V2, ordering immutable post-score)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | K2 KSFL + ssid pool + read-only |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + blob_size + speedup ratio + ssid count |
| B3 | enforcement-strength | 강제력 | 40 | self-fixture + magic check + version pin |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa, 부수 효과 0, /tmp blob 격리 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + source kind + classifier_version |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima 3-hop |
| B7 | emission-cost-bounded | 방출 비용 (V2) | 40 | payload ≤16KB + 1-pass + /tmp |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty / missing / corrupt / synth-fallback |
| B9 | meta-rubric-finite | 메타 유한성 (V2) | 20 | 깊이≤2, self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

`/Library/Preferences/com.apple.wifi.known-networks.plist`
- size: 8320 B
- owner: `root:wheel`, mode `600`
- read attempt as user `ghost`: **PERMISSION DENIED** (`couldn't be opened because you don't have permission to view it`)
- legacy `~/Library/Preferences/com.apple.airport.preferences.plist`: **NOT PRESENT** (Sequoia migrated)

Sudo-confirmed schema (out-of-band): `wifi.network.ssid.<NAME>` keys with `AddReason`, `AddedAt`, `LastJoinedAt` sub-fields.

---

## §C. Candidate Score Table (raw 240 V2, BEFORE descriptions)

| Block | (a) plistlib + walk | (b) raw byte SSID extraction |
|-------|---------------------|------------------------------|
| B1 design-rigor (50) | 32 | 28 |
| B2 measurability (90) | 42 | 38 |
| B3 enforcement-strength (40) | 24 | 22 |
| B4 atomicity (40) | 36 | 35 |
| B5 observability (30) | 24 | 22 |
| B6 cross-repo (30) | 20 | 18 |
| B7 emission-cost (40) | 30 | 28 |
| B8 adversarial-resistance (40) | 28 | 26 |
| B9 meta-rubric-finite (20) | 18 | 16 |
| **Σ /400** | **254** | **233** |

Hybrid: (a) primary blocked by 600 perms; synth-only fallback yields no real-probe ROI = **241/400**.

### Synthesis (만점 ≥350/400)
**HOLD**: 241 < 350. Root cause: read-blocked (`root:wheel 600`), and synth-only filter contributes near-zero real-world ROI. Re-evaluate when:
1. user explicitly grants sudo cat → /tmp shadow (out-of-policy, likely never).
2. macOS schema migrates to user-readable location (low probability).
3. user provides a one-time SSID list export (manual carve-out).

Final SL2 score: **241/400** (cut ≥350 FAIL → HOLD).

---

## §D. Honest C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | Read-blocked at OS level; no filter possible without sudo. | high |
| G2 | Synth-only filter would mislead consumers (ssid list ≠ user's real list). | high |
| G3 | No alternate readable surface (CoreWLAN private API requires entitlement). | medium |
| G4 | If we ever escalated, BSSID values are PII-equivalent — must scrub before blob. | high |
| G5 | macOS Sequoia changed the file from per-user to system-wide; future migration risk. | low |

Gap count: **5**. HOLD verdict eliminates G1, G2, G4 from immediate concern.

---

## §E. Cross-Repo Carve-Out (deferred)

Defer hive `.raw` ledger entry until either real-read becomes feasible or user opts into a manual SSID seed file.
