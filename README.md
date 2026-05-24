<p align="center">
  <img src="docs/logo.svg" width="140" alt="airgenome">
</p>

<h1 align="center">🎛️ airgenome</h1>

<p align="center"><strong>OS Genome Scanner</strong> — six axes · sixty bytes · every host's vitals → one hexagon</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <img alt="Genome" src="https://img.shields.io/badge/genome-60_bytes%20·%206_axes-success">
  <img alt="Milestones" src="https://img.shields.io/badge/M0–M6-done-brightgreen">
  <img alt="Forecast" src="https://img.shields.io/badge/Holt_MAE-0%25_held--out-brightgreen">
  <img alt="Native" src="https://img.shields.io/badge/macOS-menubar%20·%20⌃S-informational">
</p>

<p align="center">cpu · mem · io · net · gpu · fs · 60 bytes · ring buffer · Holt forecast · macOS menubar · ⌃S launcher · hexa-lang · self-hosted</p>

---

**Six axes. Sixty bytes. Every host's vitals → one hexagon.**

```
            cpu
          ╱     ╲
        io       net
        │   60B   │      A host's live state condensed into one
        mem      gpu     perfectly-shaped hexagon — diffable,
          ╲     ╱        accumulable, forecastable.
            fs
```

> Project Mac / Ubuntu / Hetzner vitals onto a 6-axis hexagon (60 bytes per genome).
> Accumulate per-process samples → ring buffer → label anomalies → forecast 1 h ahead with
> Holt's double exponential smoothing. 100 % self-hosted in
> [hexa](https://github.com/dancinlab/hexa-lang).

<!-- SHARED:PROJECTS:START -->
<!-- AUTO:COMMON_LINKS:START -->
**[YouTube](https://www.youtube.com/@dancinlife)** · **[Email](mailto:nerve011235@gmail.com)** · **[Ko-fi](https://ko-fi.com/dancinlife)** · **[Sponsor](https://github.com/sponsors/dancinlab)** · **[PayPal](https://www.paypal.com/donate?business=nerve011235%40gmail.com)** · **[Atlas](https://dancinlab.github.io/TECS-L/atlas/)** · **[Papers](https://dancinlab.github.io/papers/)**
<!-- AUTO:COMMON_LINKS:END -->

## Main projects

> **[Anima](https://github.com/dancinlab/anima)** — Consciousness implementation. PureField repulsion-field engine + 1030 laws + Φ ratchet.
>
> **[NEXUS](https://github.com/dancinlab/nexus)** — Universal Discovery Engine. 216 lenses + OUROBOROS evolution + 5-phase singularity cycle.
>
> **[N6 Architecture](https://github.com/dancinlab/canon)** — Architecture from perfect number 6. 225 AI techniques + chip design + crypto/OS/display.
>
> **[HEXA-LANG](https://github.com/dancinlab/hexa-lang)** — The Perfect Number Programming Language. Working compiler + REPL.
>
> **[Papers](https://github.com/dancinlab/papers)** — Complete paper collection (92 papers, Zenodo DOIs).

> **[Other projects →](https://github.com/orgs/dancinlab/repositories)**

<!-- private repos는 projects.json의 private_repos 필드에 저장됨 (노출 금지) -->
<!-- SHARED:PROJECTS:END -->

## Highlights

| | |
|---|---|
| 🎛️ | **6-axis hexagon · 60 bytes/genome** — cpu / mem / io / net / gpu / fs |
| 📈 | **M0–M6 done** — probe + dispatch + harvest + label + forecast (Holt MAE = 0 % on held-out) |
| 🍎 | **Native macOS menubar** — ⌃S launcher, `@snippet` → pasteboard, hotkey-action bindings |
| 🌐 | **Cross-host** — Mac + Ubuntu + Hetzner vitals → unified `infra_state.json` |
| 🔒 | **L0 invariants** — file present ∧ parse OK ∧ self-test PASS, `archive/v1/` read-only, single TCC entry |

## What it does

Each tick:

1. **probe** — sample Mac + remote vitals → `nexus/shared/infra_state.json`
2. **dispatch** — pick best host per workload (AG6 Mac-protect, AG7 fallback)
3. **harvest** — top-N processes → 60-byte hexagon → `forge/genomes.ring` + sigdiff
4. **label** — match accumulator rules → `forge/labeled_anomaly.jsonl`
5. **forecast** — Holt's α / β smoothing → 1 h-ahead → `forge/forecast.jsonl`

## Status

- **M0–M6 done** — probe + dispatch + harvest + label + forecast pipeline live
- **Holt MAE = 0 %** on held-out forecast evaluation
- **Native macOS app** — single CGEventTap + status item + ⌃S launcher (Obj-C, signed)
- **Cross-host** — Mac + Ubuntu + Hetzner converge to one `infra_state.json`
- **L0 invariants** — file present ∧ parse OK ∧ self-test PASS; `archive/v1/` read-only; single TCC entry; raw 258 amendment v2 A-policy active (kick = sole canonical CLI surface for kick cluster)

## Native macOS

`airgenome.app` runs as a non-activating menubar daemon (single CGEventTap, single TCC row). User-facing surface:

- **⌃S launcher** — fuzzy app search · inline gray ghost-suffix completion (Tab to commit) · ↑/↓ recall last 5 typed queries (LIFO, dedup) · `@<name>` enters snippet mode.
- **@snippets** — JSON at `~/Library/Application Support/airgenome/snippets.json` (name-sorted). Enter on a `@snippet` match copies the full content — `\n` preserved — to the pasteboard.
- **Settings** — menubar `airgenome settings…` (or type "settings" in ⌃S). Tabbed editor:
  - **앱 단축키** — modifier × key dropdowns + action popup (`activate-app` / `toggle-app` / `show-desktop`) + target browse → writes `hotkey_bindings.json`, daemon hot-reloads.
  - **스니펫 관리** — Name + multiline Content (NSTextView, undo) → writes `snippets.json`.

## Install

```bash
# 1. Install hexa-lang (gives you `hexa` + `hx` package manager)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"

# 2. Install airgenome — adds the `airgenome` shim, builds + signs airgenome.app,
#    installs LaunchAgents, wires com.airgenome.tap (⌃S launcher + menubar)
hx install airgenome
```

After install, grant Accessibility once: System Settings → Privacy & Security → Accessibility → enable `/Applications/airgenome.app`. Press **⌃S** anywhere to summon the launcher.

## Run

```sh
airgenome harvest        # 60-byte genome sweep → genomes.ring
airgenome label          # rule-match anomalies → labeled_anomaly.jsonl
airgenome forecast       # Holt's α / β smoothing → forecast.jsonl
airgenome dispatch       # best host per workload → dispatch_state.json
airgenome probe          # Mac + remote vitals → infra_state.json
airgenome status         # launchd + ring + state summary
airgenome doctor         # core / launchd / ring / throttle diagnostic
airgenome cli            # interactive TUI
airgenome menubar        # menubar + ⌃S launcher (already running via launchd)
```

## Repo layout

```
core/                  # self-contained: Vitals + sample + assess + AdaptiveThrottle
modules/               # M2+ pipeline (probe / dispatch / harvest / label / forecast)
native/                # macOS .app bundle — CGEventTap + menubar + ⌃S launcher (Obj-C)
  src/airgenome_tap.m         # tap loop + status item + LaunchAgent entry
  src/airgenome_launcher.m    # ⌃S overlay · @snippets · settings panel
  src/airgenome_hotkey.m      # user-defined hotkey → app/system action binder
forge/                 # genomes.ring + labeled_anomaly.jsonl + forecast.jsonl
shared/config/roadmap/ # rebuild v2 SSOT (milestones, invariants)
archive/v1/            # read-only freeze of v1
nexus/                 # cross-project SSOT (sibling repo)
docs/
  logo.svg             # README header glyph
AGENTS.tape            # governance + identity (.tape v1.2)
CLAUDE.md              # symlink → AGENTS.tape (Claude Code project instructions)
```

## Plugins

airgenome dispatches anything outside its core scope (e.g. Windows `.exe`)
through a tiny plugin registry — the core ships **zero** PE-loader / Win32 /
emulation code.

| | |
|---|---|
| Discover | `~/.airgenome/plugins/*/plugin.json` (user install) · `../airgenome-*/plugin.json` (dev sibling) |
| Manifest | `{ "name": …, "type": "exe-runner", "handles": [{"extension": ".exe", "platforms": [...], "priority": N}], "entry": "…" }` |
| Dispatch | `airgenome exe <path>` — picks the highest-priority handler whose `handles[]` matches the file |
| List | `airgenome plugins` — enumerates discovered manifests + handled extensions |

External tools: see <https://github.com/dancinlab/> for sibling repos
(formerly the `airgenome-gamebox` Win32 runtime is now standalone at
<https://github.com/dancinlab/gamebox> as of 2026-05-05; the
plugin-registry pattern remains for future external handlers).

## Roadmap (rebuild v2)

| ID  | Milestone                                    | Status  | Evidence |
|---|---|---|---|
| M0  | v1 freeze + core split                       | done | airgenome#33 · nexus#33 · 19/0 PASS |
| M1  | L0 guard parse-check (phantom block)         | done | nexus#34 · 21/0 PASS (parse 2 cases) |
| M2  | probe — Mac+ubu+htz vitals → infra_state     | done | airgenome#37 · nexus#36 · 24/0 PASS |
| M3  | dispatch — best host (AG6/AG7)               | done | airgenome#39 · ag6_gate active |
| M4  | harvest — 60-byte hexagon per process        | done | airgenome#41 · genomes.ring + sigdiff + AdaptiveThrottle |
| M5  | label — anomaly → behavior label             | done | airgenome#42 · 5 SSOT rules · synth 3-label verified |
| M6  | predict — 7 d trend → 1 h forecast           | done | airgenome#43 · Holt α/β · MAE = 0 % held-out |

- Live filter: `grep -E '^roadmap [0-9]+ (planned|active|done|blocked|deferred)' .roadmap`
- Per-track view: `awk '/^roadmap /{r=$0} /^  track/{print r" ["$2"]"}' .roadmap`

### Invariants

1. `airgenome/core/airgenome.hexa` imports no other hexa file (self-contained).
2. New modules import only `use "../../airgenome/core/airgenome"` — no inter-module imports.
3. L0 entry = file present ∧ parse OK ∧ self-test PASS (3-way gate).
4. `archive/v1/` is read-only — revival requires PR + roadmap entry + L0 refresh.

> **Utility exemption**: `track=util` modules (auxiliary launchers / tooling) are exempt from roadmap registration — invariants 1–4 only. No MAIN/cell/lora coherence required.

## Archive

v1 sources frozen in [`archive/v1/`](archive/v1/). Revival procedure: [`archive/v1/README.md`](archive/v1/README.md).

## Related projects

- [nexus](https://github.com/dancinlab/nexus) — cross-project SSOT (L0 lockdown + `hexa` resource gate)
- [hexa-lang](https://github.com/dancinlab/hexa-lang) — self-hosted language airgenome runs on

## License

[MIT](LICENSE) — see LICENSE file.

---

**[Live roadmap](https://dancinlab.github.io/nexus/roadmap/#airgenome)** · **[Papers](https://dancinlab.github.io/papers/)** · **[Atlas](https://dancinlab.github.io/TECS-L/atlas/)**

<sub>Six axes. Sixty bytes. One hexagon. · [dancinlab](https://github.com/dancinlab)</sub>

---

## raw 258 amendment v2 A-policy (2026-05-01) — kick canonical single-entry

`kick` is the sole canonical CLI surface (`nexus kick <topic>`) for the kick cluster.
Six terms (`drill / smash / blowup / free / meta-closure / absolute`) are absorbed into
`kick` as internal saturation phases and are not exposed as external `--phase` flags.

- Canonical : `nexus kick <topic>`
- Help      : `nexus kick --help`
- Banned    : direct `.hexa` invocation, deprecated direct subcommands (`nexus drill --seed`, etc.)
- Mapping   : `airgenome/docs/raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` (schema v2)
