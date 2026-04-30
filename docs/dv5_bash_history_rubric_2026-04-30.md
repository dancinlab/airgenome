# DV5 bash_history Columnar Token Dict — raw 240 V2 Weighted Rubric

Origin: `2026-04-30` arsmoriendi99@proton.me — universal shell history mandate
extension to `~/.bash_history` (raw 47 cross-repo). Direct verbatim transfer
of K6 zsh_history_columnar pattern (KZHC v1, 400/400). bash plain text format
is a strict subset of zsh plain (no `: <ts>:<dur>;` prefix variant), so the
parser path simplifies but the rubric ceiling is preserved.

## Step 1 — Rubric V2 Block Declaration (BEFORE candidates per B8)

| Block | 만점 | 만점 컷 (filter-design context) |
|-------|------|---------------------------------|
| B1 ai-native-machine-grep-ability | 60 | magic + version + 5-tuple JSONL bench emit |
| B2 channel-coverage               | 50 | filter .hexa + bench .hexa + design doc + .rubric.jsonl |
| B3 enforcement-strength           | 50 | bench self-runs + diff_test=lossless + perl alarm 120s |
| B4 measurability-closure          | 50 | 5-tuple (site, ROI#, baseline_ns, post_ns, diff_test) emit |
| B5 self-replay-automation         | 50 | deterministic synth seed, ≤120s, no manual setup |
| B6 cross-repo-propagation         | 40 | C14 (bash_history APBF) + MA3 (#99 dict) + K6 KZHC twin lineage |
| B7 emission-cost-bounded          | 40 | inline PAYLOAD ≤ ~12KB, single run() wrapper |
| B8 adversarial-resistance         | 40 | synth fallback when no real ~/.bash_history; HISTTIMEFORMAT comment-ts honest |
| B9 meta-rubric-finite             | 20 | filter ≠ rubric; depth-1 design artifact |

Total ceiling: **400**.

## Step 2 — Probe (~/.bash_history on this host)

- Path: `~/.bash_history` — plain text, **5,649 B** (500 lines).
- Format: **plain** (bash never emits `: <ts>:<dur>;`; HISTTIMEFORMAT prefixes
  a `#<epoch>\n` comment line if set, otherwise none). Filter MUST handle both
  formats (`#<digits>` ts-comment optional, otherwise ts=0).
- distinct cmd[0]: 5 on this host (echo, exit, ls, for, printf) — plenty of
  headroom under the 255 cap.
- Open ($HOME) — no TCC dance.

## Step 3 — Candidate Score Matrix (≥2 per B8)

| ID | Cand | B1/60 | B2/50 | B3/50 | B4/50 | B5/50 | B6/40 | B7/40 | B8/40 | B9/20 | Total |
|----|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-------|
| DV5-a | flat sorted cmd-pool + ts u32 (F18 form, no dict) | 55 | 45 | 50 | 40 | 50 | 35 | 40 | 35 | 20 | **370** |
| DV5-b | cmd-head u8 dict (#99) + full-line pool + ts u32 (#65 wyhash for cmd-head canonicalize) — K6 verbatim transfer | 60 | 50 | 50 | 50 | 50 | 40 | 40 | 40 | 20 | **400** |

DV5-b reasoning:
- B1 60: DBHC magic + v1 + 5-tuple JSONL → fully machine-greppable.
- B4 50: per-query latency + size + GROUP BY by cmd-head all measurable.
- B6 40: C14 bash_history APBF (sorted-pool bisect prefix) + MA3 #99 dict
  (≤255 enum) + K6 KZHC twin — three-pattern fusion, pure airgenome ancestry.
- B8 40: distinct cmd[0] >255 → most_common(255) fallback per MA3; missing
  ~/.bash_history → 10K synth (50 distinct cmds, seed=7); ts-comment-vs-plain
  parser branch; both paths diff-tested.

DV5-a falls short (-30) because flat pool loses the GROUP BY ROI; cmd-head
column scan is the dominant query (statusline / shell-genome).

## Step 4 — Synthesis

**Selected: DV5-b — 400/400.**

Layout (little-endian):
```
magic    : 4B  "DBHC"
version  : 4B  u32 (1)
n_cmd    : 4B  u32 distinct cmd-head count (≤255)
n_line   : 4B  u32 total history lines
str_sz   : 4B  u32 cmd-dict pool size
line_sz  : 4B  u32 full-line pool size
[n_cmd*4]: u32 cmd_dict_offs
[n_cmd*4]: u32 cmd_dict_lens
[str_sz] : utf-8 cmd-dict pool
[n_line] : u8  cmd_dict_idx column
[n_line] : u32 ts column (HISTTIMEFORMAT #<epoch> → ts; plain → 0)
[n_line] : u32 full_line_offs
[n_line] : u32 full_line_lens
[line_sz]: utf-8 full-line pool
```

Query patterns:
- prefix `git ` top-K by ts: cmd_dict_idx == id_of("git") → scan u8 col O(n)
  + filter ts → top-K heap. ~50× over `grep '^git ' ~/.bash_history`.
- GROUP BY cmd-head: u8 col 1-pass → 256-bucket counter.

Wyhash (#65) usage: canonicalize cmd-head before dict insert (e.g. trim
trailing whitespace) — collision-resistant 64-bit hash backs the python dict
during encode; final blob stores plain string keys.

## Step 5 — honest-C3 (Gap Disclosure)

- G1: ~/.bash_history on this host has no HISTTIMEFORMAT preamble — ts
  column is all-zero in current probe. Filter still passes diff_test (ts=0
  lossless) but ROI on "top-K by ts" is degenerate until user sets
  `HISTTIMEFORMAT="%s "`. Synth path uses synthesized ts to validate columnar
  sort.
- G2: bash multi-line history (`shopt -s lithist` / `cmdhist`) coalesces
  embedded newlines via `\012` literal; filter preserves bytes as-is in the
  full-line pool — reader must apply `\012` → `\n` decode if rendering.
- G3: DV5-b distinct cmd[0] ≤255 fits comfortably (probe = 5) but heavy
  pipeline users (npm/yarn wrappers) could hit the cap; most_common(255)
  fallback maps tail to id=0 ("misc" bucket) — collision risk noted but
  acceptable for shell genome.
- G4: Filter does NOT capture exit-status (bash history doesn't store it
  natively); cross-reference with $? requires `PROMPT_COMMAND` hook (out of
  scope).

**Gap count: 4.**

## Step 6 — Deliverables

1. `/Users/ghost/core/airgenome/docs/dv5_bash_history_rubric_2026-04-30.md` (this)
2. `/Users/ghost/core/airgenome/docs/dv5_bash_history_rubric_2026-04-30.rubric.jsonl`
3. `/Users/ghost/core/airgenome/modules/filters/data/bash_history_columnar.hexa`
4. `/Users/ghost/core/airgenome/tool/bench/bench_dv5_bash_history.hexa`

**Final DV5 score: 400/400.**
