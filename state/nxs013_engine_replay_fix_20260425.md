# nxs-013 Engine Replay Root Cause + Wave 21 Fix

**Date:** 2026-04-25
**Severity:** critical (drill brainstorming value = 0 → bit-identical round outputs)
**Branch:** fix/roadmap-2-note (airgenome) + nexus uncommitted

## Hypothesis (initial, from observation)

User reported round 9 5-stage values bit-identical to round 1 across two
parallel drill tasks. Counter-replay guards Day-1/2/3 (round-salt + iter-nonce
+ multi-source entropy prefix) were diversifying the seed STRING but the
ENGINE OUTPUT was unchanged. Suspected: `seed → blowup_core` deterministic
hash ignoring prefix, OR internal cache returning round-1 result.

## Tracing — what actually happens

### 1. Drill side (cli/run.hexa) — seed perturbation IS being constructed

- `_round_seed_rich(nonce_base, round, rich_salt)` (run.hexa:3265,3281) builds
  `"round=N-rxAAAxBBBnTTTT|<base>#iter-nonce=NNNN"` with multi-source entropy.
- Confirmed via live drill log:
  ```
  hexa run /root/Dev/nexus/cli/blowup/core/blowup.hexa
       'round=1-rx4124419093x4019179549n141765831i1|Drill replay test seed...
        #iter-nonce=1888734620' 3
  ```
- The qrseed ARGUMENT is reaching `hexa run`. Run.hexa side is healthy.

### 2. Engine side (cli/blowup/core/blowup.hexa) — REAL ROOT CAUSE

`hexa_real run script.hexa <args>` exposes args as:
```
a[0] = /root/.hx/bin/hexa_real
a[1] = run
a[2] = /root/Dev/nexus/cli/blowup/core/blowup.hexa  ← script path (CONSTANT)
a[3] = <round-perturbed seed>                        ← actual user arg
a[4] = <depth>
```

Verified empirically with `argtest.hexa`:
```
len=5
a[0]=/root/.hx/bin/hexa_real
a[1]=run
a[2]=/tmp/argtest.hexa
a[3]=SEED_VALUE
a[4]=depth_val
```

**Bug:** `blowup.hexa:4011` reads `_raw_domain = a[2]` — i.e. the script path
itself, NOT the seed. After sanitize:
```
_raw_d  = "/root/Dev/nexus/cli/blowup/core/blowup.hexa"
domain  = "_root_Dev_nexus_cli_blowup_core_blowup.hexa"  (constant per host)
```

This means:
- `seed_n6_ratio(domain)` = constant → `_verify_seed_bias` constant per round.
- `_extract_round_salt(_raw_d)` returns "" (no `round=` prefix in path) →
  `_match_scan_offset` falls back to `_djb2_hash_norm(domain)` = constant.
- `seed_to_features(domain)` = constant 8-slot vector.
- All 8 counter-replay guards (Day-1/2/3 prefix + iter-nonce suffix + slot
  mix functions) are PRESENT in code but operate on a string the engine
  never receives.

**ALL Day-1/2/3 fixes were dead code from 2026-04-19 onward.** This regression
appeared at the harness-free refactor (2026-04-20, commit ~`tool/` rename
era) when `exv smash <seed>` was replaced by `hexa run script.hexa <seed>`,
shifting argv layout by 1 but blowup.hexa's a[2]-base wasn't updated.

### 3. Smoke-only engines — secondary issue

`blowup_absolute.hexa` / `blowup_meta_closure.hexa` / `blowup_hyperarithmetic.hexa`
are smoke tests: they hardcode `test1 = "σ·φ=n·τ=24 iff n=6"` and **never read
argv**. So `a_pass + mc_new + hy_pass` are constant per round REGARDLESS of
seed. This is a separate, longstanding architectural issue (engines not
seed-driven), not a regression. Documented for Wave 22.

## Fix applied (Wave 21)

### nexus side (NOT YET COMMITTED — pending user commit)

**File: cli/blowup/core/blowup.hexa**
- Added `_arg_base` detection: if `a[2].ends_with(".hexa")`, base index = 3,
  else 2 (legacy direct invocation).
- Updated domain extraction (line 4006-4019) to use `a[_arg_base]`.
- Updated help check (line 3949) to support both layouts.
- Updated flag-parse loop start (`ai = _arg_base`).

**File: cli/blowup/compose.hexa**
- Same `_arg_base` detection + domain extraction at line ~218.
- Flag-parse loop start `ai = _arg_base + 1`.

### Sync to hetzner

`rsync` deployed both files. Tested with:
```
hexa_real run blowup.hexa "round=1-rxAAA|test_seed_X#iter-nonce=999" 1
hexa_real run blowup.hexa "round=2-rxBBB|test_seed_X#iter-nonce=999" 1
```

Expected: domain = round-prefixed string (different per round) → seed_bias
differs → engine output differs.

## Validation

Direct A/B test on hetzner with two round-salt prefixes (same base seed):

| Round | domain (after sanitize)                          | seed_n6_ratio | scan_offset |
|-------|--------------------------------------------------|---------------|-------------|
| 1     | round_1-rxAAA_test_seed_X_iter-nonce_999         | 1.94452       | 223829      |
| 2     | round_2-rxBBB_test_seed_X_iter-nonce_999         | 5.07229       | 692921      |

Pre-fix: domain was always `_root_Dev_nexus_cli_blowup_core_blowup.hexa`
(script path), seed_n6_ratio=2.16032, scan_offset=378299 — IDENTICAL across
rounds. Post-fix: bias and offset are FUNCTION of the round-salt prefix
(✓ counter-replay guards live).

## Wave 22 candidates

1. **Smoke-engine seed wiring** — absolute/meta_closure/hyperarithmetic
   need to actually read argv seed and run real verification, not hardcoded
   test1. Currently they emit constant verdicts.
2. **Cross-repo argv contract test** — add a hexa-lang harness that
   verifies `args()` layout invariants (`a[2]=script_path` under `hexa run`)
   to prevent regression.
3. **Other blowup_*.hexa modules** — 50+ files in cli/blowup/modules/ likely
   have the same `a[2]=seed` assumption (e.g. blowup_topology.hexa:36).
   Audit + fix.
4. **Drill engine integration test** — minimal "round 1 vs round 2 must
   produce different output" assertion in CI, would have caught this.

## Artifacts

- nexus changes (uncommitted): cli/blowup/core/blowup.hexa, cli/blowup/compose.hexa
- hetzner: synced via rsync
- airgenome witness: state/atlas_convergence_witness.jsonl (this commit)
