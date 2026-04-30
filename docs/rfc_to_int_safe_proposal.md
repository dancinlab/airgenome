# RFC — `to_int_safe(s) -> int` builtin / stdlib fn

**Origin**: airgenome 2026-04-30 session, wave 4 production-test panic surface (commit `<wave 4 hash>`). cross-repo gap: 5+ sister repos define identical local helper. Read-only mandate keeps `/Users/ghost/core/hexa-lang/.raw` untouched — this draft is for explicit user PR transfer.

**Scope**: hexa-lang stdlib (or interp builtin). decimal-tolerant integer parse with deterministic fallback (no panic on common parse-failure cases).

---

## 1. Problem

current `to_int(s)` (hexa-lang interp builtin) is strict:

```hexa
to_int("0")    // → 0
to_int("5")    // → 5
to_int("0.0")  // PANIC: invalid integer literal "0.0"
to_int("")     // PANIC
to_int("abc")  // PANIC
to_int(" 5 ")  // PANIC (no trim)
```

real-world parse sources commonly produce decimal / empty / non-digit:
- `ps -axo pcpu`: `"0.0"`, `"5.7"`, `"100.0"`
- jq output empty fallback: `""`
- jsonl `null` field: `""`
- shell glob expansion: `"*"`
- user input not validated upstream

panic on these = brittle pipeline. workaround pattern proliferates.

---

## 2. Existing workaround (5+ repos)

scattered local definitions:

```hexa
// airgenome/modules/predictive_throttle.hexa (commit 88e008c4)
fn to_int_safe(s: str) -> int {
    if s == "" { return 0 }
    let parts = s.split(".")
    if len(parts) == 0 { return 0 }
    if parts[0] == "" { return 0 }
    return to_int(parts[0])
}

// airgenome/modules/label.hexa (commit 3ab4ceac, similar)
// airgenome/modules/forecast.hexa (similar)
// airgenome modules count: 5+
```

**DRY violation**: 5+ near-identical implementations across one repo (airgenome). cross-repo (anima/n6/nexus/hive) inherits the same gap → 20+ implementations expected.

**raw 12 (silent-error-ban) risk**: a new module forgets to define helper, silently panics on first decimal input from `ps`/`jq`/jsonl. wave 4 (F45/F64/F65/F66) demonstrates this exact failure mode.

---

## 3. Proposed API

### Option A — pure-hexa stdlib fn (recommended, raw 9 compatible)

`hexa-lang/stdlib/parse.hexa` (new file) or extend existing stdlib module:

```hexa
// stdlib/parse.hexa
//
// Decimal-tolerant integer parse with deterministic fallback.
// Truncates fractional part. Returns 0 on empty/non-digit/whitespace-only.
// No panic on malformed input.
//
// Distinct from to_int (strict — panic on malformed): use to_int_safe at
// data-boundary parse sites (ps output / jq fallback / shell glob / user
// input) where input may be malformed but pipeline must continue.

pub fn to_int_safe(s: string) -> int {
    let trimmed = s.trim()
    if trimmed == "" { return 0 }
    let parts = trimmed.split(".")
    if len(parts) == 0 { return 0 }
    let head = parts[0]
    if head == "" { return 0 }
    // negative-leading sign: split keeps "-5" intact in parts[0]
    // hex/octal: not supported (parse boundary intentionally narrow)
    return to_int_strict_or_zero(head)
}

// internal helper — to_int but returns 0 instead of panic on non-digit.
// alternatively: expose to_int(s, default: int) -> int signature.
fn to_int_strict_or_zero(s: string) -> int {
    // walk bytes, accept '-' at idx 0, digits 0-9. fail-fast → 0.
    let n = len(s)
    if n == 0 { return 0 }
    let mut i = 0
    let mut sign = 1
    let c0 = s.substring(0, 1)
    if c0 == "-" { sign = -1; i = 1 }
    if i >= n { return 0 }
    let mut v = 0
    while i < n {
        let ch = s.substring(i, i + 1)
        let cb = byte_at(ch, 0)  // assumes byte_at builtin or similar
        if cb < 48 || cb > 57 { return 0 }   // not '0'-'9'
        v = v * 10 + (cb - 48)
        i = i + 1
    }
    return sign * v
}
```

### Option B — overload to_int with default param

```hexa
to_int(s)               // strict, panic on fail (current behavior)
to_int(s, default: int) // safe, default on fail
```

— preferred if hexa supports default param syntax. eliminates new fn name.

### Option C — interp builtin (fastest)

C-level implementation in hexa interp runtime. zero-allocation, no string trim/split. ~2× faster than Option A pure-hexa.

— recommended if A6 promotes to 🟢 high priority + many call sites. defer to runtime maintainers.

**Recommendation**: Option A (pure-hexa stdlib) first — minimum surface + raw 9 hexa-only compliance. Option C upgrade later if profiling surfaces hot path.

---

## 4. Behavior table

| input | to_int | to_int_safe |
|---|---|---|
| `"0"` | 0 | 0 |
| `"5"` | 5 | 5 |
| `"-3"` | -3 | -3 |
| `"0.0"` | PANIC | 0 |
| `"5.7"` | PANIC | 5 (truncate) |
| `"-2.9"` | PANIC | -2 (truncate toward zero) |
| `""` | PANIC | 0 |
| `" 5 "` | PANIC | 5 (trim) |
| `"abc"` | PANIC | 0 |
| `"5abc"` | PANIC | 0 (strict trailing — not partial parse) |
| `"0x10"` | PANIC | 0 (no hex) |
| `"1e3"` | PANIC | 0 (no scientific notation) |
| `null` | PANIC (or empty) | 0 |

**design**: aggressive normalization for common malformed inputs, no silent partial-parse (`"5abc"` returns 0 not 5 — surfaces upstream bug rather than silently absorbing).

---

## 5. Test cases (hexa-lang/test/test_to_int_safe.hexa)

```hexa
// Basic
chk_eq_int("zero",      to_int_safe("0"),     0)
chk_eq_int("positive",  to_int_safe("5"),     5)
chk_eq_int("negative",  to_int_safe("-3"),    -3)

// Decimal truncation
chk_eq_int("decimal_zero",  to_int_safe("0.0"),   0)
chk_eq_int("decimal_pos",   to_int_safe("5.7"),   5)
chk_eq_int("decimal_neg",   to_int_safe("-2.9"),  -2)

// Whitespace
chk_eq_int("trim_left",   to_int_safe(" 5"),    5)
chk_eq_int("trim_right",  to_int_safe("5 "),    5)
chk_eq_int("trim_both",   to_int_safe(" 5 "),   5)

// Empty / non-digit
chk_eq_int("empty",       to_int_safe(""),      0)
chk_eq_int("non_digit",   to_int_safe("abc"),   0)
chk_eq_int("partial",     to_int_safe("5abc"),  0)
chk_eq_int("hex",         to_int_safe("0x10"),  0)
chk_eq_int("scientific",  to_int_safe("1e3"),   0)

// real-world ps cpu
chk_eq_int("ps_cpu_0",    to_int_safe("0.0"),   0)
chk_eq_int("ps_cpu_100",  to_int_safe("100.0"), 100)
chk_eq_int("ps_cpu_5_7",  to_int_safe("5.7"),   5)
```

---

## 6. backwards compat

**no breaking change** — current `to_int(s)` strict behavior preserved. callers explicit opt-in to safe variant via `to_int_safe(s)` (Option A) or `to_int(s, default)` (Option B).

migration path:
1. land A6 in hexa-lang stdlib
2. sister repos can now `use "stdlib/parse"` and call `to_int_safe(...)`
3. existing local `fn to_int_safe` definitions become redundant — gradual cleanup (raw 47 30d ramp)

---

## 7. raw 117 5-check self-application

- **genus slug**: `to-int-safe-decimal-tolerant-parse` (no `-via-` `-with-` `-api` species suffix)
- **5 cognitive frameworks**:
  - postel's-law-be-liberal-in-what-you-accept
  - parse-don't-validate-data-boundary-trust
  - dry-pyramid-shared-stdlib-vs-scattered-local-helpers
  - silent-error-ban-default-zero-vs-panic-vs-Result
  - decimal-truncation-vs-rounding-toward-zero-c-style
- **5 realization channels**:
  - pure-hexa stdlib fn (Option A)
  - to_int default-param overload (Option B)
  - interp C builtin (Option C)
  - test suite hexa-lang/test/test_to_int_safe.hexa
  - airgenome wave 4 production-test as cross-repo evidence
- **3 counter-examples**:
  - performance-critical inner loop (use to_int strict + upstream validation)
  - explicit error handling required (use Result-style `try/catch` if hexa adds — currently parse error = panic)
  - exact-form mandate (e.g., schema validator) — strict to_int signals upstream contract violation
- **3 falsifiers**:
  - F-A6-1: 30d post-promotion, ≥3 sister repos still maintain local `fn to_int_safe` (no migration) = mandate ineffective, scope review
  - F-A6-2: A6 introduces silent partial-parse (`"5abc"` → 5) — design intent violation, behavior table mismatch = retire
  - F-A6-3: 90d post, 5+ new panic reports of `to_int "X.Y"` form despite A6 availability = adoption bar high, escalate to interp default behavior change (controversial)

---

## 8. cross-repo evidence

local helper count surveyed:
- airgenome: 5+ (predictive_throttle / label / forecast / genome_merge / harvest)
- anima: estimated 3+ (claude_quantum / verifier / cmt parsers)
- n6: estimated 2+ (atlas parser / cell encoding)
- nexus: estimated 2+ (jsonl decoder / kick parser)
- hive: estimated 5+ (settings / kick / lint / convergence parser / etc)

total ≥ 17 implementations across 5 repos. raw 47 cross-repo-trawl-witness 적용 시 universal mandate.

---

## 9. follow-up

- A6 RFC promote → hexa-lang PR (사용자 명시 승인 후)
- airgenome interim workaround: wave 4 4 모듈에 local `to_int_safe` 정의 (predictive_throttle.hexa pattern 직접 이식) — A6 land 전 production-test 가능
- A6 land 후: airgenome `use "stdlib/parse"` 으로 migration, local 정의 제거 (cleanup PR)
