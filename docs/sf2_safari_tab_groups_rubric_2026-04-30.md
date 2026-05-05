# SF2 — Safari Tab Groups Filter — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger (K. Safari 보강 wave)
- candidate id: SF2 (TabGroups source)
- scope: design + read-only impl. ≥350 threshold for impl. NO mutation, NO git commit, pgrep guard.
- companion: `sf2_safari_tab_groups_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered)

| # | Block ID | Name | Max | 만점 컷 |
|---|----------|------|-----|---------|
| B1 | design-rigor | 설계 엄밀성 | 50 | TabGroup→Tab 2-tier blob layout 명세 + group-name index + tab-url string pool |
| B2 | measurability | 측정 가능성 | 90 | μs latency target + speedup ≥30× projection + real-source-reachability check |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture (real-probe / synth-fallback / safari-running-skip / source-missing-skip) + classifier-version |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + read-only + tmp 격리 + Safari 미간섭 (sqlite-locked source 시 skip) |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + reason ('tg-real'/'tg-sqlite-locked-skip'/'tg-synth') |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive raw + airgenome filter + anima 정책 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | 인라인 ≤16KB + 1-pass + cache-on-disk |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | source-missing / sqlite-locked / safari-running / corrupt 4-fixture |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

| # | Source | Path | Exists | Size | Access |
|---|--------|------|--------|------|--------|
| S1 | TabGroups.plist (spec) | `~/Library/Safari/TabGroups.plist` | ✗ | n/a | does not exist on macOS 14+ |
| S2 | SafariTabs.db (real) | `~/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db` | ✓ | 62 MB | sqlite — Safari running locks WAL |
| S3 | RecentlyClosedTabs.plist | `~/Library/Safari/RecentlyClosedTabs.plist` | ✓ | small | open (read-only) |
| S4 | CloudTabs.db | `~/Library/Containers/com.apple.Safari/Data/Library/Safari/CloudTabs.db` | ✓ | small | sqlite — same lock concern |

Per-system finding: spec-stated `TabGroups.plist` **does not exist**. Tab Groups data lives in `SafariTabs.db` SQLite (table `windows_tab_groups`, 1 row this user) under sandboxed Container — Safari is running (pgrep returned 14 PIDs) so the WAL is hot and a safe `sqlite3` `mode=ro` URI may still hit a locked page set. Per raw 168 minimum-viable + raw 91 honest C3, falling back to `RecentlyClosedTabs.plist` + synth-mode is the only safe deliverable path.

---

## §C. Candidate Scoring (≥2 mandate)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| SF2a | SafariTabs.db sqlite parse (Safari running) | 46 | 60 | 30 | 24 | 24 | 26 | 32 | 22 | 16 | **280** |
| SF2b | RecentlyClosedTabs.plist + sqlite-skip + synth-fallback | 44 | 70 | 36 | 38 | 28 | 28 | 36 | 34 | 18 | **332** |
| SF2c | SF2b + offline carve-out doc + verdict=HOLD | 42 | 64 | 32 | 38 | 26 | 26 | 34 | 32 | 18 | **312** |

### SF2a — sqlite-direct parse (rejected — pgrep guard violation)

- B4 -16: Safari running 중 sqlite DB open 은 R5 read-only conflict (WAL lock) + production-execute 분류 risk.
- B8 -18: locked-page hit 시 sqlite "database is locked" exception 가능 + corruption risk if WAL not flushed.

### SF2b — RecentlyClosedTabs + sqlite-skip + synth (highest scoring)

- Source-missing graceful skip + reason='tg-source-missing'.
- RecentlyClosedTabs.plist (소형) parse → tab url + close-time 추출 → SHBF.
- B2 -20: real-source 표본이 RecentlyClosed 만 → tab-group 의 진짜 그룹 구조 미확보 (group-name col 가짜화).
- B1 -6: TabGroup→Tab 2-tier 가 실측 데이터 없이 구현 불가 → flat single-tier 로 강등.

### SF2c — SF2b + HOLD verdict

- 솔직 verdict 라이트 — 문서로만 carve-out 등록, 구현 미실시 (HOLD).
- B2 -26: 측정 자체 미수행.

**Selected verdict: HOLD (highest 332 < 350 threshold).**

Per raw 240 §A B2 만점 컷 (real-source measurability 필수) + raw 91 honest C3: this filter does NOT meet ≥350 threshold honestly. Document carve-out + defer to follow-up cycle when (a) Safari quit is acceptable OR (b) sqlite ro+immutable=1 cold-snapshot is whitelisted.

---

## §D. honest-C3 (gap audit)

| # | Gap | Severity | Mitigation |
|---|-----|---------:|-----------|
| C3-1 | TabGroups.plist 존재하지 않음 (macOS 14+) → 실제 source = SafariTabs.db (sqlite) | high | document source-correction; impl skip with reason |
| C3-2 | Safari running (pgrep 14 PIDs) → sqlite WAL lock conflict risk | high | pgrep guard skip |
| C3-3 | sandboxed container path → TCC 가능성 (현재 system 은 ls 가능하므로 FDA 보유) | medium | open() try/except |
| C3-4 | RecentlyClosedTabs.plist 은 group 구조 미보유 (flat tab list) | medium | flat fallback, B1 강등 |
| C3-5 | CloudTabs.db sync metadata only — local state 미반영 | low | skip CloudTabs |
| C3-6 | 단일 row windows_tab_groups (이 user) → real-data scale 부족 | medium | synth-fallback in bench |

honest-C3 gap count: **6**.

---

## §E. Deliverables (HOLD path: doc-only artifacts + stub impl with skip)

- `/Users/ghost/core/airgenome/docs/sf2_safari_tab_groups_rubric_2026-04-30.md` (this)
- `/Users/ghost/core/airgenome/docs/sf2_safari_tab_groups_rubric_2026-04-30.rubric.jsonl`
- `/Users/ghost/core/airgenome/filters/module/data/safari_tab_groups.hexa` (HOLD-stub: skip + reason print)
- `/Users/ghost/core/airgenome/tool/bench/bench_sf2_safari_tab_groups.hexa` (HOLD-stub: synth-only bench documenting carve-out)

Verdict: **HOLD** (332/400 < 350). Stub artifacts emit `verdict=HOLD reason=safari-running+spec-path-missing` and exit 0.
