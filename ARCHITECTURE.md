# airgenome — Architecture (SSOT · update-in-place)

> Single source of truth for the final architecture. **Overwrite (update) this file** on change — it is not append-only. History and decisions live in [CHANGELOG.md](CHANGELOG.md).

airgenome is an **OS genome scanner**: it condenses every host's live vitals onto a
**6-axis resource hexagon** (cpu · mem · io · net · gpu · fs) serialized as a **60-byte
genome**, accumulates those genomes in a ring buffer, labels anomalies, and forecasts
one hour ahead. The whole pipeline is self-hosted in [hexa-lang](https://github.com/dancinlab/hexa-lang)
and shipped as a native macOS menubar daemon (`⌃S` launcher).

The convergence behavior of the tick loop is modeled as a **Banach 1/3 contraction**:
each tick maps the current resource state toward a stable fixed point at contraction
factor 1/3, so the adaptive throttle settles deterministically rather than oscillating.

## Overview

Each tick runs a five-stage pipeline over the 6-axis hexagon:

1. **probe** — sample Mac + remote (Ubuntu / Hetzner) vitals → `nexus/shared/infra_state.json`
2. **dispatch** — pick the best host per workload (AG6 Mac-protect, AG7 fallback) → dispatch state
3. **harvest** — top-N processes → 60-byte hexagon per process → `forge/*.ring` + sigdiff
4. **label** — match accumulator rules → `forge/labeled_anomaly.jsonl`
5. **forecast** — Holt double-exponential (α / β) smoothing → 1 h-ahead → `forge/forecast.jsonl`

L0 invariant for every module: **file present ∧ parse OK ∧ self-test PASS** (3-way gate).
`archive/v1/` is a read-only freeze; revival requires a PR + roadmap entry + L0 refresh.

## Components

| Path | Role |
|---|---|
| `airgenome/core/airgenome.hexa` | Self-contained core — Vitals + sample + assess + AdaptiveThrottle (imports no other hexa file). L0. |
| `airgenome/core/test/core_test.hexa` | Core self-test (the PASS leg of the L0 3-way gate). |
| `run.hexa` | Tick driver — runs the probe → dispatch → harvest → label → forecast pipeline. L0. |
| `install.hexa` | `hx install` entry — installs the `airgenome` shim, builds + signs the app, wires LaunchAgents. L0. |
| `native/src/` | macOS `.app` (Obj-C) — `airgenome_tap.m` (CGEventTap + status item), `airgenome_launcher.m` (⌃S overlay · @snippets · settings), `airgenome_hotkey.m` (hotkey → action binder), overload/notify/winctl helpers. |
| `bin/` | Shell shims + supervisor — `airgenome` CLI shim, `airgenome-supervisor`, `menubar.hexa`, build/stress/host helpers. |
| `forge/` | Genome ring buffers (`*.ring`) + `labeled_anomaly.jsonl` + `forecast.jsonl` + sample sets. |
| `config/` | Runtime config — `hosts.json`, `label_rules.jsonl`, `commands.json`, `lens_registry.json`, `protected_agents.txt`. |
| `nexus/shared/` | Cross-host SSOT — unified `infra_state.json` (sibling-repo convergence point). |
| `tool/governance.hexa` | Governance / policy enforcement surface. |
| `archive/v1/` | Read-only freeze of v1 sources (revival = PR + roadmap + L0 refresh). |
| `docs/` | Supporting docs + `logo.svg` (README header glyph). |

## Data flow

```
hosts (Mac · Ubuntu · Hetzner)
        │  probe
        ▼
nexus/shared/infra_state.json ──dispatch──▶ best-host-per-workload
        │  harvest
        ▼
60-byte hexagon per process ──▶ forge/*.ring (ring buffer) ──sigdiff──▶ deltas
        │  label
        ▼
forge/labeled_anomaly.jsonl ──forecast (Holt α/β)──▶ forge/forecast.jsonl
```

Input = live host vitals. Processing = hexagon encode → ring accumulate → rule label →
Holt smoothing. Output = `infra_state.json` (state), `labeled_anomaly.jsonl` (anomalies),
`forecast.jsonl` (1 h-ahead prediction). The AdaptiveThrottle in the core contracts the
tick interval toward its fixed point (Banach 1/3) based on observed load.

## Governance & verify

- **Lockdown (L0)**: `airgenome/core/airgenome.hexa`, `run.hexa`, `install.hexa` are L0 — edits
  require explicit approval + a CHANGELOG entry in the same change (see [CLAUDE.md](CLAUDE.md)).
- **Verify**: `hexa verify` (wired as the harness verify check) runs the parse + self-test gate.
- **Protected branches**: `main`, `master` (harness `pre-push` / branch-protection in hardcore profile).
- **Docs discipline**: this file is the architecture SSOT (update-in-place); history is appended to
  `CHANGELOG.md`; transient artifacts go under `scripts/scratch/`. Run `harness docs check` to verify.
- **Harness engine**: pinned as the `.harness-engine` submodule (`dancinlab/harness@harness-hardcore`).
