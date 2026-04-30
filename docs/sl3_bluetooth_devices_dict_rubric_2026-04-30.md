# SL3 — Bluetooth Devices Dictionary Filter Design Rubric (raw 240 V2, 400pt) — HOLD

- date: 2026-04-30
- author: airgenome design ledger (System Logs wave, SL3 site)
- mandate: raw 240 V2 — 9 named blocks, 만점 cut per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `sl3_bluetooth_devices_dict_rubric_2026-04-30.rubric.jsonl`
- pattern parent: MA3 #99 column-dict (device list dict)
- scope: design phase only — **HOLD verdict, NO implementation**
- decision: 227/400 < 350 cut → HOLD

---

## §A. Rubric Block Table (raw 240 V2)

| # | Block ID | Name | Max | 만점 cut |
|---|----------|------|-----|----------|
| B1 | design-rigor | 설계 엄밀성 | 50 | column-dict + device address pool + read-only |
| B2 | measurability | 측정 가능성 | 90 | per-query μs + blob_size + speedup + device count |
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

| Path | Size | Owner | Schema |
|------|------|-------|--------|
| /Library/Preferences/com.apple.Bluetooth.plist | 321 B | root:wheel 644 | Auto-seek toggles + game controller flags only — **no PairedDevices key** |
| ~/Library/Preferences/com.apple.Bluetooth.plist | 75 B | ghost:staff 600 | `lastNowPlayedTime` only — **no device list** |

The actual paired-device cache lives in `/Library/Preferences/com.apple.MobileBluetooth.plist` and `/private/var/db/Bluetooth/` (root-owned 600); macOS Sequoia moved the visible plist to a system-protected location.

---

## §C. Candidate Score Table (raw 240 V2)

| Block | (a) plistlib walk visible plists | (b) ioreg subprocess parse |
|-------|----------------------------------|----------------------------|
| B1 design-rigor (50) | 28 | 26 |
| B2 measurability (90) | 38 | 32 |
| B3 enforcement-strength (40) | 22 | 20 |
| B4 atomicity (40) | 32 | 28 |
| B5 observability (30) | 22 | 20 |
| B6 cross-repo (30) | 18 | 16 |
| B7 emission-cost (40) | 28 | 24 |
| B8 adversarial-resistance (40) | 28 | 24 |
| B9 meta-rubric-finite (20) | 18 | 16 |
| **Σ /400** | **234** | **206** |

Hybrid (a)+(b)= 227. (a) reads only meta toggles (no device list). (b) `ioreg -l -p IOBluetooth` works but spawns subprocess (~30 ms cold) and parsing is brittle.

### Synthesis
**HOLD**: 227 < 350. Visible plist contains no device list (schema mismatch); the ioreg subprocess path violates atomicity (B4 cost) and offers low ROI (most users have ≤5 paired devices — speedup matters at n>50). Re-evaluate when:
1. user opts into the ioreg-subprocess path (B4 carve-out).
2. macOS exposes paired-device list at a user-readable plist (low probability).

Final SL3 score: **227/400** (cut ≥350 FAIL → HOLD).

---

## §D. Honest C3 (gap audit)

| # | Gap | Severity |
|---|-----|----------|
| G1 | Visible Bluetooth.plist lacks PairedDevices key on Sequoia. | high |
| G2 | ioreg subprocess violates B4 atomicity (subprocess + non-deterministic output). | medium |
| G3 | Bluetooth address (BD_ADDR) is PII-equivalent; must scrub. | high |
| G4 | Device count typically ≤10; ROI ceiling is intrinsically low. | medium |
| G5 | /private/var/db/Bluetooth requires sudo; same class as SL2. | high |

Gap count: **5**. HOLD verdict.

---

## §E. Cross-Repo Carve-Out (deferred)

Defer hive `.raw` ledger entry. Filter holds at design phase pending readable schema discovery.
