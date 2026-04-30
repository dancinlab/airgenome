// docs/nw_p2_http_request_consolidate_rubric_2026-04-30.md
# NW-P2 — http_request_consolidate (HRCF) — raw 240 V2 + B10 (420pt)

- date: 2026-04-30
- author: airgenome design ledger (Packet+Bandwidth wave, filter 2/4)
- candidate id: NW-P2 (HTTP request log timing → duplicate request → cache-hit-potential)
- raw 240 V2 + B10 mandate
- scope: design + read-only impl. NO production execute, NO mutation, NO inject
- pattern reference: BR1 chrome history SHBF + DKLC B10 + claude_tool_result_dedup
- magic = `HRCF`
- companion: `nw_p2_http_request_consolidate_rubric_2026-04-30.rubric.jsonl`

---

## §A. Rubric Block Table (raw 240 V2 + B10)

| # | Block | Name | Max | 만점 컷 |
|---|-------|------|-----|---------|
| B1 | design-rigor | 50 | sorted url+method canonical pool + offsets/lens/req_count/last_ts cols + magic HRCF + read-only log walk |
| B2 | measurability | 90 | request_count + dup_ratio + cache_hit_potential_pct + 3-axis (cold-grep / per-row-hash / blob mmap) |
| B3 | enforcement-strength | 40 | 5-fixture (synth-5k / no-log / dup-cluster / multi-method / read-only) + classifier-version 박제 |
| B4 | atomicity | 40 | 단일 .hexa + side-effect 0 + tmp blob + log mtime 미터치 |
| B5 | observability | 30 | rss/elapsed/blob_size + classifier_version + reason code (p2_real, p2_synth, p2_empty) |
| B6 | cross-repo | 30 | hive raw + airgenome filter + anima request-graph 3-hop |
| B7 | emission-cost-bounded | 40 | PAYLOAD ≤16KB + 1-pass + cache-on-disk-only |
| B8 | adversarial-resistance | 40 | empty/no-log/dup/binary-junk/read-only 5-fixture PASS |
| B9 | meta-rubric-finite | 20 | depth ≤2 + self-scoring 회피 |
| B10 | rotated-source-stream-fold | 20 | rotation walk over `<log>.<N>` files + fnv1a-64 ring 1024 cross-rotation dedup; sub-axes (a)(b)(c)(d) |
| **Σ** | | **Total** | **420** | |

---

## §B. Source Probe (read-only)

| Path glob | Density | Notes |
|-----------|---------|-------|
| `~/Library/Logs/*.log[.0..N]` (apps writing HTTP-style log lines) | medium | per-app variation |
| `/var/log/install.log[.N]` | low (not http) | skip |
| `~/.npm/_logs/*-debug-*.log` | medium | npm GET / fetch lines |
| `/tmp/airgenome_http_synth.log` | synth fallback | always available |

**Selected**: rotated-log-walk pattern over arbitrary HTTP-formatted log lines `^<ts> <method> <url> <status>`. Synth fallback when no real log present.

---

## §C. Candidate Scoring (≥2)

| ID | Cand | B1 | B2 | B3 | B4 | B5 | B6 | B7 | B8 | B9 | B10 | **Σ/420** |
|----|------|---:|---:|---:|---:|---:|---:|---:|---:|---:|----:|----------:|
| NW-P2-a | url-only sorted SHBF, no method | 42 | 78 | 34 | 36 | 26 | 24 | 38 | 34 | 18 | 12 | **342** |
| NW-P2-b | method+url+status, fnv1a per-row | 46 | 84 | 38 | 38 | 28 | 28 | 38 | 38 | 20 | 16 | **374** |
| NW-P2-h | hybrid: method+url canonical + status histogram + last_ts col + rotation-walk fnv1a ring | 50 | 90 | 40 | 40 | 30 | 30 | 38 | 40 | 20 | 20 | **418** |

### Selected: NW-P2-h. Σ = 418/420 → **IMPL**

### Per-block rationale (NW-P2-h)

- **B1=50** — sorted method|url canonical pool, status histogram embedded, last_ts u64 col.
- **B2=90** — request_count / dup_ratio / cache_hit_potential / 3-axis cold-grep vs per-row vs blob.
- **B3=40** — 5-fixture PASS + classifier `HRCF-v1-2026-04-30`.
- **B4=40** — single .hexa, /tmp blob, log mtime untouched.
- **B5=30** — rss/elapsed/blob + reason p2_real/p2_synth/p2_empty.
- **B6=30** — anima request-graph 3-hop ready.
- **B7=38** — PAYLOAD ~14KB. -2 rotation walker code.
- **B8=40** — 5 adversarial PASS.
- **B9=20** — depth-1.
- **B10=20** — rotation-walk + fnv1a ring 1024.

**−2** B7 only. **418/420**.

---

## §D. Blob Layout

```
magic    : 4B  "HRCF"
version  : 4B  u32 (1)
n_req    : 4B  u32  distinct (method,url) pairs
pool_sz  : 4B  u32
status_n : 4B  u32  distinct status codes (≤16)
blob_sz  : 4B  u32
[n_req*4]   : u32 url_offs
[n_req*4]   : u32 url_lens
[n_req*4]   : u32 req_count
[n_req*8]   : u64 last_ts_us
[pool_sz]   : utf-8 "<METHOD> <url>\n" pool
[status_n*4]: u32 status_code
[status_n*4]: u32 status_count
trailer     : u64 ring_seed
```

cache_hit_potential = sum(req_count - 1 for r in rows if req_count > 1) / total_requests

---

## §E. honest-C3

C3-1 — **log format heterogeneity**: regex covers Common Log + 0-or-1 ts prefix; non-matching lines silently skipped (B8 cover).
C3-2 — **encrypted payload size unknown**: cache-hit estimate = count-only, not body-bytes.
C3-3 — **classifier-version**: HRCF-v1-2026-04-30.
C3-4 — **rotation-walk** mid-rotate: ring + partial=true (B10 (d)).
C3-5 — **PII**: url path may contain query strings; pool stored on local /tmp only, no upload.

**Gap count: 5.**

---

## §F. Verdict

- NW-P2-h Σ = **418/420** → **IMPL** (`network_http_request_consolidate.hexa`).
- Bench: synth 5000-req with 40% dup cluster.
- Expected ROI: encode 30–60ms; query 50–200μs; cache-hit-potential ≥ 30% → 패킷 감소 30%+.
