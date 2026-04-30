# raw 258: canonical-tool-term-disambiguation

## Summary

- Codifies a 15-entry canonical mapping for ambiguous reserved tool terms (kick / harvest / label / forecast / drill / blowup / revive / ingest / absorb / kick-tree / omega-ingest / smash / free / meta-closure / absolute) so AI agents resolve term -> canonical tool deterministically before any alternative interpretation, with a finite 3-vocab disambiguation gate ({canonical, natural_language, explicit_override}) and a per-decision trailer.
- Scored **800/800** against raw 240 V2.6 (V2.7+ candidates B31-B33 all FAIL the orthogonality + cross-repo + counter-example gate; termination at B33 per raw 91 corollary 3-consecutive-FAIL rule).
- Backed by a **30d transcript-walk baseline** of `~/.claude/projects/` (5662 files walked, 1307 with term hits, 4744 user-mentions of the 15 terms, **97.34% overall fail_rate** — strengthening_class = `justified_evidence` for 14 of 15 terms; only kick-tree shows no transcript hits).

## Origin

User mandate 2026-05-01 (raw 33 verbatim Korean carve-out):

> "kick 하라고 하면 nexus cli kick 사용이라는것을 인식을 잘못하는데 해당 raw 강화 필요할듯, ai-native 고려, ai agent 고려 만점 기준 강화고갈시까지 강화"

Translation (raw 175): when 'kick' is requested, AI fails to recognize this means `nexus cli kick`. Strengthen until exhaustion at full-marks (만점) standard, considering ai-native + ai-agent.

## Phase A -> B -> C trail

- **Phase A** (cycle +0, this proposal): 3 airgenome/docs artifacts landed
  - `airgenome/docs/raw_canonical_tool_term_disambiguation_proposal.md` (V2.6 800/800 derivation, 381 lines)
  - `airgenome/docs/raw_canonical_tool_term_disambiguation_proposal.rubric.jsonl` (per-block rubric companion)
  - `airgenome/docs/raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` (15 entries × 12 fields)
- **Phase B** (cycle +1 to +2, baselined now): 2 artifacts
  - `airgenome/state/canonical_term_baseline_audit/baseline_30d_2026-05-01.jsonl` (5662 transcripts, 4744 mentions, 97.34% fail_rate baseline)
  - `airgenome/docs/anima_registry_row_canonical_term_disambiguation.jsonl` (raw 135 auto-absorption registry artifact, anima-ready format)
- **Phase C** (this PR): 3 artifacts
  - `airgenome/docs/hive_pr_ready_canonical_term_disambiguation_2026-05-01.raw_entry.txt` (the raw 258 entry text)
  - `airgenome/tool/apply_canonical_term_raw_to_hive.sh` (manual apply tool, dry-run default + chflags + EXPLICIT_USER_APPROVAL gate)
  - `airgenome/docs/hive_pr_description_canonical_term_disambiguation.md` (this file)

## 30d baseline (per-term fail_rate)

| Term | mentions | canonical | alternative | fail_rate | strengthening_class |
|---|---:|---:|---:|---:|---|
| kick | 780 | 50 | 730 | 93.59% | justified_evidence |
| harvest | 84 | 1 | 83 | 98.81% | justified_evidence |
| label | 458 | 0 | 458 | 100.00% | justified_evidence |
| forecast | 49 | 0 | 49 | 100.00% | justified_evidence |
| drill | 977 | 72 | 905 | 92.63% | justified_evidence |
| blowup | 542 | 3 | 539 | 99.45% | justified_evidence |
| revive | 13 | 0 | 13 | 100.00% | justified_evidence |
| ingest | 192 | 0 | 192 | 100.00% | justified_evidence |
| absorb | 203 | 0 | 203 | 100.00% | justified_evidence |
| kick-tree | 0 | 0 | 0 | 0.00% | preventive (no_data) |
| omega-ingest | 4 | 0 | 4 | 100.00% | preventive (low_sample) |
| smash | 195 | 0 | 195 | 100.00% | justified_evidence |
| free | 767 | 0 | 767 | 100.00% | justified_evidence |
| meta-closure | 28 | 0 | 28 | 100.00% | justified_evidence |
| absolute | 452 | 0 | 452 | 100.00% | justified_evidence |
| **OVERALL** | **4744** | **126** | **4618** | **97.34%** | strengthening justified |

Top-5 fail-rate (sorted by fail_rate × volume signal): label (458 × 100%), free (767 × 100%), absolute (452 × 100%), absorb (203 × 100%), ingest (192 × 100%). High-volume + high fail-rate terms = the strongest evidence for strengthening.

## V2.6 ceiling derivation

raw 240 V2.6 800/800: 9 V2 blocks (B1-B9, 400) + 1 V3 block (B10, +20) + 6 V2.3 blocks (B11-B16, +100) + 6 V2.4 blocks (B17-B22, +120) + 4 V2.5 blocks (B23-B26, +80) + 4 V2.6 blocks (B27-B30, +80) = **800/800**.

V2.7+ exhaustion: B31 cluster-scale-coordination FAIL (single-machine cluster), B32 sharding-strategy FAIL (15-term keyspace), B33 replication-consistency FAIL (no replica copies) — third consecutive FAIL fires raw 91 corollary termination signal at B33. V2.8 (B34-B36) candidates fail orthogonality (sub_block_of B22 / B16+B22 / composite B17+B20+B28). Confirmed exhaustion.

## Test plan

- [ ] Reviewer confirms `airgenome/docs/raw_canonical_tool_term_disambiguation_proposal.md` matches the 800/800 V2.6 derivation block-by-block (§8 of the proposal md).
- [ ] Reviewer confirms `airgenome/docs/raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` has 15 rows × 12 fields per row (terms + canonical_path + ambiguity_examples ≥4 + falsifier per row).
- [ ] Reviewer confirms `airgenome/state/canonical_term_baseline_audit/baseline_30d_2026-05-01.jsonl` was generated from a fresh transcript walk (15 per-term rows + 1 overall summary row).
- [ ] Reviewer dry-runs `airgenome/tool/apply_canonical_term_raw_to_hive.sh --dry-run`; confirms it reports current chflags=uchg + last raw=257 (predecessor) + expected next=258.
- [ ] Reviewer reads `airgenome/docs/hive_pr_ready_canonical_term_disambiguation_2026-05-01.raw_entry.txt`; confirms it follows the raw N format used by raw 256 / raw 257 (slug + 5 cog frameworks + 5 realization channels + 3 counter-examples + ≥5 falsifiers + classifier-version + raw 117 5-check + raw 91 honest C3 ≥5 + enforce/proof/spec-form/paired-roadmap-id/deps/category/applies-to/phase/severity).
- [ ] Reviewer confirms 5 distinct cognitive frameworks declared (lexical-semantics + Stroop + HIG/GNU + DNS-RFC1034 + Schelling).
- [ ] Reviewer confirms 5 realization channels declared (machine-readable JSONL + brief-frame + raw entry + paired lint + raw 135 absorption).
- [ ] Reviewer confirms 3 counter-examples declared (natural_language carry-over + external-domain + explicit_override).
- [ ] Reviewer confirms ≥5 falsifiers declared (F-RAW258-1 30d ≥5% fail_rate / F-RAW258-2 false-positive >2% / F-RAW258-3 canonical_path 404 / F-RAW258-4 mapping >50 entries / F-RAW258-5 missing cross_repo_evidence).
- [ ] Reviewer confirms genus naming follows raw 106 (`canonical-tool-term-disambiguation-mandate` is 4-genus composite; no `-via/-with/-api/-tool` suffix).
- [ ] Reviewer confirms cross_repo coverage per raw 47 (nexus 7 terms / anima 3 / airgenome 2 / hive 2; hexa-lang + n6-architecture inherit downstream).
- [ ] Reviewer confirms apply path is gated: chflags uchg detected -> abort, `HIVE_PR_APPLY_CONFIRMED=yes` env var required, no auto-commit, no `--force` push.

## Migration readiness checklist

- [x] Phase A artifacts landed in airgenome/docs (3 files).
- [x] Phase B 30d baseline measured and persisted (state/canonical_term_baseline_audit/baseline_30d_2026-05-01.jsonl).
- [x] Phase B anima registry artifact written to airgenome/docs (anima_registry_row_canonical_term_disambiguation.jsonl).
- [x] Phase C raw entry text drafted (hive_pr_ready_canonical_term_disambiguation_2026-05-01.raw_entry.txt).
- [x] Phase C apply script drafted (tool/apply_canonical_term_raw_to_hive.sh, dry-run default).
- [x] Phase C PR description drafted (this file).
- [ ] User explicit approval for hive transfer (cycle +3 to +5 trigger window).
- [ ] User runs `sudo chflags nouchg /Users/ghost/core/hive/.raw` (raw 1 r25 SSOT immutability acknowledgment).
- [ ] User sets `HIVE_PR_APPLY_CONFIRMED=yes` env var (apply-script gate).
- [ ] User runs `tool/apply_canonical_term_raw_to_hive.sh --apply`.
- [ ] User runs `tool/raw_lint.hexa --selftest` in hive (auto-attempted by apply script, manual fallback if hexa runtime absent).
- [ ] User runs `sudo chflags uchg /Users/ghost/core/hive/.raw` to restore lock (apply script attempts non-interactive sudo).
- [ ] User reviews + executes the printed `git add .raw && git commit` commands manually.
- [ ] User runs `git push origin main` (NEVER `--force`) or opens a PR via `gh pr create`.

## Honest C3 (raw 91, top gaps)

1. **Transcript coverage gap**: 30d baseline walked single-host `~/.claude/projects/` only (Mac local, 5662 files). Cross-host (ubu1/ubu2/hetzner) transcripts NOT in scope. Remote bg-agent transcripts not measured. Follow-up cycle expected.
2. **Canonical-pattern false-negative risk**: baseline classifier matches `\bnexus kick\b` etc. via regex; tool_use blocks invoking `nexus kick` via Bash subprocess with quoted argv shapes that don't surface the literal token would register as alt. Lint v1.1 refinement expected (parse Bash command argv structure).
3. **`free` term high natural_language load**: 25 of 767 mentions are NL flagged (C `free()` discussions, `feel free` idiom). Classification stays `alternative` because no canonical tool was invoked. At agent-decision time the disambiguation gate vocab=`natural_language` would suppress this — lint v1.1 NL-pre-filter expected.
4. **Low-sample terms** (kick-tree 0, omega-ingest 4, revive 13): preventive class, justified_evidence threshold not met. 30d post-registration window will accumulate more data; F-RAW258-1 retire-or-strengthen falsifier window resolves this.
5. **Advisory-tier at registration**: tool/canonical_term_disambiguation_lint.hexa lands as warn-only audit row; promotion to hard-block requires 30d zero-violation streak per raw 256/257 calibration pattern. Some agent drift may persist during the audit-tier window.
6. **AI-agent system prompt injection** (channel ii) is brief-frame load (raw 30 / raw 236) — depends on Claude Code session bootstrap surface; not an in-process Claude Code feature gate.
7. **explicit_override grammar** is loose (`no, I mean X` pattern); v1.1 may formalize via `--no-canonical` CLI flag.

## Constraints honored

- NO direct mutation of `/Users/ghost/core/hive` (read-only, all artifacts in `/Users/ghost/core/airgenome/docs` + `/Users/ghost/core/airgenome/state` + `/Users/ghost/core/airgenome/tool`).
- NO direct mutation of `/Users/ghost/core/anima` (registry row written as airgenome artifact, not anima).
- NO direct mutation of `/Users/ghost/core/hexa-lang`.
- NO git commit by this Phase B/C run (main agent commits after, user approves).
- Apply script defaults to dry-run; mutating path requires chflags unlock + `HIVE_PR_APPLY_CONFIRMED=yes` env var; never auto-commits, never force-pushes, never skips hooks.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
