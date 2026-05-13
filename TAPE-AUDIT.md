# TAPE-AUDIT — airgenome

> Audit-class survey for `.tape` adoption (typed events + provenance edges + delivery grade).

## A. Audit-class ledgers
**DESIGN, dense.** Multiple .jsonl streams: `config/label_rules.jsonl`, `config/e2e_acceptance.jsonl` (config-class); `docs/*.rubric.jsonl` (dense — `cc_bg6_read_cache_layer_rubric_2026-05-01`, `nw_w2_wifi_scan_dedup_rubric_2026-04-30`, `k2_sharedfilelist_recent_shbf_rubric_2026-04-30`, `pb1_pasteboard_history_columnar_rubric_2026-04-30`, `ct1_podman_containers_dict_rubric_2026-04-30`, `k1_imessage_attachment_dedup_rubric_2026-04-30`, `raw_240_v3_blocks_b11_to_b30_full_expansion`, ...). `docs/raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl`. `state/bench_results.jsonl`, `state/rig_trend_history.jsonl`. `state/markers/` dense (probe / label / harvest / dispatch / safari_battery_freeze_filter). `state/canonical_term_baseline_audit/` + `state/discovery_absorption/` + `state/safety_bypass_audit/` (real audit dirs).

## B. Identity surface
**Rig identity** (per-genome-axis fingerprint — 60 bytes × 6 axes). **Device identity** via WiFi-MAC / serial / hostname. **App identity** via bundle-id rubric matches. Heavy identity surface.

## C. Domain.md files
Light root: `AGENTS.md`, `CLAUDE.md`, `README.md`. M0–M6 milestones are in README — not lifted to UPPERCASE.md root files. Opportunity exists.

## D. Per-run / per-event history
`state/bench_results.jsonl` + `state/rig_trend_history.jsonl` are the trend ledgers. `docs/*.rubric.jsonl` are per-rubric event manifests (one rubric = one detection / dedup / label rule). The `.rubric.jsonl` convention is unusual and already very tape-shaped (typed rule events per file).

## E. Promotion candidates
- **`.tape` events (HIGH)**: rubric.jsonl files are proto-tape — formalize as typed `@R` (rubric match) / `@K` (config) events with rig `@S` provenance. `bench_results.jsonl` + `rig_trend_history.jsonl` are per-rig event tapes.
- **n6 atoms (MED)**: canonical_term mapping + label_rules + e2e_acceptance criteria are atom-shaped.
- **n12 cube (LOW-MED)**: rig × axis × era × app × rubric could be 5-axis if cataloging takes off.
- **hxc wire (MED)**: harvest → label → forecast pipeline is a natural wire pipe (Holt MAE 0% held-out is the cited delivery grade).

## Verdict
**HEAVY** — airgenome is a strong `.tape` adopter on volume grounds alone (10+ `.rubric.jsonl` files, 2 trend .jsonl, dense markers). The `.rubric.jsonl` naming convention is already typed-event-shaped. Promotion = formalize per-rubric events + per-rig provenance + hoist M0–M6 milestones to root domain files.
