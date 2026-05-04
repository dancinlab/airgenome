---
doc: ghost.cpre.identity
kind: core_preamble
audience: [human, agent]
mk: 1
since: 2026-05-04
parent: airgenome.modules.ghost
---

# Identity — name, glyph, paired siblings

## Name origin

**ghost** — the operator's residual presence at the network layer when every other footprint is stripped. ghost makes orpheus 🗝️ and wraith-wallet 🫥 indistinguishable from passing background traffic: no real IP, no ASN linkage, no exit jurisdiction tied to the operator.

The metaphor is deliberate. orpheus *descends* (recovers what was lost). wraith-wallet *hides* (custodies what was found). ghost *ceases to exist* (the operator was never there).

## Glyph

🕶️ — sunglasses. The visible "I'm not visible" mark. Used in:
- airgenome README (when the ghost subdomain is announced)
- commit message prefixes when meaningful (`🕶️ ghost: <verb-phrase>`)
- log channel emoji in `state/runs/ghost_*.jsonl` (audit decisions only — never traffic content, see G2)

## Paired trio

| Repo | Glyph | Role | Side |
|---|---|---|---|
| `orpheus` | 🗝️ | produces the key | input / discovery |
| `wraith-wallet` | 🫥 | hides the operator (custody, signing, broadcast) | output / settlement |
| `airgenome/modules/ghost` | 🕶️ | hides the operator at the network layer (VPN/Tor/mixnet wrap) | substrate / opsec |

### Trio reading

`🗝️ orpheus → 🫥 wraith-wallet → 🕶️ ghost` = `produces key → custodies+signs+routes payout → routes anonymously at the network layer`.

Three repos, three glyphs, three layers of separation:
- **orpheus** opens the door (finds the key).
- **wraith-wallet** walks through it without leaving footprints (signs and settles).
- **ghost** ensures the door's pavement was never on a map (the network path was never observable).

### Why ghost lives inside airgenome (not as a sibling repo)

The original sibling-design research (`docs/ghost_feature_design_inbox_2026_05_04.ai.md`) assumed ghost would be a third sibling repo. The frame changed 2026-05-04: ghost is an **optional module of airgenome**, not a separate repo. Justification:

- airgenome already owns the operator's local opsec surface (CGEventTap, menubar daemon, single TCC entry). Adding network-layer anonymity to the same daemon's responsibility avoids a second always-on background process.
- airgenome's `modules/` already holds plugin-style additive features (`exe_dispatch`, `predictive_throttle`); ghost fits the same pattern.
- The `cpre+moduler` discipline of orpheus / wraith-wallet is preserved, but contained: only `modules/ghost/` follows it. The airgenome main pattern (flat `modules/*.hexa`) is untouched.

## Naming conventions inside `modules/ghost/`

| Element | Convention |
|---|---|
| Sub-files | `wrap_<provider>.hexa`, `route.hexa`, `policy.hexa`, `audit.hexa`, `selftest.hexa` |
| cpre files | `cpre/{intent,scope,contracts,identity}.ai.md` |
| Docs | airgenome top-level `docs/<topic>_<YYYY_MM_DD>.ai.md` (shared with the rest of airgenome) |
| Roadmap conds | `ghost.cond.<n>` |
| Roadmap blockers | `ghost.blk.<n>` |
| Audit log | `state/ghost_audit.jsonl` (metadata only — see G2) |
| Run logs | `state/runs/ghost_<tier>_<ts>.jsonl` |
| Commit prefix | `🕶️ ghost: <verb-phrase>` (optional emoji per G6) |

## Pronunciation note (low-stakes)

GHOST (English) / 고스트 (Korean). The module dir is just `ghost`.
