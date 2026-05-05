# RFC — `json_field_str` / `json_field_int` / `json_field_float` / `json_field_bool` builtin / stdlib fn

**Origin**: airgenome 2026-04-30 session, wave 2 process gate measurement (docs/process_gate_bench_2026-04-30.md A10 surface, agent a94c4efd) + own 5/6/7 site-axis 패턴 일반화. cross-repo gap: 5+ airgenome modules define identical local `jq_field` helper; sister repos (anima/n6/nexus/hive) inherit same gap. Read-only mandate keeps `/Users/ghost/core/hexa-lang/.raw` untouched — this draft is for explicit user PR transfer.

**Scope**: hexa-lang stdlib (or interp builtin). Single-pass JSON-line field extraction with deterministic fallback (no panic on missing/null/malformed key). Generalizes own 5 site-2 (`vit_at`, single-key, 614×) to multi-key cases.

**Companion**: A6 (`to_int_safe`, decimal-tolerant int parse, landed 3ea7fe69) — A14 + A6 jointly cover the boundary-parse pipeline (jsonl line → field → typed value).

---

## 1. Problem

5+ scattered local `jq_field` implementations exist across airgenome modules. Each module re-defines a near-identical helper that calls `exec("echo LINE | jq -r '.key'")` per call. own 5 site-2 (`vit_at`) demonstrated the in-process slice replacement gives 614× speedup for single-key extraction. own 6 site-6 (1649×) and own 7 site-9 (3269×) confirmed the pattern across forecast and label stages.

surveyed call-sites:

```
airgenome/forecast/module/forecast.hexa:39
    fn jq_field(line: str, expr: str) -> str { ... }
    callers: read_recent_genomes (162) / run_forecast (184) / run_forecast (198, 200)

airgenome/label/module/label.hexa:41
    fn jq_field(line: str, expr: str) -> str { ... }
    callers: parse_rule (211, 212, 213, 214 — 8× per rule load)
             run_label (199 host extract per genome line)

airgenome/predictive_throttle/module/predictive_throttle.hexa:79
    fn jq_field_int(line: str, key: str) -> int { ... }
    callers: read_history (110)

airgenome/genome_merge/module/genome_merge.hexa
    inline jq -c piped pattern (pre-site-8b commit) — replaced by
    in-process transform_line; same logical helper

airgenome/filters/module/data/safari_bookmarks_shbf.hexa:29
    inline PAYLOAD python plistlib parser — different format, but
    surfaces same gap when jsonl emit path is added
```

each implementation is 5-10 LoC, all do approximately:

```hexa
fn jq_field(line: str, expr: str) -> str {
    // expr like ".pid" / ".vitals[0]" / ".host"
    // strategy: byte-anchor `"key":` + slice to next `,` or `}`
    let key = expr.substring(1, len(expr))   // strip leading dot
    let anchor = "\"" + key + "\":"
    let idx = line.find(anchor)
    if idx < 0 { return "" }
    // ... slice to comma/brace, strip quotes, trim
}
```

**DRY violation**: 5+ near-identical implementations across one repo. cross-repo (anima/n6/nexus/hive) inherits the same gap → 20+ implementations expected. Each local helper diverges slightly (whitespace handling, escaped-quote handling, nested-object behavior) — silent semantic drift.

**raw 12 (silent-error-ban) risk**: a new module forgets to define helper, falls back to `exec("jq")` which silently degrades cycle wall by N× (own 6 wave 2 measurement: 5,600 jq fork per forecast cycle pre-site-6).

**raw 91 (honest C3 measure) evidence**: site-2/6/9 production measurements (614× / 1649× / 3269×) prove the in-process pattern is universal win for single-line jsonl. A14 generalizes the verified primitive.

---

## 2. Existing workaround (5+ repos, scattered)

scattered local definitions in airgenome alone:

```hexa
// airgenome/forecast/module/forecast.hexa#jq_field (commit f9554afd, own 6 site-6)
fn jq_field(line: str, expr: str) -> str {
    // anchor + slice — own 5 site-2 vit_at pattern
    // single-key only
}

// airgenome/label/module/label.hexa#jq_field (commit 3ab4ceac, own 7 site-9)
// near-identical to forecast.hexa, separate definition

// airgenome/predictive_throttle/module/predictive_throttle.hexa#jq_field_int (commit 88e008c4, own 8 site-14)
// int-typed variant

// airgenome/genome_merge/module/genome_merge.hexa (own 6 site-8b commit)
// transform_line replaces the jq -c pipe pattern
```

cross-repo (estimated, surveyed via own 9 BENCHMARK-COMPLETE wave 2 + filter audit):
- airgenome: 5+ (forecast / label / predictive_throttle / harvest / genome_merge / safari_bookmarks_shbf python wrapper)
- anima: 3+ (claude_quantum / verifier / cmt parsers — A10 try/catch blocked currently)
- n6: 2+ (atlas parser / cell encoding)
- nexus: 2+ (jsonl decoder / kick parser)
- hive: 5+ (settings / kick / lint / convergence parser / etc)

total ≥ 17 implementations across 5 repos. raw 47 cross-repo-trawl-witness 적용 시 universal mandate.

---

## 3. Proposed API

### Option A — pure-hexa stdlib fn (recommended, raw 9 compatible)

`hexa-lang/stdlib/json_lite.hexa` (new file) or extend existing stdlib parse module:

```hexa
// stdlib/json_lite.hexa
//
// Single-pass JSON-line field extraction with deterministic fallback.
// Returns "" / 0 / 0.0 / false on missing/null/malformed key.
// No panic on malformed input.
//
// Distinct from full JSON parser: scope is single-line flat jsonl
// (90% airgenome use case). Nested-object access not supported —
// caller responsibility to extract nested layer first.
//
// Companion: to_int_safe (A6) / to_float_safe (A6+) — A14 returns
// already-typed value, callers no longer need separate to_int_safe wrap.

pub fn json_field_str(line: str, key: str) -> str
//   key: bare key name without leading "." (e.g., "pid" not ".pid")
//   line: single jsonl line `{"pid":12345,"comm":"Safari",...}`
//   returns: extracted string value, "" if missing/null
//   handles: quoted string ("foo") / null / missing key

pub fn json_field_int(line: str, key: str) -> int
//   returns: parsed int, 0 if missing/null/non-integer
//   handles: integer literal (5) / null / missing
//   composes: json_field_str + to_int_safe (A6) internally

pub fn json_field_float(line: str, key: str) -> float
//   returns: parsed float, 0.0 if missing/null/non-numeric
//   handles: integer / decimal / null / missing

pub fn json_field_bool(line: str, key: str) -> bool
//   returns: parsed bool, false if missing/null/malformed
//   handles: true / false / null / missing
```

### Option B — single generic + caller-side cast

```hexa
pub fn json_field(line: str, key: str) -> str  // raw slice
// caller: to_int_safe(json_field(line, "pid")) etc
```

— rejected: forces every caller to re-wrap, defeats DRY purpose of A14. retained as internal helper only.

### Option C — interp builtin (fastest)

C-level implementation in hexa interp runtime. zero-allocation, no string slice, in-line byte scan. ~3-5× faster than Option A pure-hexa.

— recommended if A14 land + many call sites confirmed. defer to runtime maintainers.

**Recommendation**: Option A (pure-hexa stdlib) first — minimum surface + raw 9 hexa-only compliance + own 5 site-2 verified anchor-slice algorithm direct port. Option C upgrade later if profiling surfaces hot path beyond own 7 site-9 (3269× already saturates cycle budget).

---

## 4. Behavior table

| input line | key | json_field_str | json_field_int | json_field_float | json_field_bool |
|---|---|---|---|---|---|
| `{"pid":12345,"comm":"Safari"}` | `pid` | `"12345"` | `12345` | `12345.0` | `false` |
| `{"pid":12345,"comm":"Safari"}` | `comm` | `"Safari"` | `0` | `0.0` | `false` |
| `{"cpu":5.7,"mem":1024}` | `cpu` | `"5.7"` | `5` (truncate, A6 path) | `5.7` | `false` |
| `{"cpu":0.0}` | `cpu` | `"0.0"` | `0` | `0.0` | `false` |
| `{"flag":true}` | `flag` | `"true"` | `0` | `0.0` | `true` |
| `{"flag":false}` | `flag` | `"false"` | `0` | `0.0` | `false` |
| `{"x":null}` | `x` | `""` | `0` | `0.0` | `false` |
| `{"a":1}` | `b` (missing) | `""` | `0` | `0.0` | `false` |
| `{"vitals":[5,7,9]}` | `vitals` | `"[5,7,9]"` (raw array) | `0` | `0.0` | `false` |
| `{"nested":{"k":"v"}}` | `nested` | `"{\"k\":\"v\"}"` (raw obj) | `0` | `0.0` | `false` |
| `{"key with space":"val"}` | `key with space` | `"val"` | `0` | `0.0` | `false` |
| `{"escaped":"a\"b"}` | `escaped` | `"a\"b"` (raw, no unescape) | `0` | `0.0` | `false` |
| `` (empty line) | `any` | `""` | `0` | `0.0` | `false` |
| `not json` | `any` | `""` | `0` | `0.0` | `false` |

**design**:
- aggressive normalization for common malformed inputs, no silent partial-parse
- **array / nested object**: returned as raw substring slice (caller responsibility to extract). own 5 site-2 `vit_at` already handles `vitals[i]` as separate caller-side index — A14 follows same convention.
- **escape handling**: returned raw (no unescape) — minimum surface, caller can apply unescape if needed. matches own 6 site-6 / own 7 site-9 implementation.
- **null vs missing**: both → empty/zero/false. silent-error-ban (raw 12) compliant when paired with A6 (typed default zero).

---

## 5. Test cases (hexa-lang/stdlib/test/test_json_field.hexa)

```hexa
// Basic str
chk_eq_str("pid_str",     json_field_str("{\"pid\":12345,\"comm\":\"Safari\"}", "pid"),     "12345")
chk_eq_str("comm_str",    json_field_str("{\"pid\":12345,\"comm\":\"Safari\"}", "comm"),    "Safari")

// Basic int
chk_eq_int("pid_int",     json_field_int("{\"pid\":12345}", "pid"),     12345)
chk_eq_int("zero_int",    json_field_int("{\"pid\":0}", "pid"),         0)
chk_eq_int("neg_int",     json_field_int("{\"pid\":-3}", "pid"),        -3)

// Float
chk_eq_float("cpu_float", json_field_float("{\"cpu\":5.7}", "cpu"),     5.7)
chk_eq_float("zero_float", json_field_float("{\"cpu\":0.0}", "cpu"),    0.0)
chk_eq_int("cpu_to_int",  json_field_int("{\"cpu\":5.7}", "cpu"),       5)  // truncate via A6

// Bool
chk_eq_bool("flag_true",  json_field_bool("{\"flag\":true}", "flag"),   true)
chk_eq_bool("flag_false", json_field_bool("{\"flag\":false}", "flag"),  false)

// Null
chk_eq_str("null_str",    json_field_str("{\"x\":null}", "x"),          "")
chk_eq_int("null_int",    json_field_int("{\"x\":null}", "x"),          0)
chk_eq_bool("null_bool",  json_field_bool("{\"x\":null}", "x"),         false)

// Missing
chk_eq_str("missing_str", json_field_str("{\"a\":1}", "b"),             "")
chk_eq_int("missing_int", json_field_int("{\"a\":1}", "b"),             0)

// Empty / malformed
chk_eq_str("empty_line",  json_field_str("", "any"),                     "")
chk_eq_str("not_json",    json_field_str("not json", "any"),             "")

// Array / nested (raw slice)
chk_eq_str("array_raw",   json_field_str("{\"vitals\":[5,7,9]}", "vitals"),    "[5,7,9]")
chk_eq_str("nested_raw",  json_field_str("{\"n\":{\"k\":\"v\"}}", "n"),         "{\"k\":\"v\"}")

// Real-world (own 7 site-9 corpus)
chk_eq_str("genome_pid",  json_field_str(GENOME_LINE_FIXTURE, "pid"),    "51101")
chk_eq_str("genome_host", json_field_str(GENOME_LINE_FIXTURE, "host"),   "ana")
chk_eq_int("genome_ts",   json_field_int(GENOME_LINE_FIXTURE, "ts"),     1745987462)
```

---

## 6. backwards compat

**no breaking change** — A14 introduces 4 new fn names (`json_field_str` / `json_field_int` / `json_field_float` / `json_field_bool`) in `stdlib/json_lite.hexa`. existing local `jq_field` definitions remain functional until callers migrate.

migration path:
1. land A14 in hexa-lang stdlib
2. airgenome modules `use "stdlib/json_lite"` and replace local `jq_field` / `jq_field_int` calls
3. existing local `fn jq_field` definitions become redundant — gradual cleanup (raw 47 30d ramp)
4. sister repos (anima/n6/nexus/hive) inherit the builtin automatically

each migration PR follows own 5/6/7/8 5-tuple (site + ROI# + baseline ns + post ns + lossless diff_test). expected post ns ~equal to current site-6/9 in-process implementation (already 99%↓ from jq fork) — A14 land does not change ROI baseline; it removes DRY violation only.

---

## 7. raw 117 5-check self-application

- **genus slug**: `json-field-line-flat-extract` (no `-via-` `-with-` `-api` species suffix)
- **5 cognitive frameworks**:
  - postel's-law-be-liberal-in-what-you-accept (null / missing / malformed → silent zero)
  - parse-don't-validate-data-boundary-trust (jsonl line is data boundary; A14 is the parse primitive)
  - dry-pyramid-shared-stdlib-vs-scattered-local-helpers (5+ local jq_field → 1 stdlib)
  - silent-error-ban-default-zero-vs-panic-vs-Result (composes with A6 typed default; no panic at boundary)
  - flat-jsonl-vs-nested-json-scope-narrowing (90% use case; nested = caller responsibility, raw slice)
- **5 realization channels**:
  - pure-hexa stdlib fn (Option A, recommended)
  - generic single fn + caller cast (Option B, rejected — defeats DRY)
  - interp C builtin (Option C, upgrade path)
  - test suite hexa-lang/stdlib/test/test_json_field.hexa
  - airgenome own 5/6/7 production measurement (614× / 1649× / 3269×) as cross-stage evidence
- **3 counter-examples**:
  - nested-object access required (use full JSON parser; A14 returns raw slice as caller-side input)
  - performance-critical inner loop with known schema (use direct byte-anchor + slice without fn call overhead — own 5 site-2 baseline pattern)
  - schema validator / strict-mode parser (use Result-style explicit error if hexa adds; A14 is liberal-parse intent)
- **3 falsifiers**:
  - F-A14-1: 30d post-promotion, ≥3 sister repos still maintain local `fn jq_field` (no migration) = mandate ineffective, scope review
  - F-A14-2: A14 introduces silent partial-parse beyond design (e.g., `"5abc"` → 5 instead of 0) = behavior table mismatch, retire
  - F-A14-3: 90d post, A14 shows ≥10× slowdown vs site-6/9 in-process baseline = pure-hexa overhead too high, escalate to Option C interp builtin

---

## 8. cross-repo evidence

local helper count surveyed (jq_field / json_field / similar single-pass JSON-line extract):
- airgenome: 5+ (forecast / label / predictive_throttle / harvest [transform_line equivalent] / genome_merge / safari_bookmarks_shbf python wrapper)
- anima: estimated 3+ (claude_quantum / verifier / cmt parsers — currently A10 try/catch blocked, helper presence inferred)
- n6: estimated 2+ (atlas parser / cell encoding)
- nexus: estimated 2+ (jsonl decoder / kick parser)
- hive: estimated 5+ (settings / kick / lint / convergence parser / etc)

total ≥ 17 implementations across 5 repos. raw 47 cross-repo-trawl-witness 적용 시 universal mandate.

production measurement evidence (airgenome wave 2 / own 6 / own 7):
- own 6 site-6 (forecast.hexa#jq_field, jq fork → in-hexa anchor + slice): 6.09ms → 3.69μs/call (1649×, 99%↓), diff_test=0/800
- own 7 site-9 (label.hexa#jq_field, same pattern): 6.79ms → 2.08μs/call (3269×, 99%↓), diff_test=0/1600
- own 5 site-2 (harvest.hexa#vit_at, single-key precedent): 614× verified
- A14 land = these three local implementations collapse to 1 stdlib call site, no ROI regression expected

---

## 9. follow-up

- A14 RFC promote → hexa-lang PR (사용자 명시 승인 후)
- airgenome interim: own 5/6/7/8 already implemented local helpers — A14 land 후 별도 cleanup PR
- A14 land 후 5+ local helper cleanup PR:
  - airgenome/forecast/module/forecast.hexa: remove local `jq_field`, `use "stdlib/json_lite"` + `json_field_str(line, "pid")`
  - airgenome/label/module/label.hexa: remove local `jq_field`, replace 4+ call sites (parse_rule + run_label)
  - airgenome/predictive_throttle/module/predictive_throttle.hexa: remove local `jq_field_int`, replace with `json_field_int`
  - airgenome/genome_merge/module/genome_merge.hexa: confirm transform_line in-process pattern unaffected (no jq_field call), but adjacent jsonl emit can adopt A14
  - airgenome/filters/module/data/safari_bookmarks_shbf.hexa: python PAYLOAD parser is separate (plistlib), but adjacent jsonl emit path uses A14
- own 10 site-S5 (claude.hexa session_now.json substring chain) unblocked by A14 — currently blocked, A14 land = direct adoption candidate
- A6 (`to_int_safe`) + A14 jointly cover boundary parse pipeline. A14 internally composes A6 for `json_field_int`.

---

## 10. relation to own 5 / own 6 / own 7 site patterns

own 5 site-2 (`vit_at`, 614×) was the first verified instance of "jq fork → in-hexa anchor + slice" pattern, but limited to single-key case (`.vitals[i]`). own 6 site-6 (1649×) and own 7 site-9 (3269×) generalized to multi-key by re-implementing the same anchor-slice algorithm in each module. A14 elevates the verified algorithm to stdlib — single source of truth.

key relation:
- own 5 site-2 = single-field case, hexa-side (hand-written per module)
- own 6 site-6 / own 7 site-9 = multi-field case, hexa-side (5+ local copies)
- **A14 = multi-field case, stdlib (1 source)** — generalization of verified primitive

A14 is **not a new algorithm** — it's the **DRY consolidation** of own 5/6/7 verified algorithm. raw 91 (honest C3) satisfied: ROI is already measured (614× / 1649× / 3269×); A14 = lossless code organization improvement.
