# airgenome

OS genome scanner — every host's live vitals projected onto a **6-axis resource hexagon**
(cpu · mem · io · net · gpu · fs), serialized as a **60-byte genome**, accumulated in a ring
buffer, labeled for anomalies, and forecast 1 h ahead (Holt α/β). Self-hosted in
[hexa-lang](https://github.com/dancinlab/hexa-lang) and shipped as a native macOS menubar
daemon (`⌃S` launcher). The tick loop converges as a **Banach 1/3 contraction** toward a
stable resource fixed point.

Full architecture SSOT: [ARCHITECTURE.md](ARCHITECTURE.md). History: [CHANGELOG.md](CHANGELOG.md).
This file is the single markdown governance SSOT (identity · governance · structure); the legacy `project.tape` has been retired (md 단일화).

## Structure

```
├─ airgenome/core/airgenome.hexa — self-contained core (Vitals + sample + assess + AdaptiveThrottle) · L0
│  └─ test/core_test.hexa — core self-test (PASS leg of the L0 3-way gate)
├─ run.hexa — tick driver (probe → dispatch → harvest → label → forecast) · L0
├─ install.hexa — hx install entry (shim + signed app + LaunchAgents) · L0
├─ native/src — macOS .app (Obj-C): CGEventTap, ⌃S launcher, @snippets, hotkey binder
├─ bin — CLI shim + supervisor + menubar.hexa + build/stress/host helpers
├─ forge — genome ring buffers (*.ring) + labeled_anomaly.jsonl + forecast.jsonl
├─ config — runtime config (hosts.json · label_rules.jsonl · lens_registry.json · protected_agents.txt)
├─ nexus/shared — cross-host SSOT (unified infra_state.json)
├─ tool/governance.hexa — governance / policy enforcement surface
├─ archive/v1 — read-only freeze of v1 (revival = PR + roadmap + L0 refresh)
├─ docs — supporting docs + logo.svg
├─ ARCHITECTURE.md — architecture SSOT (update-in-place)
├─ CHANGELOG.md — change history (append-only)
└─ .harness-engine — pinned harness engine submodule (dancinlab/harness@harness-hardcore)
```

## Governance

- **L0 lockdown**: `airgenome/core/airgenome.hexa`, `run.hexa`, `install.hexa`. Editing an L0 file
  requires explicit approval + a `CHANGELOG.md` entry in the same change.
- **L0 invariant**: every module is **file present ∧ parse OK ∧ self-test PASS** (3-way gate).
  `archive/v1/` is read-only — revival needs a PR + roadmap entry + L0 refresh.
- **Docs discipline**: architecture → `ARCHITECTURE.md` (update-in-place); history → `CHANGELOG.md`
  (append); transient artifacts → `scripts/scratch/`. Root docs carry a quickref pointer to the SSOT.
- **Protected branches**: `main`, `master`. Verify with `hexa verify` before push.

## Harness

This repo is governed by the [dancinlab/harness](https://github.com/dancinlab/harness) engine,
pinned as the `.harness-engine` submodule (`harness-hardcore` branch, hardcore profile).
Config: [harness.config.json](harness.config.json). Hook delegates are wired in
`.claude/settings.json` (pre bash / pre write / post edit / prompt / prefs / easy / recommend /
SessionStart) — all guarded so the repo works even when the engine is absent.

Run the engine: `bash .harness-engine/bin/harness <cmd>`.

### Quick reference

| Command | Purpose |
|---|---|
| `bash .harness-engine/bin/harness lint` | staged-L0 + freshness + convergence checks |
| `bash .harness-engine/bin/harness verify` | run configured verification commands (`hexa verify`) |
| `bash .harness-engine/bin/harness docs check` | single-doc discipline (architecture SSOT + quickref) |
| `bash .harness-engine/bin/harness audit` | 6-axis self-scorecard |
| `bash .harness-engine/bin/harness pr-cycle` | push branch → open PR → self-merge |
