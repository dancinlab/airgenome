# airgenome Constitution

## Core Principles

### I. Genome Format — 6 Axes · 60 Bytes (NON-NEGOTIABLE)
A genome is one hexagon: six axes (`cpu` · `mem` · `io` · `net` · `gpu` · `fs`), 60 bytes total, one sample per host per tick. The shape is fixed — adding a 7th axis or expanding the byte budget is a MAJOR constitution change, not an implementation detail. Diffability and accumulation across hosts depend on the byte layout being stable.

### II. L0 Invariants (NON-NEGOTIABLE)
Every release passes the three L0 invariants before ship: (a) file present, (b) parse OK, (c) self-test PASS. `archive/v1/` is read-only — historical genomes are immutable; any rewrite of past records is rejected. Single TCC entry (`com.airgenome.tap`) — multi-row TCC sprawl is a regression.

### III. 5-Step Tick Pipeline
Each tick walks five stages in order, and only in this order: `probe` → `dispatch` → `harvest` → `label` → `forecast`. Each stage writes to its canonical output (`nexus/shared/infra_state.json` · `forge/genomes.ring` · `forge/labeled_anomaly.jsonl` · `forge/forecast.jsonl`). Skipping or re-ordering a stage breaks the ring buffer's accumulator semantics and is rejected at review.

### IV. Cross-Host Convergence — Unified `infra_state.json`
Mac · Ubuntu · Hetzner vitals converge into one `nexus/shared/infra_state.json`. Per-host divergence is a regression. `dispatch` is gated on the unified state — AG6 Mac-protect, AG7 fallback — so adding a host means extending the schema, never forking state files.

### V. hexa-native — 100% Self-Hosted
airgenome is implemented in hexa (`install.hexa`, `*.hexa`). When a stdlib primitive or runtime capability is missing, the gap files upstream as `~/core/hexa-lang/inbox/patches/<slug>.md`. Local Python or shell carriers for a missing hexa primitive are blocked — Python / shell tools that already exist as separate utilities are fine, but a hexa gap is fixed at hexa-lang, not papered over locally.

### VI. Native macOS Surface — Single CGEventTap, Single TCC Row
The macOS surface (`airgenome.app`) is a non-activating menubar daemon. Single CGEventTap, single TCC row, single status item. The user-facing surface (⌃S launcher · `@snippet` pasteboard · hotkey bindings · Settings tab) lives in one signed app; multiple processes or duplicate event taps are a Principle II violation.

### VII. Post-Impl Reinstall — `hx install airgenome` Mandatory Tail
Every artifact-affecting implementation ends with `hx install airgenome` (the single-entry installer rebuilds native + restarts every LaunchAgent in one verb). Build success without reinstall leaves the running `.app` stale — that failure mode is blocked at review per `design.md` Decision 2 (`g_post_impl_reinstall`). Docs-only edits (`*.md`, `design.md`, `README`) are exempt.

### VIII. Honest Forecast Tier
Holt's α / β double-exponential smoothing produces the 1-hour forecast. Forecast quality is reported as MAE on held-out data. The current "Holt MAE = 0 %" claim is a measurement on the current held-out set — it is NOT a guarantee for future data. Surfaces (badges, docs, demos) must distinguish "measured" from "expected".

## Repository Layout

```
airgenome/
├── install.hexa                 # hx install entry (rebuild + bootouts/bootstraps)
├── bin/                         # CLI entries
├── airgenome/                   # macOS app (Obj-C / Swift)
├── dispatch/                    # AG6/AG7 host-pick logic
├── exe_dispatch/                # dispatch executor
├── harvest/                     # top-N process → 60-byte hexagon
├── forge/                       # ring buffer + label + forecast outputs
├── forecast/                    # Holt α/β smoother
├── filters/ · genome_merge/     # cross-host genome merge + filter
├── displaylink/                 # display-link sampling
├── hooks/                       # tick hooks
├── config/                      # config surface
├── design.md                    # append-only decision ledger (SSOT)
├── archive/v1/                  # read-only historical genomes
└── .specify/                    # Spec Kit pipeline artifacts (this constitution lives here)
```

## Development Workflow

1. **Decision.** Every new direction lands in `design.md` as `### Decision N — <picked>` with `picked` + 3+ rationale bullets before the next decision opens.
2. **Spec.** Feature work flows through Spec Kit: `/speckit-specify → /speckit-plan → /speckit-tasks → /speckit-implement`.
3. **Tick pipeline change.** Adding or modifying a stage requires a ring-buffer compatibility check (existing records must still parse) plus a forecast-MAE delta in the PR description.
4. **hexa-lang gap.** Missing primitive → file at `~/core/hexa-lang/inbox/patches/<slug>.md`. Do NOT add a local carrier.
5. **Ship.** Every artifact-affecting PR ends with `hx install airgenome` (Principle VII).

## Governance

- This constitution governs airgenome repo-local concerns (genome format, L0 invariants, tick pipeline, macOS surface, post-impl reinstall, honest forecast tier).
- On stdlib / runtime / hexa-lang grammar subjects, the `hexa-lang` constitution is the authority.
- Amendments land via a PR that updates this file, adds a `design.md` decision entry, and bumps semver (MAJOR = principle removal / redefinition · MINOR = new principle / section · PATCH = wording).
- Complexity must be justified in the corresponding `design.md` entry. Default = simpler.

**Version**: 1.0.0 | **Ratified**: 2026-05-21 | **Last Amended**: 2026-05-21
