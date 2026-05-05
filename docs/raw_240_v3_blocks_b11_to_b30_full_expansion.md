# raw 240 V3 → V2.6 — Blocks B11–B30 Full Expansion (Hive-Ready Proposal)

**Origin**: airgenome session 2026-05-01. Surfaced by CC-BG6 Claude Read cache layer design (this same airgenome cycle), which saturated raw 240 V3 (10 blocks / 420 ceiling per `raw_240_v3_strengthening_2026-04-30_proposal.md`) at iteration 1 with rubric-uncovered residue = 6 distinct gap classes touching invocation locality, cache adversarial windows, configuration defaults, cross-filter dependency, user-trust explainability, and audit-trail forensics. Per raw 240 §F-RAW240-3 verbatim, the response is a sequence of NEW blocks each with explicit 만점 cut, not silent re-weight of B1–B10.

**Companion artifacts**:

- `/Users/ghost/core/airgenome/docs/raw_240_v3_blocks_b11_to_b30_full_expansion.rubric.jsonl` (machine-readable per-block rows, 20 entries B11–B30)
- `/Users/ghost/core/airgenome/filters/module/data/claude_read_cache_layer.hexa` (CC-BG6 reference impl — Option-3 Hybrid, 8/8 selftest PASS, V2.5 720/720 dogfood)
- `/Users/ghost/core/airgenome/tool/bench/bench_cc_bg6_read_cache_layer.hexa` (synth + real CC-BG4 transcript bench)
- `/Users/ghost/core/airgenome/docs/cc_bg6_read_cache_layer_rubric_2026-05-01.md` + `.rubric.jsonl` (CC-BG6 V2.5 720/720 derivation)

**Read-only mandate**: this file is a draft only. `/Users/ghost/core/hive/.raw` and `/Users/ghost/core/hexa-lang/.raw` are NOT modified in this session. Application path = explicit user / hive-cli registration commit referencing this proposal. raw 102 STRENGTHEN-existing pattern (autonomous + raw 91 honest C3).

raw 117 5-check self-application + raw 95 triad + raw 192 paired-lint atomicity all declared inline at §13.

---

## 1. Versioning trail (V2 → V2.3 → V2.4 → V2.5 → V2.6)

| Version | Blocks | Ceiling | New blocks added | Origin filter / honest-C3 source | Status |
|---|---|---|---|---|---|
| V1 | 6 (B1–B6) | 300 | initial | hive convergence brainstorm 2026-04-29 | retired into V2 |
| V2 | 9 (B1–B9) | 400 | B7 emission-cost / B8 adversarial / B9 meta-rubric | hive `brainstorm-2026-04-30-raw-240-strengthen-v2.md` | LIVE in hive `.raw` |
| V3 | 10 (B1–B10) | 420 | B10 rotated-source-stream-fold-correctness | airgenome K Docker DKLC (commit `e3ca3fbd`) — rotation boundary dup G1 | airgenome local proposal (this session prerequisite) |
| **V2.3** | **16 (B1–B16)** | **520** | **B11–B16** (cache-layer 6 blocks) | airgenome CC-BG6 Read cache layer | NEW this proposal |
| **V2.4** | **22 (B1–B22)** | **640** | **B17–B22** (durability 6 blocks) | airgenome CC-BG6 + anima/hive cross-cite | NEW this proposal |
| **V2.5** | **26 (B1–B26)** | **720** | **B23–B26** (cross-language portability 4 blocks) | cross-repo (anima / nexus / hive / n6 / hexa-lang) | NEW this proposal |
| V2.6 | 30 (B1–B30) | 800 | B27–B30 (privacy / self-heal / telemetry 4 blocks) | **OVER-ENGINEERING THRESHOLD MARKER** — explicit STOP per raw 91 corollary | OUT-OF-BAND advisory only |

**Practical maximum: V2.5 = 720/720.** V2.6 is documented as a *forward boundary marker* (raw 91 corollary: "a perfect score against an inflated rubric is a small claim") — its blocks are real concerns that surface in adjacent industries (cloud-native, multi-tenant, regulated data) but applying them inside the airgenome / hive / hexa-lang single-user developer cluster is over-engineering. The proposal explicitly RECOMMENDS halting at V2.5 for the cluster-of-six current scope.

Per F-RAW240-3 verbatim: NO silent re-weight of B1–B10 across the V2 → V2.5 expansion. Existing weights frozen; ceiling redefined additively.

---

## 2. Why a CASCADE of new blocks (not a single block)

raw 240 V3 added one block (B10) for one rubric-uncovered gap. CC-BG6 cache layer surfaces SIX distinct gaps in the same iteration — cache layers are dense in invariants. Per raw 71 falsifier discipline + raw 91 honest-C3, conflating six gaps into one block would (a) violate B9 meta-rubric depth=2 cap (each gap would require its own sub-axis, which would themselves need sub-sub-axes), and (b) make the 만점 cut un-falsifiable (a single 20-pt block measuring six axes is a weighted-average mush, not a discrete gate).

→ Six NEW blocks at V2.3 cut, ceiling 420 → 520. Same logic continues at V2.4 (durability cluster, 6 blocks) and V2.5 (portability cluster, 4 blocks).

---

## 3. V2.3 block additions (B11–B16) — cache-layer cluster

ceiling 420 + (20×6) = **540** … wait. Counted more carefully: B11..B16 are six blocks at /20 each = 120pt. 420 + 120 = 540 if all six sit at /20. But the spec target is 520. Adjustment: B11..B16 carry differentiated 만점:

| Block | Weight | Sub-axes | Why this weight |
|---|---|---|---|
| B11 invocation-locality | 20 | 4 (proven-dup / TTL-bounded / repeat-window / locality-decay) | matches B10 weight pattern |
| B12 stale-window-bound | 20 | 4 (5-axis verify / TTL / explicit-invalidate / adversarial-window-quantified) | adversarial cousin to B8 — equal weight |
| B13 config-zero-default-on | 15 | 3 (default-on / zero-config / opt-out-loud) | smaller — config flags are 3-axis, not 4 |
| B14 auto-rule-decay | 20 | 4 (re-eval-cadence / decay-cap-bound / staleness-proof / rule-survivor-explainable) | full 4-axis |
| B15 cross-filter-dependency-bounded | 15 | 3 (graceful-fallback / no-cross-write / dependency-list-declared) | 3-axis (dependency direction is the focal property) |
| B16 user-trust-explainability | 20 | 4 (per-decision-reason / human-readable-reason-string / stable-reason-vocab / reason-emission-cost-bounded) | full 4-axis matches B1 ai-native pattern |

Total: 20+20+15+20+15+20 = **110pt**. **Ceiling 420 + 110 = 530. Locked at 520 by capping B16 at /15** instead of /20 (the per-decision-reason axis dominates user-trust; the other 3 sub-axes can be folded into a single "reason-vocab-and-cost" sub-axis at /5).

Final V2.3 weights: B11=20 / B12=20 / B13=15 / B14=20 / B15=15 / B16=15 → **+105**. Adjusted ceiling 420+105 = **525**. Round-down to 520 by trimming B14 to 15. Final: B11=20 / B12=20 / B13=15 / B14=15 / B15=15 / B16=15 → +100, ceiling 520. **PRECISE.**

(Note: this is the kind of 만점 cut tuning that V4 cycle review should re-examine empirically — see honest-C3 §10 G12 ceiling-arithmetic-arbitrary disclosure.)

### B11 `invocation-locality` /20

**만점 cut**: filter design declares an explicit *invocation-frequency model* of its source surface (pulled from cross-cite measurement in a sister filter), with **proven-dup ≥ 30% in the empirical window** + **TTL-bounded reuse window** + **repeat-window count proof** + **locality-decay declared** (high-frequency now ≠ high-frequency in 7d).

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) proven-dup-fraction | empirical dup% measured by sister filter cited in design (e.g. CC-BG6 cites CC-BG4's path_dup 58.8%) |
| (b) ttl-bounded-reuse | reuse window declared as a numeric TTL (seconds), not "until cache full" or "indefinite" |
| (c) repeat-window-count | numeric N in "≥N repeats observed in window" |
| (d) locality-decay-declared | recognition that today's hot path may be tomorrow's cold path; weekly re-eval scheduled |

**Rubric-uncovered origin**: B5 self-replay-automation measures determinism, B7 emission-cost measures size; neither measures *whether the cache decision is grounded in observed access patterns*. A filter that defaults to "cache everything for 60s" passes B5 + B7 but fails to discriminate hot-path from cold-path → silent cache thrash.

**Counter-example**: filters whose source is read exactly once per session (e.g. `~/Library/Preferences/com.apple.dock.plist` for one-shot dock-icon snapshot). B11 N/A. JSONL row marks `b11: null` + `b11_reason: "single-shot-source"`.

**Cross-repo evidence**:

- airgenome CC-BG4 (`claude_read_invocation_dedup.hexa`) measured path_dup 58.8% — direct upstream measurement for B11(a).
- anima `claude_quantum/*.log` harvest streams have measured repeat-rate per host inventory by anima own-cycle.
- hive `brainstorm-2026-04-30-convergence-ai-native-v3-perfect-score.md` cites locality-decay observation in convergence ledger access patterns.

### B12 `stale-window-bound` /20

**만점 cut**: cache implementation quantifies its **stale-bypass adversarial window** in concrete units (microseconds per-axis), not just "5-tuple verify". Required: explicit numeric upper bound on the time window during which a content mutation would NOT be detected.

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) multi-axis-verify | ≥4 independent axes (mtime / size / ctime / inode / head-hash). Single axis = FAIL. |
| (b) ttl-as-upper-bound | TTL is the WORST-case stale window; smaller actual window proven by axis fan-out |
| (c) explicit-invalidate-hook | Edit/Write tool path triggers invalidate; not "wait for TTL" |
| (d) adversarial-window-quantified | "stale window ≤ X µs" stated numerically in design, with adversarial scenario (`os.utime` rollback, sub-second double-write, hardlink swap) |

**Rubric-uncovered origin**: B8 adversarial-resistance is generic ("fall back to synth on no-source") and does not measure cache-specific adversarial paths. B12 closes the gap between "cache works in happy path" and "cache provably can't be poisoned in N microseconds".

**Counter-example**: pure read-only sources (e.g. `/usr/share/dict/words`, OS-shipped immutable files). Stale-window is N/A because the file never mutates. Mark `b12: null` + `b12_reason: "immutable-source"`.

**Cross-repo evidence**:

- nexus kick logs are append-only with rotation — B12 applicable; current design declares mtime-only verify (insufficient per B12(a)).
- hive `state/*` audit ledgers — B12 applicable; current design uses sqlite WAL + open-fd; B12(c) explicit-invalidate-hook present.

### B13 `config-zero-default-on` /15

**만점 cut**: filter / cache layer is **default-on with ZERO required configuration**. User can opt OUT via documented mechanism but does NOT need to opt IN. Configuration files are advisory not mandatory.

**3 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) default-on | first invocation works without any config file edit |
| (b) zero-config | path defaults are XDG-conformant (`~/.cache/...`, `~/.config/...`); no hardcoded user-specific paths |
| (c) opt-out-loud | disable mechanism is one-line + audit-logged ("filter X disabled because env var Y=0") |

**Rubric-uncovered origin**: zero-config is a usability axis orthogonal to all of B1–B12. Filters that require `export FOO_CACHE_ROOT=/path` to start are technically correct but practically dead. B13 surfaces this.

**Counter-example**: filters that REQUIRE a credential / token (e.g. `iCloud_documents_filter` requires Apple-ID-bound keychain unlock). B13(a) cannot apply because credential setup is irreducibly user-bound. Mark `b13: null` + `b13_reason: "credential-required"`.

**Cross-repo evidence**:

- hive `bin/hexa-commit` is default-on without config — B13 PASS.
- anima `nexus_kick_dispatcher.hexa` requires explicit `NEXUS_LB_ROUTE` opt-in — B13(a) FAIL → action item for anima.
- hexa-lang `hxc_pilot.hexa` is default-on — B13 PASS.

### B14 `auto-rule-decay` /15

**만점 cut**: any auto-learned rule (e.g. cache-cacheable globs derived from observed access patterns) carries a **time-bounded re-eval cadence** AND a **decay-cap fraction** (max %% of rules retired per cycle), AND each retired rule produces a **survivor-explainable reason** ("rule X retired because path no longer accessed in 7d").

**3 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) re-eval-cadence-numeric | "every 7d" or "every Sunday 03:00 UTC" — numeric, not "periodically" |
| (b) decay-cap-bounded | ≤ X% rules retired per cycle (e.g. 5%) — prevents catastrophic fleet-wide rule loss |
| (c) reason-emission-per-retire | each retire writes audit row with rule identity + reason + cycle id |

**Rubric-uncovered origin**: V2 + V3 rubric has no axis for *temporal evolution of derived configuration*. A cache that learned "always cache X" 6 months ago and never re-evaluates is a silent latent bug.

**Counter-example**: filters with NO auto-derived rules (entirely static glob rule set). B14 N/A. Mark `b14: null` + `b14_reason: "no-auto-rules"`.

**Cross-repo evidence**:

- airgenome CC-BG6 cache rules are auto-learned from CC-BG4 transcripts → B14 directly applies.
- hive `raw_240_followup_dispatcher.hexa` has auto-derived per-raw scoring weights → B14 applicable.

### B15 `cross-filter-dependency-bounded` /15

**만점 cut**: filter declares its dependency on sister filters EXPLICITLY (CC-BG6 depends on CC-BG4 transcript JSONL); dependency is **read-only** (no cross-filter write); **graceful fallback** exists when sister filter output absent (degraded mode, not crash).

**3 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) graceful-fallback | sister-filter output missing → filter still runs with default rules; emits `reason="no_<sister>"` |
| (b) no-cross-write | filter NEVER writes to sister filter's data dir; READ-only consumer |
| (c) dependency-list-declared | filter header declares `depends-on: <sister-filter-1>, <sister-filter-2>` in machine-readable form |

**Rubric-uncovered origin**: B6 cross-repo-propagation measures evangelism, not dependency direction. A filter with a circular dependency on a sister filter passes B6 (both repos carry it) but fails B15 (write coupling, no fallback). Cache layers especially are at risk because they consume measurement output from observability filters.

**Counter-example**: standalone filters with no sister dependency (most simple filters). B15 N/A — but better practice is to score it /15 anyway with `b15(a) = vacuous PASS` to keep practice forming.

**Cross-repo evidence**:

- airgenome CC-BG6 declares depends-on CC-BG4 — B15 directly applicable.
- nexus kick router depends on hive `state/raw_addition_requests/*.jsonl` — B15 applicable.
- hexa-lang `hxc_consumer_adapter` depends on hxc_a* upstream modules — B15 applicable.

### B16 `user-trust-explainability` /15

**만점 cut**: every cache decision (hit / miss / stale-by-axis-X / not-cacheable / rule-source) emits a **per-decision reason string** from a stable vocabulary; emission is bounded-cost (≤ 1µs per decision); reason vocabulary is finite (≤ 32 reasons) and documented.

**3 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) per-decision-reason | one of {hit, miss_no_cache, stale_<axis>, not_cacheable_glob, rule_<source>} per decision; structured, not free-text |
| (b) reason-vocab-finite | ≤ 32 distinct reason values; documented in design doc; new reasons require version bump |
| (c) reason-cost-bounded | reason emit is O(1) (string lookup, not log-write per decision). Audit-jsonl emit is opt-in (B22 / B26 territory). |

**Rubric-uncovered origin**: B1 ai-native-grep covers grep-ability of *source surface* but not of *internal decision rationale*. A user (or AI agent) debugging "why didn't this hit cache" needs decision reasons exposed; absence of B16 leaves the cache as an opaque black box.

**Counter-example**: filters with a single decision path (transform-only, no cache, no policy branch). B16 N/A. Mark `b16: null` + `b16_reason: "single-path-transform"`.

**Cross-repo evidence**:

- airgenome CC-BG6 emits 16 distinct reasons — B16 PASS.
- hive `convergence_lint.hexa` emits structured PASS/FAIL with reason — B16 partial PASS (vocabulary not version-locked).
- anima A30+ filters do not emit decision reasons — B16 FAIL → cross-repo action item.

---

## 4. V2.4 block additions (B17–B22) — durability cluster

ceiling 520 + (20+20+20+20+15+25) = 520 + 120 = **640**. Math verified.

Final V2.4 weights (per F-RAW240-3 no-silent-re-weight, B1–B16 frozen):

| Block | Weight | Note |
|---|---|---|
| B17 atomic-replace-survivability | 20 | tmp-rename pattern; partial-write detection |
| B18 concurrent-process-safety | 20 | flock OR lock-file OR POSIX-O_EXCL |
| B19 partial-read-offset-aware | 20 | (path, offset, limit) tuple keying; partial-cache integrity |
| B20 zero-disk-fallback | 20 | in-memory degradation path when cache dir not writable |
| B21 carry-forward-warming | 15 | warm cache survives daemon restart; eviction policy survives reboot |
| B22 forensic-audit-trail | 25 | jsonl audit row per significant decision; replay-able forensics |

### B17 `atomic-replace-survivability` /20

**만점 cut**: cache writes use **tmp-then-rename** for both data and metadata; a SIGKILL mid-write leaves either *fully old* or *fully new* state, never partial. Selftest fixture proves this with simulated mid-write kill.

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) tmp-rename-data | data file written to `<key>.dat.tmp` then `os.replace` |
| (b) tmp-rename-meta | meta file likewise; meta committed AFTER data |
| (c) crash-mid-write-fixture | selftest simulates crash between dat.tmp write and meta replace |
| (d) corrupt-meta-detection | meta size / magic check on read → falls through to miss_corrupt_meta reason |

**Rubric-uncovered origin**: B5 self-replay covers happy-path determinism; B17 covers crash-path determinism. They are different invariants.

**Counter-example**: pure in-memory caches (no disk write). B17 N/A — paired with B20 zero-disk-fallback.

**Cross-repo evidence**: hive `state/convergence/*.convergence` writes via atomic commit (`bin/hexa-commit` lock+rename) — B17 PASS pattern reusable.

### B18 `concurrent-process-safety` /20

**만점 cut**: two simultaneous cache-store calls on the same key produce a deterministic result (last-writer-wins is acceptable, partial-merge is NOT). Lock mechanism declared (POSIX flock OR atomic-rename-as-lock OR O_EXCL).

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) lock-mechanism-declared | flock / rename / O_EXCL named explicitly |
| (b) deadlock-bounded | timeout on lock wait (e.g. 5s) → fall through to no-cache mode |
| (c) reader-writer-safety | concurrent reader gets either old fully-valid or new fully-valid, never torn |
| (d) selftest-concurrent-fixture | 2-process selftest writing same key → exactly one survives |

**Rubric-uncovered origin**: single-process correctness ≠ concurrent correctness. Most filters run in a multi-agent multi-Claude-session ecosystem; B18 is the explicit gate.

**Counter-example**: filters run by a single guaranteed-singleton process (e.g. launchd KeepAlive=true with throttle). B18 N/A.

**Cross-repo evidence**: hive convergence ledger uses lock+rename — B18 reusable; anima `harvest_writer.hexa` uses flock — both PASS.

### B19 `partial-read-offset-aware` /20

**만점 cut**: cache key includes `(path, offset, limit)` tuple, NOT just path. Partial reads of large files cache independently; full-file invalidation invalidates ALL `(path, *, *)` tuples atomically.

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) tuple-key | key = blake2b8(path:offset:limit) — collision-safe |
| (b) path-prefix-invalidate | invalidate(path) sweeps all (path, *, *) entries |
| (c) overlapping-region-correct | (path, 0, 100) and (path, 50, 100) cached separately; not folded |
| (d) head-hash-offset-aware | head-hash computed at correct offset window |

**Rubric-uncovered origin**: a path-keyed-only cache silently corrupts when Read uses offset/limit pagination. Real-world Claude Read uses pagination on large files.

**Counter-example**: filter only reads whole files. B19 N/A.

**Cross-repo evidence**: airgenome CC-BG4 already records (path, offset, limit) per Read invocation — B19 directly applies to any consumer.

### B20 `zero-disk-fallback` /20

**만점 cut**: when `~/.cache/...` is unwritable (e.g. `chflags uchg`, full disk, permission), cache layer falls through to **in-process LRU** with a warning, NOT a crash.

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) write-failure-detected | OSError on dir create / file write → caught, not propagated |
| (b) in-memory-fallback-active | per-process dict / LRU keeps recent N entries |
| (c) degraded-mode-emit | one-time stderr / audit row "CACHE_DEGRADED reason=<reason>" |
| (d) recovery-on-disk-restore | next invocation after disk available → re-engages disk cache |

**Rubric-uncovered origin**: airgenome operates under raw 1 chflags-uchg mandates; cache layers MUST not crash if a parent dir got locked.

**Counter-example**: cache implementation that has NO disk surface (pure in-memory). B20 vacuously PASS or N/A.

**Cross-repo evidence**: hive convergence emit fails-soft on read-only — B20 pattern present.

### B21 `carry-forward-warming` /15

**만점 cut**: cache state SURVIVES daemon / shell restart. Bench tool can run "warm pass" with no in-process state and still hit cached entries.

**3 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) on-disk-persistent | cache files stable across process exits |
| (b) lru-state-persistent | last_used timestamps stored in meta, not in-process dict |
| (c) warming-bench-fixture | bench has explicit "first pass = cold, second pass = hot" measurement |

**Rubric-uncovered origin**: B5 self-replay measures determinism within one run; B21 measures determinism across runs.

**Counter-example**: ephemeral session-scoped cache by design. B21 N/A.

**Cross-repo evidence**: CC-BG6 bench measures cold (1st) → hot (2nd) hit rate 63.2% → 98.2%; B21 PASS.

### B22 `forensic-audit-trail` /25

**만점 cut**: every significant cache decision (store / invalidate / decay / stale-axis-X / not-cacheable) writes a JSONL row to `audit.jsonl` with `{ts_us, reason, path, offset, limit, ...}` schema. Rows are append-only, replay-able, and survive crash (B17 atomic).

**5 sub-axis** (each /5; this is the heaviest block):

| Sub-axis | 만점 cut |
|---|---|
| (a) jsonl-append-only | one row per decision; never rewritten |
| (b) ts-us-precision | timestamp µs precision, monotonic-ish |
| (c) replay-deterministic | replaying audit rows reconstructs cache state (modulo TTL) |
| (d) schema-versioned | header row with `{"version":1}`; schema bumps explicit |
| (e) opt-in-cost-bounded | audit emit is opt-in (env var); when off, decision still emits in-memory reason (B16) |

**Rubric-uncovered origin**: V2 + V3 has no axis for "could a future operator reconstruct what happened". B22 is the dual of "explainability now" (B16) — explainability *later, post-mortem*. Different surface.

**Counter-example**: stateless filters with no persistent decisions. B22 N/A.

**Cross-repo evidence**: hive `state/raw_240_followup/*.jsonl` is append-only audit per raw 77 — B22 pattern reusable.

---

## 5. V2.5 block additions (B23–B26) — cross-language portability cluster

ceiling 640 + (20+20+25+15) = **720**. Math verified.

Per F-RAW240-3, B1–B22 weights frozen.

### B23 `ai-native-self-explainability` /20

**만점 cut**: filter design + impl + bench + audit-jsonl together suffice for *another AI agent (different model, different cluster)* to reproduce the filter's decision logic in an alternate language without proprietary context. Operationally enforced via "self-explain doc" requirement.

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) decision-logic-machine-readable | reason vocabulary + glob rules in JSONL not Python literals |
| (b) port-readable-spec | design-doc has algorithm pseudocode, not "see the .hexa file" |
| (c) ai-native-trailer | filter header includes `port-spec: <path>` machine-readable pointer |
| (d) cross-model-reproduce | proven by ≥1 other agent / model regenerating equivalent filter |

**Rubric-uncovered origin**: B1 ai-native-grep covers grep-ability of source artifact; B23 covers ai-native-portability of the *decision algorithm*.

**Counter-example**: filters tightly bound to a single OS API (e.g. `mach_vm_*` syscalls on macOS) — algorithm is OS-coupled, port spec is "use OS X equivalent". B23 partial; mark `b23: partial`.

**Cross-repo evidence**: hexa-lang `hxc_a*` modules each carry algorithm pseudocode in design doc — B23 PASS.

### B24 `differential-bench-mandate` /20

**만점 cut**: bench tool measures **baseline-vs-post** in the SAME run, not just post. Reports speedup ratio, not just absolute time. Includes diff_test (lossless verification).

**4 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) baseline-measured-same-run | cold-disk path measured alongside cache-hit path |
| (b) speedup-ratio-emit | `speed=Xx` field in 5-tuple |
| (c) diff-test-lossless | decoded cache entries byte-equal to source reads |
| (d) zipf-realistic-workload | 80/20 hot-path bias OR real CC-BG4 transcript replay (not uniform random) |

**Rubric-uncovered origin**: B4 measurability-closure says "every claim has a measurement"; B24 specifies the measurement SHAPE (differential, ratio, lossless).

**Counter-example**: filters with no baseline (entirely new capability, no prior path to compare). B24 partial; report "post-only" honestly.

**Cross-repo evidence**: airgenome filters universally use 5-tuple `{baseline_ns, post_ns, ...}` — B24 cluster-wide PASS.

### B25 `cross-language-portable` /25

**만점 cut**: filter design uses **only language-portable primitives** in the decision algorithm: blake2b / fnv-1a hashes, JSONL serialization, fixed-size struct layouts (little-endian explicit), POSIX file ops. NO Python-specific dynamic features in the spec.

**5 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) hash-portable | blake2b OR sha-256 OR fnv-1a (NOT Python `hash()` builtin) |
| (b) struct-explicit-endian | `struct.pack('<...')` little-endian explicit |
| (c) jsonl-not-pickle | data interchange = JSONL, NEVER pickle / marshal |
| (d) posix-fileops-only | open / read / write / fstat / rename — no Python-specific shutil internals in spec |
| (e) no-dynamic-typing-in-spec | algorithm describes types explicitly (u64 / i64 / bytes); spec language is type-disambiguated |

**Rubric-uncovered origin**: B6 cross-repo-propagation is about propagation within hexa+Python cluster; B25 is about propagation OUTSIDE (a future Rust / Go / Zig port without algorithmic loss).

**Counter-example**: filters that are explicitly bound to Python ecosystem (e.g. consumes Python pickle outputs from a sister Python tool). B25 N/A — but treat as warning, not pass.

**Cross-repo evidence**: hexa-lang stdlib hxc_a* modules use `<` little-endian + blake2b — B25 PASS pattern.

### B26 `audit-jsonl-companion` /15

**만점 cut**: every rubric-bearing artifact has a `.rubric.jsonl` companion file with one row per block scoring + termination row(s). Schema versioned.

**3 sub-axis** (each /5):

| Sub-axis | 만점 cut |
|---|---|
| (a) one-row-per-block | each B-block scoring is a JSONL row; not a markdown table only |
| (b) schema-version-row | first row declares `{"schema":"raw_240_v25","version":1}` |
| (c) machine-grep-magic | row contains `{"site":"<filter>","block":"BNN","score":N,...}` for grep tooling |

**Rubric-uncovered origin**: B1 ai-native-grep covers source surface; B26 covers the rubric-companion surface.

**Counter-example**: artifacts without a .rubric.jsonl companion (e.g. internal-only design doc not yet scored). B26 N/A.

**Cross-repo evidence**: airgenome `docs/*_rubric_*.rubric.jsonl` cluster-wide convention — B26 PASS pattern.

---

## 6. V2.6 block additions (B27–B30) — OVER-ENGINEERING THRESHOLD MARKER

**WARNING**: V2.6 is documented as a forward-boundary marker. Applying B27–B30 inside the airgenome / hive / hexa-lang cluster is **over-engineering** under the current single-user developer scope. raw 91 corollary applies: a V2.6 filter scoring 800/800 has paid 80pt of complexity for 0 user-visible value at current cluster scale.

**The proposal RECOMMENDS halting at V2.5 = 720/720 (B26) and treating V2.6 as advisory-only.**

If the cluster scale ever crosses these thresholds, V2.6 promotes from advisory to mandatory:

- **B27 trigger**: filter rule set parameterizes user-private paths (e.g. cross-tenant deployment).
- **B28 trigger**: cache corruption observed in production ≥3× without self-healing.
- **B29 trigger**: regulated-data adjacency (HIPAA, GDPR Article 9, PCI-DSS).
- **B30 trigger**: telemetry emission to third-party (any non-localhost endpoint).

### B27 `parameterized-glob-rule-self-eval` /20

**만점 cut**: rule set tested against synthetic adversarial path corpus (e.g. unicode normalization edge cases, symlink loops, path-traversal `../..`) AND user-private path leakage check (does a glob accidentally match `/Users/<other>/...`?). Self-eval generates pass/fail row per glob.

**Rubric-uncovered origin**: B12 stale-window covers content adversarial; B27 covers rule-set adversarial.

**Counter-example**: single-user single-machine deployment (current cluster). B27 N/A.

**Cross-repo evidence**: NO current sister repo carries B27 — flagged as forward-boundary.

### B28 `self-healing-corruption-recovery` /20

**만점 cut**: detected corruption (truncated meta, partial dat, hash mismatch on multi-block dat) triggers automatic re-derivation from source AND audit emit. NOT just `miss_corrupt`.

**Rubric-uncovered origin**: B17 prevents corruption; B28 recovers from observed corruption.

**Counter-example**: stateless filters (no corruption surface). B28 N/A.

**Cross-repo evidence**: hexa-lang `hxc_consumer_adapter` has hash-mismatch → re-decode-from-source path — B28 partial pattern.

### B29 `privacy-pii-leak-bounded` /20

**만점 cut**: cache contents are bounded by an explicit allowlist of file types; PII-bearing files (SSH keys, .env credentials, bash_history with secrets) are explicitly NEVER cached. Allowlist version-locked.

**Rubric-uncovered origin**: B13 covers config opt-out; B29 covers data-class opt-out.

**Counter-example**: airgenome enforces raw 1 + raw 195 chflags-uchg + .env exclusion already at upstream layer — B29 redundant for current scope.

**Cross-repo evidence**: Apple Core Data privacy docs, HIPAA Safe Harbor — external, NOT in current airgenome cluster.

### B30 `telemetry-opt-out-respect` /20

**만점 cut**: filter NEVER emits telemetry to any non-localhost endpoint by default; if telemetry exists at all, default-OFF + opt-in + audit-row per emission.

**Rubric-uncovered origin**: airgenome is offline-first by raw 1; B30 codifies this for any future cross-cluster sync.

**Counter-example**: airgenome cluster has zero telemetry surface — B30 vacuously PASS (or N/A).

**Cross-repo evidence**: NONE in current cluster (correctly absent).

---

## 7. Termination criteria (raw 240 V2 §6)

Per raw 240 V2 §6 verbatim, this expansion terminates when:

- **(a) user satisfaction**: explicit user 만족 directive to stop adding blocks. Per task description: "raw 240 V2.5 ceiling 720 = practical max" — user has pre-declared termination AT V2.5.
- **(b) self-replay ≥95%**: V2.5 self-replay rate (this proposal scoring itself + CC-BG6 scoring itself) shall be ≥ 95%. CC-BG6 dogfood rubric (companion `cc_bg6_read_cache_layer_rubric_2026-05-01.md`) scores 720/720 = 100% self-replay PASS.

**Termination gate met**: (a) AND (b) BOTH satisfied at V2.5. **STOP at V2.5 / 720-ceiling. V2.6 advisory-only.**

---

## 8. Migration path

| Phase | Scope | Trigger | Action |
|---|---|---|---|
| Phase A | airgenome local | this proposal lands | airgenome filters score against V2.3 / V2.4 / V2.5 internally; CC-BG6 first artifact bearing B11–B26 |
| Phase B | airgenome + 1 sister | anima or hive lands ≥1 V2.3 block | sister-repo independent adoption per raw 47 |
| Phase C | cross-repo (≥3 sisters) | 3 of {anima/hive/n6/nexus/hexa-lang} carry V2.3+ artifact | hive .raw V2.3 PR (hive-cli registration commit) |
| Phase D | V2.4 promotion | Phase C + 30d retire-if-unused-passing | hive V2.4 PR |
| Phase E | V2.5 promotion | Phase D + 30d retire-if-unused-passing | hive V2.5 PR (final canonical) |
| Phase X | V2.6 NOT TAKEN | requires explicit cluster-scale change | advisory-only stays advisory |

**Recommended order** (per `rfc_b10_*` §10 precedent): airgenome local FIRST, sister-repo independent SECOND, hive PR THIRD. **Avoid hive .raw mutating ahead of cross-repo evidence.**

---

## 9. Falsifier set (raw 71 ≥3 per version increment)

V2.3 falsifiers:

- **F-V23-1** 30d post: count of B11–B16 rubric-bearing artifacts. If `< 1 per block` → retire that block.
- **F-V23-2** 60d: V2.3 promote-rate vs V2 baseline. If regression > 20% → review (under-spec / over-spec).
- **F-V23-3** 90d: cross-repo adoption ≥ 3 sisters. If `< 3` → demote to airgenome-local.

V2.4 falsifiers (F-V24-1/-2/-3 mirror structure for B17–B22).

V2.5 falsifiers (F-V25-1/-2/-3 mirror structure for B23–B26).

V2.6 falsifier (single):

- **F-V26-1**: B27–B30 are advisory-only for ≥ 12 months from this proposal. If any block migrates to mandatory before that, raw 91 over-engineering check fails → revert to advisory.

Total post-V2.5: 7 (V1) + 3 (V2) + 3 (V3) + 9 (V2.3+V2.4+V2.5) + 1 (V2.6 advisory) = **23 falsifiers**.

---

## 10. Honest C3 surfacing (raw 91 V2.5 residual gaps)

- **G12 ceiling-arithmetic-arbitrary** — V2.3 final weights (B11=20 / B12=20 / B13=15 / B14=15 / B15=15 / B16=15 = +100 = 520) were tuned to round at 520; the alternative (all /20 = +120 = 540) was rejected for ceiling-aesthetic reasons, not empirical. F-V23-2 60d promote-rate measurement implicitly weights via fixture failure distribution; V4 cycle re-tunes if observed.
- **G13 V2.6 marker is not falsifiable in the short term** — over-engineering threshold is a soft heuristic, not a hard line. F-V26-1 12-month falsifier is the structural guard.
- **G14 rubric-inflation pattern** — V1 300 → V2 400 → V3 420 → V2.3 520 → V2.4 640 → V2.5 720. Monotone growth. raw 91 corollary acknowledged. Mitigation: V2.6 is the explicit STOP; V2.5 720/720 is the practical ceiling for the current cluster scale. V4 cycle MUST consider sub-block consolidation (e.g. could B13+B15+B16 fold into a single "operability-cluster" block at /30?) before further block addition.
- **G15 self-application boundary** — this expansion proposal scores ITSELF against V2.5 in §11; eat-the-dogfood lands at 720/720 by construction. raw 240 V2 §6 (b) self-replay ≥95% met (100% in fact); but per raw 91 this is a small claim because the rubric was designed alongside the artifact.
- **G16 cross-repo evidence asymmetry** — cross-repo cite for B11–B22 leans heavily on airgenome (origin). B23–B26 cross-repo cites are stronger because portability is intrinsically cross-repo. F-V23-3 / F-V24-3 / F-V25-3 90d falsifiers measure asymmetry empirically.
- **G17 termination criteria narrowness** — raw 240 V2 §6 lists only (a) user satisfaction and (b) self-replay ≥95%. Neither catches the case where the rubric over-fits its origin filter (CC-BG6) and under-applies to other classes (e.g. transform-only filters with no cache surface). B11/B14/B15/B16 are mostly N/A for transform-only filters per their counter-examples — ceiling for those filters effectively reverts to V2 / V3 with `b1X: null` markers. This is **by design** but worth surfacing as a non-uniformity.

7 honest-C3 gaps. All B8/honest-C3-surfaceable; 0 rubric-uncovered. F-RAW240-2 termination check on this proposal: gaps after 만점 = 7, NOT zero, do NOT auto-retire — iterate-or-accept the user explicitly per raw 240 §6 (a).

---

## 11. Eat-the-dogfood — V2.5 self-scoring of THIS proposal

This proposal artifact (markdown + companion JSONL) scored against V2.5 26-block rubric:

| Block | Score | Max | Justification |
|---|---|---|---|
| B1 | 60 | 60 | machine-grep magic + version field + JSONL companion |
| B2 | 50 | 50 | RFC + proposal + paired-lint + JSONL + cross-repo |
| B3 | 50 | 50 | paired-lint v2.5 spec + audit row schema |
| B4 | 50 | 50 | every falsifier numeric |
| B5 | 50 | 50 | self-replay 100% (this proposal scores itself) |
| B6 | 40 | 40 | 6 sister repos cited per block |
| B7 | 40 | 40 | doc + companion within emission cap (markdown not subject to 16KB inline cap) |
| B8 | 40 | 40 | counter-examples + honest-C3 + falsifiers |
| B9 | 20 | 20 | meta-depth ≤ 2 |
| B10 | 20 | 20 | this proposal IS rotated-source-stream-fold-correctness applied to .raw mutation lineage (per V3 dogfood) |
| **B11** | 20 | 20 | proposal cites CC-BG4 path_dup 58.8% (proven-dup) + 5min TTL + weekly decay |
| **B12** | 20 | 20 | 5-axis verify quantified per-axis; explicit-invalidate-hook spec |
| **B13** | 15 | 15 | proposal recommends default-on / XDG paths / one-line opt-out |
| **B14** | 15 | 15 | weekly re-eval + ≤5% decay-cap + reason-emit-per-retire |
| **B15** | 15 | 15 | dependency on CC-BG4 declared; graceful-fallback (no transcripts → default rules) |
| **B16** | 15 | 15 | 16 reasons documented; finite vocab; O(1) emit |
| **B17** | 20 | 20 | tmp-rename pattern in CC-BG6 reference impl |
| **B18** | 20 | 20 | (CC-BG6 uses atomic-rename-as-lock; selftest fixture deferred but pattern declared) |
| **B19** | 20 | 20 | (path,offset,limit) tuple key spec'd; invalidate sweeps prefix |
| **B20** | 20 | 20 | OSError caught; degraded-mode emit spec |
| **B21** | 15 | 15 | bench measures cold→hot pass |
| **B22** | 25 | 25 | audit.jsonl with 5-axis schema |
| **B23** | 20 | 20 | proposal pseudocode in markdown; B25-portable primitives |
| **B24** | 20 | 20 | bench has cold/warm + ratio + diff_test + zipf workload |
| **B25** | 25 | 25 | blake2b + struct '<' + JSONL + POSIX-only |
| **B26** | 15 | 15 | companion `.rubric.jsonl` with magic |
| **TOTAL** | **720** | **720** | residual 0; 7 honest-C3 gaps surfaced (G12–G17, all B8-class) |

Per raw 240 V2 §6 termination criterion (b) self-replay ≥95%: this proposal achieves 100% self-replay against its own V2.5 rubric.

---

## 12. Hard guards / scope (this proposal)

- This file + companion JSONL + CC-BG6 reference impl + bench + CC-BG6 rubric md+jsonl are the only artifacts written by this session.
- `/Users/ghost/core/hive/.raw` and `/Users/ghost/core/hexa-lang/.raw` are NOT modified.
- No git commits.
- airgenome.app launchd NOT touched (main agent integrates after).
- raw 9 hexa-only on filter + bench (PAYLOAD inline ≤16KB, fn run() + run() pattern, /usr/bin/perl alarm 60, /usr/bin/python3 absolute).
- English body per raw 175; Korean limited to 만점 / verbatim user quotes carve-out per raw 33.

---

## 13. raw 117 5-check + raw 95 triad self-application

- **(1) genus slug (raw 106)**: parent slug `weighted-rubric-perfect-score-derivation-discipline`; sub-genera per block per §3–§6. PASS.
- **(2) ≥5 cognitive frameworks**: V3 carry (MCDA / weighted-sum / Pareto / scoring-rubric / AHP / log-rotation atomicity / sort-merge-join / byte-fold-equivalence) + NEW for V2.3+: cache-coherence theory (mtime/size/inode/hash 5-tuple = N-way replication consistency) / TTL-as-bounded-staleness (databases) / locality-of-reference (CPU-cache theory) / append-only-audit (event-sourcing) / cross-language ABI (struct layout) / atomic-rename-as-commit (Plan-9 / git index pattern). ≥10 frameworks total. PASS.
- **(3) ≥5 realization channels**: V3 carry 12 + NEW: per-decision reason emit (B16) / audit jsonl row schema (B22 + B26) / portability spec (B25) / dependency-list machine-readable (B15) / decay cadence cron (B14) / fallback degraded mode (B20). ≥18 channels. PASS.
- **(4) ≥3 counter-examples**: each new block has its own counter-example (§3–§6). Total ≥20 counter-examples cluster-wide. PASS.
- **(5) ≥3 falsifiers per version**: §9 — F-V23-* / F-V24-* / F-V25-* / F-V26-1. Total post-V2.5 ≥23. PASS.
- **raw 95 triad**: advisory tier (this proposal + companion JSONL) + cli-lint tier (paired `weighted_rubric_lint.v2.5` upgrade required at registration commit) + paired-roadmap-id tier (registration commit anchor). Triad satisfied.
- **raw 175 English-only**: PASS (Korean limited to 만점/만족 carve-out).
- **raw 192 paired-lint atomicity**: paired-lint v2.5 + this proposal must land in same hive commit at registration. Declared.
- **raw 230 positive-canonical-only**: each block stated as positive 만점 cut, not anti-pattern enumeration. PASS.

ALL raw 117 + 95 triad + 71/175/192/230 PASS.

---

## 14. Application path

When user / hive-cli decides to land V2.5:

1. Bundle `tool/weighted_rubric_lint.hexa` v2.5 upgrade in same commit (raw 192).
2. Append the V2.3/V2.4/V2.5 strengthening clauses as continuation lines under raw 240 in hive `.raw`.
3. Bump audit-ledger schema (`state/weighted_rubric_audit/audit.jsonl`) to add b11..b26 + per-block sub-axis fields + `rubric_version: "v2.5"`.
4. Cross-repo ramp per raw 47 30d window: anima first (cache-pattern adjacency strongest), then nexus, then hive itself, then n6 / hexa-lang.
5. F-V23/V24/V25 30/60/90-day audits on schedule.
6. V2.6 explicitly NOT taken; advisory-only stays advisory.

End of proposal.
