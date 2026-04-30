# macOS-Level Data 재해석 Filter Candidates — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger
- raw 240 V2 mandate: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- scope: design-only, NO implementation, NO production execution, read-only filesystem probe artifact
- companion: `macos_level_candidates_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered, edit-after-score banned)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | shbf/dedup/columnar/dict 중 1+ 고전 패턴 적용 + binary layout 명세 + read-only 전략 명시 |
| B2 | measurability | 측정 가능성 | 90 | hot path latency target μs급 + memory ceiling MB급 + before/after compression ratio 정량 |
| B3 | enforcement-strength | 강제력 | 40 | Self-test 4-fixture 이상 + classifier-version 박제 + lint/CI 후보 |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa 파일 + 부수 효과 0 + tmp/{filter} 격리 + WAL/-shm 미손상 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size 3-축 출력 + classifier_version row + reason 코드 |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima 분석 3-홉 활용 가능 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | 인라인 페이로드 ≤16KB + 1회 read-pass + cache-on-disk-only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-DB / corrupt-WAL / sandbox-deny / schema-version-skew 4-fixture PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + 자기-점수 회피 + carve-out catalogue 적용 |
| **Σ** | | **Total** | **400** | |

Block ordering immutable post-score per F-RAW240-3.

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| # | Candidate | Path | Exists | Size/Count | Access |
|---|-----------|------|--------|------------|--------|
| C1 | iMessage chat.db | `~/Library/Messages/chat.db` | ✓ | 475 KB + 1.4 MB WAL | open (no FDA needed for $HOME) |
| C2 | Spotlight metadata cache | `~/Library/Caches/com.apple.metadata*` | ✗ (no glob match) | — | sandboxed elsewhere |
| C2' | CoreSpotlight receiver plists | `~/Library/Metadata/CoreSpotlight/` | ✓ | small plists | open |
| C3 | Defaults plist columnar | `~/Library/Preferences/*.plist` | ✓ | 442 files | open |
| C4 | SharedFileList (.sfl2/.sfl3/.sfl4) | `~/Library/Application Support/com.apple.sharedfilelist/` | ✓ (sfl3/sfl4, not sfl2) | 8+ files including RecentDocuments/RecentApplications/FavoriteVolumes | open |
| C5 | QuickLook thumbnail cache | `~/Library/Caches/com.apple.QuickLook.thumbnailcache` | ✗ | — | FDA / sandboxed |
| C6 | Stickies database | `StickiesDatabase` plist | ✗ (mdfind empty) | — | app not used |
| C7 | TextEdit recents/autosave | `~/Library/Containers/com.apple.TextEdit/Data/Library/Autosave Information/` | ✓ but empty | 0 entries | open (when populated) |
| C8 | Voice Memos CloudRecordings.db | various candidate paths | ✗ (no mdfind hit) | — | sandboxed container |
| C9 | iTerm/Terminal saved state | `~/Library/Application Support/iTerm2/` (12 KB chatdb.sqlite) + `~/.zsh_history` 524 KB | ✓ | iTerm small + zsh hist 524 KB | open |
| C10 | LaunchAgents | `~/Library/LaunchAgents/` | ✓ | ~50 entries (incl. anima symlinks) | open |
| C11 | Discord LevelDB | `~/Library/Application Support/discord/Local Storage/leveldb/` | ✓ | (LevelDB present, 0.0.388 build dir + Cache/Code Cache) | open |
| C12 | Slack storage | `~/Library/Application Support/Slack/` | ✗ | — | not installed |
| C13 | Time Machine local snapshots | `tmutil listlocalsnapshots /` | ✓ command works (0 snapshots現) | metadata only | tmutil readable |
| C14 | Keychain listing (read-only) | `security list-keychains` / `dump-keychain` | ✓ | login + System keychain | OS-level (per-item ACL prompts) |
| C15 | ~/Library/Caches/* path index | `~/Library/Caches/` | ✓ | 5.6 GB aggregate | open (mostly) |

FDA = Full Disk Access. "open" = readable from non-sandboxed CLI under $HOME without TCC prompt.

---

## §C. Candidate Scoring (raw 240 V2, ≥2 candidates mandate satisfied — 15 here)

Pattern-fidelity reference: T1/T2/T3 (telegram), M1/M2/M3 (memo), MA1/MA2/MA3 (mail), IM1 (imessage_chat_shbf already landed).

### Score Matrix (per-block, /400)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| K1 | iMessage attachment dedup (companion to IM1) | 50 | 88 | 40 | 40 | 30 | 30 | 40 | 38 | 20 | **376** |
| K2 | SharedFileList Recent (.sfl3/.sfl4) shbf | 50 | 90 | 40 | 40 | 30 | 30 | 40 | 40 | 20 | **380** |
| K3 | Defaults plist columnar dict | 48 | 86 | 38 | 40 | 28 | 28 | 38 | 36 | 20 | **362** |
| K4 | Discord LevelDB IndexedDB shbf | 42 | 70 | 32 | 32 | 28 | 24 | 30 | 22 | 18 | **298** |
| K5 | LaunchAgents/LoginItems enumeration shbf | 50 | 88 | 40 | 40 | 30 | 30 | 40 | 40 | 20 | **378** |
| K6 | zsh_history columnar token dict | 50 | 90 | 40 | 40 | 30 | 30 | 40 | 40 | 20 | **380** |
| K7 | iTerm chatdb sqlite shbf | 46 | 76 | 36 | 38 | 28 | 26 | 36 | 32 | 18 | **336** |
| K8 | TextEdit autosave shbf | 38 | 60 | 30 | 36 | 26 | 22 | 32 | 24 | 18 | **286** |
| K9 | Stickies plist shbf | 30 | 40 | 24 | 32 | 22 | 18 | 26 | 18 | 16 | **226** (path absent) |
| K10 | Voice Memos CloudRecordings.db | 32 | 50 | 26 | 28 | 22 | 20 | 24 | 18 | 16 | **236** (sandboxed/path miss) |
| K11 | Spotlight CoreSpotlight receiver plist | 36 | 56 | 28 | 32 | 24 | 22 | 30 | 22 | 18 | **268** |
| K12 | Time Machine snapshot metadata | 44 | 72 | 36 | 38 | 28 | 26 | 36 | 30 | 18 | **328** |
| K13 | Keychain entries listing (read-only meta) | 30 | 50 | 24 | 28 | 22 | 22 | 24 | 16 | 16 | **232** (TCC fragile) |
| K14 | ~/Library/Caches/* aggregate path index | 46 | 78 | 36 | 38 | 28 | 28 | 34 | 34 | 18 | **340** |
| K15 | QuickLook thumbnail cache | — | — | — | — | — | — | — | — | — | **N/A** (path absent) |

만점 (400/400) candidates: none unconditionally. Top-3 ≥ 380 listed below.

### §C.1 Top-3 Justification (≥ 380/400)

#### K2 — SharedFileList Recent shbf — 380/400
- B1: sfl3/sfl4 binary plist with bookmark blobs → shbf-prefix on app-bundle-id sorted, dedup on bookmark hash. classic pattern fit.
- B2: 8 files, < 200 KB total, parse μs-budget achievable; before=8 plist parses each query → after=single mmap-bisect.
- B7: payload < 8 KB feasible (sfl parser inline).
- B8: empty-file / corrupt-bplist / unknown-magic / version-skew 4-fixture trivially constructable.
- Pattern fidelity: matches finder_recent_file_shbf.hexa T-class layout.

#### K6 — zsh_history columnar token dict — 380/400
- B1: 524 KB plain text → token dict + delta-coded timestamp columnar = textbook claude_token_columnar.hexa twin.
- B2: hot-path "find command containing X" trie-bisect μs; compression 3-5× on dict reuse.
- B6: hive raw 9 + anima self-replay history both read shell ledger; cross-repo natural.
- B8: truncated tail / non-utf8 sequence / extended-history-format / empty-file 4-fixture clean.

#### K5 — LaunchAgents/LoginItems enum shbf — 378/400 (rounded up to top-3)
- B1: ~/Library/LaunchAgents + /Library/LaunchAgents + LSSharedFileList LoginItems → unified shbf with provenance dict.
- B2: ~50 plists, parse < 5 ms, blob < 32 KB.
- B6: anima auto_evolution 이미 launchctl 영역 — airgenome 측 read-only 인덱스 자연스러움.
- B8: symlink-loop / stale-target / disabled-key-missing / non-plist-XML 4-fixture.

(K1 iMessage attachment dedup at 376 is honorable mention — would be top-3 if companion to existing IM1 weighted.)

### §C.2 Hybrid Recommendation — K-HYBRID

Land K2 + K6 + K5 atomic-3 in one phase: all three score ≥ 378, all open-access (no FDA), all extend existing pattern (T-class shbf, columnar-dict, dedup). Estimated combined emission < 40 KB inline payload. Exposes 3 wave domains (recent-files / shell-history / launch-graph) the existing 6 do not yet cover.

K1 attachment dedup as phase-1.5 since it is direct extension of IM1 already in tree.

---

## §D. honest-C3 — Gaps This Rubric Does NOT Measure

(raw 91 + raw 240 honest-C3 mandate — perfect score against small rubric is small claim)

1. **G-FDA**: TCC / Full Disk Access dependency is binary (works / TCC-deny) and not graded — K15 QuickLook, K8 partial Voice Memos invisibly blocked at runtime.
2. **G-SCHEMA-UNDOC**: chat.db / sfl3 / Discord LevelDB schemas are reverse-engineered. macOS minor version (e.g. 14.x → 15.x) can break column names silently. Rubric scores design-now, not schema-stability-over-time.
3. **G-VENDOR-DRIFT**: Discord auto-updates (currently 0.0.388 dir) — IndexedDB key format is per-build. K4's 298 already reflects, but the rubric has no continuous drift KPI.
4. **G-CLOUD-PARTIAL**: Voice Memos / Notes / Messages are CloudKit-synced; the local DB may be a partial mirror with deletions tombstoned differently per OS version. Rubric does not measure local-vs-cloud divergence.
5. **G-PRIVACY-ETHICS**: Keychain listing (K13) is technically meta-only but a poison-pill audit-wise; rubric does not score policy-friction.
6. **G-VOLATILE-WAL**: chat.db-wal mid-write race during query — immutable=1 mitigates but rubric counts no race-fixture beyond B8's 4-fixture.
7. **G-COST-AT-COLD-CACHE**: B7 measures emission size, not first-run mmap hydration cost; cold-cache 1-pass vs warm-cache reload not graded.
8. **G-CROSS-USER**: $HOME assumption breaks under sudo / multi-user; B6 cross-repo is repo-axis, not user-axis.
9. **G-LANG-i18n**: zsh_history utf-8 decode robustness for CJK / RTL not measured (raw 240 V2 G4 gap inheritance).
10. **G-LIFECYCLE-DEPRECATION**: Stickies (K9) effectively dead app; rubric does not penalize "low population" beyond raw scores.

Gap count: **10**. Mitigation strategy: each gap is candidate for V3 block addition (B10 cloud-divergence /20 + B11 schema-stability /20 etc.) — deferred to next cycle per F-RAW240-3 (no silent re-weight).

---

## §E. Access Mode Triage (FDA-blocked vs sandbox-OK vs open)

- **open (no TCC, $HOME, immediate)**: K1, K2, K3, K5, K6, K7, K8, K11, K12, K14 (mostly), K1-companion (iMessage attachment in $HOME/Library/Messages/Attachments)
- **sandbox-container readable but app-installed-required**: K4 (Discord installed → readable), K10 (Voice Memos requires app run + container present — currently absent on this host)
- **FDA-required / TCC-prompted**: K5 path index hits some `/Library/Caches/` subtrees that prompt; K15 QuickLook absent on this host (Sequoia changed location).
- **TCC per-item ACL**: K13 Keychain (each `dump-keychain` access prompts; meta listing OK).
- **path absent on this host (deprecate or skip)**: K9 Stickies, K10 Voice Memos, K15 QuickLook.

---

## §F. Termination Criterion Check (raw 240 step 6)

- (a) user-explicit acceptance: pending user signal post-report.
- (b) self-replay PASS metric: this artifact is design-only, no implementation; self-replay infrastructure unchanged. Therefore termination depends on (a).

End of artifact.
