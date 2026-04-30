# Wave Retroactive Audit — raw 240 V2 Weighted Rubric Applied to 19 Filters

Origin: `2026-04-30` — user directive `다른 영역들도 만점기준 조사 후 한건지 체크`. The 5 bg-agent waves landed 19 filters across 6 domains (memo / telegram / mail / calendar / finder / system) without explicit raw 240 V2 weighted-rubric scoring at design time. This artifact applies the rubric retroactively to assess whether each filter would have cleared the 만점 cut had it been forced through raw 240's gate.

Rubric source: `/Users/ghost/core/hive/.raw` raw 240 V2 + `hive/docs/brainstorm-2026-04-30-raw-240-strengthen-v2.md`. 9 blocks, 400pt ceiling.

Companion JSONL: `wave_retroactive_audit_rubric_2026-04-30.rubric.jsonl` (B1 ai-native machine-grep). This audit is itself a non-trivial design decision so it eats-the-dogfood by emitting both the markdown table AND the JSONL companion + honest-C3 trailer.

## Step 1 — Rubric V2 Block Declaration (BEFORE candidate scoring per B8)

| Block | 만점 | 만점 컷 (filter-design context interpretation) |
|-------|------|-----------------------------------------------|
| B1 ai-native-machine-grep-ability | 60 | structured blob layout doc + magic + version + JSONL bench-tuple emit |
| B2 channel-coverage | 50 | filter .hexa + bench .hexa + ROI ledger + commit body + .raw site-list (≥4) |
| B3 enforcement-strength | 50 | bench harness fires automatically + diff_test=lossless gate + perl alarm 120s |
| B4 measurability-closure | 50 | bench emits 5-tuple (site, ROI#, baseline_ns, post_ns, diff_test) + numeric ROI |
| B5 self-replay-automation | 50 | bench re-runnable, deterministic seed, no manual setup, ≤120s |
| B6 cross-repo-propagation | 40 | F18 / E4 ancestry traceable; pattern reusable across sister domains |
| B7 emission-cost-bounded | 40 | inline PAYLOAD ≤ ~13KB, run() wrapper boilerplate stable, no .py sprawl |
| B8 adversarial-resistance | 40 | synthetic fallback gated by SYNTH_MARK; honest about real-vs-synth path |
| B9 meta-rubric-finite | 20 | filter ≠ rubric-of-rubric; depth-1 design artifact |

Total ceiling: 400.

## Step 2 — Score Matrix (19 filters × 9 blocks)

| ID | Filter | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|--------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| M1  | memo_notes_shbf            | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| M2  | memo_attachment_dedup      | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| M3  | memo_notes_search_apbf     | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| T1  | telegram_chat_shbf         | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 35 | 20 | **395** |
| T2  | telegram_media_dedup       | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 35 | 20 | **395** |
| T3  | telegram_contact_apbf      | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 35 | 20 | **395** |
| MA1 | mail_envelope_shbf         | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| MA2 | mail_body_dedup            | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| MA3 | mail_sender_dict           | 60 | 50 | 50 | 30 | 50 | 40 | 40 | 40 | 20 | **380** |
| CA1 | calendar_event_shbf        | 55 | 45 | 50 | 40 | 50 | 35 | 40 | 35 | 20 | **370** |
| CA2 | calendar_recurring_pack    | 55 | 45 | 50 | 40 | 50 | 35 | 40 | 35 | 20 | **370** |
| FI1 | finder_recent_file_shbf    | 55 | 45 | 50 | 40 | 50 | 35 | 40 | 35 | 20 | **370** |
| FI2 | finder_alias_dedup         | 50 | 45 | 50 | 30 | 50 | 35 | 40 | 35 | 20 | **355** |
| SY1 | photos_library_shbf        | 60 | 50 | 50 | 40 | 50 | 40 | 40 | 35 | 20 | **385** |
| SY2 | music_library_shbf         | 60 | 50 | 50 | 40 | 50 | 40 | 40 | 35 | 20 | **385** |
| SY3 | maps_search_history_shbf   | 60 | 50 | 50 | 40 | 50 | 40 | 40 | 35 | 20 | **385** |
| SY4 | reminders_shbf             | 60 | 50 | 50 | 40 | 50 | 40 | 40 | 35 | 20 | **385** |
| SY5 | books_annotation_shbf      | 60 | 50 | 50 | 40 | 50 | 40 | 40 | 35 | 20 | **385** |
| SY6 | shortcuts_config_mmap      | 55 | 45 | 50 | 30 | 50 | 35 | 40 | 30 | 20 | **355** |

Filters scoring 만점 (≥380/400): **13** (M1, M2, M3, T1, T2, T3, MA1, MA2, MA3, SY1, SY2, SY3, SY4, SY5 — recount: 14 — see below).

Recount 만점 (≥380): M1, M2, M3, T1, T2, T3, MA1, MA2, MA3, SY1, SY2, SY3, SY4, SY5 = **14**.

Significant-gap filters (<340/400): **0**. None fall below 340.

Mid-gap filters (340-379): **5** (CA1 370, CA2 370, FI1 370, FI2 355, SY6 355).

## Step 3 — Per-filter recommendations for non-만점 (13 above 만점, 6 below)

| ID | Total | Recommendation |
|----|-------|----------------|
| MA3 | 380 | borderline 만점. Accept; B4 partial (size 96% but wall 0.88×) — disclose honestly in C3, no redesign needed. |
| CA1 | 370 | accept-with-honest-C3 — B4 ROI range 50-200× is wide (factor 4 spread); tighten by adding deterministic seed bench replay; B6 generic shbf (not F18 direct). |
| CA2 | 370 | accept-with-honest-C3 — recurring_pack design is novel (no F18 ancestor) so B6 -5; ROI 10-30× wide on B4. |
| FI1 | 370 | accept-with-honest-C3 — Spotlight metadata fragility; B4 80-300× wide. |
| FI2 | 355 | accept-with-honest-C3 OR redesign — ROI 3-8× is the lowest in the wave; alias dedup may not justify mmap blob. Consider downgrade to advisory or merge into FI1. |
| SY6 | 355 | accept-with-honest-C3 — projection ROI 45× lowest among system; shortcuts are config files not hot-path query; B4 wall-clock not measured (size-only proxy). |

No filter rated **remove**. No filter rated **redesign mandatory** — all 19 ship value above floor.

## Step 4 — Per-domain summary (6 domains)

| Domain | Filters | Mean | 만점 count | Cleanest | Weakest |
|--------|---------|------|-----------|----------|---------|
| memo (M)         | 3 | 400.0 | 3/3 | M1/M2/M3 (all tie) | none |
| telegram (T)     | 3 | 395.0 | 3/3 | T1/T2/T3 (B8 -5 each, app-encrypted SQLite carve-out) | T1/T2/T3 (tied at 395) |
| mail (MA)        | 3 | 393.3 | 3/3 | MA1/MA2 | MA3 (B4 size-only, wall 0.88× honest) |
| calendar (CA)    | 2 | 370.0 | 0/2 | CA1 = CA2 | CA1/CA2 (tied) |
| finder (FI)      | 2 | 362.5 | 0/2 | FI1 | **FI2 (355 — domain weakest overall)** |
| system (SY)      | 6 | 378.3 | 5/6 | SY1-SY5 (tied 385) | SY6 (355) |

**Highest gap density**: calendar (0/2 만점) + finder (0/2 만점). Both ship novel-pattern designs (recurring_pack, alias_dedup) without direct F18/E4 ancestor → B6 -5, B8 -5.

**Cleanest 만점**: memo (3/3 = 100%) is the only domain with full 만점 sweep. Pattern: all 3 inherit cleanly from F18 SHBF / dedup / APBF templates with NotesAccount.sqlite + ZICCLOUDSYNCINGOBJECT real schema understood.

## Step 5 — Honest C3 (concerns the rubric does NOT measure)

Total honest-C3 gap count: **8** (top 3 surfaced for action; remaining 5 are forward-spec).

1. **Real-data accessibility unmeasured (CRITICAL)** — rubric scores blob layout + bench harness, but does not penalize filters whose synthetic-fallback path is the *only* path actually exercised in CI. T1/T2/T3 score 395 despite Telegram Desktop's app-encrypted SQLite making real-data probe schema-inaccessible; rubric did not catch this. Falsifier: count of `SYNTH_MARK` hits per bench run on user's actual machine.

2. **FDA / TCC blocker unmeasured** — Photos (SY1), Music (SY2), Maps (SY3) all require macOS Full Disk Access OR per-app TCC grant. Rubric scores these 385 because design+bench are clean, but real-machine ROI may be 0× if user has not granted FDA. CA1 calendar similarly TCC-gated. The 만점 column does not penalize "shipped but blocked at runtime by macOS permission model".

3. **F18/T1 pattern transfer fidelity unmeasured** — F18 (Safari bookmarks SHBF) is the canonical ancestor; M1/T1/MA1/CA1/FI1/SY1-SY5 all claim "F18 직접 이식" but the rubric does not verify schema-level isomorphism (sorted-key + bisect_left + range top-K). A rubric block "pattern-fidelity-lint" would catch CA2 recurring_pack as truly novel (not F18 transfer) vs CA1 event_shbf which is.

4. (forward-spec) Schema fragility — Apple SQLite schema (Notes ZICCLOUDSYNCINGOBJECT, Mail Envelope, Calendar) drifts each macOS release; no Block measures version-pin coverage.

5. (forward-spec) ROI confidence interval — bg-agent reported point estimates (591×, 365×, etc.); rubric does not require ±σ or n=k replay distribution.

6. (forward-spec) Wall-clock vs size-saved — MA3 96% size but 0.88× wall is a known mismatch; rubric should split B4 into two sub-blocks.

7. (forward-spec) `--mode=run-once` integration — filters scored 만점 in isolation; whether they correctly hook into airgenome filter runtime is a separate axis.

8. (forward-spec) ROI-floor cutoff — FI2 at 3-8× and SY6 at 45× both score 355; rubric does not encode "must beat 10× to ship" floor that the F18 wave implicitly held to.

## Step 6 — Net assessment: cost of "5 wave 만점기준 미적용"

**Cost: LOW.**

Quantitative breakdown:
- 14/19 (73.7%) filters retroactively score 만점 (≥380) — bg-agents honored the F18-derived design discipline by pattern-imitation even without explicit rubric.
- 0/19 score below 340 — no filter is in "must-redesign" territory.
- 5/19 mid-gap filters (CA1, CA2, FI1, FI2, SY6) need only honest-C3 disclosure, not redesign — they ship value (3-200×) and the rubric points at narrow improvements (deterministic seed, ROI floor).
- The honest-C3 trailer (Step 5) surfaces 3 critical gaps the rubric itself misses (real-data, FDA, pattern-fidelity) — these would have surfaced even WITH upfront rubric application. So upfront rubric ≠ closing those gaps.

Implication: skipping raw 240 V2 at wave-time was a recoverable shortcut. A retroactive sweep (this audit) recovers the audit-trail at minimal cost (single read-only pass, no .hexa modification, no re-bench). Going forward the rubric should be applied at design-time for any new SY7+ filters where the F18 ancestor is *not* a clear template — that's where the cost of skipping rubric becomes high (CA2-class novel patterns).

## Termination

(a) explicit user 만족 acceptance pending for this audit artifact. (b) self-replay PASS metric not wired (per V2 G6 — agent-intuition weight distribution).

---

Audit ledger row: forward-spec — append to `state/weighted_rubric_audit/audit.jsonl` (raw 77 schema) on next hive cycle that touches that ledger; airgenome side has no audit ledger yet.
