# Gate / Filter / Byte 재해석 브레인스토밍 — 2026-04-30

범례: 🟢 적용중/즉시 가치 · 🟡 검토 가치 · 🔴 위험/안티패턴 · ⚪ 추측·경계

---

## 1. 게이트 / 필터 브레인스토밍

### A. 입력 게이트 (pre-admission)

1. 🟢 Allow-list discriminator — raw9 whitelist 패턴 (정확히 매칭만 통과)
2. 🟢 Deny-list — sandbox_deny_enrich (TCC, /private/var, ~/Library)
3. 🟡 Rate-limit (token bucket) — burst N + sustained R/sec
4. 🟡 Leaky bucket — 정확한 평균 보장, burst 흡수 ×
5. 🟡 Concurrency cap — semaphore N (load_balancer slot 이미 있음)
6. 🟡 Quota gate — per-cwd/per-session 일일 호출 한도
7. 🟢 Permission mode — Claude Code 권한 모드 (acceptEdits/plan/etc)
8. 🔴 Implicit allow on unknown — 화이트리스트 누락 시 통과 (fail-open) 안티패턴
9. 🟢 Fail-closed default — 미정의 = 거부 (raw9 대원칙)
10. 🟡 Dry-run gate — write op 전 echo 미러링 (preview)
11. 🟡 Two-key gate — destructive 작업은 사용자 confirm + 에이전트 의도 둘 다
12. 🟡 Cooldown — 직전 동일 호출 후 N초간 차단 (thrash 방지)

### B. 출력 게이트 (post-emission)

13. 🟢 Witness emit — 모든 effect 후 audit.jsonl 기록 (raw9 streak)
14. 🟡 Output sanitizer — secret/key 패턴 마스킹 후 emit
15. 🟡 Size cap — 단일 emit > N KB 차단 (스팸/로그봄빙)
16. 🟡 Schema validator — 출력이 선언된 스키마와 일치할 때만 통과
17. 🟡 Linter gate (post) — emit 직전 raw 192/190/169 룰 통과
18. 🟢 Pre-commit hook — git_pre_commit.hexa
19. 🟢 Pre-push hook — git_pre_push.hexa
20. 🟡 Diff-cap gate — 단일 commit > N 파일 거부
21. 🟡 Binary gate — bin 변경은 별도 lane (실수 commit 방지)

### C. 스트림 필터

22. 🟢 Debounce — N ms 내 동일 키 마지막만 (statusline tick)
23. 🟡 Throttle — 최대 R/sec, 초과분 drop
24. 🟡 Sliding window dedup — 직전 W개 내 동일 시그널 1회만
25. 🟡 RLE filter — 연속 동일값 압축 (statusline RLE 이미 있음)
26. 🟡 Coalesce — 인접 N ms write 합치기 (디스크 I/O 절약)
27. 🟡 Backpressure — consumer lag > T 시 producer pause
28. 🟡 Watermark — late event drop (out-of-order 한계)

### D. 패턴/구문 필터

29. 🟢 Regex match — raw_english_only_watcher 등
30. 🟡 Glob — fast path (regex 보다 가벼움)
31. 🟡 PEG/Tree-sitter — AST 레벨 매칭 (false positive ↓)
32. 🟡 Aho-Corasick — N 패턴 동시
33. 🟡 Boyer-Moore — 단일 큰 패턴
34. 🟡 Bitap — 짧은 패턴 + 근사 매치
35. 🟡 Suffix array — 반복 substring 빠른 lookup
36. 🟡 FST (finite state transducer) — 사전 + 패턴 합성

### E. 확률적 자료구조 (pre-filter)

37. 🟡 Bloom filter — "절대 없음" 빠른 판정, 거짓양성 허용
38. 🟡 Cuckoo filter — Bloom + 삭제 가능
39. 🟡 Quotient filter — locality 좋음, merge 가능
40. 🟡 XOR filter — Bloom 보다 작음, immutable
41. 🟡 Count-Min Sketch — 빈도 근사
42. 🟡 t-digest / HDR histogram — 분위수 근사
43. 🟡 HyperLogLog — cardinality
44. 🟡 MinHash — 유사도
45. 🟡 SimHash — 단일 fingerprint, 거의 동일 문서 dedup

### F. 시간/순서 게이트

46. 🟡 TTL gate — N초 지난 entry 자동 만료
47. 🟢 Vector clock — 인과 순서 확인 (witness chain)
48. 🟡 Lamport timestamp — 단일 카운터 partial order
49. 🟡 HLC (hybrid logical clock) — 시계 skew 흡수
50. 🟡 Monotonic-only — 시간 역행 이벤트 거부
51. 🟡 Gap-fill gate — seq 누락 N개 초과 시 alarm + drop
52. 🔴 Wall-clock 비교만 — NTP skew 시 무너짐

### G. 카디널리티/볼륨 게이트

53. 🟡 Top-K gate — frequency 상위 K개만 통과
54. 🟡 Bottom-K — rare event 만 (anomaly)
55. 🟡 Reservoir sampling — N개 균등 표본
56. 🟡 Priority sampling — weight 비례 표본
57. 🟡 Stratified — 카테고리별 quota 표본

### H. 인과/위트니스 게이트

58. 🟢 Pre-condition witness — 입력 hash 기록 후 진행
59. 🟢 Post-condition witness — 출력 + diff hash
60. 🟢 Forward-spec witness — raw192 (의도 → 결과 일치)
61. 🟡 Replay gate — 과거 witness 재생 시 동일 결과
62. 🟡 Bisect gate — 실패 시 chain 이등분 탐색
63. 🟡 Quorum gate — N개 중 K개 위트니스 합의 (옴메가)

### I. 권한/보안 게이트

64. 🟢 TCC db write ban — raw 시리즈
65. 🟢 uchg flag lock (.roadmap 등 SSOT)
66. 🟢 hx_unlock 감사 — 잠금 해제도 기록
67. 🟡 Capability token — 호출자가 보유한 cap 만 허용
68. 🟡 Path canonicalization — symlink/.. 정규화 후 매칭 (TOCTOU 방지)
69. 🟡 chroot/sandbox-exec gate — OS 레벨 격리
70. 🔴 String prefix check — `/private/var` startswith 만으로는 우회 가능

### J. 스키마/타입 게이트

71. 🟢 JSON Schema validate
72. 🟡 Protobuf/MsgPack required-field
73. 🟡 Refinement type — int + range
74. 🟡 Newtype wrapper — Path vs str 혼용 차단
75. 🟡 Total function check — 모든 input 도메인 다룸

### K. 의미/시맨틱 필터

76. 🟡 Embedding-NN — cosine sim > θ 만 통과
77. 🟡 LLM judge — 작은 모델로 빠른 분류
78. 🟡 NER 기반 — entity 일치만
79. 🟡 Topic model (LDA) — 토픽 분포 거리
80. 🟡 BM25 — 텍스트 검색 ranking

### L. 형식/인코딩 필터

81. 🟡 BOM/encoding sniff — UTF-8 외 거부
82. 🟢 English-only watcher (raw)
83. 🟡 Binary detection (NUL byte) — text-only 채널 보호
84. 🟡 Line-length cap — 단일 라인 N KB
85. 🟡 Newline normalize — CRLF → LF

### M. 압축 게이트

86. 🟡 Tiered TTL — gzip after N days
87. 🟡 Hot/cold tier
88. 🟡 Dictionary compression — zstd dict 사전 학습
89. 🟡 Delta encoding — 연속 record diff 만 저장 (witness chain)

### N. 적응/학습 필터

90. 🟡 Bandit — multi-arm 으로 룰 weight 조정
91. 🟡 Online classifier — passive-aggressive / SGD
92. 🟡 EWMA threshold — 이동평균 ± k·σ 밖 anomaly
93. 🟡 Drift detector — ADWIN/PageHinkley
94. 🟡 Adaptive index
95. 🔴 무제한 학습 메모리 — drift 후에도 옛 weight 잔존

### O. 분산/샤드 게이트

96. 🟡 Consistent hashing — key → shard, rebalance 비용 ↓
97. 🟡 Rendezvous (HRW) hashing — 균등성 좋음
98. 🟡 Shard quota — 단일 shard skew 차단
99. 🟡 Cross-shard fanout cap — broadcast 폭발 방지

### P. 회로차단/장애 게이트

100. 🟡 Circuit breaker — 실패율 > θ 시 N초 차단
101. 🟡 Bulkhead — 풀 격리 (한 종류 실패가 전체 안 잡아먹음)
102. 🟡 Hedged request — N ms 후 백업 호출, 빠른 쪽 채택
103. 🟡 Retry with jitter — exponential + random
104. 🔴 Retry without limit — thundering herd
105. 🟡 Dead-letter queue — N회 실패 후 격리 보관

### Q. 비용/예산 게이트

106. 🟡 Token budget — LLM 호출 token 한도
107. 🟡 Time budget — wall-clock N초 후 abort
108. 🟡 Memory budget — RSS > N MB 시 거부
109. 🟡 Cache-miss budget — miss N회 초과 시 prefetch trigger

### R. 멱등/중복 게이트

110. 🟢 Content-hash dedup — 동일 hash → skip (witness)
111. 🟡 Idempotency key — client 제공 키로 1회만
112. 🟡 Compare-and-swap — etag/version 일치 시만 write
113. 🟡 Exactly-once via 2PC — 비싸지만 강함

### S. 토폴로지/구조 게이트

114. 🟡 DAG cycle 검출 — 의존 cycle 거부
115. 🟡 Depth cap — recursion N 단계 차단
116. 🟡 Fanout cap — 단일 노드 자식 N개 초과 거부
117. 🟡 Diameter cap — 그래프 직경 한계

### T. 메타 (게이트의 게이트)

118. 🟡 Gate ordering — 싼 게이트 먼저 (Bloom → regex → AST)
119. 🟡 Short-circuit — 첫 거부에서 즉시 stop
120. 🟡 Gate pipeline 캐시 — 동일 입력 재계산 회피
121. 🟡 Gate witness — 어느 게이트가 막았나 자체 기록
122. 🟡 Gate bypass token — 디버그용, 사용 자체가 audit
123. 🔴 사일런트 통과 — 게이트 통과/거부 기록 없음 (no_silent_errors 위반)
124. 🟡 Gate budget — 단일 호출 게이트 체인 비용 cap
125. 🟡 Self-test — 게이트 자체가 known-bad 입력으로 주기 검증
126. 🟡 Canary — 새 게이트는 N% 트래픽만, 비교
127. 🟡 Dual-run — old + new 결과 diff, 동일하면 cutover

---

## 2. 무손실 성능/자원/속도 개선 (lossless)

원칙: 입력→출력 동일, 동작 의미 보존. 빨라지거나/가벼워질 뿐.

### A. 캐시 (재계산 회피)

1. 🟢 Memoize pure function — 동일 인자 재계산 0 (raw9 결정성 ↑)
2. 🟢 Hash-keyed result cache — fs::stat → mtime+size key
3. 🟡 Negative cache — "없음" 결과도 캐시 (반복 miss 회피)
4. 🟡 LRU + size cap — 메모리 bound, 동작 동일
5. 🟡 Two-tier cache (L1 in-proc + L2 disk) — cold start 도 빠름
6. 🟡 Computed-property cache — derived 값 invalidate-on-write
7. 🟡 jq/parse 결과 cache — 동일 JSON 재파싱 회피
8. 🟢 Sigdiff cache revive
9. 🔴 Stale-without-invalidation — 재계산 회피하다 진짜 stale 반환 (손실 발생)

### B. 인덱싱 (lookup 가속)

10. 🟡 Hash index — O(1) point lookup
11. 🟡 B-tree — range scan
12. 🟡 Trie / radix tree — prefix
13. 🟡 Inverted index — 토큰 → doc list
14. 🟡 Roaring bitmap — set intersect 빠름, 메모리 작음
15. 🟡 FST — 사전 조회 + 압축
16. 🟡 Skiplist — witness chain seek
17. 🟡 Adaptive index — 사용 패턴 보고 자동
18. 🔴 인덱스 부정합 — write 경로 누락 시 읽기 결과 달라짐 (손실)

### C. 프리컴퓨트 / 머터리얼라이즈

19. 🟡 Build-time table — 런타임 계산 → 빌드시 산출
20. 🟡 Statusline 미리 렌더 (정적 부분)
21. 🟡 Roadmap progress 캐시 — git rev hash 키
22. 🟡 Witness tail cursor — 끝 N개만 항상 메모리

### D. 압축 (lossless 한정)

23. 🟢 gzip → zstd — 동일 비율 + 더 빠름
24. 🟡 zstd long-range mode — 큰 파일 압축률 ↑
25. 🟡 zstd dictionary — JSONL 같은 동질 데이터 비율 ↑↑
26. 🟡 lz4 (속도 우선) — hot path
27. 🟡 Frame/chunk 압축 — random access 유지
28. 🟡 Tiered TTL gzip
29. 🔴 Lossy 알고리즘 혼입 — JPEG/Opus 등 절대 금지

### E. 인코딩 변경 (의미 동일)

30. 🟡 JSON → MessagePack
31. 🟡 JSON → CBOR / BSON
32. 🟡 Decimal string → integer (cents)
33. 🟡 UTF-8 ASCII fast path
34. 🟡 Varint / zigzag — small int 바이트 ↓
35. 🟡 Base64 → binary — 33% 감소
36. 🟡 Schema-aware decode

### F. 자료구조 교체 (asymptotic 개선)

37. 🟡 List 검색 → set/map
38. 🟡 String concat 루프 → builder/rope
39. 🟡 Linear dedup → hashset
40. 🟡 Sort+merge → priority queue
41. 🟡 BFS visited list → bitset
42. 🟡 Bloom prefilter — 비싼 체크 회피만

### G. 배치 / 융합

43. 🟢 N개 fs::write → 1개 — syscall 비용 분할
44. 🟡 Loop fusion — 같은 컬렉션 두 번 순회 → 한 번
45. 🟡 Pipeline fusion — map().filter().map() → 단일 pass
46. 🟡 Batch git commands — `git status` + `git diff` 동시
47. 🟡 Batch jsonl append — fsync 1회로 N record
48. 🟡 Vectorized op — row 루프 → 컬럼 SIMD

### H. 병렬화 (독립 작업)

49. 🟢 독립 fs::read 동시 — async/Promise.all
50. 🟢 멀티 grep — fan-out
51. 🟡 omega cycle — 이미 정책
52. 🟡 work-stealing queue
53. 🟡 SIMD (AVX/NEON) — 압축/해시/검색
54. 🔴 동시성으로 race 도입 — 결과 비결정 (손실)

### I. 지연 vs eager 전환

55. 🟡 Lazy field decode
56. 🟡 Lazy import — cold path 모듈 미로드
57. 🟡 Lazy evaluation — 안 쓴 분기 비용 0
58. 🟡 Eager warmup — 첫 쿼리 cold miss 제거 (반대 방향)

### J. 단축평가 / early exit

59. 🟢 `&&` / `||` 순서 — 싸고 자주 false 인 항부터
60. 🟢 길이 비교 먼저 → 내용 비교
61. 🟡 Hash 비교 먼저 → byte-by-byte
62. 🟡 First-mismatch fast path — 단일 차이로 충분한 곳
63. 🟡 Exists check 먼저 — 없으면 read 안 함

### K. 컴파일러/엔진 최적화

64. 🟡 Constant folding — `2*PI` → 6.28...
65. 🟡 Common subexpression — 동일 식 1회만
66. 🟡 Dead code 제거
67. 🟡 Inlining — call 비용 0
68. 🟡 Tail call — 스택 ↓
69. 🟡 Monomorphization — 제네릭 → 구체 타입
70. 🟡 PGO (profile-guided) — 핫 분기 우선

### L. 메모리 / 캐시 친화

71. 🟡 Struct of arrays — SIMD + cache line
72. 🟡 Cache line 정렬 — false sharing 제거
73. 🟡 NUMA-local 할당
74. 🟡 Frequency-sorted column
75. 🟡 String interning — dedup + 비교 O(1)
76. 🟡 Small-string optimization — heap alloc 회피

### M. 할당기 / 메모리 풀

77. 🟡 Arena allocator — 요청 단위 bulk free
78. 🟡 Object pool — alloc/free 사이클 0
79. 🟡 Slab — 동일 크기 빠른 alloc
80. 🟡 mimalloc/jemalloc 교체
81. 🟡 Stack alloc (alloca/SBO) — heap 회피

### N. 시스템콜 감소

82. 🟢 readv/writev — 여러 buffer 1콜
83. 🟡 sendfile / splice — 유저공간 경유 0
84. 🟡 io_uring (Linux) — 콜 자체 배치
85. 🟡 epoll/kqueue edge-trigger
86. 🟡 mmap 읽기 — read syscall 회피
87. 🟢 madvise SEQUENTIAL
88. 🟢 posix_fadvise

### O. zero-copy / 무복사

89. 🟡 String slice (view) — substring 복사 회피
90. 🟡 Bytes ref-count — 공유 buffer
91. 🟡 mmap 파싱 — 파일 → 메모리 복사 0
92. 🟡 Splice pipe → file
93. 🟡 io_uring fixed buffer

### P. 잠금 / 동기화

94. 🟡 Lock-free queue (MPSC/SPSC)
95. 🟡 RCU — read 측 비용 0
96. 🟡 Reader-writer lock — 독자 다수
97. 🟡 Sharded lock — 컨텐션 ↓
98. 🟡 Atomic refcount → epoch GC

### Q. I/O 패턴

99. 🟡 Buffered write (BufWriter) — write syscall 합병
100. 🟡 fdatasync vs fsync — 메타데이터 동기화 회피
101. 🟡 Append-only log — random write → seq write
102. 🟡 Write-ahead + 비동기 flush
103. 🟡 Direct I/O 단, 전제 충족 시만

### R. 네트워크 (LLM 호출 등)

104. 🟢 Prompt cache — Anthropic 캐시 ttl 5min
105. 🟡 HTTP/2 multiplex — 연결 재사용
106. 🟡 Keep-alive — TLS handshake 회피
107. 🟡 gzip/br content-encoding
108. 🟡 응답 stream — 첫 byte 빠름
109. 🟡 DNS cache + IP pinning
110. 🟡 Coalescing — 동일 prompt N개 1회 호출

### S. 알고리즘 교체 (동일 결과)

111. 🟡 O(n²) → O(n log n) sort+merge dedup
112. 🟡 Naive search → KMP/BM
113. 🟡 String hash → Rabin-Karp rolling
114. 🟡 GCD → binary GCD
115. 🟡 Set intersect → sorted merge
116. 🟡 Levenshtein → bitap (짧은 패턴)

### T. 점진/증분 계산

117. 🟡 Incremental hash — 변경 chunk 만 재해시 (Merkle)
118. 🟡 Watch + diff — 전체 rescan 회피 (format_watch)
119. 🟡 Reactive recompute — 종속 그래프 dirty 표시
120. 🟡 Memoize + invalidate-on-deps

### U. 빌드/런타임 시작 비용

121. 🟡 AOT compile — JIT warmup 0
122. 🟡 Snapshot/heap dump — 시작 즉시 ready
123. 🟡 Pre-link — 동적 링크 lookup ↓
124. 🟡 Module bundle — 파일 N개 → 1개
125. 🟡 Bytecode cache — parse 1회

### V. 데이터 모델 보존하며 표현 변경

126. 🟡 Columnar (Arrow/Parquet) — 분석 쿼리 ↑↑
127. 🟡 Dictionary encoding — 저-cardinality 컬럼
128. 🟡 RLE column
129. 🟡 Delta encoding — 시계열/witness 시퀀스
130. 🟡 Bit-packing — 작은 정수 N비트만

### W. 지표/관측 비용 절감 (관측 정확도 보존)

131. 🟡 Sampling reservoir (관측만)
132. 🟡 Lazy log formatting — disabled level 비용 0
133. 🟡 String interpolation 지연
134. 🟡 Async append — hot path 차단 0

### X. 메타 / 검증

135. 🟢 Property test — 변경 전후 동일 출력 확인 (무손실 입증)
136. 🟢 Differential test — old vs new 결과 diff 0
137. 🟢 Snapshot test — 회귀 잡힘
138. 🟡 Bench guard — 변경 후 느려지면 fail
139. 🟡 Memory guard — RSS 회귀 fail
140. 🟡 Determinism test — 동일 입력 N회 동일 출력 (raw9)

### 무손실 함정 체크리스트

- ❓ Float 재배치 — 부동소수 결합법칙 깨짐 → 결과 다름
- ❓ Hash collision — Bloom/cache 키로 다른 entry 덮음
- ❓ TOCTOU — stat → open 사이 변경
- ❓ Encoding round-trip — UTF-8 정규화 NFC/NFD 손실
- ❓ Sort stability — 동일 키 순서 변함
- ❓ JSON 키 순서 — 의미 동일하지만 byte hash 다름
- ❓ 시간 의존 — 캐시 mtime이 ms 미만이면 동일 mtime 충돌

---

## 3. byte 재해석 (lossless reinterpretation)

원칙: 같은 바이트, 다르게 보기. 복사·파싱·디코드 비용 0 또는 최소.

### A. 메모리 뷰 / 슬라이스 (복사 없음)

1. 🟢 String slice view — `&s[a..b]`, substring 복사 0
2. 🟢 Bytes ref-count slice — Rust `Bytes`, Java ByteBuffer
3. 🟢 mmap 영역을 struct로 cast — read syscall 0
4. 🟡 ArrayBuffer + DataView/TypedArray — 같은 buffer 다른 view
5. 🟡 Subarray (Node Buffer.subarray) — 풀 공유, 0 alloc
6. 🟡 Arena slice — 동일 arena 내 offset+len 만 변경
7. 🟡 Iovec — scatter/gather, 논리 buffer 1개로 보임
8. 🟡 Cord/rope — concat 0-copy 누적

### B. 타입 펀닝 / bit-cast (의미 동일, 표현만 변경)

9. 🟡 `f32 ↔ u32` bit-cast — 비교/해시에 정수 사용
10. 🟡 `f64 ↔ u64` — total-order key (NaN 처리 후)
11. 🟡 Struct ↔ byte array — repr(C)/packed
12. 🟡 Union view — 동일 메모리 다중 해석
13. 🟡 std::bit_cast / Rust bytemuck — 안전 POD 재해석
14. 🔴 reinterpret_cast 무경계 — strict aliasing 위반 UB
15. 🔴 packed struct 직접 dereference — alignment fault (ARM)

### C. 정렬·SIMD 재해석

16. 🟡 u8[16] → __m128i — SIMD 1로드
17. 🟡 u8 stream → u64 chunk — 8바이트씩 읽기 (memcmp 가속)
18. 🟡 Aligned mmap + AVX 로드 — realign 복사 0
19. 🟡 Bitmask popcount — N 비트 검색 한 번에
20. 🔴 미정렬 SIMD 로드 — 일부 ISA 에서 fault

### D. 엔디안 / 바이트 순서

21. 🟡 bswap intrinsic — 4/8 byte 1사이클
22. 🟡 LE↔BE 재해석 시 parse 없이 swap
23. 🟡 Network order ↔ host — htonl 단일 명령
24. 🟡 Endian-agnostic format (varint) — swap 자체 회피
25. 🔴 Endian 가정 누락 — cross-platform 결과 다름

### E. 태그 비트 / 포인터 압축 (같은 바이트, 의미 다중)

26. 🟡 Tagged pointer — low N비트 정렬 보장 → 태그 사용
27. 🟡 NaN-boxing — f64 NaN payload 51비트에 포인터/정수
28. 🟡 Pointer compression (32-bit on 64-bit) — V8/JVM 기법
29. 🟡 Small-string optimization — 포인터 자리에 inline 문자열
30. 🟡 Discriminated 1바이트 — 첫 byte = tag, 나머지 payload
31. 🟡 Bitfield pack — flag N개 1byte 공유
32. 🔴 정렬 가정 깨진 alloc — 태그 비트 충돌

### F. zero-parse 포맷 (바이트 = 구조)

33. 🟡 Cap'n Proto — wire = mem layout, accessor만
34. 🟡 FlatBuffers — table offset 따라 random access
35. 🟡 Arrow IPC — column buffer 그대로 사용
36. 🟡 Postcard/bincode zero-copy — borrow 모드
37. 🟡 simdjson On-demand — bytes → 값 lazy
38. 🟡 MessagePack ext type — 바이너리 그대로 노출
39. 🟡 BSON int32 prefix — 길이만 보고 skip
40. 🟡 DuckDB vector — column buffer 직접 연산

### G. 디스크 ↔ 메모리 동일 표현

41. 🟡 mmap 파일 → struct view — read 0, parse 0
42. 🟡 Persistent memory (DAX) — file = address space
43. 🟡 Append-only log + offset index — seek = 포인터 산술
44. 🟡 MADV_RANDOM/SEQUENTIAL 힌트
45. 🟡 Page cache 공유 — N 프로세스 동일 페이지

### H. 커널 zero-copy (유저공간 경유 0)

46. 🟡 sendfile — file fd → socket fd
47. 🟡 splice — pipe 통해 fd↔fd
48. 🟡 vmsplice — user mem → pipe (페이지 그대로)
49. 🟡 tee — pipe 분기, 복사 0
50. 🟡 io_uring fixed buffer — 등록 buffer 재사용
51. 🟡 io_uring buffer select — 커널이 풀에서 선택
52. 🟡 AF_XDP — 패킷 = mem, NIC ↔ user
53. 🟡 DPDK / RDMA — 네트워크 byte = 호스트 byte
54. 🟢 readv/writev — 여러 buffer 1콜

### I. 파일시스템 reflink/clone (동일 블록 다중 참조)

55. 🟡 APFS clonefile — 동일 블록 두 inode (macOS)
56. 🟡 BTRFS/XFS reflink — `cp --reflink`
57. 🟢 Hard link — 동일 inode
58. 🟡 Symlink + canonicalize 캐시 — resolve 1회
59. 🔴 cp 일반 — reflink 가능한데 풀카피 (성능 손실, 결과 동일)

### J. 공유 메모리 / IPC

60. 🟡 POSIX shm + mmap — 프로세스간 동일 페이지
61. 🟡 memfd + send — fd 패스, byte 0 카피
62. 🟡 ring buffer (SPSC/MPSC) — wrap-around 재해석
63. 🟡 Double-mapping ring — 끝 ↔ 시작 자동 wrap

### K. 해시·비교 — 파싱 없이 byte 직접

64. 🟢 memcmp — equality 빠름
65. 🟡 xxhash on raw bytes — JSON 정규화 회피하면 다른 의미. 동일 byte 만 hit
66. 🟡 BLAKE3 streaming — chunked, parallel
67. 🟡 SipHash — hashmap key 직접
68. 🟡 CRC32 HW — SSE4.2 / ARM CRC
69. 🟡 AES-NI 1-block — 빠른 비암호 fingerprint
70. 🟡 Rolling hash (Rabin-Karp) — 슬라이딩 윈도우 재해석
71. 🔴 hash 후 byte 다르지만 의미 같은 경우 miss — 정규화 필요

### L. 가변 길이 정수 / 비트 스트림 (in-place)

72. 🟡 Varint/ULEB128 — byte 그대로 길이 가변 정수
73. 🟡 Zigzag — 음수 부호 압축
74. 🟡 Bit-pack — N비트 정수 연속, 경계 무관 read
75. 🟡 Elias-Fano — 정렬 정수 압축, random access 유지
76. 🟡 Roaring bitmap — 비트 layout 그대로 set 연산

### M. 문자열 ↔ 바이트 zero-cost

77. 🟢 UTF-8 = byte stream — encode 비용 0
78. 🟡 ASCII fast path — 모든 byte < 128 → 바로 char
79. 🟡 Cow<str> — borrow 가능 시 view, 필요할 때만 복사
80. 🟡 OsStr / Path — 인코딩 변환 없이 byte 보유
81. 🔴 UTF-16 ↔ UTF-8 transmute — 인코딩 다름, 손실

### N. 버퍼 풀 / 슬롯 재해석

82. 🟡 Object pool — alloc 재사용, 같은 byte 슬롯 의미 변경
83. 🟡 Slab — 고정 크기 슬롯, 타입 변경 재할당 0
84. 🟡 Bump allocator + reset — 프레임 끝에 의미 폐기
85. 🟡 Generational arena — index = byte 재해석 키
86. 🟡 Ring buffer 슬롯 덮어쓰기 — 오래된 데이터 in-place 폐기

### O. 압축 프레임 부분 재해석

87. 🟡 zstd skippable frame — 메타데이터 in-place
88. 🟡 LZ4 frame — block 단위 random skip
89. 🟡 gzip member — concat 된 멤버 1개만 디코드
90. 🟡 Parquet row group — column chunk 단위 read
91. 🟡 Arrow IPC dictionary — index 재해석으로 string 참조

### P. 스키마 호환 재해석 (forward/backward)

92. 🟡 Protobuf unknown field skip — wire scan, 파싱 0
93. 🟡 CBOR/JSON ignore unknown — 동일
94. 🟡 v1 struct → v2 view — 추가 필드 default
95. 🟡 Bit-flag 추가 호환 — 미사용 비트 0 보장 시
96. 🔴 알 수 없는 enum value — 무시 vs 거부 정책 미정 시 의미 손실

### Q. 압축 사전 / 인코딩 사전

97. 🟡 zstd dict — 사전 byte 공유, 본문에서 참조만
98. 🟡 String table / interning — id → byte 1회만 보유
99. 🟡 Dictionary column (Arrow) — id 재해석으로 값
100. 🟡 RLE — 같은 byte run, count 만 저장

### R. 메타: 재해석 안전 도구

101. 🟢 bytemuck (Rust) — POD trait 로 안전 cast
102. 🟢 std::bit_cast (C++20) — UB 없는 재해석
103. 🟡 zerocopy (Rust) — alignment + endian 검증
104. 🟡 abomonation — repr 강제 + flat serialize
105. 🟡 rkyv — archived view, deserialize 0
106. 🟡 Captain Proto schema compiler — 검증된 layout

### byte 재해석 함정 체크리스트

- ❓ Alignment — u8* → u32* 비정렬 → ARM/SPARC fault
- ❓ Padding — repr(C) 아니면 컴파일러 마음대로
- ❓ Endian — wire 와 host 다를 때 swap 누락
- ❓ Strict aliasing — C/C++ UB, char* 만 안전
- ❓ Lifetime — view 가 원본보다 오래 살면 dangling
- ❓ Mutation aliasing — 두 view 가 동일 byte 쓰기
- ❓ Encoding round-trip — UTF-8 NFC/NFD 다른 byte 같은 의미
- ❓ Float NaN — bit-cast 후 비교 시 -0/NaN/denormal 처리
- ❓ Partial write 가시성 — torn read, 다른 스레드가 중간 상태 봄
- ❓ Cache line bouncing — 공유 view 가 false sharing 유발

---

## 4. byte 재해석 — 효과 % 표

baseline = 복사/파싱하는 naive 구현. 절감% = (baseline − reinterpret) / baseline × 100. 범위는 워크로드 의존, 전형값.

> **실측 보정 적용**: 2026-04-30 hive 코퍼스 (40MB JSONL) 벤치 결과 반영. 측정값은 `[측정: ... ]` 로 표기. 상세 [bench-results.md](brainstorm-2026-04-30-bench-results.md).

### A. 메모리 뷰 / 슬라이스

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 1 | String slice view | alloc/CPU | 95–99 [측정 JS: **99.8% / 486×**] | 낮 | 🟢 |
| 2 | Bytes ref-count slice | alloc | 80–95 | 낮 | 🟢 |
| 3 | mmap → struct cast | I/O+CPU | 80–98 [미측정 — hexa FFI 필요] | 중 | 🟡 audit tail |
| 4 | DataView / TypedArray | mem | 30–60 | 낮 | 🟡 |
| 5 | Subarray | alloc | 95–100 [측정 Bun: **99.99% / 7,079×**] | 낮 | 🟢 |
| 6 | Arena slice | alloc | 80–99 | 중 | 🟡 omega frame |
| 7 | Iovec scatter/gather | syscall | 50–90 | 낮 | 🟢 jsonl batch |
| 8 | Cord/rope | CPU concat | 50–99 | 중 | 🟡 statusline |

### B. 타입 펀닝 / bit-cast

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 9 | f32↔u32 bit-cast | 비교 CPU | 60–80 [측정 Bun: **0.81 ns/op** — 사실상 무료] | 낮 | 🟡 |
| 10 | f64↔u64 total-order | sort | 60–80 | 낮 | 🟡 |
| 11 | repr(C) struct↔bytes | parse | 90–99 | 중 | 🟡 |
| 12 | Union view | mem | 30–50 | 중 | 🟡 |
| 13 | bytemuck / bit_cast | safety | 0 (안전성만) | 0 | 🟢 |

### C. SIMD 재해석

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 16 | u8[16] → __m128i | CPU | 87–94 (8–16×) | 중 | 🟡 |
| 17 | u8 → u64 chunk memcmp | CPU | 85–92 (~8×) | 낮 | 🟢 |
| 18 | Aligned mmap+AVX | I/O+CPU | 90–98 | 중 | 🟡 |
| 19 | Bitmask popcount | CPU | 90–99 | 낮 | 🟢 |

### D. 엔디안

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 21 | bswap intrinsic | CPU | 90–99 [측정 Bun: **swap32 0.22 ns/op**] | 낮 | 🟢 |
| 22 | LE↔BE in-place | parse | 95–100 | 낮 | 🟢 |

### E. 태그 비트 / 포인터 압축

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 26 | Tagged pointer | mem | 6–12 (포인터당) | 중 | 🟡 |
| 27 | NaN-boxing | mem | 40–50 (dyn val) | 중 | 🟡 |
| 28 | Pointer compression | mem | 40–50 (포인터) | 중 | 🟡 |
| 29 | SSO (small string) | alloc | 70–95 (짧은 str) | 낮 | 🟢 |
| 30 | Discriminated 1-byte tag | mem | 15–25 | 낮 | 🟡 |
| 31 | Bitfield pack | mem | 75–87 (flag) | 낮 | 🟢 |

### F. zero-parse 포맷

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 33 | Cap'n Proto | parse CPU | 95–99 (5–50×) [미측정 — Rust/C++ 환경 필요] | 중 | 🟡 |
| 34 | FlatBuffers | parse | 95–99 [미측정] | 중 | 🟡 |
| 35 | Arrow IPC | parse | 90–99 [미측정] | 중 | 🟡 |
| 36 | Postcard borrow | parse | 70–95 [미측정] | 낮 | 🟡 |
| 37 | simdjson on-demand | parse | 80–95 [측정 Bun: **JSON.parse 가 더 빠름** — Bun JSON 최적화 우월] | 낮 | 🔴 JS 무효 |
| 38 | MessagePack ext | encode | 30–60 [측정: 크기 14%↓ but 디코드 **3× 느림**] | 낮 | ❌ JS 무효 |
| 39 | BSON length skip | parse | 50–90 [미측정] | 낮 | 🟡 |
| 40 | DuckDB vector | analytic | 95–99 (10–100×) [미측정] | 중 | 🟡 |

### G. 디스크 ↔ 메모리

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 41 | mmap struct view | I/O+parse | 90–99 | 중 | 🟡 |
| 42 | PMEM / DAX | load | 95–99 | 고 (HW) | 🔴 인프라 |
| 43 | Append-only log | write I/O | 50–90 | 낮 | 🟢 (이미) |
| 44 | madvise hint | I/O | 10–30 | 0 | 🟢 |
| 45 | Page cache share | I/O | 50–100 [측정 sudo purge: **72.6% / 3.66×** (NVMe; HDD 면 더 큼)] | 0 | 🟢 |

### H. 커널 zero-copy

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 46 | sendfile | memcpy | 50 (1차 카피 out) | 낮 | 🟡 |
| 47 | splice | memcpy | 80–99 | 중 | 🟡 |
| 48 | vmsplice | memcpy | 95–99 | 고 | 🔴 |
| 50 | io_uring fixed buf | latency | 20–50 | 중 | 🟡 |
| 52 | AF_XDP | 패킷경로 | 90–99 | 고 | 🔴 |
| 53 | DPDK / RDMA | syscall | ~100 | 고 | 🔴 |
| 54 | readv/writev | syscall | 50–90 [측정 Bun: **3.22× / 69%** (100→1 write)] | 낮 | 🟢 |

### I. 파일시스템 reflink/clone

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 55 | APFS clonefile | copy time | 99–100 [측정: **85.8% / 7.06× vs cp**] | 0 | 🟢 macOS |
| 56 | BTRFS reflink | copy time | 99–100 | 0 | (linux only) |
| 57 | Hard link | copy | 100 [측정: **82.5% / 5.71×**, clonefile 보다 느림] | 0 | 🟢 |
| 58 | canonicalize cache | lookup | 50–90 | 낮 | 🟡 |

### J. 공유 메모리 / IPC

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 60 | shm+mmap | IPC copy | 95–100 | 중 | 🟡 |
| 61 | memfd send | IPC copy | 95–100 | 중 | 🟡 |
| 62 | SPSC ring | latency | 50–90 | 중 | 🟡 |

### K. 해시·비교 (파싱 없이)

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 64 | memcmp | CPU | 80–95 (5–10×) [측정: **99.9% / 1500×+ vs byte loop**] | 낮 | 🟢 |
| 65 | xxhash on raw bytes | CPU | 30–70 [측정: **89.5% / 10.86× vs sha256** (Bun wyhash)] | 낮 | 🟢 |
| 66 | BLAKE3 parallel | CPU | 75–87 (4–8×) [미측정 — b3sum 부재] | 낮 | 🟡 |
| 68 | CRC32 HW | CPU | 80–95 [측정: 71% / 3.4× vs sha256 — wyhash 보다 느림] | 낮 | 🟡 |
| 69 | AES-NI fingerprint | CPU | 70–90 [측정 안함 — wyhash 가 더 빠름] | 낮 | 🔴 |
| 70 | Rabin-Karp rolling | CPU sliding | 90–99 [측정: **96.7% / 30.77×**] | 낮 | 🟡 |

### L. 가변길이 / 비트 스트림

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 72 | Varint / ULEB128 | bytes | 50–87 [측정: **53% / 2.14×** crime; CPU 6× trade-off] | 낮 | 🟡 trade-off |
| 73 | Zigzag | bytes | 동일 | 낮 | 🟡 |
| 74 | Bit-pack N-bit | mem | 50–87 | 낮 | 🟡 |
| 75 | Elias-Fano | mem | 50–90 (sorted) [미측정] | 중 | 🟡 |
| 76 | Roaring bitmap | mem+CPU | 80–99 (sparse) [미측정] | 중 | 🟡 |

### M. 문자열 ↔ 바이트

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 77 | UTF-8 = byte stream | encode | 100 [측정: **65% / 2.9× — 변환만, 다운스트림 처리 포함시 더 큼**] | 0 | 🟢 |
| 78 | ASCII fast path | CPU | 50–75 [측정: byte vs charCodeAt 21%, **vs for-of 92% / 12×**] | 낮 | 🟢 |
| 79 | Cow<str> borrow | alloc | 50–90 | 낮 | 🟢 |
| 80 | OsStr / Path | convert | 100 | 0 | 🟢 |

### N. 버퍼 풀 / 슬롯 재해석

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 82 | Object pool | alloc | 90–99 [측정 Bun: **-505% (느려짐)** — V8 inline-alloc 우월; C/Rust 에서만 유효] | 낮 | 🔴 JS 무효 |
| 83 | Slab | alloc | 90–99 [동상 — JS 무효] | 낮 | 🔴 JS 무효 |
| 84 | Bump + reset | alloc | 95–100 [측정 Bun proxy: 45.6% / 1.83× — JS Buffer 풀 효율; C/Rust 재측정 필요] | 낮 | 🟡 |
| 85 | Generational arena | alloc | 85–95 [미측정 — Rust] | 중 | 🟡 |
| 86 | Ring overwrite | alloc | 100 [측정: ring 도 naive 보다 느림 (V8 한정)] | 낮 | 🔴 JS 무효 |

### O. 압축 프레임 부분 재해석

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 87 | zstd skippable frame | decode | 90–99 [미측정] | 낮 | 🟡 |
| 88 | LZ4 frame skip | decode | 80–95 [미측정] | 낮 | 🟡 |
| 89 | gzip member | decode | 50–90 [측정: **66.1% / 2.95× (1/3 만)**] | 낮 | 🟡 |
| 90 | Parquet column read | I/O | 70–95 [미측정 — DuckDB 필요] | 중 | 🟡 |
| 91 | Arrow dictionary | mem | 70–95 [측정 (#99로 대체): **69.8% / 3.32×**] | 중 | 🟡 |

### P. 스키마 호환 재해석

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 92 | Protobuf unknown skip | parse | 50–90 | 낮 | 🟡 |
| 93 | CBOR ignore unknown | parse | 50–90 | 낮 | 🟡 |
| 94 | v1→v2 struct view | migrate | 100 | 낮 | 🟡 |
| 95 | Bit-flag forward compat | migrate | 100 | 낮 | 🟢 |

### Q. 사전 / 인코딩 사전

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 97 | zstd dict | size | 30–70 [측정: **whole-file ~0%**, **per-row 2.44× 추가** (1.31→3.20×)] | 중 | 🟡 jsonl |
| 98 | String interning | mem | 50–90 [측정 Bun: **0%** — JSON.parse 자동 intern; hexa runtime 에서만 유효] | 낮 | 🟢 |
| 99 | Arrow dict column | mem | 70–95 [측정: **69.8% / 3.32×** for repeated keys] | 중 | 🟢 |
| 100 | RLE | size | 80–99 [측정 run-heavy: **90.2% / 10.25×**] | 낮 | 🟢 (이미) |

### R. 안전 도구 (절감 0, 안전성)

| # | 항목 | 주차원 | 절감% | 비용 | 적용 |
|---|---|---|---|---|---|
| 101 | bytemuck | safety | 0 | 0 | 🟢 |
| 102 | std::bit_cast | safety | 0 | 0 | 🟢 |
| 103 | zerocopy | safety | 0 | 0 | 🟢 |
| 104 | abomonation | parse | 95–99 | 중 | 🟡 |
| 105 | rkyv | parse | 95–99 | 중 | 🟡 |

---

## 5. ROI 상위 — 실측 재정렬

가설 ROI 순위는 실측 후 크게 변동. 아래는 **실측 기반 재순위**.

| 순위 | 항목 | 실측 절감% | 난이도 | hive 즉시 가치 |
|---|---|---|---|---|
| 1 | #5 Buffer.subarray (view) | **99.99% / 7,079×** | 0 | 핫패스 slice 절대 view |
| 2 | #64 Buffer.equals (memcmp) | **99.95% / 2026×** | 0 | witness hash 비교 |
| 3 | #1 String slice view | **99.8% / 486×** | 0 | jsonl 토큰 (auto-share) |
| 4 | #70 Rabin-Karp rolling | **96.7% / 30.77×** | 낮 | 슬라이딩 윈도우 |
| 5 | #100 RLE (run-heavy) | **90.2% / 10.25×** | 낮 | 압축 |
| 6 | #65 wyhash/xxh64 | **89.5% / 10.86×** vs sha256 | 0 | fingerprint, 비암호 hash |
| 7 | #55 APFS clonefile | **85.8% / 7.06×** | 0 | SSOT 다중 view (cp -c) |
| 8 | #57 Hard link | **82.5% / 5.71×** | 0 | clonefile 보다 약간 느림 |
| 9 | #45 Page cache (NVMe) | **72.6% / 3.66×** | 0 | 자동 (HDD 면 더 큼) |
| 10 | #99 Dict column encoding | **69.8% / 3.32×** | 낮 | jsonl 키 컬럼 |
| 11 | #54 writev (iovec) | **69% / 3.22×** | 낮 | jsonl batch append |
| 12 | #89 gzip member skip | **66.1% / 2.95×** | 낮 | multi-member archive |
| 13 | #77 UTF-8 byte stream | **65% / 2.9×** | 0 | 변환 비용 제거 |
| 14 | #97 zstd dict (per-row) | **2.44× 추가** (1.31→3.20×) | 중 | witness chain row |
| 15 | #72 Varint | **53% / 2.14×** (CPU 6× ↑) | 낮 | trade-off, 저장만 |

### 적용 금지 (실측 후 JS/Bun 한정 안티패턴 확정)

| 항목 | 사유 |
|---|---|
| ❌ #8 Cord/rope | `string +=` 가 5.5× 빠름 (V8 cons-string) |
| ❌ #82-86 Object pool / Slab / Ring | V8 inline-alloc 이 6× 빠름 |
| ❌ #98 String intern | JSON.parse 자동 intern (heap delta 0) |
| ❌ #37 simdjson / #38 MsgPack 속도 | Bun JSON.parse 가 더 빠름 |
| ❌ #97 zstd dict (큰 파일) | long-range 모드가 이미 잡음 |

### 중위 (효과 큼, 도입 비용 중) — 미측정

| 순위 | 항목 | 가설 절감% | 사유 |
|---|---|---|---|
| 16 | #33 Cap'n Proto | 95–99 | Rust/C++ 환경 필요 |
| 17 | #105 rkyv | 95–99 | Rust |
| 18 | #76 Roaring bitmap | 80–99 | npm 도입 후 측정 |
| 19 | #3 mmap struct cast | 80–98 | hexa FFI 후 측정 |
| 20 | #84 Bump arena (C/Rust) | 95–100 | hexa runtime 후 |

### 하위 (HW/인프라 의존)

| 항목 | 사유 |
|---|---|
| #42 PMEM/DAX | HW 부재 |
| #48 vmsplice | UB 위험 |
| #52 AF_XDP / #53 DPDK | 커널 모듈 |
| #56 BTRFS reflink | macOS 비대상 |

---

## 6. hive 즉시 적용 후보 (byte 재해석 한정)

- #1 #2 #3 — witness chain, jsonl 읽기 모두 mmap + slice 가능
- #38 — MessagePack 변환 시 ext 로 hexa 고유 타입 byte 보존
- #57 #56 — `.roadmap` 등 SSOT 의 다중 view 는 hardlink/reflink
- #64 #68 — witness hash 비교 memcmp + CRC32 HW
- #97 — jsonl 동질성 → zstd dict 사전 학습
- #101 #102 — hexa-lang FFI 경계에 안전 캐스트 도구 표준화
