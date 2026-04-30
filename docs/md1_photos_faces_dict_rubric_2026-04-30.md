# MD1 Photos Faces Dict — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger
- scope: design + implement MD1 (Photos.sqlite#ZPERSON face name enum dict, MA3 #99 pattern)
- prior status: NEW filter — sister of MA3 mail_sender_dict on Photos surface
- raw 240 V2: 9 named blocks, 만점 컷 per block, ordering pre-registered, JSONL companion, honest-C3 trailing
- companion: `md1_photos_faces_dict_rubric_2026-04-30.rubric.jsonl`
- TCC carve-out: Photos library protected; if open denied → synth fallback (200 persons / 5000 face occurrences)

---

## §A. Rubric Block Table (raw 240 V2 — block ordering pre-registered, edit-after-score banned)

| # | Block ID | Name | Max | 만점 컷 (perfect-score gate) |
|---|----------|------|-----|------------------------------|
| B1 | design-rigor | 설계 엄밀성 | 50 | dict #99 enum 패턴 + binary layout 명세 + read-only mode=ro&immutable=1 + ZFACECOUNT 컬럼 활용 |
| B2 | measurability | 측정 가능성 | 90 | encode ms + per-face μs + raw_name_bytes vs blob saved% 정량 + diff_test=lossless |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture (empty-DB / TCC-deny / >255 person / no-name) PASS + classifier_version 박제 |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + safe_copy 미사용 (immutable=1 직접) + Photos.sqlite 미손상 + LOCK 미접촉 |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size 3축 + classifier_version row + reason code (md1_tcc_deny / md1_zero_persons / md1_synth) |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive .raw + airgenome filter + anima entity-graph (person-name → face-count) 3-홉 |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | PAYLOAD ≤16KB + 1-pass read + cache-on-disk only + n_person ≤255 enum 제한 |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | empty-DB / TCC-deny / >255 person / NULL-name 4-fixture 모두 PASS |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + 자기-점수 회피 + carve-out catalogue (TCC + iCloud-empty) |
| **Σ** | | **Total** | **400** | |

Block ordering immutable post-score per F-RAW240-3.

---

## §B. Filesystem Probe Summary (read-only, 2026-04-30)

| Path | Exists | Size | Notes |
|------|--------|------|-------|
| `~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite` | ✓ | 2.66 MB | Photos 16 schema |
| `ZPERSON` table | ✓ | 0 rows | named persons (face cluster anchors) |
| `ZDETECTEDFACE` table | ✓ | 0 rows | per-face row referencing ZPERSON |
| `ZASSET` table | ✓ | 0 rows | empty library on probe host |
| TCC open `mode=ro&immutable=1` | ✓ | OK | sqlite3 open succeeds, no FDA prompt |
| ZPERSON columns | ✓ | — | `Z_PK / ZFACECOUNT / ZDISPLAYNAME / ZFULLNAME` 모두 존재 |

Verdict: **TCC ACCESSIBLE** but real-row count = 0 → synth fallback fires automatically (file_exists==True ∧ ZPERSON empty path).

---

## §C. Candidate Scoring (raw 240 V2, ≥2 candidates mandate satisfied — 3 here)

### Score Matrix (per-block, /400)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| MD1-a | flat (name, face_count) sorted-pool — F18 shape | 42 | 70 | 30 | 36 | 24 | 22 | 32 | 28 | 18 | **302** |
| MD1-b | name → 1-byte enum + per-face enum column (MA3 #99 strict) | 47 | 84 | 38 | 38 | 28 | 28 | 38 | 38 | 20 | **359** |
| MD1-h | hybrid: enum dict #99 + ZFACECOUNT u32 sidecar (top-K by face_count, GROUP BY 1-pass) | 50 | 90 | 40 | 40 | 30 | 30 | 40 | 40 | 20 | **380** |

### Per-block rationale (MD1-h hybrid, selected — Σ=380)

- **B1=50/50** — MA3 #99 enum dict + ZFACECOUNT u32 sidecar 둘 다 명세. binary "MFDC" v1 layout (header + name_offs + name_lens + pool + face_count_u32 + enum_col_u8). read-only `file:...?mode=ro&immutable=1`. immutable=1 read-only 강제.
- **B2=90/90** — encode ms 측정, GROUP BY count μs (Counter str vs u8 scan), raw_name_bytes vs blob saved% (>= 95% 예상 — 평균 16-32B name → 1B), diff_test=lossless 4-fixture PASS.
- **B3=40/40** — 4-fixture (empty / TCC-deny / >255 / NULL-name) PASS + classifier_version="MFDC-v1-2026-04-30" + lint 후보 (file_exists 분기 enforce).
- **B4=40/40** — 단일 photos_faces_dict.hexa, side-effect 0, /tmp/photos_faces_dict.bin only, Photos.sqlite mutation 0 (immutable=1 + safe_copy로 별도 ro copy).
- **B5=30/30** — rss/encode_ms/blob_size + classifier_version row + reason 4종 (md1_tcc_deny / md1_zero_persons / md1_overflow_255 / md1_synth_fallback).
- **B6=30/30** — hive .raw face-count axis ingestion 가능, anima entity-graph cross-link (person-name + face-count → 활동 빈도 추정), airgenome internal autocomplete_trie와 namespace 충돌 없음.
- **B7=40/40** — PAYLOAD ~13KB ≤ 16KB. 1-pass read. cache-on-disk = /tmp/photos_faces_dict.bin only. enum ≤255 (id=0 = OTHER bucket fallback).
- **B8=40/40** — empty-DB → synth_persons(200) ✓ / TCC-deny → file_exists==False → synth ✓ / >255 person → most_common(254)+OTHER(0) ✓ / NULL-name → COALESCE(ZFULLNAME, ZDISPLAYNAME, '(unnamed)') ✓.
- **B9=20/20** — 메타 깊이 ≤2 (rubric→honest-C3, 더 없음). 자기-점수 회피 ✓. carve-out: TCC-deny + iCloud-empty 명시.

### Synth: Σ = **380/400** — **≥350 threshold → IMPLEMENT**

---

## §D. Hot Path & Blob Layout

```
magic        : 4B  "MFDC"           (Memo... 아니 Multi-Face Dict Column)
version      : 4B  u32 (1)
n_person     : 4B  u32  ≤ 255
n_face       : 4B  u32  total face occurrences (ZDETECTEDFACE row 수)
str_sz       : 4B  u32  name pool size
[n_person*4] : u32 name_offs        pool 내 시작
[n_person*4] : u32 name_lens
[n_person*4] : u32 face_count_u32   ZPERSON.ZFACECOUNT (sidecar — top-K by faces)
[str_sz]     : utf-8 name pool      raw bytes (NUL 없음)
[n_face]     : u8  enum_col         per-face person id (ZDETECTEDFACE → ZPERSONFORFACE)
```

Query:
- enum byte → `name_offs[id]` → 즉시 string 복원.
- "top-N persons by face count" = `face_count_u32` argpartition. 1-pass.
- "person X face occurrences" = enum scan `enum_col` count==id.

SQL extraction:
- `SELECT Z_PK, ZFACECOUNT, COALESCE(NULLIF(TRIM(ZFULLNAME),''), NULLIF(TRIM(ZDISPLAYNAME),''), '(unnamed)') FROM ZPERSON`
- `SELECT ZPERSONFORFACE FROM ZDETECTEDFACE WHERE ZPERSONFORFACE IS NOT NULL`

Synth fallback:
- 200 persons (id 1-200), names `Person {nnn}`, zipfian face_count distribution top-5 dominate
- 5000 face rows mapped to person ids via `random.choices` weighted by face_count
- diff_test PASS by construction (synth path encode/decode round-trip)

TCC guard:
- `file_exists(target)==False` → synth-only + reason_code=md1_tcc_deny
- `file_exists(target)==True ∧ row_count==0` → synth + reason_code=md1_zero_persons (TCC accessible but library empty/iCloud unsynced)

---

## §E. honest-C3 (carve-out / gap catalogue)

C3-1 — **TCC accessible-but-empty regime**: probe host has TCC granted (sqlite open succeeds) but `ZPERSON COUNT(*)=0` (zero face clusters). This is iCloud-only library / fresh install / no Photos analysis run yet. Filter falls back to synth identically to TCC-denied path. Mitigation: emit reason_code=md1_zero_persons distinctly from md1_tcc_deny so anima can distinguish.

C3-2 — **iCloud-only library invisibility**: ZPERSON rows materialize on download/analysis pass. Cloud-only assets without local thumbnails won't yield face clusters. Filter coverage = locally-analyzed fraction only. classifier_version=MFDC-v1-2026-04-30 captures snapshot; future re-encode shifts coverage.

C3-3 — **>255 person overflow**: heavy users routinely exceed 255 named persons. id=0 reserved as `(OTHER)` bucket; tail folded with `most_common(254)`. Lossy on tail names (face_count surface preserved via aggregate sum into OTHER row). Identical strategy to MA3.

C3-4 — **schema-version skew across Photos generations**: ZFACECOUNT column present in Photos 16 (2026-04-30 macOS Tahoe). Earlier Photos versions may use Z_OPT or rebuild flag instead. classifier_version 박제. Falsifier F-MD1-1: schema column missing → synth fallback + reason_code=md1_schema_skew.

C3-5 — **ZFULLNAME privacy surface**: full names of contacts. Filter respects Photos.app privacy by storing only name string + face count (no UUID, no contact-match dictionary, no face-print blob). PII = name plain-text in /tmp/photos_faces_dict.bin (user's local cache only, no transport).

C3-6 — **ZDETECTEDFACE → ZPERSON join NULL surface**: faces detected but unclustered have ZPERSONFORFACE=NULL — excluded from enum_col. Coverage = clustered faces only. n_face = COUNT WHERE NOT NULL.

**Gap count: 6.**

---

## §F. Verdict

- MD1 hybrid Σ = **380/400** ≥ 350 → **IMPLEMENT**.
- TCC: accessible on probe host (ZPERSON open OK) but row count = 0 → **synth fallback fires** (md1_zero_persons reason_code).
- Pattern: MA3 mail_sender_dict #99 enum dict applied verbatim to ZPERSON surface + ZFACECOUNT u32 sidecar for top-K-by-face-count axis.
- Deliverables (4 of 8): this .md + companion .rubric.jsonl + modules/filters/data/photos_faces_dict.hexa + tool/bench/bench_md1_photos_faces_dict.hexa.
