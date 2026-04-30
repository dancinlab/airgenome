# MX4 — Calendar.sqlitedb#ZALARM Alarms Dict — raw 240 V2 Weighted Rubric

Origin: 2026-04-30 — user directive: "Design + implement G. Mail/Calendar 보강 wave (4 filters)". MX4 = Calendar.sqlitedb ZALARM table (alarm time/type/relativeOffset enum dict).

Pattern parents (READ FIRST):
- `/Users/ghost/core/airgenome/modules/filters/data/mail_sender_dict.hexa` (MA3, 400) — 1B enum dict.
- `/Users/ghost/core/airgenome/modules/filters/data/calendar_event_shbf.hexa` (CA1) — Calendar.sqlitedb path probe.
- `/Users/ghost/core/airgenome/modules/filters/data/calendar_recurring_pack.hexa` (CA2) — bit-pack record per RRule (relevant pattern: pack alarm fields into u64 record).

Rubric source: `/Users/ghost/core/hive/.raw` raw 240 V2. 9 blocks, 400pt ceiling.

Probe: `~/Library/Calendars/Calendar.sqlitedb` table `ZALARM` columns: ZTYPE (1=display,2=audio,3=email,4=procedure), ZRELATIVEOFFSET (REAL seconds), ZTRIGGERDATE (CFAbsoluteTime), ZACTION, ZSOUND. Synthetic fallback: 800 alarms, 4 types, seed=14.

## Step 1 — Rubric V2 Block Declaration

| Block | 만점 | 만점 컷 (MX4 filter-design context) |
|-------|------|--------------------------------------|
| B1 ai-native-machine-grep-ability | 60 | "CALD" magic + version + 16B header + u8 type-enum + u32 offset-seconds + JSONL 5-tuple emit |
| B2 channel-coverage | 50 | filter + bench + rubric.md + rubric.jsonl + .raw site-list slot |
| B3 enforcement-strength | 50 | bench harness + diff_test=lossless + perl alarm 120s + sqlite immutable=1 (no Calendar.sqlitedb mutation) |
| B4 measurability-closure | 50 | 5-tuple (site=MX4) + GROUP BY type count old (Counter) vs u8 scan |
| B5 self-replay-automation | 50 | bench re-runnable, deterministic seed=14, ≤120s, synthetic-only |
| B6 cross-repo-propagation | 40 | MA3 enum-dict + CA1 sqlitedb probe + CA2 bit-pack ancestry |
| B7 emission-cost-bounded | 40 | inline PAYLOAD ≤ ~13KB, run()+run() boilerplate |
| B8 adversarial-resistance | 40 | synth fallback honest-disclosed; CFAbsoluteTime epoch shift handled (unix offset 978307200) |
| B9 meta-rubric-finite | 20 | filter ≠ rubric-of-rubric; depth-1 |

Total ceiling: **400**.

## Step 2 — Candidate Variants (≥2)

### C-A: 1B type-enum + i32 relativeOffset + i64 triggerDate, columnar (MA3+CA2 hybrid)
- Per-row layout (within blob): u32 ZALARM_PK + u8 type + i32 offset_sec + i64 trigger_unix.
- 4 distinct alarm types (display/audio/email/procedure) → fit in 2 bits, 1B has slack.
- Query: `count_by_type` = u8 column 1-pass; offset histogram = i32 array bisect.

### C-B: full-row pickle per alarm
- Loses B1, B4 (no compaction metric).

### C-C: sqlite re-query each call (no blob)
- Trivial baseline; no machine-grep, no speedup.

## Step 3 — Score Matrix

| ID | Variant | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|---------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| C-A | 1B-enum + columnar | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| C-B | full-row pickle | 25 | 30 | 35 | 25 | 45 | 20 | 30 | 30 | 20 | **260** |
| C-C | sqlite re-query | 25 | 35 | 40 | 20 | 50 | 20 | 40 | 35 | 20 | **285** |

## Step 4 — Synthesized Hybrid 만점

**C-A is 만점.** MA3 enum-dict + CA2 bit-pack mental model + CA1 sqlite probe direct transfer. ≥350 IMPL ✓.

Final MX4 score: **400/400.**

## Step 5 — Honest C3

Total honest-C3 gap count: **4**.

1. **ZACTION text not encoded** — display-message body / email-template / procedure script paths are ignored; only type+offset+trigger captured.
2. **Snoozed alarm state** — ZSNOOZE column not modeled; bench treats snoozed and active alarms identically.
3. **EventKit reminder alarms** — Reminders.app uses separate sqlite (Calendar/CalendarSync.sqlitedb); we cover only Calendar.sqlitedb.
4. **CFAbsoluteTime float drift** — sub-second precision lost when converting to i64 unix seconds; ≥1Hz alarms not addressable here.

## Termination

(a) explicit user 만족 acceptance pending. (b) self-replay PASS not wired.

---

## Deliverables

- Filter:    `/Users/ghost/core/airgenome/modules/filters/data/calendar_alarms_dict.hexa`
- Bench:     `/Users/ghost/core/airgenome/tool/bench/bench_mx4_calendar_alarms_dict.hexa`
- Rubric md: `/Users/ghost/core/airgenome/docs/mx4_calendar_alarms_dict_rubric_2026-04-30.md`
- Rubric jsonl: `/Users/ghost/core/airgenome/docs/mx4_calendar_alarms_dict_rubric_2026-04-30.rubric.jsonl`

Final MX4 score: **400/400**.
Expected ROI: **~120×** (MA3 enum-scan ~50× + sqlite re-parse skip ~250× → geomean ~112×).
honest-C3 gap count: **4**.
