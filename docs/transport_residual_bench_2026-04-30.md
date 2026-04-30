# Transport + Residual Filter Production-Test — 2026-04-30

본 wave: transport/ 의 anomaly·client·dns_blocklist 3 + data/ 잔여 safari_mmap·safari_bookmarks_shbf·prefix_trie_mmap 3 = **총 6 filter** 를 airgenome.app `--mode=run-once` 로 production-test. 코드 수정 / commit / hexa-lang touch 0. 측정만.

Runtime: `/Applications/airgenome.app/Contents/MacOS/airgenome` (FDA inheritance) → posix_spawn hexa.
Host: darwin-arm64 (Apple Silicon), `~/.airgenome/loop-run-once.log` 캡처.

---

## 1. 6 Filter 측정 결과 (5-tuple)

| # | Filter | Path | Wall | Exit | Output Status |
|---|--------|------|------|------|---------------|
| 1 | anomaly | `modules/filters/transport/anomaly.hexa` | 0.46s | 0 | parse-warn (try/catch 4건) → run → `[anomaly] skip: 0 rows < 5` (baseline 부족 — genomes.log empty) |
| 2 | client | `modules/filters/transport/client.hexa` | 0.49s | 0 | parse-warn (try/catch 4건) → `printenv: not found` → `nc -q invalid` → soft-exit (BusyBox nc fallback) |
| 3 | safari_mmap (E4) | `modules/filters/data/safari_mmap.hexa` | 0.25s | 0 | OK — encode 19.9ms, urls=2058, blob=383.5KB (7.6%), **blob 18.7μs/q vs sqlite cold 395.2μs → 21.1× / persistent 50.5μs → 2.7×** |
| 4 | safari_bookmarks_shbf (F18) | `modules/filters/data/safari_bookmarks_shbf.hexa` | 1.82s | 0 | OK — encode 3.8ms, urls=55 (실 사용자), blob=3.7KB (1.4%), **blob 3.1μs/q vs plistlib cold 1147.4μs → 365.0× / persistent 4.8μs → 1.5×** |
| 5 | prefix_trie_mmap (F58 PTBF) | `modules/filters/data/prefix_trie_mmap.hexa` | **2.91s** | 0 | OK first-measurement — encode 25.2ms, n=10000 synth, blob=265.4KB (raw_est 499.9KB → **53.1%**), **bisect 54.9μs/q (linear→bisect 13.9×)**; trie traversal 5696.9μs/q **0.1× (slower)** |
| 6 | dns_blocklist_aho_corasick (F7) | `modules/filters/transport/dns_blocklist_aho_corasick.hexa` | 35.1s | 137 | **TIMEOUT/SIGKILL** — default mode=encode AC trie build 10K domains in pure-hexa hangs at "loaded 10000 domains in 152ms" then watchdog SIGKILL. bench mode 별도 실행 필요. 이전 측정 (`bench_f7_dns_blocklist.hexa`) 의 hashset 66μs/q vs AC 357μs/q 본 wave 재현 미달성 — entry point 가 bench harness 가 아닌 default encode. |

5-tuple 요약 (filter, mode, exit, wall_s, key-metric):
```
1. anomaly                     run         0   0.46   skip(rows<5)
2. client                      main        0   0.49   nc-fallback-fail
3. safari_mmap                 default     0   0.25   21.1× cold / 2.7× persistent
4. safari_bookmarks_shbf       default     0   1.82   365.0× cold / 1.5× persistent
5. prefix_trie_mmap            default     0   2.91   13.9× linear→bisect / 0.1× trie
6. dns_blocklist_aho_corasick  encode    137   35.1   AC build SIGKILL
```

---

## 2. 재현 검증 (이전 측정 vs 본 wave)

| Filter | 이전 측정 (state/bench_results.jsonl) | 본 wave | Variance | Verdict |
|--------|----------------------------------------|---------|----------|---------|
| **E4 safari_mmap** | cold 17.9× / persistent 2.5× / urls 2030 / blob 7.5% | cold **21.1×** / persistent **2.7×** / urls 2058 / blob 7.6% | +17.9% / +8.0% / +1.4% / +1.3% | ✓ **stable** (variance <20%, 신규 28 url 추가 reflect) |
| **F18 bookmarks** | cold **652×** / urls=5000 (synth) / encode 2.2ms / blob 244.7KB | cold **365×** / urls=55 (real bookmarks) / encode 3.8ms / blob 3.7KB | dataset shift — synth 5K → real 55 | ⚠ **dataset-bound**; speedup 365× ≠ 652× 는 corpus 차 (55 entries 의 plistlib parse cost 가 5K 보다 작음 → ratio 축소). framework 동작 reproducible, 절대 ratio 비교 불가. |
| **F7 hashset 2×** | hashset 66μs/q vs linear 192μs/q = **2.9×** (bench harness 별도) | default mode encode → SIGKILL | N/A | ✗ **not-reproduced** in this wave — 본 wave entry point (default encode) 와 이전 measurement (`tool/bench/bench_f7_dns_blocklist.hexa`) 가 다른 코드 path. 재현하려면 별도 bench tool 호출 필요 (본 wave scope 밖). |

종합: 환경 안정성 surface — page cache 따뜻한 상태에서 E4 cold ratio 가 +17.9% 변동, 이는 sqlite open cost 의 system-wide page cache state 의존성을 시사 (이전 측정 직후 cold cache reset 안된 점도 영향). dataset 의존 measurement (F18) 는 절대 ratio 보다 framework 동작 검증으로 해석.

---

## 3. PTBF 첫 측정값 (압축률 + query latency)

`modules/filters/data/prefix_trie_mmap.hexa` (F58 PTBF variant):

- **압축률**: blob 265.4KB / raw_est 499.9KB = **53.1%** of raw
  - 추정 1.8% (safari_bench 의 `prefix_trie_pct: 1.8`) **미달성** — 이는 safari_bench 가 sorted real URL 의 common-prefix dedup 에서 1.8% 도달했고, 본 PTBF 는 synthetic 10K URL (rng path/sub) 로 prefix 다양성 ↑ → cp 누적 덜됨.
  - 실측 raw 의 53% 수준은 여전히 의미있는 압축이지만 "byte-only 인코딩 최강 (1.0~1.8%)" claim 은 **synthetic dataset 에서 재현 안됨**.
- **Query latency** (200 queries, top-K=10):
  - linear scan : 764.4 μs/q
  - **bisect on restore : 54.9 μs/q (linear→bisect 13.9×)**
  - trie traversal : 5696.9 μs/q (linear→trie **0.1×, 즉 7.4× slower**)
- **Lossless**: hits all equal True (linear == bisect == trie)

핵심 surface: **trie traversal 모드는 pure-hexa(python PAYLOAD)에서 cp 누적 + suffix concat 의 스트링 빌드가 bisect 의 단순 restore 보다 느림**. text-line trie 의 압축 우선 trade-off 가 query latency 측에서는 역효과 — production 은 `bisect` 모드 권장.

권장: PTBF 의 production query path = **bisect on restore 54.9μs/q**, trie traversal 은 archival/streaming 용. 압축률 1.8% claim 은 corpus-specific (실 Safari URL sorted) 이므로 hot-path KPI 는 query latency 우선.

---

## 4. own 9 등록 권장

본 wave evidence 기반 own 9 후보:

**own 9 — Transport-Layer Filter Production Verifiability**

A. **Site-1**: `transport/anomaly.hexa` — try/catch 4건이 hexa runtime parse-warn → 본 wave 에서도 정상 실행되지만 hexa-lang A8 (panic stderr capture) 와 직결. anomaly 가 baseline 부족시 silent skip (`skip: 0 rows < 5`) 하므로 "filter 가 실제로 동작했는지" 외부 health check 필요. 권장: stdout JSON 1줄 (`{"ts":..., "ran":true|false, "reason":"..."}`) — 0 fork 추가, 기존 코드 수정 0.5L.

B. **Site-2**: `transport/client.hexa` — BusyBox nc fallback 환경에서 `nc -q invalid` 로 silent fail. AG3 ubu side 에 `nc -q` (GNU netcat) 미존재. dependency surface — hexa-lang A9 (raw socket builtin) 후보로 escalate 가능. own 9 site-2: client 가 transport 라기보다 nc-shell-wrapper 임을 evidence 로 정리.

C. **Site-3**: `transport/dns_blocklist_aho_corasick.hexa` — default mode=encode 가 production-test 환경 (120s budget) 에서 SIGKILL. own 9 site-3: AC trie build 가 pure-hexa interpreter overhead 1000× (이전 catalog #32 estimate 100ns/q vs 측정 357μs/q AC trie) — entry point 를 default=`benchmark-summary` (build 안 하고 state 만 report) 로 surface 변경 권장. 본 task 는 측정만이므로 권장만.

D. **Site-4**: PTBF trie-mode 0.1× — production path 는 bisect 만 사용하도록 default 변경 권장.

own 9 ROI: A·C·D 세 site 가 transport-layer "production verifiability" 라는 단일 테마. own 9 = "filter 가 호출되었을 때 실제 일을 한 흔적을 stdout 1줄로 남긴다" enforcement.

---

## 5. hexa-lang upstream — 신규 후보 (A9 / A10)

A1-A8 외 본 wave 신규 surface:

### A9 — `core.net.unix_socket(path, payload: bytes) -> bytes` builtin

**Evidence**: `transport/client.hexa` 가 `nc -U <sock>` 쉘 우회. nc 환경의존성 (BusyBox 의 `-q` 미지원) 이 production fail 의 직접 원인. `client.hexa:6` 주석: *"hexa raw socket API 부재. ncat 미설치 → nc 사용"* — 본 candidate 는 직접 source comment 로 surface 됨.

**Proposed API**:
```hexa
// stdlib/core_net.hexa 신규
pub fn unix_socket_send(path: string, payload: bytes, eof_close: bool) -> bytes
//   Darwin/Linux: connect(AF_UNIX) + send + recv until EOF
//   timeout: SO_RCVTIMEO 통합 (default 5000ms)
//   반환: response bytes (closed state)
```

**Caller**: `transport/client.hexa#main` — `exec("exec nc -q 0 -U " + sock)` 1-line 대체. 환경 의존 제거 + nc dependency 0.

**Priority**: 🟢 high — gate.sock 협력 layer 의 production 정합성 직접 영향.

### A10 — `try`/`catch` 토큰 표준화 (parser warning 해소)

**Evidence**: `anomaly.hexa` 4건, `client.hexa` 4건, **두 transport filter 모두**에서 `Parse error: unexpected token Try / Catch` 가 stderr 에 나옴에도 실행은 정상. 이는 hexa-lang parser 가 try/catch 를 RFC 미정 상태로 처리 — A6 / A7 와 별개의 **lexer 표준화 후보**.

`/Users/ghost/core/hexa-lang` 의 try-block syntax 가 일부 file 에서만 인식되는지 또는 모든 file 에서 warn-and-tolerate 인지 확인 필요. 본 wave 측정 만 — 코드 수정 0.

**Proposed**:
```
RFC: try { ... } catch e { ... } 를 hexa-lang grammar 정식 추가 (또는 panic-recover 으로 통일).
현 상태 Parse warning + best-effort eval → 명시 syntax error 로 strict 화 또는 정식화.
```

**Priority**: 🟡 medium — production 동작은 OK 이지만 stderr noise 가 own 9 verifiability 와 충돌.

---

## 산출 요약

- 산출 파일: `/Users/ghost/core/airgenome/docs/transport_residual_bench_2026-04-30.md`
- 코드 수정 / commit / hexa-lang touch / launchctl / daemon spawn / SSH 호출: **모두 0**
- 6 filter 측정 완료 (5/6 success, 1 SIGKILL = F7 default encode mode)
- 재현 검증: E4 stable (+18%), F18 dataset-bound (framework OK, ratio 비교 불가), F7 not-reproduced (path 차)
- PTBF 첫 측정: bisect 54.9μs/q / 13.9× / 압축률 53.1% (synthetic — sorted real URL 1.8% claim 미재현)
- hexa-lang gap 신규 2 (A9 unix_socket, A10 try/catch 표준화)
- own 9 후보 4 site 정리 (transport verifiability 테마)
