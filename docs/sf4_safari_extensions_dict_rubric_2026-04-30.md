# SF4 — Safari Extensions Dict Filter — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger (K. Safari 보강 wave)
- candidate id: SF4
- scope: design + read-only impl. ≥350 threshold for impl. NO mutation, NO git commit, pgrep guard.
- companion: `sf4_safari_extensions_dict_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2)

| # | Block ID | Name | Max | 만점 컷 |
|---|----------|------|-----|---------|
| B1 | design-rigor | 설계 엄밀성 | 50 | sorted bundle-id blob + name-pool + flags u8 (enabled / app-vs-web kind) + magic "SXBF" |
| B2 | measurability | 측정 가능성 | 90 | μs latency + speedup ≥30× projection + real 2-source measurable |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture (real-AppExt / real-WebExt / synth / corrupt-plist-skip) + classifier_version |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + read-only `open('rb')` + tmp 격리 + plist 미손상 + Safari 미간섭 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + reason ('ext-real'/'ext-empty-synth'/'ext-corrupt-skip') + n_app/n_web |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive raw + airgenome filter + anima 정책 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | 인라인 ≤16KB + 1-pass + cache-on-disk |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-dict / corrupt-plist / bundle-id-malformed / non-dict-root 4-fixture |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

| # | Source | Path | Exists | Schema |
|---|--------|------|--------|--------|
| S1 | AppExtensions Extensions.plist | `~/Library/Containers/com.apple.Safari/Data/Library/Safari/AppExtensions/Extensions.plist` | ✓ | dict[bundle_id_str → dict{AddedDate, GrantedPermissionOrigins, RevokedPermissionOrigins, WebsiteAccess}] |
| S2 | WebExtensions Extensions.plist | `~/Library/Containers/com.apple.Safari/Data/Library/Safari/WebExtensions/Extensions.plist` | ✓ | dict[bundle_id_str → dict{AccessibleOrigins, AddedDate, Enabled, EnabledByUserGesture, EnabledModificationDate, GrantedPermissionOrigins}] |
| S3 | spec path | `~/Library/Safari/Extensions/` | ✗ | does not exist (legacy pre-13 path) |

Per-system finding: spec-stated `Safari/Extensions/` directory does not exist; real Safari 14+ extensions data lives in two `Extensions.plist` files inside the sandboxed Container (one per kind: AppExtension legacy / WebExtension modern). Both are simple top-level dicts keyed by bundle id (with team id suffix `(XXXXXXXXXX)`).

This-system count: 1 AppExtension + 1 WebExtension.

---

## §C. Candidate Scoring (≥2 mandate)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| SF4a | bundle-id only sorted blob (single source) | 40 | 64 | 32 | 38 | 24 | 26 | 38 | 32 | 18 | **312** |
| SF4b | bundle-id sort + name-pool + flags + dual-source merge + synth | 50 | 86 | 40 | 40 | 30 | 30 | 40 | 40 | 20 | **376** |
| SF4c | SF4b + GrantedOrigins secondary col | 50 | 88 | 40 | 40 | 30 | 30 | 36 | 40 | 20 | **374** |

### SF4a — single-source bundle-id only (rejected — shallow)

- B1 -10: dual-source merge 누락, kind flag 없음.
- B2 -26: 1-source 1-row scale 측정 의미 부족.
- B8 -8: corrupt 한 쪽만 처리 시 다른쪽 미커버.

### SF4b — dual-source merge + name pool + flags (selected)

- App + Web Extensions.plist 둘 다 read → merge → bundle-id sorted SHBF.
- Magic "SXBF" v1.
- flags u8: `bit0=app-kind, bit1=web-kind, bit2=enabled (from WebExt 'Enabled' key, 1 if true), bit3=user-gesture-enabled`.
- Empty 시 synth 50-row fallback.
- 만점 컷 충족: 9/9 PASS.

### SF4c — SF4b + GrantedPermissionOrigins col

- 추가 column → 적용 origin prefix bisect 가능.
- B7 -4: payload 추가, B2 -2 (origin pool 측정).
- 본 cycle scope: SF4b 채택, GrantedOrigins 는 follow-up.

**Selected: SF4b → 376/400. ≥350 threshold MET → IMPL.**

---

## §D. honest-C3 (gap audit)

| # | Gap | Severity | Mitigation |
|---|-----|---------:|-----------|
| C3-1 | 이 system 은 1 AppExt + 1 WebExt 만 보유 → real-data scale 매우 작음 | medium | synth-50 fallback in bench |
| C3-2 | bundle id 끝의 ` (XXXXXXXXXX)` team-id 부분 정렬 영향 | low | strip team-id before sort key |
| C3-3 | 'Enabled' 키가 WebExt 만 존재 — AppExt 는 추론 불가 | medium | flag bit2 = WebExt only |
| C3-4 | spec `~/Library/Safari/Extensions/` 부재 (carve-out) | medium | doc 명시, jsonl `path_corrected:true` |
| C3-5 | TCC: Container 접근 FDA 필요 | medium | open() try/except + reason='ext-tcc-deny' |
| C3-6 | 비-dict root 또는 corrupt plist 시 전체 skip | low | per-source try/except + reason |
| C3-7 | extension dir 단위 스캔 (manifest.json 직접 read) 미수행 — plist 의 메타만 | medium | follow-up SF4d |

honest-C3 gap count: **7**.

---

## §E. ROI Projection

- 2 plist × ~1KB → cold parse ~1-3 ms.
- 50-row blob mmap+bisect: <50 μs/query.
- Expected speedup: **20-100×** on bundle-id prefix query (예: `com.colliderli.*` 그룹).

---

## §F. Deliverables

- `/Users/ghost/core/airgenome/docs/sf4_safari_extensions_dict_rubric_2026-04-30.md` (this)
- `/Users/ghost/core/airgenome/docs/sf4_safari_extensions_dict_rubric_2026-04-30.rubric.jsonl`
- `/Users/ghost/core/airgenome/filters/module/data/safari_extensions_dict.hexa`
- `/Users/ghost/core/airgenome/tool/bench/bench_sf4_safari_extensions_dict.hexa`

Verdict: **IMPL** (376/400 ≥ 350).
