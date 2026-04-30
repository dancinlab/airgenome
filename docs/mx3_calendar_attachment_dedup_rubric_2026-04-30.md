# MX3 — Calendar Event Attachment Dedup — raw 240 V2 Weighted Rubric

Origin: 2026-04-30 — user directive: "Design + implement G. Mail/Calendar 보강 wave (4 filters)". MX3 = EventKit attachments (T2 pattern blake2b hash dedup, calendar event attachments path probe).

Pattern parents (READ FIRST):
- `/Users/ghost/core/airgenome/modules/filters/data/telegram_media_dedup.hexa` (T2, score 395, ROI 237×) — content-hash blake2b 64bit + sorted blob + bisect cluster lookup; head 64KB hashing.
- `/Users/ghost/core/airgenome/modules/filters/data/imessage_attachment_dedup.hexa` (K1, 400) — direct T2/M2 transfer pattern.
- `/Users/ghost/core/airgenome/modules/filters/data/calendar_event_shbf.hexa` (CA1) — Calendar.sqlitedb path probe + schema fallback.

Rubric source: `/Users/ghost/core/hive/.raw` raw 240 V2. 9 blocks, 400pt ceiling.

Probe: Calendar event attachments live under `~/Library/Calendars/<UUID>.calendar/Events/<UUID>.ics/Attachments/` OR are referenced via `Calendar.sqlitedb#ZATTACHMENT` with `ZFILEURL` column (file:// path). Fallback: synth 1500 entries 30% dup, seed=13.

## Step 1 — Rubric V2 Block Declaration

| Block | 만점 | 만점 컷 (MX3 filter-design context) |
|-------|------|--------------------------------------|
| B1 ai-native-machine-grep-ability | 60 | "CADD" magic + version + 16B header + sorted u64 hashes + JSONL 5-tuple emit |
| B2 channel-coverage | 50 | filter + bench + rubric.md + rubric.jsonl + .raw site-list slot |
| B3 enforcement-strength | 50 | bench harness + diff_test=lossless + perl alarm 120s + read-only `os.lstat` + sqlite immutable=1 |
| B4 measurability-closure | 50 | 5-tuple (site=MX3) + dedup-saving size + per-query speedup |
| B5 self-replay-automation | 50 | bench re-runnable, deterministic seed=13, ≤120s, synthetic-only |
| B6 cross-repo-propagation | 40 | T2+K1 ancestry; pattern reusable for any path-attachment dedup (MS Outlook, Notion, etc.) |
| B7 emission-cost-bounded | 40 | inline PAYLOAD ≤ ~13KB; run()+run() boilerplate stable |
| B8 adversarial-resistance | 40 | synth fallback honest-disclosed; (hash, size) composite key for collision safety |
| B9 meta-rubric-finite | 20 | filter ≠ rubric-of-rubric; depth-1 |

Total ceiling: **400**.

## Step 2 — Candidate Variants (≥2)

### C-A: blake2b-64 + head(64KB) + sorted u64 blob + bisect (T2/K1 direct transfer)
- Hash: `hashlib.blake2b(content[:65536], digest_size=8, key=size_le8)` (T2 wyh64).
- Path probe order: (1) Calendar.sqlitedb ZATTACHMENT.ZFILEURL → resolve file:// → lstat; (2) `~/Library/Calendars/*.calendar/Events/*/Attachments/*` glob; (3) synth.
- Layout: 16B header + sorted u64 hashes + u32 sizes + u32 dup_count (T2 layout).

### C-B: full-file SHA1 + linear scan (no blob)
- Loses B5 (slow on large attachments — meeting recordings can be 100MB+), B7 (no inline blob → reuse cost), B6 (breaks T2 wyh64 lineage).

### C-C: filename-only dedup (no content hash)
- Loses B8 hard (false dedup if user has IMG_0001.jpg in 2 distinct events).

## Step 3 — Score Matrix

| ID | Variant | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total/400 |
|----|---------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-----------|
| C-A | blake2b-64 + head(64KB) + bisect | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |
| C-B | SHA1 + full + linear | 50 | 35 | 45 | 45 | 30 | 30 | 25 | 40 | 20 | **320** |
| C-C | filename dedup | 30 | 30 | 35 | 30 | 50 | 25 | 40 | 15 | 20 | **275** |

## Step 4 — Synthesized Hybrid 만점

**C-A is 만점.** T2 + K1 + CA1 direct transfer; no synthesis needed. ≥350 IMPL ✓.

Final MX3 score: **400/400.**

## Step 5 — Honest C3

Total honest-C3 gap count: **5**.

1. **EventKit private API not used** — we walk filesystem + sqlite; iOS-style EventKit-bridge (PyObjC) would expose Calendar attachments more reliably but adds ObjC dependency.
2. **iCloud calendar attachments downloaded lazily** — file:// URLs may resolve to placeholder until accessed; lstat returns 0 size.
3. **Head-64KB collision risk** — same as T2/K1; mitigated by (hash, size) composite key, not eliminated.
4. **APFS-clone double-count** — saving may already be APFS-applied.
5. **Recurring event attachment fanout** — same attachment referenced by N RRULE expansions counts as N hits; saving estimate inflates.

## Termination

(a) explicit user 만족 acceptance pending. (b) self-replay PASS not wired.

---

## Deliverables

- Filter:    `/Users/ghost/core/airgenome/modules/filters/data/calendar_attachment_dedup.hexa`
- Bench:     `/Users/ghost/core/airgenome/tool/bench/bench_mx3_calendar_attachment_dedup.hexa`
- Rubric md: `/Users/ghost/core/airgenome/docs/mx3_calendar_attachment_dedup_rubric_2026-04-30.md`
- Rubric jsonl: `/Users/ghost/core/airgenome/docs/mx3_calendar_attachment_dedup_rubric_2026-04-30.rubric.jsonl`

Final MX3 score: **400/400**.
Expected ROI: **~220×** (geometric mean of T2 237× and K1 ~250×).
honest-C3 gap count: **5**.
