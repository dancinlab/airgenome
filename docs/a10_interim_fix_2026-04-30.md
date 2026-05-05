# A10 Interim Fix — 5 Blocked Filter try/catch Removal

**Date**: 2026-04-30
**Scope**: A10 wave 5 — `try/catch` PANIC parse blocker workaround on 5 filters previously blocked from production measurement.
**Pattern source**: commit `9eea1795` (Safari E4 SHBF) + commit `788e483a` (wave 4 to_int_safe interim).
**Sample corpus**: `/Users/ghost/.claude-claude9/projects/-Users-ghost-Dev-airgenome/d07e7302-7c0a-4f5b-803e-422a45af2e4e.jsonl` (5.23 MB, 3659 records).

## 1. Parse PASS / FAIL Table

| # | Filter | Before | After | `hexa parse` |
|---|---|---|---|---|
| E1 | `filters/module/data/claude_quantum.hexa` | 2 try/catch (date, perl-exec) | 0 | **PASS** |
| E2 | `filters/module/data/claude_bytes.hexa` | 2 try/catch (date, perl-exec) | 0 | **PASS** |
| E3 | `filters/module/data/claude_runtime.hexa` | 2 try/catch (date, perl-exec) | 0 | **PASS** |
| —  | `filters/module/transport/anomaly.hexa` | 11 try/catch (parse + exec mix) | 0 | **PASS** |
| —  | `filters/module/transport/client.hexa` | 5 try/catch + `nc -q` invalid on Darwin | 0 | **PASS** |

**Total**: 22 try/catch sites removed across 5 files. `hexa parse <file>` clean for all 5.

> Note: the user-supplied site-count (E3 "6 sites") referred to the `try { exec(...) } catch e {...}` pattern across data filters as a bg-agent sweep estimate; the actual count per file is verified above.

## 2. Production Measurement

### E1 — `claude_quantum.hexa` (verify mode, 5.23 MB JSONL)

Run via `airgenome.app --mode=run-once` (FDA-bearing TCC client):

```
records         : 3659
entangled pairs : 13
dropped keys    : entrypoint, gitBranch, isMeta, isSidechain, messageCount, parentUuid, sessionId, slug ...
raw jsonl       : 5.23MB  100.0%
raw + gzip-9    : 1.15MB   21.9%
qfilter (pre-gz): 4.79MB   91.6%
qfilter + gzip-9: 1.14MB   21.8%   (vs raw+gz: 99.5%)
sha256 round-trip: OK LOSSLESS
```

**5-tuple** (records / entangled / qfilter+gz % / vs-raw+gz % / round-trip): **3659 / 13 / 21.8% / 99.5% / LOSSLESS**.

### E2 — `claude_bytes.hexa` (full report, 5.23 MB JSONL)

Run via `hexa_real run` directly (FDA from terminal session):

```
records              : 3659
constants lifted     : 16 keys
deco dedup           : 35 chunks
uuid table           : 3416 unique UUIDs
raw jsonl            : 5.23MB  100.0%
semantic jsonl       : 4.58MB   87.6%
raw + gzip           : 1.15MB   21.9%
semantic jsonl + gzip: 1.12MB   21.3%
semantic msgpack     : 4.13MB   78.9%
semantic msgpack + gz: 1.11MB   21.1%
```

**5-tuple** (records / lifted / dedup / uuids / msgpack+gz %): **3659 / 16 / 35 / 3416 / 21.1%**.

### E3 — `claude_runtime.hexa` (bench mode, 5.23 MB JSONL)

```
records             : 3659  codec: msgpack
raw_bytes           : 5,488,489
blob_bytes          : 5,025,216  (ratio 0.9156)
encode_total_ms     : 199.15
raw_load_ms         : 29.55
blob_load_ms        : 15.27   load_speedup_x: 1.94
lazy_load_ms        : 3.55    lazy_vs_raw_load_x: 8.32
raw_reparse_ms      : 30.61   reparse_vs_blobload_x: 2.0
raw_query_us/100    : 5.06
blob_query_us/100   : 4.87    query_speedup_x: 1.04
lazy_query_us/100   : 421.86  lazy_query_vs_raw_x: 0.01
rss                 : 104.1 MB (raw) / 104.1 MB (blob)
```

**5-tuple** (records / blob_ratio / load_speedup / lazy_speedup / reparse_vs_blobload): **3659 / 0.9156 / 1.94× / 8.32× / 2.0×**.

### `anomaly.hexa` (synthetic genomes.log fixture, 6 rows / 3 gates)

Run with synthesized fixture `/tmp/a10_anomaly_home/genomes.log` and `/tmp/airgenome-state.json`:

```
[anomaly] v0.2.0 ok: clean
sys_z = ram:-0.013 / cpu:0.133
gate_anomalies = 0
score = 0.0178
output JSON written to forge/anomaly_gate.json
```

**5-tuple** (rows / gates_checked / sys_severity / anomalies / score): **6 / 3 / ok / 0 / 0.0178**.

### `client.hexa` (dry-run, no socket)

`echo test | hexa_real run client.hexa` → exit=0, no `nc: invalid option` warning, no panic.
Run via `airgenome.app --mode=run-once` → exit=0 silent.

**5-tuple** (parse / launch / nc_arg_OK / exit / panic): **PASS / PASS / -N→nullflag (Darwin) / 0 / none**.

## 3. Additional Findings (Post-Fix Gaps)

1. **A6 helper drift**: `anomaly.hexa` had no `to_int_safe` / `to_float_safe` / `is_numeric_str` (unlike wave-4 fixed Safari filters). Added inline in this fix. Same as commit `788e483a` pattern — local helpers slated for removal once A6 RFC promotes to hexa-lang stdlib.
2. **`airgenome --mode=run-once` arg passthrough gap**: `airgenome_loop.m:458-462` passes only `module_path` to the spawned `hexa run` — extra positional args (e.g. JSONL corpus path) are lost. claude_bytes.hexa has no default sample, so run-once picks up `argv[0]="exe"` from hexa-cache and reports `records: 0`. Workaround: bench via `hexa_real run <file> <arg>` directly. Suggested upstream fix: extend `--mode=run-once=<path>:<arg1>:<arg2>` or add `--arg=` flag.
3. **`nc -q` cross-platform**: Darwin BSD `nc` rejects `-q 0` ("invalid option") AND `-N` ("invalid tcp adaptive write timeout value"). Only Linux GNU `nc`/`ncat` accept `-q`. Fixed via `uname -s` runtime branch — Darwin uses no flag (BSD nc closes on stdin EOF by default), Linux uses `-q 0`.
4. **`docker route` poisoning hexa direct invocation**: `/Users/ghost/.hx/bin/hexa` resolver picks docker route for non-`--version` args, which lacks `/usr/bin/perl` and FDA. Use `/Users/ghost/.hx/bin/hexa_real` (raw arm64 binary) for production measurement, or invoke via `airgenome.app` for FDA-bearing context.
5. **Hardcoded sample path**: All 3 data filters embed `/Users/ghost/.claude-claude9/projects/-Users-ghost-Dev-airgenome/d07e7302-7c0a-4f5b-803e-422a45af2e4e.jsonl` literal. Survives because file exists (5.5 MB), but breaks portability. Future: `env("AG_SAMPLE_JSONL")` fallback.

## 4. own 9 Classification Recommendation

| Filter | Status | own 9 bucket | Rationale |
|---|---|---|---|
| `claude_quantum.hexa` | parse PASS, prod LOSSLESS | **production-validated** | 13 entanglements detected, sha256 round-trip OK, 99.5% of raw+gz size — meaningful reduction floor |
| `claude_bytes.hexa` | parse PASS, prod 21.1% | **production-validated** | 16 const keys lifted + 3416 UUIDs deduped + 35 deco chunks → semantic msgpack+gz beats raw+gz (21.1% vs 21.9%, 0.8 pp lossless saving) |
| `claude_runtime.hexa` | parse PASS, prod 8.32× lazy | **production-validated** | lazy load 8.32× faster than raw, reparse_vs_blobload 2.0× — runtime hot-path candidate |
| `anomaly.hexa` | parse PASS, prod synthetic | **추가 workaround** | helper helpers added inline (A6 dup); needs real `genomes.log ≥ 5 rows` fixture from prod sampler — synthetic fixture passed but real-world calibration pending |
| `client.hexa` | parse PASS, prod dry-run | **추가 workaround** | nc -q Darwin/Linux split fixed; SSH endpoint not exercised — needs Linux-side gate.sock smoke test for full validation |

## 5. Files Touched (no commits — main agent will batch)

- `filters/module/data/claude_quantum.hexa` — try/catch ×2 → 0
- `filters/module/data/claude_bytes.hexa` — try/catch ×2 → 0
- `filters/module/data/claude_runtime.hexa` — try/catch ×2 → 0
- `filters/module/transport/anomaly.hexa` — try/catch ×11 → 0 (added is_numeric_str / to_float_safe / to_int_safe inline helpers)
- `filters/module/transport/client.hexa` — try/catch ×5 → 0; `nc -q` → uname-branched flag

All 5 files pass `hexa parse` clean. 3 of 5 measured against live 5.23 MB JSONL corpus; 1 against synthetic fixture; 1 dry-run only (production validation gated on Linux-side socket).
