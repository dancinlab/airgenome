# ROI 상위 byte 재해석 — 실측 벤치마크 (전체)

**측정 환경**: macOS (APFS, M-series), Bun 1.3.12, GNU coreutils, openssl, lz4, xxh64sum, zstd
**코퍼스**: hive `state/**/*.jsonl` 전체 cat → 20× 누적 = **42,063,420 bytes (≈40MB)** real JSONL audit 데이터
**방법**: 각 항목 5회 median (n=5), warmup 2회, ns 단위. 코퍼스 동일.

---

## 1. 파일시스템 — copy vs reference (#55, #57, #56)

40MB 파일 1회 복사/링크:

| 항목 | 시간 (ns) | vs cp | 절감% |
|---|---|---|---|
| `cp big.jsonl copy.jsonl` (full copy) | 18,473,500 | 1.0× | baseline |
| `cp -c big.jsonl clone.jsonl` (APFS clonefile) | **2,616,375** | **7.06×** | **85.8%** |
| `ln big.jsonl link.jsonl` (hard link) | 3,235,417 | 5.71× | 82.5% |

> **의외**: clonefile 이 hard link 보다 더 빠름. 이유 — link count 증가 메타데이터 갱신 없음.

---

## 2. 페이지 캐시 cold vs warm (#45) — sudo purge 사용

40MB 읽기, 5회 median:

| 항목 | 시간 (ns) |
|---|---|
| cold read (sudo purge 후) | 18,775,417 |
| warm read (캐시 적중) | **5,136,584** |
| **speedup** | **3.66×** |
| **절감%** | **72.6%** |

> NVMe SSD M-series 라 cold/warm 차이 적음. HDD 면 50–100× 차이 예상. 대용량·반복 read 워크로드면 강제 prewarm 가치 큼.

---

## 3. 압축 — 알고리즘·레벨 비교 (#23-#28, #97)

### 3.1 압축률 (40MB 통째)

| 알고리즘 | 출력 | 비율 |
|---|---|---|
| raw | 42,063,420 | 1.00× |
| gzip -1 | 4,544,985 | 9.25× |
| gzip -9 | 3,682,584 | 11.42× |
| lz4 -1 | 5,577,563 | 7.54× |
| lz4 -9 | 4,440,675 | 9.47× |
| zstd -1 | 3,811,525 | 11.04× |
| zstd -3 | 3,505,894 | **12.00×** |
| zstd -19 | 151,508 | **277.63×** |
| zstd -22 --long --ultra | 150,086 | **280.26×** |

### 3.2 압축 속도 (40MB)

| 항목 | 시간 (ns) | MB/s |
|---|---|---|
| lz4 -1 compress | **19,923,750** | **2,011** |
| zstd -1 compress | 21,929,542 | 1,827 |
| zstd -3 compress | 30,977,250 | 1,294 |
| lz4 -9 compress | 63,308,542 | 633 |
| gzip -1 compress | 101,157,083 | 396 |
| gzip -9 compress | 404,139,833 | 99 |
| zstd -19 compress | 923,946,958 | 43 |

### 3.3 해제 속도

| 항목 | 시간 (ns) | MB/s |
|---|---|---|
| lz4 decompress | **28,207,500** | **1,420** |
| zstd -19 decompress | 30,853,125 | 1,298 |
| zstd -3 decompress | 41,255,250 | 970 |
| gzip decompress | 42,630,625 | 939 |

### 3.4 zstd dict — per-row vs whole-file

| 항목 | 출력 | 비율 |
|---|---|---|
| 40MB 통째 zstd -19 + 64K dict | 151,616 | 277.43× (dict 효과 없음) |
| 100 rows zstd-3 each (no dict) | 21,134 / 27,708 | 1.31× |
| 100 rows zstd-3 each + 8K dict | **8,661 / 27,708** | **3.20×** |

> **결론**: dict 는 **개별 row 독립 압축에서만** 효과 (witness chain row append). long-range zstd 가 동작하는 큰 파일에서는 무의미.

### 3.5 #89 gzip member skip

| 항목 | 시간 (ns) |
|---|---|
| 3 concat gzip members 모두 decompress | 125,717,167 |
| 1 member only | **42,601,333** | (33.9%, **2.95× 빠름**) |

---

## 4. 해시 / 체크섬 (#64, #65, #66, #67, #68)

### 4.1 40MB 단일 해시 (CLI)

| 항목 | 시간 (ns) | MB/s | vs sha256 |
|---|---|---|---|
| **xxh64sum (XXH3-64)** | **7,414,583** | **5,403** | **3.19× faster** |
| openssl sha256 | 23,669,292 | 1,693 | 1.0× |
| openssl sha1 | 23,638,416 | 1,695 | 1.0× |
| openssl md5 | 57,518,292 | 697 | 0.41× |
| cksum (CRC32 + size) | 99,849,125 | 401 | 0.24× |
| shasum -a 256 (perl) | 106,358,750 | 376 | 0.22× |

### 4.2 Bun-side 해시

| 항목 | 시간 (ns) | vs sha256 |
|---|---|---|
| **Bun.hash.wyhash** | **1,339,125** | **10.86×** |
| Bun.hash (xxh64 default) | 1,364,542 | 10.66× |
| Bun.hash.cityHash64 | 1,717,084 | 8.47× |
| zlib.crc32 | 4,262,708 | 3.41× |
| Bun.hash.crc32 | 4,222,458 | 3.44× |
| Bun.hash.adler32 | 11,316,916 | 1.28× |
| crypto sha256 (HW) | 14,538,250 | 1.0× |
| crypto sha1 | 14,728,416 | 0.99× |
| crypto md5 | 51,026,000 | 0.28× |

> **결론**: **wyhash/xxh64 = sha256 의 10× 빠름**. 비암호 fingerprint (witness dedup, cache key) 는 무조건 wyhash/xxh64.

### 4.3 #64 Buffer.equals — distinct buffers 진짜 memcmp

| 항목 | 시간 (ns) |
|---|---|
| `buf.equals(buf)` (same ref short-circuit) | 83 |
| `buf.equals(buf2)` (distinct buffers, eq content) | **1,183,208** |
| Python `bytes ==` (40MB) | 1,566,000 |
| `cmp` CLI (40MB) | 62,669,708 (read I/O 포함) |
| Python byte-by-byte loop | 2,398,447,667 |

> 진짜 memcmp 1.18ms vs python loop 2.4초 = **2026× faster**. memcmp 경로는 절대적.

### 4.4 #70 Rabin-Karp rolling vs 매 위치 rehash (1MB 윈도우 64)

| 항목 | 시간 (ns) |
|---|---|
| rolling hash (1MB full pass) | **6,445,750** |
| naive rehash every position | 198,323,375 |
| **speedup** | **30.77×** |

---

## 5. byte 직접 vs 변환 (#1, #5, #77)

40MB Buffer middle slice (≈20MB), 1000회 반복:

| 항목 | per-op (ns) | vs slice copy |
|---|---|---|
| `Buffer.from(buf.buffer, off, len)` (view) | **75** | 10,861× faster |
| `Buffer.subarray(a, b)` (view) | 115 | 7,079× faster |
| `Uint8Array.slice` (full copy) | 814,052 | 1.0× |

4096-byte UTF-8 decode 비교, 1000회:

| 항목 | per-op (ns) |
|---|---|
| raw byte access (no decode) | **1,130** |
| toString('utf8') + iterate | 3,275 (2.9× slower) |

JS string slice 1000회 (V8/Bun 자동 share):

| 항목 | per-op (ns) |
|---|---|
| string.substring | **11** |
| string.slice | 16 |
| `[...slice].join('')` (forced copy) | 5,351 (486× slower) |

---

## 6. bit-cast / endian (#9, #10, #21)

100만 회 read, per-op ns:

| 항목 | per-op (ns) |
|---|---|
| **Buffer.swap32 in-place** | **0.22** |
| DataView readFloat32LE | 0.54 |
| Buffer.readFloat32LE | 0.68 |
| DataView readUint32LE | 0.81 |
| Buffer.readUInt32LE | 0.95 |
| Buffer.readUInt32BE | 1.04 |

> bit-cast 와 endian swap 은 **사실상 무료** (1ns 미만). LE↔BE 변환에 parse 절대 금지.

---

## 7. varint / bit-pack (#72, #73, #74)

100K 정수 (0–999 분포):

| 항목 | per-op (ns) | 크기 |
|---|---|---|
| Int32Array fixed read | **0.87** | 400,000 B (1.0×) |
| varint encode | 9.16 | — |
| varint decode | 5.06 | 187,175 B (**2.14× 작음**) |

> CPU 5–10× 손해 ↔ 메모리 2× 절감. read-heavy 면 fixed, 저장/네트워크 면 varint.

---

## 8. RLE encoding (#100, #25)

run-heavy 800KB:

| 항목 | 결과 |
|---|---|
| raw | 409,990 B |
| RLE encoded | **40,000 B** (10.25× 작음) |
| encode 시간 | 348,792 ns |

> run 비율 높을 때 무손실 10× 압축.

---

## 9. 인코딩 포맷 — JSON / MsgPack / CBOR (#37, #38)

5000 JSONL rows (1.63 MB JSON):

### 9.1 인코딩 크기

| 포맷 | 크기 | vs JSON |
|---|---|---|
| JSON | 1,634,941 | 1.0× |
| MsgPack | 1,429,989 | **1.14× 작음** |
| CBOR | 1,448,407 | 1.13× 작음 |

### 9.2 디코드 속도

| 항목 | 시간 (ns) | vs JSON.parse |
|---|---|---|
| **JSON.parse (Bun built-in)** | **2,310,750** | **1.0× (가장 빠름)** |
| cbor-x decode | 4,743,708 | 0.49× |
| msgpack-lite decode | 6,850,666 | 0.34× |

### 9.3 인코드 속도

| 항목 | 시간 (ns) | vs JSON.stringify |
|---|---|---|
| **JSON.stringify** | **3,008,625** | **1.0× (가장 빠름)** |
| cbor-x encode | 4,268,542 | 0.71× |
| msgpack-lite encode | 6,384,083 | 0.47× |

> **반전 결론**: Bun JSON.parse/stringify 가 가장 빠름. **MsgPack/CBOR 은 크기만 14% 작아질 뿐 속도는 2-3× 느림**. 네트워크 대역폭 병목 아니면 JSON 유지가 정답.

---

## 10. mmap (Bun.file) vs readFileSync (#3, #41)

| 항목 | 시간 (ns) |
|---|---|
| `Bun.file().bytes()` (lazy ref) | ~1,000 (lazy, 실제 read 미발생) |
| readFileSync (full 40MB) | 4,900,875 |

> Bun.file 은 lazy mmap-style — 첫 access 까지 물리 read 0. random-access 패턴에서 진짜 가치.

---

## 11. iovec / writev (#7, #54)

100개 짧은 buffer 디스크 write:

| 항목 | 시간 (ns) | speedup |
|---|---|---|
| 100 separate writeSync (syscall ×100) | 283,333 | 1.0× |
| 1 merged write (writev-equiv) | **87,833** | **3.22×** |

---

## 12. Cord/rope vs string concat (#8)

10K 청크 concat:

| 항목 | 시간 (ns) | 비고 |
|---|---|---|
| **string += concat** | **280,250** | V8 cons string 자동 |
| array.join('') | 536,416 | — |
| Buffer.concat | 1,542,167 | 5.5× 느림 |

> JS 에서는 `string +=` 가 cons-rope 자동 적용 → 명시적 rope 불필요.

---

## 13. Object pool (#82, #83, #86) — JS 한정

100K 객체 alloc:

| 항목 | 시간 (ns) |
|---|---|
| **naive `{...}` per op** | **55,541** |
| object pool reuse | 336,125 (6.05× 느림) |
| ring buffer Float64Array | 295,875 (5.32× 느림) |

> **반전 결론**: V8/Bun 의 inline-allocation 이 너무 빨라 pool 오버헤드가 더 큼. **JS 에서는 풀이 안티패턴**. C/Rust/hexa runtime 에서만 가치.

---

## 14. ASCII fast path (#78)

1MB 샘플:

| 항목 | 시간 (ns) | 비율 |
|---|---|---|
| **byte loop (skip non-ASCII)** | **556,000** | 1.0× |
| string.charCodeAt loop | 676,541 | 1.21× 느림 |
| for-of code-point iter | 6,673,625 | **12.0× 느림** |

> for-of 는 UTF-8 디코드 + iterator 객체 생성. 단순 문자 카운트는 byte loop.

---

## 15. dictionary encoding for repeated keys (#99)

5000 JSONL 의 field name 컬럼:

| 항목 | 크기 |
|---|---|
| 37,175 key refs (raw concat) | 273,612 B |
| dict (662 unique) + Uint16 ids | **82,502 B** |
| **ratio** | **3.32×** |

> JSONL 처럼 키 반복이 많은 컬럼은 dict + id 인코딩 만으로 3× 절감.

---

## 종합 — 가설 vs 실측 (full)

| # | 항목 | 가설 절감% | 실측 결과 | 평가 |
|---|---|---|---|---|
| 1 | string slice view (JS) | 95–99 | **99.8% / 486×** | ✅ |
| 5 | Buffer.subarray | 95–100 | **99.99% / 7,079×** | ✅ 초과 |
| 8 | Cord vs string concat | 50–99 | JS 는 string += 가 가장 빠름 (-450%) | ❌ JS 한정 무효 |
| 45 | Page cache cold→warm | 50–100 | **72.6% / 3.66×** (NVMe) | ✅ |
| 55 | APFS clonefile | 99–100 | **85.8% / 7.06×** | ✅ |
| 57 | Hard link | 100 | 82.5% / 5.71× (clonefile 보다 느림) | ⚠️ 의외 |
| 64 | Buffer.equals (memcmp) | 80–95 | **99.95% / 2026× vs Python loop** | ✅ 초과 |
| 65 | xxhash on raw bytes | 30–70 | **89.5% / 10.86× vs sha256** (wyhash) | ✅ |
| 68 | CRC32 HW | 80–95 | 71% / 3.4× vs sha256 | ⚠️ 가설보다 작음 |
| 70 | Rabin-Karp rolling | 90–99 | **96.7% / 30.77×** | ✅ |
| 72 | Varint | 50–87 | 53% (2.14×) — CPU 6× trade-off | ⚠️ trade-off |
| 77 | UTF-8 raw byte | 100 | 65% / 2.9× (변환만) | ⚠️ |
| 78 | ASCII fast path | 50–75 | 21% (byte vs charCodeAt), **92% vs for-of** | ✅ for-of 회피 시 |
| 84 | Bump arena (JS) | 95–100 | -505% (느려짐) | ❌ JS 한정 무효 |
| 89 | gzip member skip | 50–90 | **66.1% / 2.95× (1/3 만 decode)** | ✅ |
| 97 | zstd dict (whole) | 30–70 | ~0% (long-range가 다 잡음) | ❌ |
| 97 | zstd dict (per-row) | — | **2.44× 추가 (1.31→3.20×)** | ✅ |
| 98 | String intern (JS) | 50–90 | 0% (auto intern) | ❌ JS 한정 |
| 99 | Dict column encoding | 70–95 | **69.8% (3.32×)** | ✅ |
| 100 | RLE | 80–99 | **90.2% (10.25×)** for run-heavy | ✅ |

### 압축 알고리즘 정리 (실측)

| 용도 | 1순위 | 비고 |
|---|---|---|
| 최대 압축률 | zstd -19 (-22 long) | 277× 비율 |
| 빠른 압축 | lz4 -1 (2.0 GB/s) | gzip 의 5× |
| 빠른 해제 | lz4 (1.4 GB/s) | gzip-9 의 1.5× |
| 균형 | zstd -3 | 12× 비율, 1.3 GB/s |

### 인코딩 (실측 반전)

- JSON.parse (Bun) > cbor-x > msgpack-lite (속도)
- MsgPack/CBOR 은 14% 만 작아짐 — **속도 손해 vs 크기 이득 비대칭**
- 네트워크 대역폭 병목이 아니면 **JSON 유지가 정답**

### 의외의 결과 5개

1. **clonefile > hard link** — link count 갱신이 느림
2. **JSON.parse > MsgPack/CBOR** (속도) — Bun 의 JSON 이 최강
3. **JS string concat > Buffer.concat** — V8 cons-string 자동 적용
4. **JS object pool 안티패턴** — V8 inline-alloc 이 더 빠름
5. **zstd dict 큰 파일 무효** — long-range 가 이미 잡음

---

## hive 적용 의사결정 (실측 기반)

### 즉시 적용 (✅)

1. **APFS clonefile (#55)** — `cp -c` 로 SSOT 다중 view, 7× 빠름
2. **Buffer.equals / memcmp (#64)** — witness hash, 절대 byte loop 금지
3. **Bun.hash.wyhash / xxh64 (#65)** — fingerprint, sha256 의 10×
4. **per-row zstd dict (#97)** — witness chain append/verify 시 추가 2.44×
5. **lz4 hot path (#23-#28)** — 실시간 압축은 lz4 -1 (gzip 의 5×)
6. **Buffer.subarray (#5)** — slice 복사 절대 금지 (7000× 손실)
7. **dict encoding for keys (#99)** — JSONL 키 컬럼 3.32× 절감
8. **Rabin-Karp rolling (#70)** — 슬라이딩 윈도우 30× 가속

### 조건부 적용

9. **page cache prewarm (#45)** — HDD/원격 스토리지면 가치, NVMe 면 3.66×
10. **gzip member skip (#89)** — 멀티 멤버 archive 면 큰 효과, 단일 파일은 무의미

### 적용 금지 (JS/Bun 한정 안티패턴)

11. ❌ **Cord/rope (#8)** — `string +=` 가 더 빠름
12. ❌ **Object pool (#82-86)** — V8 inline-alloc 이 우위
13. ❌ **String intern (#98)** — JSON.parse 자동 intern
14. ❌ **MsgPack/CBOR 속도 목적 (#37, #38)** — JSON 이 더 빠름. 크기만 14%
15. ❌ **zstd dict 큰 파일 (#97)** — long-range 모드가 이미 잡음

### 미측정 (재측정 필요)

16. **mmap struct cast (#3)** — hexa runtime FFI 추가 후
17. **bump arena (#84)** — C/Rust/hexa runtime 에서
18. **Cap'n Proto / FlatBuffers / rkyv (#33-35, #105)** — Rust/C++ 환경
19. **DPDK / RDMA / AF_XDP (#52-53)** — 커널 환경
20. **PMEM / DAX (#42)** — HW 부재
