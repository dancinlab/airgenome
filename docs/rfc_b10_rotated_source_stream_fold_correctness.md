# RFC — B10 `rotated-source-stream-fold-correctness` (raw 240 V3 candidate block)

**RFC date**: 2026-04-30
**Author**: airgenome agent (arsmoriendi99@proton.me cycle)
**Origin**: airgenome Docker DKLC filter design, commit `e3ca3fbd`
**Source artifacts**: `/Users/ghost/core/airgenome/docs/k_docker_filter_rubric_2026-04-30.md` + `.rubric.jsonl`
**Status**: DRAFT for hive raw 240 V3 strengthening cycle. NOT yet registered.
**Read-only mandate**: this RFC is a draft only. `/Users/ghost/core/hive/.raw` and `/Users/ghost/core/hexa-lang/.raw` are NOT touched in this session. Application path = explicit user / hive-cli registration commit referencing this RFC. raw 102 STRENGTHEN-existing pattern (autonomous + raw 91 honest C3).

---

## 1. Why a NEW block (not a re-weight)

raw 240 V2 §F-RAW240-3 mandates: when honest-C3 surfaces a *rubric-uncovered* gap in a saturating candidate, the fix is **add a NEW block with explicit 만점 컷, no silent re-weight of B1..B9**, then redefine the ceiling.

K Docker DKLC iteration 1 saturated V2 at **V4 = 395/400** with residual **G1 = rotated-log boundary line dup risk between rotation files** (`backend.log` → `backend.log.0` partial-line-tail + duplicate-line-head). G1 is rubric-uncovered: V2's 9 blocks (B1 ai-native-grep / B2 channel-coverage / B3 enforcement / B4 measurability / B5 self-replay / B6 cross-repo / B7 emission-cost / B8 adversarial / B9 meta-rubric) have no axis that scores **rotation-fold byte-correctness** as such. B8 adversarial-resistance partially overlaps (rotated-log adversarial path), but B8's 만점 컷 is "synth fallback when no real source + honest-C3 surfacing" — it does not measure byte-fold-equivalence.

→ NEW block, ceiling 400 → 420.

---

## 2. B10 spec — `rotated-source-stream-fold-correctness /20`

### 2.1 만점 컷 (block-level)

A filter design earns the full 20 points iff its encoder, when applied to a rolling-rotation timestamped-component log stream `[file.0 ... file.N]`, produces a single columnar artifact whose round-trip-decoded line set is **byte-fold-equivalent** to the canonical sort-merge of the rotation files (excluding documented mid-rotation atomicity gaps owned by the producer daemon, which are out-of-scope per raw 91 honest-C3 surfacing).

Operationally enforced via:

- **Rotation-walk discipline**: encoder iterates rotation files in a deterministic order (oldest → newest OR newest → oldest, declared in spec).
- **Boundary-dedup mechanism**: a 64-bit hash (fnv-1a or equivalent) over `(ts_us, comp_idx, msg_lens, first_32_bytes_of_msg)` with a last-N ring buffer (N ≥ 1024) at each file boundary suppresses partial-tail / duplicate-head artifacts.
- **Byte-fold-equivalence diff_test**: at bench time, `decode(encode(rotation_set))` MUST equal `sort(union(rotation_set))` modulo the documented timestamp-precision truncation.

### 2.2 Four sub-axis (each /5, summed → /20)

| Sub-axis | Name | 만점 컷 (5pt) |
|---|---|---|
| **(a)** | rotation-boundary-lossless | partial-line tail at `file.K` + duplicate-line head at `file.K-1` are joined or deduped; no line lost AND no line double-counted. Selftest fixture: `tail of file.0 = "[2026-04-30T..."` (truncated) + `head of file = "[2026-04-30T..." complete` → exactly one line in fold. |
| **(b)** | cross-rotation-dedup | identical record (same ts + comp + msg) appearing in two adjacent rotation files (race condition during rotation) is folded to one. fnv-1a hash ring buffer ≥1024 entries. Selftest fixture: same line bytes literally present at end of `file.0` and start of `file` → exactly one line in fold. |
| **(c)** | clock-skew-tolerance | out-of-order timestamps WITHIN a single rotation file (sub-second skew, multi-thread interleave, NTP step) preserved in fold; no silent reorder; no silent drop. Selftest fixture: ts sequence `[t+0, t+5, t+3, t+8]` in one file → 4 lines in fold, original order preserved. |
| **(d)** | cleanup-mid-encode-safety | rotation OR truncation OR `logrotate copytruncate` happening DURING encode does not panic; encoder exits with a deterministic verdict (PASS-with-partial OR FAIL with reason) and never writes a corrupt artifact. Selftest fixture: simulate `unlink(file.8)` mid-encode → encoder must surface `partial=true` field in JSONL emit, not crash. |

### 2.3 Anti-pattern surface (raw 230 positive-canonical-only — phrased as violating intent, not name-enumerated)

- Encoder reads ONLY the active `file` (no rotation walk) → (a) FAIL.
- Encoder concatenates rotation files without boundary hash → (b) FAIL.
- Encoder sorts by timestamp before emit, dropping skew → (c) FAIL.
- Encoder panics on missing rotation file mid-walk → (d) FAIL.

---

## 3. Cross-repo evidence (raw 47 trawl, 5+ repos surface)

Rolling-rotation timestamped-component log streams are present across the repo cluster. B10 universal mandate candidacy threshold per raw 47 (≥3 sister repos) is exceeded:

| Repo | Stream | Rotation? | Component? | Affected |
|---|---|---|---|---|
| **hive** itself | `~/Library/Logs/<App>/*.log[.N]` (claude harness, harness-cli stream) | yes (size-based) | yes | YES |
| **anima** | `claude_quantum/*.log` harvest streams + `harvest_*.jsonl[.N]` | yes (daily) | yes | YES |
| **nexus** | kick logs (`kick_*.log[.N]`) + atlas parser streams | yes | yes | YES |
| **n6-architecture** | cell-encoding rolling fold files | yes (size-based) | yes | YES |
| **hexa-lang** | build-log rotation under `state/build/*.log[.N]` | yes | yes | YES |
| **airgenome** (origin) | Docker DKLC `backend.log[.0..8]` + console `console.log[.0..N]` | yes (size+time) | yes | YES (origin) |

**6 repos affected. raw 47 universal mandate threshold (≥3) cleared by 2×.**

Top affected (priority for sister-repo independent adoption — see §6 migration path):

1. **anima** — `claude_quantum` harvest streams are the highest-volume rolling source in the cluster; any harvest-replay analytic that ignores rotation-fold correctness silently corrupts cross-day metrics. Estimated impact: every harvest-trend rubric block in anima.
2. **hive** itself — harness logs feed convergence/audit ledgers; rotation-boundary dup risk leaks into raw 77 audit row counts. Direct impact on raw 240 audit ledger fidelity.

---

## 4. Three candidate scoring forms (≥3 per raw 240 V2 §B8 ordering)

raw 240 V2 §B8 mandates ≥2 candidates pre-registered before scoring. Three candidate forms for **how** B10 attaches to the rubric:

| Form | Description | Pros | Cons | Score-against-V2-meta |
|---|---|---|---|---|
| **F-A: rubric-block-addition** (recommended) | NEW block B10 /20, ceiling 400 → 420. Explicitly per F-RAW240-3 (no silent re-weight). | clean ceiling math; honors F-RAW240-3 verbatim; one ledger row per block; cross-repo lint extends additively. | ceiling drifts upward over time (V2.1 → V2.2 → V3 → ...); 30d falsifier required to retire if unused. | meta-rubric depth=1 (B9 cap=2); PASS. |
| **F-B: separate-raw** (raw 247 candidate `rolling-rotation-fold-correctness-mandate`) | New top-level raw entry, NOT a raw 240 block. Scored independently like raw 241. | reusable across non-rubric contexts (any rotation-walking code); cross-repo lint becomes a dedicated tool. | duplicates measurement infrastructure; rubric-bearing artifacts must reference TWO raws (240 + 247); registration friction. | orthogonal to raw 240; PASS but lower coupling efficacy. |
| **F-C: B5-sub-block** (B5 self-replay-automation /50 → /50 with sub-axis B5d rotation-fold) | Embed rotation-fold as a 4th sub-axis under existing B5. No ceiling change. | no ceiling drift; B5 already covers self-replay determinism. | violates F-RAW240-3 verbatim ("no silent re-weight"); B5 sub-axis weights become opaque; 만점 컷 of B5 changes silently for V2 users. | F-RAW240-3 FAIL — silent re-weight. |

**Recommendation: F-A.** F-A honors F-RAW240-3 verbatim, preserves V2 backward compatibility (V2 rubrics still score /400; V3 rubrics score /420), and matches the K Docker DKLC iteration 2 derivation already in evidence at `k_docker_filter_rubric_2026-04-30.md` §5. F-B is a viable backup if rolling-rotation-fold becomes a non-rubric concern (e.g. live `tail -F`-style consumers); F-C is rejected outright.

### 4.1 Numeric rubric scoring of the three forms (eat-the-dogfood)

Scored against the V2 rubric itself (recursion is finite per raw 240 §B9 depth=2 cap):

| Form | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|---|---|---|---|---|---|---|---|---|---|---|
| F-A rubric-block-addition | 55 | 50 | 50 | 50 | 45 | 40 | 35 | 40 | 20 | **385** |
| F-B separate-raw | 50 | 45 | 45 | 45 | 40 | 40 | 35 | 35 | 20 | **355** |
| F-C B5-sub-block | 40 | 35 | 25 | 35 | 40 | 30 | 35 | 25 | 10 | **275** |

F-A wins by 30pt over F-B and 110pt over F-C. F-A residual −15: B1 (no machine-grep magic for the proposal artifact itself), B5 (self-replay of the B10 rubric requires fixture set), B7 (RFC + proposal pair adds ~12KB to docs/). All B8/honest-C3-surfaceable, none rubric-uncovered.

---

## 5. raw 117 5-check self-application

Mandatory per raw 240 §B9 meta-rubric-finite (depth=1 application here; depth=2 cap honored).

- **(1) genus slug (raw 106)**: `rotated-source-stream-fold-correctness`. No `-via/-with/-api/-using` species suffix. Composite genus per raw 106 (`rotated-source-stream` × `fold-correctness`). PASS.
- **(2) ≥5 cognitive frameworks**:
  - log-rotation atomicity (UNIX rename + open-fd race semantics)
  - sort-merge-join correctness (4-sub-axis mirrors classic merge invariants: lossless / dedup / order-preserving / interruption-safe)
  - byte-fold-equivalence (round-trip identity property — `decode∘encode = id` on canonical sort-merge)
  - clock-skew tolerance (NTP step / multi-writer interleave, distributed-systems angle)
  - reservoir-ring boundary detection (last-N hash ring as bounded-memory dedup)
- **(3) ≥5 realization channels**:
  - rubric block in V3 markdown table (`B10 rotated-source-stream-fold-correctness /20`)
  - JSONL companion row (`{"block":"B10","weight":20,"manjeom_cut":"..."}`)
  - paired lint `tool/b10_rotation_fold_lint.hexa` (4-fixture selftest covering sub-axis a–d)
  - cross-repo bootstrap row in `state/weighted_rubric_audit/audit.jsonl` per repo carrying B10
  - design-doc declaration: any filter design doc touching a rolling-rotation source MUST declare its rotation-walk discipline + boundary-dedup mechanism
- **(4) ≥3 counter-examples** (where B10 does NOT apply, kept mandate-orthogonal):
  - **single-file source**: source is one append-only file, no rotation surface (e.g. `bash_history` post-r22 honor-system) — B10 marked N/A in JSONL row, scored as 20/20 vacuously OR excluded from total per filter declaration.
  - **append-only without rotation**: source is `WAL`-style append (e.g. SQLite `-wal` file before checkpoint) where no rotation file exists — B10 N/A.
  - **in-memory ringbuffer**: source is a process-memory ring (e.g. `dmesg` kernel ring) read by syscall, no on-disk rotation — B10 N/A.
- **(5) ≥3 falsifiers (raw 71)**: see `raw_240_v3_strengthening_2026-04-30_proposal.md` §4 for full falsifier set (F-RAW240-V3-1 / -V3-2 / -V3-3). Slug-keyed: `F-RAW240-V3-*`.

PASS on all 5 raw 117 checks.

---

## 6. Migration path — hive raw 240 V2 → V2.1 → V2.2 → V3

Three-stage migration, each stage independently retire-able if its falsifier fires.

| Stage | Cut | Trigger | Action |
|---|---|---|---|
| **V2.1** | airgenome alone | this RFC + paired lint registered as airgenome-local; hive .raw NOT modified yet. K Docker DKLC + future airgenome filters score /420 internally. | bootstrap. landing window: 1 cycle. |
| **V2.2** | airgenome + 1 sister repo (anima recommended — highest impact per §3) | sister repo independently lands B10 in its filter rubrics; cross-repo evidence count ≥2 sister repos. | sister-repo independent adoption; PR to hive raw 240 strengthening. |
| **V3** | hive raw 240 official V3 (10-block / 420-ceiling) | hive PR merged; F-RAW240-V3-1 30d retire-if-unused check passing; ≥3 sister repos have rubric-bearing artifacts. | hive .raw entry strengthening (raw 102 STRENGTHEN-existing autonomous); paired lint upgrade to v3 (`weighted_rubric_lint.v3` recognising B10 row). |

**Recommended path (see §10): sister-repo independent adoption FIRST, hive PR SECOND.** This avoids the silent-coupling risk of hive .raw mutating before cross-repo evidence is in.

---

## 7. Test cases — 4 fixture inputs covering sub-axis (a)–(d)

Paired-lint `tool/b10_rotation_fold_lint.hexa` selftest fixtures (raw 192 atomicity):

### F1 — sub-axis (a) rotation-boundary-lossless

```
file.0 (last 80 bytes):  [2026-04-30T09:59:58.123Z][com.docker.backend.api] sta
file    (first 80 bytes): [2026-04-30T09:59:58.123Z][com.docker.backend.api] start ok
```

Expected fold: ONE line `[2026-04-30T09:59:58.123Z][com.docker.backend.api] start ok`. Verdict: PASS iff exactly one occurrence in decoded output.

### F2 — sub-axis (b) cross-rotation-dedup

```
file.0 (last line):  [2026-04-30T09:59:58.999Z][com.docker.backend.vm] heartbeat
file    (first line): [2026-04-30T09:59:58.999Z][com.docker.backend.vm] heartbeat
```

(Identical bytes — race condition during rotation.) Expected fold: ONE line. Verdict: PASS iff fnv-1a ring detects.

### F3 — sub-axis (c) clock-skew-tolerance

```
file (single rotation, 4 lines):
  [2026-04-30T10:00:00.000Z][component-a] msg-1
  [2026-04-30T10:00:00.005Z][component-b] msg-2
  [2026-04-30T10:00:00.003Z][component-c] msg-3   ← out-of-order
  [2026-04-30T10:00:00.008Z][component-d] msg-4
```

Expected fold: 4 lines, original physical order preserved (NOT timestamp-sorted). Verdict: PASS iff decoded line order matches source line order.

### F4 — sub-axis (d) cleanup-mid-encode-safety

Simulated: encoder is mid-walk, has consumed `file.8 .. file.2`. External actor calls `unlink(file.1)` (logrotate cleanup tail). Expected: encoder emits artifact with `partial=true` field in JSONL bench row, exit code 0 (PASS-with-partial verdict), no corrupt bytes in artifact. Verdict: PASS iff JSONL row contains `partial=true` AND artifact decodes cleanly.

---

## 8. Backwards compatibility

- V2 rubric (9 blocks / 400pt ceiling) remains valid for any filter where source is single-file / append-only / in-memory (counter-examples §5(4)). Such filters mark `b10: null` (or omit the field) in their JSONL companion; total scores out of 400.
- V3 rubric (10 blocks / 420pt ceiling) applies to any filter whose source is a rolling-rotation stream. Score is out of 420.
- A filter MAY declare `rubric_version: "v2"` or `rubric_version: "v3"` in its JSONL header row; absence defaults to v2 for backward compat.
- `weighted_rubric_lint` (existing hive paired-lint) gains a v3 mode that recognizes B10 rows; v2 mode unchanged.

No silent re-weight. F-RAW240-3 satisfied.

---

## 9. Hard guards / scope (this RFC)

- This file + `raw_240_v3_strengthening_2026-04-30_proposal.md` are the only artifacts written by this session.
- `/Users/ghost/core/hive/.raw` is NOT modified.
- `/Users/ghost/core/hexa-lang/.raw` is NOT modified.
- No `.hexa` code emitted (markdown only per task constraint).
- No git commits.
- English body per raw 175; Korean limited to user verbatim quotes (raw 33 carve-out) — no quotes used in this RFC.
- Self-applied raw 117 5-check at §5; raw 95 triad satisfied (advisory tier this RFC + cli-lint paired tool spec at §7 + paired-roadmap-id implicit on registration commit).

---

## 10. Application path (recommended order)

1. **(this cycle)** — RFC + V3 strengthening proposal land in `airgenome/docs/` for explicit user PR transfer. raw 102 STRENGTHEN-existing autonomous; no hive write.
2. **(cycle +1)** — airgenome registers `tool/b10_rotation_fold_lint.hexa` paired lint locally; K Docker DKLC filter is the first artifact bearing B10 row. JSONL companion `state/weighted_rubric_audit/audit.jsonl` gains B10 rows.
3. **(cycle +2 to +4)** — sister-repo independent adoption priority order: anima (harvest streams) → hive (harness logs) → n6 (cell-encoding) → nexus (kick logs) → hexa-lang (build logs).
4. **(cycle +5, after ≥3 sister repos)** — hive PR: append `strengthening 2026-04-30 weighted-rubric-perfect-score-derivation-discipline-v3` clause to raw 240 entry + bump paired lint to v3.
5. **(30d post hive PR)** — F-RAW240-V3-1 audit: count of B10 rubric-bearing artifacts ≥1 across cluster → keep; == 0 → retire B10 from V3 spec.
6. **(60d post)** — F-RAW240-V3-2 audit: V3 rubric promote rate vs V2 baseline; promote rate < V2 baseline by >20% → review.
7. **(90d post)** — F-RAW240-V3-3 audit: cross-repo adoption ≥3 sister repos confirmed → V3 considered stable; < 3 → V3 demoted to V2.5 (block stays advisory, ceiling reverts to 400).

End of RFC.
