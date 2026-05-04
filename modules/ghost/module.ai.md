---
doc: ghost.module
kind: module_ssot
audience: [human, agent]
mk: 1
since: 2026-05-04
status: scaffold
contributes_to: [ghost.cond.0, ghost.cond.1]
parent: airgenome.modules
glyph: 🕶️
---

# modules/ghost — network-layer anonymity (operator opsec)

Optional airgenome subdomain. Provides VPN-like / Tor / mixnet wrap so that orpheus 🗝️ research traffic and wraith-wallet 🫥 broadcast traffic never expose the operator's IP / ASN / fingerprint.

> **Trio**: `🗝️ orpheus → 🫥 wraith-wallet → 🕶️ ghost` = `produces key → custodies+signs+routes → routes anonymously at the network layer`.

## Sub-pattern (cpre + flat moduler, contained)

`modules/ghost/` adopts the `cpre+moduler` pattern from orpheus / wraith-wallet, but **contained inside this subdir only** — airgenome's main `modules/*.hexa` flat pattern is untouched.

```
modules/ghost/
├── cpre/
│   ├── intent.ai.md       ← why ghost exists (operator opsec for the trio)
│   ├── scope.ai.md        ← in: operator opsec, sweep broadcast egress, generic browse
│   │                          out: customer-facing SaaS (Phase 2), KYC bypass, fraud
│   ├── contracts.ai.md    ← G1–G10 (network single-edit, no cleartext, kill-switch, ...)
│   └── identity.ai.md     ← name origin, glyph 🕶️, trio reading
├── module.ai.md           ← (this file) — ghost subdomain SSOT
├── route.hexa             ← orchestrator: tier → backend selection + lifecycle FSM
├── wrap_mullvad.hexa      ← Mullvad CLI wrap (G1; default fast path, tier=research)
├── wrap_tor.hexa          ← system tor wrap (G1; default privacy path, tier=sweep)
├── wrap_nym.hexa          ← Nym SDK wrap stub (G1; Phase 2, tier=broadcast_high_value)
├── policy.hexa            ← G4 kill-switch + G5 knowledge gate + G8 jurisdiction allowlist
├── audit.hexa             ← G2 metadata-only ledger → state/ghost_audit.jsonl
├── selftest.hexa          ← G2 leak tests (DNS / IPv6 / WebRTC / SNI fingerprint)
└── .roadmap.ghost         ← cond list (12 conds; see §Roadmap below)
```

## Tier model

| Tier | Use case | Default backend (Phase 1) | Phase 2 upgrade |
|---|---|---|---|
| `research` | orpheus puzzle/recovery HTTP, mempool queries, Vast.ai control | Mullvad MultiHop + DAITA | — |
| `sweep` | wraith broadcast (Slipstream POST etc.) | fresh-circuit Tor over Mullvad | — |
| `broadcast_high_value` | #135-class sweep (≥10 BTC) | Tor over Mullvad | Nym mixnet 5-hop |
| `customer` (DEFER) | customer-facing recovery contact | — (Phase 2 only) | Nym mixnet |

## Surface (planned — defined as conds land)

The wrap_*.hexa files expose adapter functions; `route.hexa` exposes the public surface to the rest of airgenome and to cross-repo callers (orpheus / wraith-wallet, via the cond.11 link adapters):

```
ghost::up(tier: str) -> handle              # cond.4
ghost::down() -> ()                          # cond.4
ghost::route(tier: str) -> session_handle    # cond.4 + cond.11
ghost::tunnel_alive() -> bool                # cond.6 (cross-repo G4↔W4 gate)
ghost::selftest() -> report                  # cond.8
ghost::audit_emit(decision) -> ()            # cond.7 (G2 + G8 enforced)
```

Function signatures are illustrative; final hexa-lang signatures land per the conds.

## Status

`scaffold` — cond.0 met (research doc landed) + cond.1 in_progress (this commit lays the cpre + module.ai.md + 7 stubs + .roadmap.ghost). Conds 2–11 unmet.

See `.roadmap.ghost` for full cond list, verifiers, and per-cond status.

## Hard rules recap (from `cpre/contracts.ai.md`)

1. **G1** All egress only through `wrap_*.hexa` — single edit point per backend.
2. **G2** Never log cleartext traffic — only `{ts, tier, backend, exit_jurisdiction, rationale}` metadata.
3. **G4** Kill-switch — `ghost::tunnel_alive()` is the cross-repo gate; orpheus & wraith MUST check it before any external call.
4. **G5** Separation-of-knowledge — ghost ⊥ orpheus ⊥ wraith.
5. **G8** Foreign exit (JP/SG/CH/SE) for sweep tiers; no KR Tor exit ever.
6. **G9** ghost is HTTP egress only — never constructs, signs, or broadcasts a tx.

## Capability flag (cond.9)

Kernel-level pf / NetworkExtension integration is opt-in. Without the capability flag, ghost runs in userland-only mode (cooperative gate via `tunnel_alive()`), which provides the policy contract but not the kernel-level enforcement. The flag is set in airgenome's main settings, requires explicit user consent, and is reflected in `audit.jsonl` per session.

## Disabling ghost

Disabling the ghost subdomain (set `airgenome.modules.ghost.enabled = false` in airgenome config) does not affect airgenome core (probe / dispatch / harvest / label / forecast). Cross-repo callers (orpheus, wraith-wallet) handle a missing ghost the same way they handle any other unavailable substrate — by treating `tunnel_alive() == false` as the unconditional answer, which their policy gates already cover.
