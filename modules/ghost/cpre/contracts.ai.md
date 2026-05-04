---
doc: ghost.cpre.contracts
kind: core_preamble
audience: [human, agent]
mk: 1
since: 2026-05-04
parent: airgenome.modules.ghost
---

# Contracts — invariants that must hold across all `modules/ghost/` files

These are subdomain-wide rules. Violating any of them is a **stop-the-line bug**, not a style nit. Mirrors orpheus C1–C7 / wraith-wallet W1–W8 in spirit; numbered G1–G10 here.

## G1 — All external network access only via `wrap_*.hexa`

- ❌ Forbidden: any `.hexa` outside `modules/ghost/wrap_mullvad.hexa`, `wrap_tor.hexa`, `wrap_nym.hexa` opens a socket, calls DNS, or shells to a network tool (`curl`, `wget`, `mullvad`, `tor`, `nymcli`, etc.).
- ✅ Required: every egress is mediated by exactly one wrap_*.hexa adapter. Single edit point per backend.
- **Why**: single chokepoint for kill-switch enforcement (G4) and route-decision audit (G8). Mirrors orpheus C1 (qmirror via single CLI) and wraith W1 (wallet-tools via single link/).

## G2 — No log of cleartext traffic, ever

- ❌ Forbidden: any module writing request bodies, response bodies, full URLs (path + query), DNS query names, or any byte of payload.
- ✅ Required: route metadata only — `{ts, requester, tier, backend, exit_jurisdiction, rationale, no_content: true}`.
- **Why**: ghost is the privacy layer; if ghost logs the very traffic it's hiding, the threat model collapses. Analog of orpheus C3 (encrypt-at-rest) shifted to "never-write-at-all" because we don't even have a key to encrypt with.

## G3 — No telemetry to orpheus / wraith-wallet that could deanonymize

- ❌ Forbidden: ghost reporting tunnel-up status to orpheus / wraith-wallet with operator-identifying detail (real IP, exit IP, public DNS results, ASN strings).
- ✅ Required: status reports are `{tier, backend, health: "up"|"degraded"|"down"}` only — never IP-revealing.
- **Why**: separation-of-knowledge enforcement at the cross-repo seam (see G5).

## G4 — Kill-switch — if ghost layer drops, dependent ops pause

- ❌ Forbidden: orpheus or wraith-wallet sending a request when ghost reports `health=down`.
- ✅ Required: ghost exposes `ghost::tunnel_alive() -> bool` as a gate. orpheus's outbound HTTP and **wraith-wallet's broadcast (W4)** MUST check this gate before any external call.
- ✅ Required: kernel-level enforcement via `policy.hexa` opt-in capability flag (cond.9): pf on macOS / nftables on Linux blocks all egress except localhost + the tunnel reconnect endpoint when ghost is down. Userland gate is the cooperative layer; kernel gate is the belt-and-suspenders.
- **Why**: a momentary tunnel drop without a gate exposes the operator IP for the duration. Cross-repo with wraith W4 (broadcast policy gate).

## G5 — Separation-of-knowledge

- ✅ Required: ghost knows traffic patterns; orpheus knows recovery context; wraith-wallet knows wallet keys. **No single layer ever sees all three.**
- ✅ Required: each cross-repo `link/*.hexa` adapter (cond.11) enforces the surface contract — orpheus can request "research-tier route" but never tells ghost what address it's about to query; wraith can request "sweep-tier route" but never tells ghost what tx hex it carries.
- ❌ Forbidden: any ghost API that accepts puzzle ids, BIP39 candidate positions, owner-proof contents, raw tx hex, or any other recovery/wallet identifier.
- **Why**: a compromise of any single layer must not collapse the trio. The "we know your seed now" trust gap (orpheus `recover_research_2026_05_04.ai.md` §5.5) is structurally addressed only by separating the three knowledges across boundaries.

## G6 — ai-native doc cadence

- ✅ Required: `modules/ghost/module.ai.md` (subdomain SSOT) updated when surface or contract changes.
- ✅ Required: every non-trivial decision dropped into airgenome-level `docs/<topic>_<YYYY_MM_DD>.ai.md`.
- ✅ Required: `modules/ghost/.roadmap.ghost` `ghost.cond.*` status stays current.
- **Why**: ghost shares airgenome's repo but is operator-sensitive. Six months from now, the only continuity is the docs. Mirror of orpheus C6 / wraith W6.

## G7 — No `.py` files committed

- Mirror of orpheus C7 / wraith W7 / nexus raw#9.
- Python invocation, if absolutely needed (e.g. `stem` for advanced Tor control), goes through subprocess + isolated venv via airgenome's existing `_python_bridge/` pattern (if/when introduced) — never via committed `.py` source in this subdomain.

## G8 — Jurisdiction-explicit — every routing decision tags exit jurisdiction + threat-model rationale

- ❌ Forbidden: ghost selecting an exit at random or by latency alone.
- ✅ Required: each route decision logs `{exit_jurisdiction, threat_model_tier, rationale}` to `state/ghost_audit.jsonl`.
- ✅ Required: `policy.hexa` enforces the foreign-exit allowlist (`JP|SG|CH|SE`) for tier ∈ {sweep, broadcast_high_value}. KR exit is permitted only for tier=generic_browse where KR-source traffic is expected (Korbit OTC, KR research papers).
- ❌ Forbidden: KR Tor exit — `policy.allow_kr_tor_exit = false`, hard-coded.
- **Why**: operator must be able to reconstruct, after the fact, "why was that traffic egressing through US?". Operational discipline carried over from orpheus jurisdictional research.

## G9 — ghost MUST NEVER broadcast a Bitcoin tx itself

- ❌ Forbidden: ghost calling `sendrawtransaction`, posting a tx hex to a private relay endpoint, or constructing any transaction.
- ✅ Required: ghost's role at sweep-tier is **HTTP/HTTPS egress** only. The POST body comes pre-formed from wraith-wallet via `link/wraith.hexa` (cond.11); ghost is a transparent transport.
- **Why**: G5 knowledge separation. wraith-wallet owns tx construction (W2/W3); ghost owns egress only. Analog of orpheus C2 (no signing/broadcast in orpheus).

## G10 — Live-mode honesty — fall-back downgrades MUST be recorded and surfaced

- ❌ Forbidden: ghost silently falling back from mixnet → tor, or tor → plain VPN, on backend outage.
- ✅ Required: each downgrade is recorded in `state/ghost_audit.jsonl` with `{event: "downgrade", from: <tier>, to: <tier>, reason}`, and ghost reports `health=degraded` (not `up`) until the original tier recovers. Dependent ops (wraith broadcast on sweep tier) MUST refuse on `degraded` per their own policy gate.
- **Why**: operator's threat model assumes the tier they requested was honored. A silent downgrade quietly weakens the entire chain. Analog of orpheus C5 (qmirror live-vs-mock honesty) and wraith W5 (mode honesty).

## Summary table

| Contract | Single-line statement |
|---|---|
| G1 | External network access only via `wrap_*.hexa` (single edit point per backend) |
| G2 | No cleartext traffic logging, ever |
| G3 | No deanonymizing telemetry to orpheus / wraith-wallet |
| G4 | Kill-switch gate; tunnel-down → dependent ops pause (cross-repo with W4) |
| G5 | Separation-of-knowledge (ghost=traffic / orpheus=recovery / wraith=keys) |
| G6 | ai-native doc cadence (module.ai.md + docs/<topic>_<DATE>.ai.md + .roadmap.ghost) |
| G7 | No `.py` files committed |
| G8 | Jurisdiction-explicit routing decisions (foreign exit, no KR Tor exit) |
| G9 | ghost MUST NEVER broadcast a tx itself (egress-only role) |
| G10 | Live-mode honesty — fall-back downgrades recorded + surfaced as `degraded` |
