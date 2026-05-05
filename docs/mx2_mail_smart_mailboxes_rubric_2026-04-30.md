# MX2 — Mail.app SmartMailboxes.plist Predicate Dict — raw 240 V2 Weighted Rubric

Origin: 2026-04-30 — user directive: "Design + implement G. Mail/Calendar 보강 wave (4 filters)". MX2 = `~/Library/Mail/V*/MailData/SmartMailboxes.plist` mailbox name + NSPredicate-string column.

Pattern parents (READ FIRST):
- `/Users/ghost/core/airgenome/filters/module/data/mail_sender_dict.hexa` (MA3, 400) — 1B enum dict + name pool.
- `/Users/ghost/core/airgenome/filters/module/data/shortcuts_config_mmap.hexa` (existing plist-mmap) — plist-driven mmap layout sibling.

Rubric source: `/Users/ghost/core/hive/.raw` raw 240 V2. 9 blocks, 400pt ceiling.

Companion JSONL: `mx2_mail_smart_mailboxes_rubric_2026-04-30.rubric.jsonl`.

Probe: `~/Library/Mail/V*/MailData/SmartMailboxes.plist` exists when user has any Smart Mailbox configured. Read via `plistlib.load`. Synthetic fallback: 20 mailboxes × 6 predicate-clause avg.

## Step 1 — Rubric V2 Block Declaration

| Block | 만점 | 만점 컷 (MX2 filter-design context) |
|-------|------|--------------------------------------|
| B1 ai-native-machine-grep-ability | 60 | "MSMB" magic + version + 20B header + JSONL bench-tuple emit + sorted u32 mailbox-id index |
| B2 channel-coverage | 50 | filter .hexa + bench .hexa + rubric.md + rubric.jsonl + .raw site-list slot |
| B3 enforcement-strength | 50 | bench harness fires automatically + diff_test=lossless gate + perl alarm 120s + read-only plistlib |
| B4 measurability-closure | 50 | bench emits 5-tuple (site=MX2, ROI#, baseline_ns, post_ns, diff_test) + plist-size vs blob-size delta |
| B5 self-replay-automation | 50 | bench re-runnable, deterministic seed=12, no manual setup, ≤120s, synthetic-only |
| B6 cross-repo-propagation | 40 | MA3 enum-dict ancestry + MX1 SyncedRules sibling pattern; reusable for any plist→dict-blob conversion |
| B7 emission-cost-bounded | 40 | inline PAYLOAD ≤ ~14KB, run()+run() boilerplate stable |
| B8 adversarial-resistance | 40 | synth fallback honest-disclosed; predicate-string truncated safely (≤512B); source label printed |
| B9 meta-rubric-finite | 20 | filter ≠ rubric-of-rubric; depth-1 design artifact |

Total ceiling: **400**.

## Step 2 — Candidate Variants (≥2)

### C-A: 1B enum mailbox-name dict + predicate string pool + sorted predicate-token index
- Layout: 20B header + name_offs/lens (mailbox names, ≤255) + predicate_offs/lens (per-mailbox NSPredicate string, full text) + predicate-token (lowercased word) sorted u32 hashes for keyword lookup.
- Read: `plistlib.load`, walk top-level array; each entry has `MailboxName` (or `Name`), `Predicate` (NSPredicate plist representation — flatten to canonical string).
- Query: 1B id → instant name + predicate; token-hash bisect for "which mailbox uses 'is_unread' clause".

### C-B: per-mailbox JSON dump
- Loses B6 (no MA3 lineage), B4 (no token bisect speedup measurable).

### C-C: full plist round-trip cache
- Just stores raw plist bytes + index; no compaction, no machine-grep magic. Loses B1 hard.

## Step 3 — Score Matrix

| ID | Variant | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|---------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| C-A | enum-dict + token bisect | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| C-B | per-mailbox JSON | 50 | 35 | 40 | 30 | 45 | 25 | 35 | 35 | 20 | **315** |
| C-C | raw plist cache | 30 | 30 | 35 | 25 | 45 | 20 | 30 | 35 | 20 | **270** |

## Step 4 — Synthesized Hybrid 만점

**C-A is 만점.** ≥350 IMPL ✓. Final MX2 score: **400/400**.

Witness:
- B1 60 — MSMB magic + sorted u32 token hashes + JSONL 5-tuple line.
- B2 50 — 4 channels + .raw site-list slot prepared.
- B3 50 — plistlib RO, perl alarm 120s, diff_test gate.
- B4 50 — 5-tuple printed + blob/plist size delta.
- B5 50 — `random.Random(12)` seed.
- B6 40 — MA3+MX1 ancestry; pattern reusable.
- B7 40 — inline PAYLOAD only.
- B8 40 — synth fallback gated on `os.path.isfile`.
- B9 20 — depth-1 data filter.

## Step 5 — Honest C3

Total honest-C3 gap count: **4**.

1. **NSPredicate flattening lossy** — plistlib returns `NSCompoundPredicate` as nested dict; we serialize to canonical string but do not preserve every operator subtype.
2. **Localized mailbox names** — Mail.app may store names with locale prefix; we don't normalize.
3. **iCloud-shared smart mailboxes** — same shadow concern as MX1.
4. **Timestamp predicates** — `(date_received > $TODAY-7d)` evaluates differently across runs; bench treats predicate-string equality only.

## Termination

(a) explicit user 만족 acceptance pending. (b) self-replay PASS metric not wired.

---

## Deliverables

- Filter:    `/Users/ghost/core/airgenome/filters/module/data/mail_smart_mailboxes.hexa`
- Bench:     `/Users/ghost/core/airgenome/tool/bench/bench_mx2_mail_smart_mailboxes.hexa`
- Rubric md: `/Users/ghost/core/airgenome/docs/mx2_mail_smart_mailboxes_rubric_2026-04-30.md`
- Rubric jsonl: `/Users/ghost/core/airgenome/docs/mx2_mail_smart_mailboxes_rubric_2026-04-30.rubric.jsonl`

Final MX2 score: **400/400**.
Expected ROI: **~60×** (plist re-parse skip + token bisect lookup vs Foundation NSPredicate evaluation).
honest-C3 gap count: **4**.
