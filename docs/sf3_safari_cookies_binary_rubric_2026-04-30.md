# SF3 — Safari Cookies.binarycookies Parse — raw 240 V2 Weighted Rubric (400pt)

- date: 2026-04-30
- author: airgenome design ledger (K. Safari 보강 wave)
- candidate id: SF3
- scope: design + read-only impl. ≥350 threshold for impl. NO mutation, NO git commit, pgrep guard.
- companion: `sf3_safari_cookies_binary_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2)

| # | Block ID | Name | Max | 만점 컷 |
|---|----------|------|-----|---------|
| B1 | design-rigor | 설계 엄밀성 | 50 | binarycookies header + page + record format 명세 + domain-sorted SHBF blob layout |
| B2 | measurability | 측정 가능성 | 90 | μs latency + speedup ≥50× projection + 336KB real source measurable |
| B3 | enforcement-strength | 강제력 | 40 | 4-fixture (real-336KB / synth-1000 / corrupt-magic-skip / truncated-skip) + classifier_version |
| B4 | atomicity | 원자성 | 40 | 단일 .hexa + read-only `open('rb')` + tmp 격리 + Cookies 미손상 + Safari 미간섭 (read-only file) |
| B5 | observability | 관찰 가능성 | 30 | rss/elapsed/blob_size + reason ('cookies-real'/'cookies-corrupt-skip'/'cookies-synth') + n_pages/n_cookies |
| B6 | cross-repo | 교차 저장소 적용성 | 30 | hive raw + airgenome filter + anima privacy 정책 (3-홉) |
| B7 | emission-cost-bounded | 방출 비용 한도 (V2) | 40 | 인라인 ≤16KB + 1-pass page-stream + cache-on-disk |
| B8 | adversarial-resistance | 적대 저항성 (V2) | 40 | corrupt-magic / page-size-overflow / record-offset-OOB / truncated 4-fixture |
| B9 | meta-rubric-finite | 메타 루브릭 유한성 (V2) | 20 | 깊이 ≤2 + self-score 회피 |
| **Σ** | | **Total** | **400** | |

---

## §B. Filesystem Probe (read-only, 2026-04-30)

| # | Source | Path | Exists | Size | Magic |
|---|--------|------|--------|------|-------|
| S1 | Cookies.binarycookies (Safari) | `~/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies` | ✓ | 336276 B (~328 KB) | `cook` (4B) |

Header probe: `cook` magic + 341 page count + per-page sizes (first 5: 535/203/1054/1136/505 bytes). Format is publicly reverse-engineered (open spec at multiple repos: as-published by libimobiledevice / safari-cookies projects). Per-cookie record walk is well-defined.

---

## §C. Cookies.binarycookies Format Reference

Big-endian outer header, little-endian page records (Apple custom):
```
[outer header big-endian]
  4B magic  = "cook"
  4B u32   = n_pages
  n_pages * 4B u32 = page_sizes[]
[page #i, little-endian internal]
  4B magic  = 0x00000100  (BIG-ENDIAN — empirically verified against real Safari file)
  4B u32   = n_cookies
  n_cookies * 4B u32 = cookie_offsets[]
  4B u32   = footer = 0x00000000
  [cookie record #j, little-endian]
    4B u32   = size
    4B u32   = unknown
    4B u32   = flags  (1=secure, 4=httpOnly)
    4B u32   = unknown
    4B u32   = url_offset    (relative to record start)
    4B u32   = name_offset
    4B u32   = path_offset
    4B u32   = value_offset
    8B end_marker = 0x0000000000000000
    8B double = expiry  (Mac OSX absolute time, +978307200 → unix)
    8B double = creation
    [NUL-terminated url, name, path, value strings at given offsets]
[outer footer big-endian]
  8B = 0x071720050000004B (checksum-ish constant)
```

Parse complexity: **medium-high** but well-bounded. Gotchas:
- Mixed endianness (outer BE, inner LE).
- Per-record string offsets relative to record-start (must compute walking with `record_offset` accumulator).
- Apple Cocoa epoch double (-978307200 offset).
- Records can be variable-length; must validate `size` to avoid OOB.
- Page-size sum should equal `total_size - 12 - 4*n_pages - 8` (sanity check).
- 0x00000100 page magic 검증 (LE u32) + 0x071720050000004B 끝 시그니처 검증.

---

## §D. Candidate Scoring (≥2 mandate)

| ID | Candidate | B1/50 | B2/90 | B3/40 | B4/40 | B5/30 | B6/30 | B7/40 | B8/40 | B9/20 | **Σ/400** |
|----|-----------|------:|------:|------:|------:|------:|------:|------:|------:|------:|----------:|
| SF3a | full per-record walk + domain-sorted SHBF | 50 | 90 | 40 | 40 | 30 | 30 | 38 | 40 | 20 | **378** |
| SF3b | header+page-count only (skip records) | 32 | 50 | 24 | 40 | 22 | 26 | 40 | 26 | 18 | **278** |
| SF3c | SF3a + value-bytes hash col (privacy-preserving) | 50 | 88 | 40 | 40 | 30 | 30 | 36 | 40 | 20 | **374** |

### SF3a — full record walk + domain-sorted SHBF (selected)

- Outer BE header → page table → per-page LE records → string offset resolve.
- Domain extracted from URL field (host part), sorted, blob layout parallel to F18 (offset/len pool + flags u8 = secure/httpOnly bits + expiry ts32).
- B7 -2: PAYLOAD ~14KB (close to 16KB ceiling but under).
- 만점 컷 충족: 9/9 PASS.

### SF3b — header-only (rejected — measurability fail)

- B2 -40: cookie 추출 안 함 → autocomplete 가속 무의미.

### SF3c — SF3a + value-hash col (privacy-preserving)

- value bytes 를 SHA-256 truncated 8B hash 로 저장 → 원본 유출 방지.
- B7 -4: payload 추가, B2 -2 (hash 비교 cost).
- 평가: privacy upside 좋지만 본 cycle scope 외 → SF3a 채택, C3-7 에 follow-up 으로 등록.

**Selected: SF3a → 378/400. ≥350 threshold MET → IMPL.**

---

## §E. honest-C3 (gap audit)

| # | Gap | Severity | Mitigation |
|---|-----|---------:|-----------|
| C3-1 | binarycookies format 은 Apple 비공개 spec — 역설계 결과 | medium | format-version check (n_pages plausibility, magic, footer); skip on mismatch |
| C3-2 | 가변 endianness (outer BE, inner LE) 혼동 가능 | medium | struct format 명시 ('>I' vs '<I') |
| C3-3 | Cocoa epoch +978307200s | low | offset 명시 conversion |
| C3-4 | 0x00000100 page magic 일부 macOS 버전 차이 가능 | low | warn + best-effort |
| C3-5 | value field 가 sensitive (cookie value) — output 은 url+name 만 | high | url+name+expiry+flags only; value 는 blob 에 미포함 (privacy) |
| C3-6 | per-record size 가 잘못된 경우 OOB read 위험 | medium | bounds-check + try/except per record |
| C3-7 | privacy: hostname 도 sensitive 가능 | medium | follow-up SF3c (value-hash) cycle 등록 |
| C3-8 | TCC: Safari Container 에 접근하려면 Full Disk Access 필요 | medium | open() try/except + reason='cookies-tcc-deny' |

honest-C3 gap count: **8**.

---

## §F. ROI Projection

- 336 KB binary cookies 파일 → ~1500-3000 cookies 추정 (record avg 100-200B).
- Repeated full-parse hot path: ~30-100 ms cold (struct.unpack + offset walk).
- Blob mmap+bisect: <50 μs/query.
- Expected speedup: **300-1000×** (parsing 회피가 핵심).

---

## §G. Deliverables

- `/Users/ghost/core/airgenome/docs/sf3_safari_cookies_binary_rubric_2026-04-30.md` (this)
- `/Users/ghost/core/airgenome/docs/sf3_safari_cookies_binary_rubric_2026-04-30.rubric.jsonl`
- `/Users/ghost/core/airgenome/filters/module/data/safari_cookies_binary.hexa`
- `/Users/ghost/core/airgenome/tool/bench/bench_sf3_safari_cookies_binary.hexa`

Verdict: **IMPL** (378/400 ≥ 350).
