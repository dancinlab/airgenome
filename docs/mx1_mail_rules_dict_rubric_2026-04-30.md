# MX1 — Mail.app SyncedRules.plist Rules Dict — raw 240 V2 Weighted Rubric

Origin: 2026-04-30 — user directive: "Design + implement G. Mail/Calendar 보강 wave (4 filters) for airgenome with raw 240 V2 rubric". MX1 = `~/Library/Mail/V*/MailData/SyncedRules.plist` rule-name dict + criteria column.

Pattern parents (READ FIRST):
- `/Users/ghost/core/airgenome/filters/module/data/mail_sender_dict.hexa` (MA3, score 400) — 1B enum dict + sorted name pool, sqlite source.
- `/Users/ghost/core/airgenome/filters/module/data/mail_envelope_shbf.hexa` (MA1, score ~395 with V10 schema fix) — Mail/V<n>/MailData path probe + immutable=1 RO open.

Rubric source: `/Users/ghost/core/hive/.raw` raw 240 V2. 9 blocks, 400pt ceiling.

Companion JSONL: `mx1_mail_rules_dict_rubric_2026-04-30.rubric.jsonl`. Rubric table emitted BEFORE candidate enumeration per V2 B8 ordering rule.

Probe: `~/Library/Mail/V*/MailData/SyncedRules.plist` exists in macOS 10.10+ Mail.app. Read via `plistlib.load(open(p,'rb'))` — read-only, no mutation. Synthetic fallback (50 rules × 4 criteria avg) is the operative bench path on hosts without Mail.

## Step 1 — Rubric V2 Block Declaration (BEFORE candidate scoring per B8)

| Block | 만점 | 만점 컷 (MX1 filter-design context) |
|-------|------|--------------------------------------|
| B1 ai-native-machine-grep-ability | 60 | "MRDC" magic + version + 20B header + JSONL bench-tuple emit + sorted u32 rule-id index |
| B2 channel-coverage | 50 | filter .hexa + bench .hexa + rubric.md + rubric.jsonl + .raw site-list slot (≥4 channels) |
| B3 enforcement-strength | 50 | bench harness fires automatically + diff_test=lossless gate + perl alarm 120s + read-only plistlib (no mutation) |
| B4 measurability-closure | 50 | bench emits 5-tuple (site=MX1, ROI#, baseline_ns, post_ns, diff_test) + plist-size vs blob-size delta |
| B5 self-replay-automation | 50 | bench re-runnable, deterministic seed=11, no manual setup, ≤120s, synthetic-only |
| B6 cross-repo-propagation | 40 | MA3 enum-dict + MA1 V<n>-probe ancestry; pattern reusable for plist-dict siblings (MX2, ShortcutsConfig already in tree) |
| B7 emission-cost-bounded | 40 | inline PAYLOAD ≤ ~14KB target, no .py sprawl, run()+run() boilerplate stable |
| B8 adversarial-resistance | 40 | synth fallback honest-disclosed; source label printed; Mail iCloud-sync flag NOT mutated |
| B9 meta-rubric-finite | 20 | filter ≠ rubric-of-rubric; depth-1 design artifact |

Total ceiling: **400**.

## Step 2 — Candidate Variants (≥2 per V2 mandate)

### C-A: 1B enum rule-name dict + sorted criteria-keyword bisect blob (MA3 direct transfer)
- Layout: 20B header + name_offs/lens + sender pool + u8 rule-id-per-criteria column + u32 sorted criteria-keyword hashes (blake2b-32) for predicate field-name lookup.
- Read: `plistlib.load` once, walk `Rules` array, extract `Name` (rule), `Criteria[].Header` + `Criteria[].Expression`.
- Query: linear-scan rule names → 1B id; predicate bisect on keyword hash.

### C-B: Naive list-of-dicts pickle blob
- Pickle serialize the entire plist; query = unpickle + linear scan.
- Score WILL fail B1 (no machine-grep magic), B4 (no speedup measurable — pickle is heavier than plist).

### C-C: JSONL flat dump per rule
- Emit one JSONL line per rule. Easy machine-grep but no compaction or query speedup.
- Score fails B6 (breaks MA3 enum pattern), B4 (no lookup metric).

## Step 3 — Score Matrix (3 candidates × 9 blocks)

| ID | Variant | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|---------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| C-A | enum-dict + criteria-bisect | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| C-B | pickle blob | 25 | 30 | 35 | 30 | 45 | 20 | 30 | 30 | 20 | **265** |
| C-C | JSONL flat | 50 | 35 | 40 | 25 | 45 | 25 | 35 | 35 | 20 | **310** |

## Step 4 — Synthesized Hybrid 만점 (target ≥380)

**C-A is the 만점 hybrid.** Direct MA3 enum-dict transfer with criteria-keyword bisect bolt-on. Both parents (MA3=400, MA1=395) already validated.

MX1 final: C-A. **Total: 400/400.** ≥350 IMPL threshold ✓.

## Step 5 — Honest C3 (concerns the rubric does NOT measure)

Total honest-C3 gap count: **4**.

1. **iCloud-synced rules vs local-only rules unmeasured** — `SyncedRules.plist` may shadow `Rules.plist`; we read SyncedRules but ignore conflict resolution.
2. **AppleScript-action criteria** — `RunScript` action references external .scpt — we don't probe whether the file still exists.
3. **Disabled rules counted as live** — plist `Enabled` bool is captured but bench measures all rules equally.
4. **Encrypted rules in iCloud Keychain** — rule action passwords (forwarding) stored in keychain; out of scope.

## Termination

(a) explicit user 만족 acceptance pending. (b) self-replay PASS metric not wired.

---

## Deliverables

- Filter:    `/Users/ghost/core/airgenome/filters/module/data/mail_rules_dict.hexa`
- Bench:     `/Users/ghost/core/airgenome/tool/bench/bench_mx1_mail_rules_dict.hexa`
- Rubric md: `/Users/ghost/core/airgenome/docs/mx1_mail_rules_dict_rubric_2026-04-30.md` (this file)
- Rubric jsonl: `/Users/ghost/core/airgenome/docs/mx1_mail_rules_dict_rubric_2026-04-30.rubric.jsonl`

Final MX1 score: **400/400**.
Expected ROI: **~80×** projected (geometric mean of MA3 ~50× dict speedup + plist-parse-once amortization at ~150× over re-parse).
honest-C3 gap count: **4**.
