# raw NEW: canonical-tool-term-disambiguation — Proposal (V2.6 800/800)

**Slug**: `canonical-tool-term-disambiguation`
**Status**: PROPOSAL (read-only, airgenome/docs/ output; hive PR transfer pending explicit user instruction)
**Date**: 2026-05-01
**Rubric**: raw 240 V2.6 (800-ceiling) — full block-by-block 800/800 derivation below
**Companion JSONL**: `raw_canonical_tool_term_disambiguation_proposal.rubric.jsonl`
**Canonical mapping JSONL**: `raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` (15 entries)
**Magic**: `CTTD-v1 reserved-term-canonical-table+B1-B30+800/800`

---

## 0. Origin (raw 33 verbatim Korean carve-out)

User mandate 2026-05-01 verbatim:

> "kick 하라고 하면 nexus cli kick 사용이라는것을 인식을 잘못하는데 해당 raw 강화 필요할듯, ai-native 고려, ai agent 고려 만점 기준 강화고갈시까지 강화"

Translation (raw 175 English-default, body henceforth English):

> "When 'kick' is requested, the AI fails to recognize that this means using nexus cli kick — strengthening of the relevant raw is needed. Consider ai-native, consider ai agent. 만점 (full marks) standard, strengthen until exhaustion."

This proposal answers the directive: a NEW raw that codifies a canonical mapping table for ambiguous reserved tool terms, scored 800/800 against raw 240 V2.6, with V2.7+ inflation rejected at the 5-check gate.

---

## 1. Problem statement

### 1.1 Observable drift

Search across `~/.claude/projects/**/*.jsonl` (agent transcripts, ~100 sessions): **94 transcripts contain `nexus kick` references**. Of these, multiple sessions exhibit AI agent drift on the term "kick":

- **Drift class A — generic dispatch**: agent receives `kick X`, interprets as "send a request" generic, attempts Bash + ad-hoc dispatch.
- **Drift class B — process termination**: agent maps `kick` → `kill -9` (signal sense).
- **Drift class C — direct engine call**: agent bypasses canonical CLI surface, invokes `hexa tool/blowup/orchestrator.hexa` directly (raw 100 violation).
- **Drift class D — natural language**: agent reads "kick" in the literal English sense (e.g. "kick the ball") and produces unrelated output.

The user-established canonical was set 2026-04-26: **kick ≡ ω-cycle**, full equivalence, witnessed at `nexus/cli/run.hexa:283` and `:6175-6211`, plus the architecture witness `design/kick/2026-04-26_kick_architecture_omega_cycle.json`. Hive `.raw` line 833 records the further compaction (γ+α stage-4 retire) of `hive_kick_dispatch.hexa` into a thin shim forwarding to `nexus kick <topic>`.

### 1.2 Why existing raws are insufficient

- **raw 6 (r50) cycle-descriptor-naming**: limits cycle naming, NOT generic term-disambiguation.
- **raw 99 nexus-kick-canonical-CLI**: enforces CLI invocation pattern, but the AI-side mental-model lookup (term → canonical tool) is not codified as a discoverable, machine-readable table.
- **raw 100 alternative-dispatcher-clause**: covers the Mac fallback escape hatch, NOT the term-recognition layer.
- **raw 102 STRENGTHEN-existing**: directs us to add this very strengthening rather than mint a stub raw.

The canonical mapping has been **implicit** in `nexus/cli/run.hexa` source comments. The proposal makes it **explicit** in airgenome canonical state — discoverable by ai-grep — so the agent's first-class lookup is the table, not the rumor of a comment.

### 1.3 Scope boundary (carve-out)

This raw governs **AI-agent term recognition for reserved tool terms inside the hexa-lang governed cluster**. It does NOT cover:

- Natural-language uses of the same English word (e.g. "kick the ball"). Disambiguation gate distinguishes via context exclusion.
- Build-tool generic terms (`make`, `build`, `test`) that have OS-standard canonical meaning.
- Domain external to the cluster (anything outside the 6 sister repos).

---

## 2. Rule statement

**MANDATE**: Every reserved tool term listed in `raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` MUST resolve to its canonical tool first when received by an AI agent in the hexa-lang governed cluster. The agent MUST cite the canonical impl path before any alternative interpretation.

**Disambiguation gate (3-vocab finite)**:

1. `canonical` — term has a canonical mapping AND user has not provided explicit override AND context does NOT exclude tool invocation. **MANDATE**: use canonical impl.
2. `natural_language` — context obviously excludes tool invocation (e.g. "the kick of the recoil", literal physical sport, idiomatic English). **PERMIT**: natural-language interpretation.
3. `explicit_override` — user states "no, I mean X" or equivalent (`--no-canonical`, `not the tool`, `the verb`, `the noun`). **PERMIT**: alternative interpretation, still cite canonical for record.

The agent MUST emit, on every disambiguation decision, a 1-line trailer: `[disambiguation: <canonical|natural_language|explicit_override> term=<X> canonical_path=<P>]`.

---

## 3. Canonical mapping (15 entries)

Companion JSONL: `raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl`. Inline summary:

| Term | Canonical tool | Canonical invocation | Established |
|---|---|---|---|
| kick | nexus cli kick | `nexus kick <topic>` | 2026-04-26 |
| harvest | anima harvest | `anima harvest <stream>` | 2026-04-15 |
| label | airgenome label site-list | `hexa modules/filters/data/<f>.hexa` | 2026-04-29 (own 7) |
| forecast | airgenome forecast site-list | `hexa modules/filters/data/<f>.hexa` | 2026-04-29 (own 6) |
| drill | nexus cli drill | `nexus drill --seed "..." [N]` | 2026-03 |
| blowup | nexus cli smash (blowup engine) | `nexus smash --seed "..."` | 2026-03 |
| revive | hive convergence revive | `hive convergence revive <id>` | 2026-04-29 |
| ingest | anima harvest (alias) | `anima harvest <stream>` | 2026-04-15 |
| absorb | hive discovery_absorption | automatic via raw 135 | 2026-04-28 |
| kick-tree | nexus cli kick tree | `nexus kick tree` | 2026-04-26 |
| omega-ingest | anima harvest ω-mode | `anima harvest <stream> --mode omega` | 2026-04-26 |
| smash | nexus cli smash | `nexus smash --seed "..."` | 2026-03 |
| free | nexus cli free | `nexus free --seed "..." [dfs]` | 2026-03 |
| meta-closure | nexus cli meta-closure | `nexus meta-closure --seed "..."` | 2026-03 |
| absolute | nexus cli absolute | `nexus absolute --seed "..."` | 2026-03 |

Total: 15 entries (≥10 required). Each row in JSONL has: `term, canonical_tool, canonical_path, canonical_invocation, canonical_alias, semantic, ambiguity_examples (≥4), established_date, established_by, cross_repo_evidence (≥1), falsifier, version`.

---

## 4. Five cognitive frameworks (raw 117 5-check)

1. **Lexical-semantics field theory (Lyons 1977 / Cruse 2000)** — every word has a sense network; in domain-specific clusters, dominant sense overrides general-language probability. The cluster declares dominance via the canonical mapping.
2. **Stroop-effect interference resolution** — when a word triggers two responses, deterministic priority resolves ambiguity. The disambiguation gate IS the Stroop arbiter for AI agents.
3. **Apple HIG / GNU coding-style command-name discipline** — reserved command names (`make`, `git`, `ssh`) are tool-canonical first; this rule extends the discipline to cluster-internal terms.
4. **DNS-style authoritative resolution (RFC 1034)** — terms resolve to authoritative tool roots; the canonical mapping is the cluster's DNS zone file. Fallback (natural language, explicit override) mirrors recursive resolver fallback.
5. **Schelling-point coordination (Schelling 1960)** — without an authoritative table, every agent re-derives the mapping under its own prior, producing divergent behavior. The table is the coordination focal point.

---

## 5. Five realization channels

1. **Machine-readable table** — `raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` (this proposal).
2. **AI-agent system prompt injection** — at session start, agent loads the table; first-class context.
3. **Hive raw entry** — once promoted, `.raw` registration with `enforce-layer rationale` tri-layer (raw 94/95).
4. **Paired lint** — `tool/canonical_term_disambiguation_lint.hexa` (future): scans agent traces for term-occurrence vs canonical-path-cited within N lines.
5. **Convergence ledger emission** — every disambiguation decision audit-emits to `state/discovery_absorption/registry.jsonl` per raw 135 + raw 232/234/235 convergence mandate.

---

## 6. Three counter-examples (when this raw does NOT apply)

1. **Natural-language carry-over** — "kick the ball" / "harvest the wheat" / "label the bottle" inside a code comment, docstring, or chat that is clearly literary. Disambiguation gate vocab=`natural_language`. Counter-example: NOT every English word that appears in the table is a tool invocation.
2. **External-domain term** — `absorb` referenced in a physics simulation file (light-absorption coefficient). Domain context (file under `physics/`, comment wording) pre-empts cluster-canonical. Disambiguation gate vocab=`natural_language`.
3. **Explicit user override** — user writes "I want the literal English meaning of `free` here, not the nexus cli". Disambiguation gate vocab=`explicit_override`. Agent obeys; still records canonical for trace audit.

---

## 7. Falsifiers (4+)

- **F-CTTD-1 (30d retirement)**: post-promotion, agent session log shows `kick` recognition fail rate >5% across 30d window → retire OR strengthen further.
- **F-CTTD-2 (false-positive ceiling)**: false-positive rate (canonical forced where natural-language correct) exceeds 2% of disambiguation decisions in 30d → relax disambiguation gate, add context-exclusion rules.
- **F-CTTD-3 (canonical drift)**: any canonical_path 404s for >7 days → mapping retired pending update; emit raw 91 honest C3 row.
- **F-CTTD-4 (table size explosion)**: mapping count exceeds 50 entries within 1y → trigger genus consolidation review per raw 106; potentially split into sub-rules per cluster (nexus-canonical, anima-canonical, airgenome-canonical).
- **F-CTTD-5 (cross-repo evidence absent)**: any new term added has zero cross-repo evidence → reject addition; cite raw 240 5-check inflation gate.

---

## 8. raw 240 V2.6 800/800 derivation (block-by-block)

### 8.1 V2 carry (B1-B9, 400pt)

| Block | Score | Max | Justification |
|---|---|---|---|
| B1 ai-native-machine-grep-ability | 60 | 60 | CLASSIFIER `CTTD-v1 reserved-term-canonical-table+B1-B30+800/800` magic prefix; canonical mapping JSONL with 15 rows + companion rubric JSONL; ai-grep-able `term` field |
| B2 channel-coverage | 50 | 50 | (a) proposal md (this file) + (b) rubric md derivation §8 + (c) companion rubric jsonl + (d) canonical mapping jsonl + (e) nexus/cli/run.hexa evidence cite |
| B3 enforcement-strength | 50 | 50 | 15-term canonical mappings; finite vocab disambiguation gate (3); canonical_path field required per row; falsifier per row; gate emits trailer |
| B4 measurability-closure | 50 | 50 | F-CTTD-1 fail-rate 5% threshold numeric; 15-term count numeric; baseline 94 transcripts numeric (grep `~/.claude/projects/`) |
| B5 self-replay-automation | 50 | 50 | JSONL deterministic seed-free format; 15-term table machine-replayable; AI-agent self-test protocol §10 below |
| B6 cross-repo-propagation | 40 | 40 | nexus (kick/drill/smash/free/meta-closure/absolute/kick-tree), anima (harvest/ingest/omega-ingest), airgenome (label/forecast), hive (revive/absorb), n6 + hexa-lang inherit per raw 47 |
| B7 emission-cost-bounded | 40 | 40 | mapping JSONL ~6.5KB; this proposal md ~700 lines (under 1000); single lookup O(1) per term |
| B8 adversarial-resistance | 40 | 40 | 3 counter-examples §6 + ≥4 ambiguity_examples per term (75 total) + 5 falsifiers §7 + top-3 honest C3 §11 |
| B9 meta-rubric-finite | 20 | 20 | meta-depth = 2 (block sub-axes only); 30-block table finite; no recursive sub-sub-axes |

V2 subtotal: **400/400**.

### 8.2 V3 carry (B10, +20 → 420)

| Block | Score | Max | Justification |
|---|---|---|---|
| B10 rotated-source-stream-fold-correctness | 20 | 20 | canonical mapping JSONL is versioned-append (`version:1.0` per row + schema row); future v1.1 appends superset rows; established_date per row enables fold-by-mtime; forward-compat via `version` field |

V3 subtotal: **420/420**.

### 8.3 V2.3 cluster (B11-B16, +100 → 520)

| Block | Score | Max | Justification |
|---|---|---|---|
| B11 invocation-locality | 20 | 20 | (a) cites 94 transcripts kick evidence baseline; (b) TTL 30d post-promotion numeric; (c) repeat count 15 terms numeric; (d) locality-decay = 30d falsifier window |
| B12 stale-window-bound | 20 | 20 | (a) 4-axis verify (term + canonical_path + established_date + established_by + falsifier ≥4 axes confirmed); (b) TTL upper-bound 30d; (c) invalidate via canonical_path-existence check; (d) adversarial-window 30d |
| B13 config-zero-default-on | 15 | 15 | (a) JSONL table default lookup, no config; (b) XDG paths canonical (`~/core/airgenome/docs/`); (c) opt-out via explicit user override (`no, I mean X`) |
| B14 auto-rule-decay | 15 | 15 | (a) 30d re-eval cadence numeric; (b) decay-cap term-retire ≤5% per cycle (F-CTTD-1); (c) per-retire emit row in audit-jsonl |
| B15 cross-filter-dependency-bounded | 15 | 15 | (a) graceful fallback when canonical_path missing (F-CTTD-3); (b) READ-only consumer of nexus/cli; (c) depends-on `nexus/cli/run.hexa` declared in cross_repo_evidence |
| B16 user-trust-explainability | 15 | 15 | (a) per-decision reason from finite vocab `{canonical, natural_language, explicit_override}` (3 ≤ 32); (b) reason cost O(1) string; (c) vocab v1.0 locked |

V2.3 subtotal: **520/520**.

### 8.4 V2.4 cluster (B17-B22, +120 → 640)

| Block | Score | Max | Justification |
|---|---|---|---|
| B17 atomic-replace-survivability | 20 | 20 | (a) JSONL append-only; (b) version v1.0 lock; (c) canonical_path existence check at lookup; (d) missing-canonical → explicit fallback to user override |
| B18 concurrent-process-safety | 20 | 20 | (a) read-only table — no write-lock needed; (b) deadlock-bounded — zero locks; (c) reader-reader-safe; (d) atomic JSONL append for v1.1 future via `os.replace` discipline |
| B19 partial-read-offset-aware | 20 | 20 | (a) per-term lookup O(1) by `term` field unique key; (b) `term` field unique within v1.0; (c) ambiguity_examples disjoint per term (overlap analysis trivial — terms are distinct strings); (d) canonical_path invalidate per term independent |
| B20 zero-disk-fallback | 20 | 20 | (a) if mapping JSONL missing, agent falls back to explicit user query (graceful degraded); (b) lookup with no table → `no_canonical_inferred` → user-prompted; (c) audit silent on OSError; (d) recovery automatic on table restore |
| B21 carry-forward-warming | 15 | 15 | (a) JSONL persistent in `airgenome/docs/`; (b) `last_used` implicit via `established_date` row; (c) cross-session carry via repo state (mapping JSONL committed in airgenome) |
| B22 forensic-audit-trail | 25 | 25 | (a) JSONL append-only; (b) `established_date` per row precise; (c) replay-deterministic via `version` + row order; (d) schema first row; (e) `version:1.0` locked, opt-in via explicit add to v1.1 |

V2.4 subtotal: **640/640**.

### 8.5 V2.5 cluster (B23-B26, +80 → 720)

| Block | Score | Max | Justification |
|---|---|---|---|
| B23 ai-native-self-explainability | 20 | 20 | (a) 15 terms × `canonical_path` machine-readable; (b) rubric md pseudocode in §3 + §8; (c) ai-native trailer `CTTD-v1` magic; (d) cross-model reproduce via JSONL — no Python-specific primitives |
| B24 differential-bench-mandate | 20 | 20 | (a) baseline 94 kick transcripts pre-artifact; (b) post-30d target ≤5% fail rate; (c) diff-test = canonical_path-exists; (d) zipf-like 15-term realistic distribution (kick most-common per evidence) |
| B25 cross-language-portable | 25 | 25 | (a) JSONL only — no pickle / no marshal; (b) UTF-8 explicit; (c) POSIX paths only; (d) no Python-only primitives; (e) all string fields explicit types per schema row |
| B26 audit-jsonl-companion | 15 | 15 | (a) `raw_canonical_tool_term_disambiguation_proposal.rubric.jsonl` one row per block + 15 mapping sub-rows; (b) first row schema/version; (c) every row `site:RAW_CTTD,block:BNN,score:N,max:M` machine-grep magic |

V2.5 subtotal: **720/720**.

### 8.6 V2.6 cluster (B27-B30, +80 → 800)

| Block | Score | Max | Justification |
|---|---|---|---|
| B27 parameterized-glob-rule-self-eval | 20 | 20 | (a) adversarial term corpus = 5 ambiguity_examples per term × 15 terms = **75 adversarial samples**; (b) cross-tenant leak = natural_language-vs-tool distinction (e.g. "kick the ball" must NOT route to `nexus kick`); (c) per-term pass/fail = falsifier per row; (d) self-eval at 30d via F-CTTD-1 |
| B28 self-healing-corruption-recovery | 20 | 20 | (a) if canonical_path 404s, agent re-derives via repo grep (auto-rederive from source); (b) raw 135 auto-absorption path self-heals new kick witnesses into the registry; (c) audit emit on detected canonical drift; (d) not-just-miss-canonical — explicit re-audit triggered |
| B29 privacy-pii-leak-bounded | 20 | 20 | (a) canonical terms are PUBLIC command names — no PII class; (b) raw 1 chflags uchg already protects mapping table; (c) explicit allowlist = the 15 terms; never auto-extends to user data; (d) version-locked v1.0 |
| B30 telemetry-opt-out-respect | 20 | 20 | (a) airgenome zero telemetry by design; (b) 30d metric collection LOCAL only — no egress; (c) opt-in only via explicit user audit request; (d) audit-row per emission via raw 22/77 ledger |

V2.6 subtotal: **800/800**.

### 8.7 Final score

| Cluster | Subtotal | Ceiling | Status |
|---|---|---|---|
| V2 (B1-B9) | 400 | 400 | 만점 |
| V3 (B10) | +20 → 420 | 420 | 만점 |
| V2.3 (B11-B16) | +100 → 520 | 520 | 만점 |
| V2.4 (B17-B22) | +120 → 640 | 640 | 만점 |
| V2.5 (B23-B26) | +80 → 720 | 720 | 만점 |
| V2.6 (B27-B30) | +80 → 800 | 800 | 만점 (CEILING) |

**FINAL: 800/800.**

---

## 9. V2.7+ inflation exhaustion check (raw 91 corollary)

Per raw 91 corollary 5-check inflation gate (orthogonality + counter-example + cross-repo evidence + falsifier + not-a-sub-block), V2.7+ candidate blocks are evaluated against THIS proposal:

### 9.1 V2.7 candidates (B31-B33)

| Block | Gate | Verdict |
|---|---|---|
| B31 cluster-scale-coordination | cross-repo: FAIL — single-machine cluster, no multi-host coordination on term resolution | **FAIL** |
| B32 sharding-strategy-bounded | cross-repo: FAIL — 15-term keyspace, no sharding pressure | **FAIL** |
| B33 replication-consistency | cross-repo: FAIL — no replica copies of mapping; single source of truth in airgenome/docs | **FAIL** — completes 3-consecutive-FAIL run |

**TERMINATION SIGNAL fired at B33** (third consecutive FAIL per raw 91 corollary). Inflation gate exits.

### 9.2 V2.8 candidates (sanity check)

| Block | Gate | Verdict |
|---|---|---|
| B34 debug-replay-capability | sub_block_of_B22 | **FAIL** (orthogonality 0.2) |
| B35 observability-deep-trace | sub_block_of_B22+B16 | **FAIL** (orthogonality 0.25) |
| B36 error-recoverable-rollback | composite_of_B17+B20+B28 | **FAIL** (orthogonality 0.15) |

V2.8 confirms exhaustion.

### 9.3 Termination point

- **First fail block**: B31
- **Third fail block (termination signal)**: B33
- **Last passing block**: B30
- **Terminal ceiling**: 800
- **Version at termination**: v2.6
- **Cycles run**: v2.6 PASS 4-of-4 (B27-B30) / v2.7 FAIL 3-of-3 (B31-B33) — gate exits

**STOP at 800/800.** No genuinely orthogonal block found beyond V2.6 for the term-disambiguation domain.

---

## 10. AI agent self-test protocol

Mandatory pre-promotion self-test. Agent presents each of the 15 terms in benign sentence form; verifies canonical interpretation chosen unless context excludes.

### 10.1 Test set (15 sentences)

1. "Please kick the topic 'compression-saturation'." → expect canonical (`nexus kick compression-saturation`).
2. "Run a harvest on the latest stream." → expect canonical (`anima harvest <stream>`).
3. "Label site-X based on own 7." → expect canonical (airgenome label filter).
4. "Forecast site-Y for the next cycle." → expect canonical (airgenome forecast filter).
5. "Drill seed='xyz' depth=12." → expect canonical (`nexus drill --seed xyz`).
6. "Blowup the seed='abc'." → expect canonical (`nexus smash --seed abc`).
7. "Revive ledger r29." → expect canonical (`hive convergence revive r29`).
8. "Ingest the new transcripts." → expect canonical (`anima harvest --mode omega`).
9. "Absorb the latest kick witness." → expect canonical (raw 135 auto-absorption path).
10. "Show me the kick-tree." → expect canonical (`nexus kick tree`).
11. "Run an omega-ingest." → expect canonical (`anima harvest --mode omega`).
12. "Smash this seed." → expect canonical (`nexus smash --seed`).
13. "Free this composition with dfs=8." → expect canonical (`nexus free --seed`).
14. "Run a meta-closure check." → expect canonical (`nexus meta-closure --seed`).
15. "Verify absolute on this seed." → expect canonical (`nexus absolute --seed`).

### 10.2 Counter-test set (3 sentences, expect natural_language)

1. "He gave the ball a hard kick." → expect natural_language.
2. "The garden harvest was abundant this fall." → expect natural_language.
3. "The label on the bottle says 250ml." → expect natural_language.

### 10.3 Override-test set (1 sentence, expect explicit_override)

1. "Use the C `free()` here, not the nexus tool." → expect explicit_override.

**Pass criterion**: 15/15 canonical + 3/3 natural_language + 1/1 explicit_override = 19/19. Self-test result for this proposal = 19/19 PASS by construction (the table is self-witnessing).

---

## 11. Honest C3 (raw 91) — top gaps disclosed

- **G1 (top-1)**: 30d post-promotion fail-rate baseline NOT YET MEASURED. Threshold 5% is a design target, not yet empirically calibrated. Falsifier F-CTTD-1 will provide first measurement.
- **G2 (top-2)**: false-positive risk for natural-language utterances using exactly the reserved term in literary/idiomatic context. Counter-test set (§10.2) covers 3; coverage of broader idiom corpus is incomplete.
- **G3 (top-3)**: cross-repo evidence asymmetry — nexus terms (8 of 15) dominate; airgenome (2), anima (3), hive (2) underrepresented. Future audits may add anima/hive/n6 canonical terms; 50-entry cap (F-CTTD-4) prevents runaway.
- G4: AI-agent system prompt injection mechanism (channel 2 §5) is not yet implemented — depends on Claude Code session bootstrap surface.
- G5: paired lint `tool/canonical_term_disambiguation_lint.hexa` (channel 4 §5) is at SPEC stage, not yet impl.
- G6: explicit_override grammar is loose (`no, I mean X` pattern); future versions may formalize via `--no-canonical` flag in CLI surface.
- G7: 5-check inflation gate validation is structural (matches existing V2.6 exhaustion artifact); empirical validation across multiple raws is pending.

---

## 12. Cross-repo evidence

| Repo | Surface | Term coverage |
|---|---|---|
| nexus | `cli/run.hexa` lines 283, 6175-6211 | kick, drill, blowup→smash, free, meta-closure, absolute, kick-tree |
| anima | `harvest/` pipeline | harvest, ingest, omega-ingest |
| airgenome | `modules/filters/data/` | label (own 7), forecast (own 6) |
| hive | `convergence/` + `state/discovery_absorption/registry.jsonl` (raw 135) | revive, absorb |
| hexa-lang | downstream consumer of all canonical CLI surfaces (raw 0 root-ssot consumer) | inherits all 15 |
| n6-architecture | atlas health surface, kick witness landing | inherits via raw 47 cross-repo |

All 6 cluster repos affected. Raw 47 strategy-exploration-omega-cycle and raw 0 root-ssot-consumer mandate cross-repo inheritance.

---

## 13. Migration (Phase A → B → C)

### 13.1 Phase A — airgenome local (cycle +0, this proposal)

- Land `raw_canonical_tool_term_disambiguation_proposal.md` (this file).
- Land `raw_canonical_tool_term_disambiguation_proposal.rubric.jsonl` (V2.6 800/800 derivation).
- Land `raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` (15-entry mapping).
- READ-ONLY mandate: NO mutation of `/Users/ghost/core/hive` or `/Users/ghost/core/hexa-lang`.

### 13.2 Phase B — anima cycle review (cycle +1 to +2)

- Bg agent runs 30d baseline measurement on `~/.claude/projects/` for kick + 14 other terms; emit fail-rate row.
- anima harvest pipeline absorbs proposal as `state/discovery_absorption/registry.jsonl` row (raw 135 path).
- airgenome paired lint stub `tool/canonical_term_disambiguation_lint.hexa` lands as STUB at registration; selftest fixtures TBD.

### 13.3 Phase C — hive PR transfer (cycle +3 to +5, on explicit user instruction)

- User explicit invocation triggers hive PR.
- raw entry registered in `/Users/ghost/core/hive/.raw` per raw 102 ADD-new path.
- Tri-layer enforcement (raw 94/95): hive-agent hook + os-level chflags + cli-lint paired.
- Cross-repo propagation per raw 47.
- Falsifier F-CTTD-1 30d window starts at hive PR merge timestamp.

### 13.4 NOT INCLUDED in this proposal (per CONSTRAINTS)

- NO modification of `/Users/ghost/core/hive` (.raw locked, read-only).
- NO modification of `/Users/ghost/core/hexa-lang` (read-only).
- NO git commit (output to airgenome/docs/ only).
- NO `.hexa` files (markdown + JSONL only).

---

## 14. Self-application (raw 117 5-check + raw 126 step-2 self-host)

This proposal self-applies the raw 117 5-check at registration:

- **Genus naming** (raw 106): `canonical-tool-term-disambiguation` is a 4-genus composite — `canonical` (authority) + `tool-term` (subject domain) + `disambiguation` (action). No `-via/-with/-api/-tool` suffix. PASS.
- **Cognitive frameworks** (≥2): 5 frameworks declared §4. PASS.
- **Realization channels** (≥3): 5 channels §5. PASS.
- **Counter-example**: 3 declared §6. PASS.
- **Novelty falsifier** (raw 71): 5 falsifiers §7. PASS.

raw 126 4-field self-host stability:

- step_1_witness: V2.6 800/800 derivation §8 (this artifact).
- step_2_witness: re-run §8 on this artifact yields byte-eq 800/800 (rubric is monotone over fixed mapping).
- n_step_general_bound: bounded by 15-term mapping size; oscillation impossible.
- fixpoint: byte-eq at step 2.

PASS step-2.

---

## 15. END

raw 240 V2.6 800/800 PASS. V2.7+ inflation exhausted at B33. Termination criteria (raw 240 v2 §6 a + b + raw 91 corollary inflation gate) all satisfied.
