# Remote Idle Utilization — Hetzner Drill Corpus Builder
**Date:** 2026-04-25
**Host:** hetzner (128GB RAM, /home=1.7T 2% used)
**Scheme:** Option A — Continuous drill corpus builder on hetzner
**Cadence:** every 2h (StartInterval=7200)

## Decision

Selected option **A** from 4 candidates (A=drill corpus, B=harvest offload, C=CI runner, D=bench sweep). Criteria order applied:

1. **Reversibility** — unload plist or `rm state/drill_corpus_cursor.json` fully disables. No runtime coupling. ✓
2. **Hetzner leverage** — each drill tick uses the `/root/.hx/bin/nexus` engine directly on the 128GB box where heavy-compute was already dispatched. ✓
3. **Interactive non-disruption** — `pgrep -f 'nexus drill' | wc -l > 1` guard aborts if the user has a drill running locally on Mac. Independent of existing hexa_remote RAM threshold (drill_corpus is host-native nexus shim, not hexa_remote). ✓
4. **Persisted artifact** — every tick appends a single JSON line with `{ts, elapsed_s, rc, seed_id, seed, problem, preset, rounds, host, output}` to both `/home/drill_corpus/drill_corpus.jsonl` (hetzner) and `forge/drill_corpus.jsonl` (Mac). Future harvest/label/forecast can tap this file as a new corpus ring. ✓

Rejected B (complex state sync risk), C (auth scope creep), D (one-shot value).

## Artifacts

| Path | Role |
|---|---|
| `config/drill_corpus_seeds.jsonl` | 10 curated seeds — 6 from `drill_stability.convergence`, 1 from `airgenome_2026_04.convergence`, 3 millennium problems (riemann/hodge/bsd) via nexus `--problem` preset |
| `bin/drill_corpus_tick.sh` | tick script — cursor round-robin, interactive guard, ssh dispatch via existing `airgenome offload htz`, rsync-free tail pull (remote emits entry, local appends) |
| `launchd/com.airgenome.drill-corpus.plist` | StartInterval=7200 (2h), RunAtLoad=false, logs to ~/.airgenome/drill_corpus.{stdout,stderr}.log |
| `state/drill_corpus_cursor.json` | round-robin cursor + last rc |
| `forge/drill_corpus.jsonl` | corpus ring (Mac mirror) |
| `/home/drill_corpus/drill_corpus.jsonl` | corpus ring (hetzner SSOT, /home md2 partition) |

## Safety caps

- server-side `timeout --kill-after=10 600s` on every nexus drill call (override via `DRILL_CORPUS_TIMEOUT` env)
- `preset=probe` + `max-rounds=3` default per seed — light for 128GB box
- writes only under `/home/drill_corpus` (/ is 87% — do NOT touch)
- cursor advances on rc≠0 too (stuck seed doesn't block rotation)
- existing hexa_remote RAM guard + disk-watchdog.timer on hetzner unaffected (separate code path, no shared state)

## Smoke verification (2026-04-24T17:37–17:47Z, 10m13s)

- seed: dcs-001 (Riemann zeta, problem=riemann, preset=probe, rounds=3)
- remote rc=124 (server timeout expected at 600s) — drill progress trace still captured in `.output`
- local rc=0, 1 line appended (24KB)
- cursor advanced idx=0 → next=1
- remote file: `/home/drill_corpus/drill_corpus.jsonl` (1 line)

## Activation

User decision — do NOT `launchctl load` unprompted. Activation when ready:

```
launchctl bootstrap gui/$(id -u) /Users/ghost/core/airgenome/launchd/com.airgenome.drill-corpus.plist
```

Deactivation:

```
launchctl bootout gui/$(id -u)/com.airgenome.drill-corpus
```

## Followups (not executed now)

- harvest daemon (M4) can treat `forge/drill_corpus.jsonl` as an additional ring source
- seed rotation refresh monthly from fresh convergence entries
- consider second tier on ubu1/ubu2 for smaller drills if hetzner saturates (unlikely given 2h cadence)
