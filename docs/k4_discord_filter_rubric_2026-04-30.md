# K4 Discord LevelDB Filter — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger
- scope: design-phase scoring of K4 (Discord Local Storage / IndexedDB leveldb), explicit user request
- prior status: K4 was NOT in macos_level_candidates_rubric_2026-04-30.md A-audit top-3 (prior Σ=298)
- raw 240 V2: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `k4_discord_filter_rubric_2026-04-30.rubric.jsonl`
- gate: hybrid synth Σ ≥ 350 → implement; else design-only + honest-C3

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered, edit-after-score banned)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | shbf/dedup/columnar/dict 1+ 패턴 + binary layout 명세 + read-only 전략 명시 |
| B2 | measurability | 측정 가능성 | 90 | hot path latency μs급 + memory ceiling MB급 + before/after compression ratio 정량 |
| B3 | enforcement-strength | 강제력 | 40 | Self-test 4-fixture 이상 + classifier-version 박제 + lint/CI 후보 |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa 파일 + 부수 효과 0 + tmp/{filter} 격리 + LOCK 미손상 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size 3-축 출력 + classifier_version row + reason 코드 |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima 분석 3-홉 활용 가능 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | 인라인 페이로드 ≤16KB + 1회 read-pass + cache-on-disk-only |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-DB / corrupt-LDB / Discord-running / snappy-skew 4-fixture PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + 자기-점수 회피 + carve-out catalogue 적용 |
| **Σ** | | **Total** | **400** | |

Block ordering immutable post-score per F-RAW240-3.

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| Path | Exists | Size | Notes |
|------|--------|------|-------|
| `~/Library/Application Support/discord/` | ✓ | dir | Discord 0.0.388 build present |
| `~/Library/Application Support/discord/Local Storage/leveldb/` | ✓ | **11 MB** | 4 .ldb files + 1 .log + LOCK + LOG + LOG.old + MANIFEST + CURRENT |
| ↳ `000005.ldb` | ✓ | 2.26 MB | older entries, possible non-snappy |
| ↳ `000139.ldb` | ✓ | 4.67 MB | recent |
| ↳ `000140.ldb` | ✓ | 27 KB | small overflow |
| ↳ `000142.ldb` | ✓ | 4.68 MB | recent |
| ↳ `000141.log` | ✓ | 38 KB | uncompacted writes |
| `~/Library/Application Support/discord/IndexedDB/https_discord.com_0.indexeddb.leveldb/` | ✓ | **24 KB** | sparse — `000003.log` 6.6 KB primary; no .ldb yet (pre-compaction) |
| LOCK file | ✓ (0 B) | — | leveldb advisory lock — Discord must be closed during encode |
| Discord process state at probe time | NOT running (pgrep empty) | — | encode-safe window |

Access: open under $HOME, no FDA prompt. Sandboxed reads via `open('rb')` are fine; no leveldb library required (raw block scan).

---

## §C. Candidate Scoring (raw 240 V2, ≥2 candidates mandate satisfied — 3 here)

Two strategies + hybrid synth required by mandate.

### Score Matrix (per-block, /400)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| K4-a | Raw byte-level .ldb scan, Local Storage + IndexedDB 둘 다 | 44 | 78 | 34 | 36 | 28 | 22 | 32 | 26 | 18 | **318** |
| K4-b | Local-Storage-only raw scan (skip 24KB IDB) | 46 | 84 | 36 | 38 | 28 | 26 | 36 | 32 | 20 | **346** |
| K4-h | Hybrid synth (LS primary + IDB optional probe, single .hexa) | 47 | 84 | 36 | 38 | 28 | 26 | 36 | 32 | 20 | **347** |

### Per-block rationale (K4-h hybrid)

- **B1=47/50** — shbf pattern (sorted-key blob), binary layout "KDLS" v1, read-only `open('rb')` strict, 만점 컷 모두 충족하나 dedup/columnar 부재로 -3.
- **B2=84/90** — predictable single-pass scan ~11MB; latency target 50–80ms encode + <100μs lookup mmap; before/after ratio 정량 가능. real-DB latency variance (snappy-block ratio unknown) -6.
- **B3=36/40** — 4-fixture (empty / corrupt-LDB / running-Discord-synth / snappy-skew) PASS 가능. classifier_version 박제 OK. lint/CI 후보 약 -4.
- **B4=38/40** — 단일 .hexa, /tmp/k4_discord_lev/ 격리, LOCK 파일 절대 미접촉 (advisory only, but airgenome never writes). -2 (Discord running 시 race window exists 0.5s pre-pgrep-check).
- **B5=28/30** — rss/elapsed/blob_size 3축 + reason_code (k4_running, k4_snappy_skew, k4_lock_seen, k4_synth_fallback). -2.
- **B6=26/30** — hive raw ingestion 가능, anima entity-graph (server/channel name) 활용 가능. 그러나 message body는 server-side, 로컬엔 캐시된 username/channel/server-name + emoji + setting key만. cross-repo value 제한. -4.
- **B7=36/40** — PAYLOAD ~12KB 추정 (≤16KB OK). 1-pass read. cache-on-disk only. -4 (snappy decode 분기로 인해 코드량 압박).
- **B8=32/40** — empty-DB synth fallback ✓; corrupt-LDB best-effort scan continues ✓; Discord-running → ps+pgrep 검출 후 synth-only ✓; snappy-skew 부분 PASS only (snappy lib stdlib 없음 → snappy 블록 skip with reason_code). 3.5/4 fixture → -8.
- **B9=20/20** — 메타 깊이 ≤2 (rubric→honest-C3, 더 없음). 자기-점수 회피 ✓ (K4 hybrid가 K4-a/K4-b를 메타-스코어하지 않음). carve-out: "snappy-skew best-effort" 명시.

### Synth: Σ = **347/400** — **<350 threshold → DESIGN-ONLY HOLD**

Per protocol: implementation skipped, honest-C3 only.

---

## §D. Hot Path & Blob Layout (specified for future re-score)

If/when score ≥350 (e.g. by adding pure-python snappy decoder bumping B8 to 36 → Σ 351), implement as:

```
magic    : 4B  "KDLS"
version  : 4B  u32 (1)
n        : 4B  u32  printable-utf8 keys 개수
str_sz   : 4B  u32  key pool 바이트 길이
[n*4]    : u32 key_offsets (정렬 X — 발견순)
[n*4]    : u32 key_lens
[n*1]    : u8  source_tag (0=LS, 1=IDB, 2=synth)
[str_sz] : utf-8 key pool (NUL 없음)
```

Filter: ascii-printable > 95%, len > 3, len < 200, dedup (set).
Source globs:
- `~/Library/Application Support/discord/Local Storage/leveldb/*.ldb`
- `~/Library/Application Support/discord/IndexedDB/*/[*.ldb,*.log]` (optional)

Synth fallback: 5000 keys, distinct distribution (channel-{i}/server-{i}/user-{i}/setting-{i} mix, lengths 8–40, 4-bucket).

Discord-running guard: `pgrep -lf '[Dd]iscord'` non-empty → synth-only + reason_code=k4_running.

---

## §E. honest-C3 (carve-out / gap catalogue)

C3-1 — **snappy compression skew**: stdlib python3 has no snappy decoder. Modern Chromium leveldb writes most blocks with snappy. We skip snappy-marked blocks with reason_code=k4_snappy_skew; coverage estimate 30–50% real keys. Mitigation: pure-python snappy decoder (~200 LOC) — adds B8 +4, Σ ≥ 351.

C3-2 — **IndexedDB sparse path**: at probe time IDB has only `000003.log` (6.6 KB) + zero .ldb. Real coverage from IDB is near-zero until next compaction. Treat as opportunistic.

C3-3 — **LOCK race window**: pgrep-then-open window is non-zero (~0.2s). If Discord launches mid-encode, leveldb advisory LOCK could be violated. We never write the LOCK file, but reading 11 MB while Discord is mid-write may yield torn blocks. Mitigation: `os.stat(LOCK).st_size==0 AND pgrep empty` double-check; fall back to synth.

C3-4 — **Schema-version skew**: Discord 0.0.388 today; future versions may rotate keyspace prefix. classifier_version=KDLS-v1-2026-04-30 박제. No silent migration.

C3-5 — **Cross-repo value gap (B6)**: Local Storage holds settings/auth-token-fragments/recent-channel-cache only — message bodies are server-side. anima entity-graph yield is modest (server/channel/user names ~5K entries) vs K2 SharedFileList (~50K recent docs). This is the primary reason Σ falls below threshold.

C3-6 — **Privacy / token surface**: Local Storage may contain auth token fragments. Filter MUST drop keys matching `/token|password|secret|auth/i`. Add to 만점 컷 if proceeding.

**Gap count: 6.**

---

## §F. Verdict

- K4 hybrid synth Σ = **347/400** < 350 → **HOLD**, implementation skipped.
- Primary blocker: B6 cross-repo value (Discord locally caches metadata only, not message corpora) + B8 snappy-skew partial.
- Alternative: K2 (SharedFileList .sfl3/.sfl4 shbf, prior Σ=380) or K6 (zsh_history columnar token dict, prior Σ=380) deliver ≥350 trivially with broader cross-repo yield. K7 (iTerm chatdb sqlite shbf, prior Σ=336) is closer-to-Discord-conceptually but also <350.
- Path to unlock K4: add pure-python snappy decoder (B8 +4, B2 +2 → Σ ~353) **OR** narrow scope to Local-Storage-keys-as-discovery-signal-only with anima cross-link to autocomplete_trie_mmap (B6 +4 → Σ ~351).

Deliverables: 2 files (this .md + companion .jsonl). No .hexa created.
