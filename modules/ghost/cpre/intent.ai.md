---
doc: ghost.cpre.intent
kind: core_preamble
audience: [human, agent]
mk: 1
since: 2026-05-04
parent: airgenome.modules.ghost
---

# Intent — what ghost is for

ghost exists to **make the operator's network footprint vanish** while orpheus 🗝️ and wraith-wallet 🫥 do their work.

## The thesis

Bitcoin Puzzle bounty research (orpheus) and authenticated own-wallet recovery (wraith-wallet) generate two classes of network traffic that, if observed by an ISP/ASN/state-level adversary, could:

1. **Deanonymize the operator** — public puzzle research is fine, but a stable IP querying privatekeys.pw, mempool.space for #135 pubkey extraction, and Vast.ai control-plane within minutes paints a profile.
2. **Front-run a sweep** — broadcasting a recovered-key spend tx to the public mempool from an exposed-pubkey puzzle address ("Puzzle #69 cautionary tale", April 2025: 6.888 BTC lost) is a near-certain loss without network-layer hide + mempool-layer hide as **complementary** defenses.

ghost is the **network-layer hide**. MARA Slipstream is the **mempool-layer hide**. Neither replaces the other.

## What ghost is NOT

- ❌ Not a wallet. Tx construction lives in wraith-wallet (G9).
- ❌ Not a recovery tool. Key/seed work lives in orpheus.
- ❌ Not a B2C VPN. Customer-facing SaaS is Phase 2 only — see `scope.ai.md`.
- ❌ Not a re-implementation of WireGuard/Tor/Nym. ghost **wraps** (Mullvad CLI / system tor / Nym SDK) rather than reinventing — same pattern as orpheus wrapping `btcrecover` and wraith-wallet wrapping `cake-wallet`.

## What ghost IS

A small **policy + orchestration + kill-switch + audit** layer that selects the right wrapped backend per traffic tier and enforces the operator-opsec invariants (G1–G8).

## Tier model

| Tier | Use case | Default backend | Phase |
|---|---|---|---|
| `research` | orpheus puzzle/recovery HTTP, mempool queries, btcrecover docs | Mullvad MultiHop + DAITA | 1 (MVP) |
| `sweep` | wraith-wallet broadcast (Slipstream POST or equivalent) | fresh-circuit Tor over WireGuard | 1 (MVP) |
| `broadcast_high_value` | #135-class sweep (≥10 BTC) | Nym mixnet (5-hop NGM) | 2 |
| `customer` | (DEFER) customer-facing recovery contact | Nym mixnet | 2 |

## The economic frame

ghost itself is **free / internal-only** for MVP. Its value is captured indirectly:
- orpheus's revenue (puzzle bounty, recover finder's fee) only materializes if the sweep tx survives front-running. ghost is the dependency that makes the realized payout ≈ the on-paper bounty.
- wraith-wallet's broadcast-policy gate (W4) needs a tunnel-state oracle; ghost provides it (G4).

Customer-facing monetization deferred to Phase 2 (scope.ai.md §out + cond.10/11).

## Boundary with airgenome core

ghost is an **optional** airgenome subdomain. Disabling ghost does not break airgenome's core (probe / dispatch / harvest / label / forecast). Enabling ghost requires explicit user opt-in via a capability flag (cond.9) — kernel-level pf/NetworkExtension integration is risky and must be consented to.

## Cross-repo dependencies

- **orpheus** — calls `ghost::route(tier=research)` via a thin `link/orpheus.hexa` adapter (cond.11).
- **wraith-wallet** — calls `ghost::tunnel_alive()` before any broadcast (G4 cross-repo with W4); calls `ghost::route(tier=sweep)` for the actual POST (cond.11).
