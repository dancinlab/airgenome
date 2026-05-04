---
doc: airgenome.docs.ghost_feature_design_inbox
kind: feature_design_inbox
audience: [human, agent]
date: 2026-05-04
mk: 1
status: draft_inbox
origin: migrated_from_orpheus_docs_2026_05_04
note: ghost is being built as an optional feature INSIDE airgenome (not a separate repo); this doc was researched while ghost was still framed as a sibling product, but the recommendations on architecture / wrap-target / threat model still apply.
---

# ghost — feature design inbox (migrated from orpheus, framing change)

> **Framing change (2026-05-04):** this document was originally drafted as
> sibling-product research for a standalone `ghost` repo paired with
> `orpheus` + `wraith-wallet`. The plan changed: `ghost` is now being built
> as an **optional feature inside this repo (`airgenome`)**, not as a
> separate sibling. Throughout the body, references to "the ghost repo",
> "scaffold ghost", or any trio reading like
> `🗝️ orpheus → 🫥 wraith-wallet → 🕶️ ghost` should be reread as
> "the ghost feature inside airgenome." The design-space map, wrap-target
> evaluation, threat model, and operator-vs-customer scoping recommendations
> all still apply unchanged — only the packaging changes (feature, not repo).
> The orpheus and wraith-wallet repos no longer mention ghost; this is the
> single canonical location for the ghost research that informed the
> architectural choice.

# 🕶️ ghost — design research (network/anonymity layer)

> ghost sits at the **network layer** — VPN-like / anonymity-layer product. It is NOT a wallet, NOT crypto-recovery. It is the part of the stack that makes sure the operator's IP / ASN / fingerprint never leaks while orpheus + wraith-wallet do their work.

---

## §A. Design-space map (VPN / anonymity-layer architectures, 2026 state)

The eight-cell matrix below is the headline. Sources cited inline.

| Style | Throughput | Latency | Anonymity | Anti-correlation | Threat coverage | OSS maturity | KR posture | Integration effort |
|---|---|---|---|---|---|---|---|---|
| **Single-hop WireGuard / OpenVPN** | High (near line-rate; Mullvad GotaTun is Rust + zero-copy [per https://www.phoronix.com/news/GotaTun-Rust-WireGuard-OSS, 2026-05-04]) | Low (~10–50 ms) | Weak (provider sees you) | None | ISP/ASN observer only | Very mature (Mullvad GPLv3 client; GotaTun BSD-3 [per https://github.com/mullvad/gotatun, 2026-05-04]) | Legal in KR [per https://www.purevpn.com/blog/is-vpn-legal-in-korea/, 2026-05-04] | Trivial |
| **Multi-hop WireGuard (Mullvad/IVPN)** | High (small overhead) | Low–Mid (~30–100 ms) | Medium (entry+exit collusion required) | Limited | + ISP+single-provider compromise | Mature; Mullvad multi-hop = WG-in-WG [per https://mullvad.net/en/help/multihop-wireguard, 2026-05-04]; IVPN Dynamic MultiHop [per https://www.ivpn.net/privacy-guides/comparing-dvpns-centralized-vpns-privacy-protection/, 2026-05-04] | Same as single-hop (KR-legal) | Low |
| **Tor (onion routing)** | Low–Mid (~25 Gbit/s exits, ~60 Gbit/s non-exits aggregate; per-circuit a few Mbps [per https://metrics.torproject.org/bandwidth.html, 2026-05-04]) | High (300 ms–2 s typical) | Strong (3 hops, no node knows both ends) | Medium (vulnerable to global passive observer / end-to-end timing) | Most threat models except global passive | Very mature; pluggable transports work but vary [per https://arxiv.org/abs/2309.14856, 2026-05-04] | Tor itself legal; **exit-node operation in KR is risky** — KR has aggressive KCSC/KCC takedown culture [per https://www.lexology.com/library/detail.aspx?g=016a929c-ad58-4d1d-8bf6-807b4272863e, 2026-05-04] | Mid (well-documented SOCKS interface) |
| **Nym mixnet** | Low (Anonymous 5-hop mode is "for messaging / crypto / email" not browsing [per https://nym.com/, 2026-05-04]) | Very high (5-hop NGM = seconds; 2-hop dVPN mode is faster but only WireGuard-equivalent privacy [per https://nym.com/mixnet, 2026-05-04]) | Strongest (cover traffic + Sphinx mixing + nation-state-resistance claim [per https://fosdem.org/2026/schedule/event/U3UCKS-nym-mixnet/, 2026-05-04]) | Strongest (designed against timing/volume correlation) | All threat tiers including nation-state | Mature SDK (Rust + TypeScript) [per https://nym.com/docs/developers/rust, 2026-05-04]; production-ready as of 2026 | No KR-specific block surfaced [UNVERIFIED] | Mid–High (custom SDK, not transparent IP-layer VPN for arbitrary apps in mixnet mode) |
| **HOPR** | Low | High | Strong (Sphinx-based, layered enc) [per https://docs.hoprnet.org/core/mixnets, 2026-05-04] | Strong (mixnet pattern) | Same threat tier as Nym | Active but smaller mcap (~$12M) [per https://photomadic.com/what-is-hopr-hopr-crypto-coin-a-comprehensive-privacy-guide, 2026-05-04]; OSS [per https://github.com/hoprnet/hoprnet, 2026-05-04] | [UNVERIFIED for KR] | High (less tooling than Nym) |
| **Lokinet** | Low | Mid–High | Strong (onion routing) | Medium | Same as Tor-class | Active project; backed by Oxen ecosystem [per https://medium.com/hackernoon/net-neutrality-via-blockchain-analyzing-loki-network-tor-protocol-2-0-d44c75a802ff, 2026-05-04] | [UNVERIFIED for KR] | Mid |
| **dVPN — Mysterium / Sentinel / Orchid** | Mid–High (residential IPs) | Low–Mid | Medium (you trust random node operators) | Low (no mixing) | ISP/ASN observer; **adds attack surface from malicious node operators** | Active commercial; Mysterium 7,500+ residential IPs [per https://www.mysteriumvpn.com/decentralized-vpn, 2026-05-04]; Sentinel 3,500+ nodes [per https://www.privacytools.io/dvpn, 2026-05-04]; Orchid uses "trusted partner" exits [per https://www.privacytools.io/dvpn, 2026-05-04] | Crypto-payment surface may complicate KR VASP posture | Mid |
| **I2P** | Low | High | Strong (intra-I2P only — no general internet exit by default) | Strong (garlic routing) | Hidden services; not general egress | Active 2026; 40K+ routers; recovering from Feb 2026 Kimwolf botnet disruption [per https://krebsonsecurity.com/2026/02/kimwolf-botnet-swamps-anonymity-network-i2p/, 2026-05-04]; v2.10.0 added PQ test [per https://i2p.net/en/blog/, 2026-05-04] | [UNVERIFIED for KR] | High (no general egress) |
| **Hybrid: Tor-over-VPN** | Mid (Tor-bound) | High | Strong | Strong (entry-side ISP is masked) | Best practical posture for most threats — recommended pattern [per https://factually.co/fact-checks/technology/vpn-before-tor-or-after-tor-vpn-over-tor-vs-tor-over-vpn-anonymity-e3110c, 2026-05-04] | Same as Tor + same as VPN | Same as Tor + VPN | Low–Mid (chain two existing tools) |
| **Hybrid: VPN-over-Tor** | Low | High | Strong vs exit observation | **Weak** — VPN becomes fixed endpoint, exposes to global timing correlation [per https://factually.co/fact-checks/technology/vpn-before-tor-or-after-tor-vpn-over-tor-vs-tor-over-vpn-anonymity-e3110c, 2026-05-04] | NOT recommended generally | — | — | High |

### A.1 Performance honest baseline

- WireGuard single-hop on a modern CPU: line rate. Mullvad GotaTun (Rust, zero-copy) is current SOTA implementation [per https://github.com/mullvad/gotatun, 2026-05-04].
- Tor circuit: a few Mbps per circuit; site usability "browsing OK, large downloads/streaming poor" [per https://www.h25.io/tools/tor-browser-for-darknet-work-in-2026-a-detailed-overview-of-pros-and-cons/, 2026-05-04].
- Nym 5-hop mixnet mode: explicitly positioned for non-real-time use; 2-hop dVPN mode for browsing [per https://nym.com/mixnet, 2026-05-04]. Independent tests confirm "noticeable latency" in mixnet mode.
- I2P: tuned for hidden-service intra-I2P traffic, not general egress.

### A.2 Threat coverage delta

The single most important delta in §A: **Tor-over-VPN dominates VPN-over-Tor** for ghost's threat model. The reverse setup makes the VPN exit a fixed correlation endpoint [per https://factually.co/fact-checks/technology/vpn-before-tor-or-after-tor-vpn-over-tor-vs-tor-over-vpn-anonymity-e3110c, 2026-05-04]. ghost should never default to VPN-over-Tor.

---

## §B. Threat model spectrum

ghost-relevant threats and which architectures defend against each. Common knowledge skimmed per time budget.

| Threat | Defended by | Notes |
|---|---|---|
| Passive ISP / ASN observer | Single-hop VPN+ | ISP sees encrypted traffic to one IP. Most basic threat. |
| Active local network attacker (rogue Wi-Fi) | Single-hop VPN+ | TLS-only-with-no-VPN leaks SNI/DNS; VPN tunnel kills this. |
| Exit-node operator (Tor) | Tor-over-VPN; Nym (no exits) | Mitigated by trusting destination TLS, by .onion services, or by mixnets that don't have classic exit roles. |
| Compromised entry node / VPN provider | Multi-hop; Tor-over-VPN | Single-hop fails; 2+ hop reduces single-point compromise. |
| Traffic correlation (timing/volume) | Mixnet (Nym/HOPR); padding (DAITA — Mullvad) | DAITA (Defense Against AI-guided Traffic Analysis) is a Mullvad feature in GotaTun [per https://www.phoronix.com/news/GotaTun-Rust-WireGuard-OSS, 2026-05-04] but NOT a substitute for mixnet cover traffic against a global passive adversary. |
| State-level adversary (5/9/14 eyes; KR NIS; CN MSS) | Nym mixnet; pluggable-transport Tor | Single-hop VPN insufficient. Mixnet's noise generation is the only design that explicitly claims nation-state coverage [per https://fosdem.org/2026/schedule/event/U3UCKS-nym-mixnet/, 2026-05-04]. |
| DNS leak | VPN-internal DNS + kill switch | Standard. Kill-switch must block all egress when tunnel down [per https://www.crazywhy.com/2025/11/13/how-to-detect-vpn-leaks-dns-ipv6-and-webrtc-explained/, 2026-05-04]. |
| WebRTC leak | Browser-side mitigation; not solvable at network layer alone | ghost should provide browser-config guidance; cannot solve in VPN tunnel itself [per https://www.vpn.com/feature/webrtc-leak-protection/, 2026-05-04]. |
| IPv6 leak | IPv6 tunnel or block | Standard. |
| Application-layer fingerprint | Browser/UA hardening | Out of ghost's network-layer scope; document. |
| Operational telemetry from orpheus / wraith-wallet | Contract G3 (no telemetry that could deanonymize) | Cross-repo invariant; ghost cannot fix what its dependents leak. |
| Bitcoin tx broadcast IP-leak | Short-lived Tor connection per broadcast [per https://gist.github.com/brunoerg/62b03daa90470b1c02e5486d13e5e025, 2026-05-04]; or mixnet broadcast | This is the §C.2 use case. |
| Bitcoin RPC endpoint deanonymization (CVE-2025-43968) | Tor/mixnet RPC routing | Recent attack: TRAP — timing-based RPC user deanonymization [per https://arxiv.org/html/2508.21440v1, 2026-05-04]. |

---

## §C. ghost-specific use cases (synthesized from orpheus + wraith-wallet integration)

### C.1 Operator-side opsec (PRIMARY MVP)

User runs orpheus + wraith-wallet on a personal Mac. ghost ensures the user's ISP / ASN never sees:

- Researching puzzle addresses (privatekeys.pw, btcpuzzle.info)
- Querying mempool for #135 pubkey extraction
- Hitting Tor-blocked endpoints (some btcrecover docs / bitcointalk threads)
- Vast.ai / cloud-burst orchestration calls
- Any RPC node call that touches a watched address

**Architectural fit**: Tor-over-VPN, or Mullvad multi-hop with DAITA. Latency-tolerant; throughput-modest.

### C.2 Sweep-tx broadcast routing (CRITICAL — orpheus puzzle dependency)

When wraith-wallet broadcasts a sweep tx (puzzle solve / recovery payout), ghost is the **network-layer hide**. MARA Slipstream is the **mempool-layer hide** [per https://ir.mara.com/news-events/press-releases/detail/1343/marathon-digital-holdings-launches-slipstream, 2026-05-04]. The two are complements, not substitutes.

The puzzle #69 cautionary tale (per `puzzle_research_2026_05_04.ai.md` §I.5): broadcasting via public mempool from an exposed-pubkey puzzle address gets the solver front-run by kangaroo bots within minutes. The defense layered:

1. **wraith-wallet**: builds tx OFFLINE; never calls local node `sendrawtransaction`.
2. **ghost**: routes the hand-off to Slipstream's web form via Tor + mixnet (so MARA + ISP see traffic from anonymous network only).
3. **Slipstream**: ingests directly into MARA Pool, bypassing public mempool.

ghost's role in this chain is **network-layer egress for the Slipstream POST**. Bitcoin community guidance: broadcast over a short-lived Tor connection per tx [per https://gist.github.com/brunoerg/62b03daa90470b1c02e5486d13e5e025, 2026-05-04]. Mixnet broadcast (Nym/HOPR) is the stronger but slower alternative [per https://bitcoinmagazine.com/technical/why-mixnets-are-needed-to-make-bitcoin-private, 2026-05-04].

**Architectural fit**: Tor short-lived circuit per broadcast (default), mixnet for high-value sweeps (#135 tier).

### C.3 Customer-facing recovery service (DEFER — flag for future)

orpheus Track 2 ("recover") deals with customers. Some customers may want their inbound contact to be anonymous (high-net-worth, KR institutional gap per `recover_research_2026_05_04.ai.md` §2.4). Could ghost be a customer-side tool?

**Recommendation**: **out of MVP scope**. Customer-facing ghost = monetization, KR telecom-licensing exposure, fraud/AML pressure. Treat as a Phase 2 product (post-orpheus monetization proven).

### C.4 Generic operator browsing / research

Buying compute on vast.ai, accessing exchange OTC desks, KYC-adjacent research, hitting CN/RU sources for academic papers. All without exposing operator identity.

**Architectural fit**: Single-hop or multi-hop WireGuard (Mullvad-class). Doesn't need Tor; needs reliability and exit-jurisdiction control.

---

## §D. Build vs wrap decision (apply the orpheus pattern)

orpheus wraps `btcrecover` + `nexus qmirror`. wraith-wallet wraps `cake-wallet` (Stage 1, per project context). What does ghost wrap?

| Candidate | License | Maturity | Hexa-wrap effort | Vendor lock-in | Notes |
|---|---|---|---|---|---|
| **Tor (BSD-3)** | BSD-3 | Very mature | Low (SOCKS5 + control port) | None | Exit-node ecosystem fragility (CDN blocks, captchas) [per https://www.h25.io/tools/tor-browser-for-darknet-work-in-2026-a-detailed-overview-of-pros-and-cons/, 2026-05-04]. Also: KR posture for exit operation is risky. |
| **WireGuard (GPL2 kernel; userspace impls vary)** | GPL2 / various | Very mature | Low | None | Bare WireGuard = single-hop only; no anonymity, just tunnel. Needs orchestration to be useful for ghost. |
| **Mullvad client (GPLv3)** | GPLv3 | Very mature; SOTA UX [per https://github.com/mullvad/mullvadvpn-app, 2026-05-04] | Low (CLI wrap) | High (Mullvad-as-provider) | GotaTun is BSD-3 if we want to embed instead of wrap. DAITA built in. **Wrap-the-CLI is fastest path to working multi-hop.** |
| **Nym (Apache-style; SDK exists [per https://nym.com/docs/developers/rust, 2026-05-04])** | Apache-style | Mature SDK; production mixnet | Mid (Rust SDK from hexa is non-trivial) | Low (open protocol) | Stronger anonymity. Slower. The right answer if KR threat model is "NIS-grade adversary". |
| **Custom orchestration (Tor + Mullvad + Nym chained)** | varies | n/a | High | None | This is where ghost's value-add is. The wrap targets are above; the orchestration over them is ghost's core SSOT. |

**Recommendation**: **wrap Mullvad CLI as the base WireGuard layer**, **wrap Tor (system tor + arti) as the onion layer**, leave **Nym SDK as a Phase 2 optional module** (`backend_nym/`). Ghost's core differentiation is the **policy + orchestration + kill-switch + audit** layer, not a re-implementation of any of these.

This mirrors the orpheus pattern exactly: don't re-implement secp256k1; wrap collider + keyhuntM1CPU.

---

## §E. Korean jurisdictional considerations

| Question | Finding | Source |
|---|---|---|
| Are VPNs legal in KR? | Yes. KR ≠ DPRK. | https://www.purevpn.com/blog/is-vpn-legal-in-korea/, 2026-05-04 |
| Does KCC license VPN providers? | No specific 2026 VPN-provider license requirement surfaced; KCC + KISA do general site/SNI takedowns and ISMS oversight | https://www.lexology.com/library/detail.aspx?g=016a929c-ad58-4d1d-8bf6-807b4272863e, 2026-05-04 |
| Tor relay/exit operation in KR? | No KR-specific case law surfaced; **EFF generic risk applies** (abuse complaints, possible police inquiries); KR's aggressive takedown culture suggests **do not run an exit node from KR**. Bridge or middle relay = lower risk. | https://www.eff.org/pages/legal-faq-tor-relay-operators, 2026-05-04; [UNVERIFIED specific KR cases] |
| Customer-facing VPN as B2C SaaS in KR? | Likely needs **VATP/VASP-adjacent posture** if accepting crypto payment; if fiat-only, falls under general telecom-resale rules. ISMS cert (KISA) effectively required for any production SaaS handling KR personal data | per Lexology cybersecurity in KR [per same Lexology link]; [UNVERIFIED specific telecom-license rule] |
| KR-friendly exit jurisdictions | JP (low-friction, low-latency, KR-adjacent); SG (mature legal); CH (Mullvad headquarters posture); SE (Mullvad headquarters). Avoid US/UK for state-actor threat model. | analyst synthesis |
| KR data-protection (PIPA) implications | Personal Information Protection Act applies if ghost ever processes KR user data; "no logs" must be enforceable not just claimed | https://practiceguides.chambers.com/practice-guides/data-protection-privacy-2026/south-korea/trends-and-developments, 2026-05-04 |

**Synthesis**: For operator-only MVP, **KR jurisdictional risk is minimal** (use VPN, route to JP/SG/CH/SE, don't run a Tor exit from a KR IP). For customer-facing Phase 2, KR exposure becomes large (ISMS, PIPA, possible VASP if crypto-paid).

---

## §F. Repo + package shape (mirror orpheus exactly)

```
ghost/
├── cpre/
│   ├── intent.ai.md            ← why ghost exists (network-layer hide for orpheus+wraith)
│   ├── scope.ai.md             ← in: operator opsec, sweep-broadcast hide, generic research
│   │                              out: customer-facing SaaS (Phase 2), KYC bypass, fraud
│   ├── contracts.ai.md         ← G1–G8 (see §G)
│   └── identity.ai.md          ← name origin (ghost / 🕶️), pairing with orpheus + wraith
├── modules/
│   ├── core/                   ← orchestrator: policy → backend selection → tunnel lifecycle
│   ├── backend_wireguard/      ← Mullvad CLI wrap (default fast path)
│   ├── backend_tor/            ← system tor / arti wrap (default privacy path)
│   ├── backend_nym/            ← Nym SDK wrap (Phase 2; optional)
│   ├── policy/                 ← jurisdiction tagging, hop-count rules, threat-model declarations per route
│   ├── network/                ← single edge-of-system file ring; only place that opens sockets
│   ├── kill_switch/            ← system firewall integration (pf on macOS / nftables on Linux); enforces G4
│   ├── audit/                  ← no-cleartext-log enforcement; route-decision provenance log
│   ├── leak_test/              ← DNS / WebRTC / IPv6 / SNI leak self-test runner
│   └── link/
│       ├── orpheus.hexa        ← contract surface for orpheus (e.g. "I'm fetching pubkey, give me research-tier route")
│       ├── wraith.hexa         ← contract surface for wraith-wallet (e.g. "I'm broadcasting, give me sweep-tier route")
│       ├── slipstream.hexa     ← MARA Slipstream POST adapter (network-layer egress only; hex from wraith)
│       └── vast.hexa           ← vast.ai control-plane adapter (orchestrating cloud-burst from anonymous network)
├── docs/
│   ├── architecture_<DATE>.ai.md
│   ├── threat_model_<DATE>.ai.md
│   ├── jurisdiction_matrix_<DATE>.ai.md
│   └── upstream_<provider>_<DATE>.ai.md   ← e.g. asks of Mullvad / Nym
├── state/
│   ├── routes/                 ← per-session route decision log (jurisdiction + threat-tier + tunnel ids)
│   ├── runs/                   ← run logs (no traffic content; only route metadata)
│   └── leak_reports/           ← leak_test outputs
├── bin/
│   └── ghost                   ← CLI entrypoint (`ghost up --tier=sweep`, `ghost test-leaks`, etc.)
├── .roadmap.ghost              ← cond list (see §H)
├── .gitignore                  ← excludes state/ contents
└── README.md
```

### F.1 Module SSOT-level descriptions

- **core/**: tunnel-lifecycle state machine (down → connecting → up → degrading → killed). Holds the policy decision per session.
- **backend_wireguard/**: shells to Mullvad CLI (`mullvad relay set …`, `mullvad connect`); reads status; exposes hexa-side handle.
- **backend_tor/**: spawns / reuses local tor; SOCKS5 + control-port; per-broadcast circuit isolation for §C.2.
- **backend_nym/** (Phase 2): Nym Rust SDK via hexa-FFI or subprocess bridge; mixnet mode only.
- **policy/**: declarative rules — `tier=research → wg-multi-hop`; `tier=sweep → tor-fresh-circuit + (optional) nym`; `tier=customer → nym (Phase 2)`.
- **network/**: the **only** ring of files allowed to bind sockets or call DNS. Everything else MUST go through this module. (This is G1.)
- **kill_switch/**: maintains pf/nftables rules; on tunnel-down, blocks all egress except localhost + the tunnel's reconnect target. Hooks into core/'s state machine.
- **audit/**: append-only JSONL of route decisions: `{ts, requester, tier, backend, jurisdiction, rationale, no_content}`. Never logs cleartext.
- **leak_test/**: runs DNS/WebRTC/IPv6 probes; emits leak_reports/.
- **link/**: cross-repo single-edit-points (mirrors orpheus's `modules/link/`).

---

## §G. Contracts (G1–G8) — analog of orpheus C1–C7 / wraith W1–W8

### G1 — All external network access goes through `modules/network/`

- ❌ Forbidden: any `.hexa` outside `modules/network/` opens a socket, calls DNS, or hits the OS network APIs directly.
- ✅ Required: all egress is mediated by `modules/network/` adapters.
- **Why**: single chokepoint for kill-switch enforcement and route-decision audit. Mirrors orpheus C1.

### G2 — No log of cleartext traffic, ever

- ❌ Forbidden: any module writing request bodies, response bodies, URLs (full path), DNS queries (qname), or any byte of payload.
- ✅ Required: route metadata only — `{ts, tier, backend, jurisdiction, rationale}`.
- **Why**: ghost is the privacy layer; if ghost logs the very traffic it's hiding, the threat model collapses. This is the analog of orpheus C3 (encrypt-at-rest) shifted to "never-write-at-all".

### G3 — No telemetry to orpheus / wraith-wallet that could deanonymize

- ❌ Forbidden: ghost reporting tunnel-up status to orpheus/wraith with operator-identifying detail (real IP, exit IP, public DNS results).
- ✅ Required: status reports are tier+backend+health only; never IP-revealing.
- **Why**: separation-of-knowledge. orpheus knows recovery context; wraith knows wallet keys; ghost knows traffic patterns. **No single layer should know all three**. (See G5.)

### G4 — Kill-switch — if ghost layer drops, dependent processes pause

- ❌ Forbidden: orpheus or wraith-wallet sending a request when ghost reports tunnel-down.
- ✅ Required: ghost exposes a "tunnel-state" gate; orpheus/wraith MUST check before any external call. (Analog of wraith W4 broadcast-gate, but for the ghost-tunnel.) Backed at the OS layer by `kill_switch/`.
- **Why**: a momentary tunnel drop without a gate exposes the operator IP for the duration. Belt-and-suspenders.

### G5 — Separation-of-knowledge — ghost knows traffic patterns; orpheus knows recovery context; wraith knows wallet keys; no single layer knows all three

- ✅ Required: each repo's `link/` module enforces the surface contract — orpheus can request "research-tier route" but never tells ghost what address it's about to query; wraith can request "sweep-tier route" but never tells ghost what tx hex it carries.
- **Why**: the operational pitch (`recover_research_2026_05_04.ai.md` §5.5: the "we know your seed now" trust gap) is structurally addressed only by separating the three knowledges across repos.

### G6 — ai-native doc cadence

- ✅ Required: every module has `module.ai.md` SSOT; every non-trivial decision dropped into `docs/<topic>_<YYYY_MM_DD>.ai.md`; `.roadmap.ghost` `cond.*` stays current. Mirror of orpheus C6.

### G7 — No `.py` files committed

- Mirror of orpheus C7 / nexus raw#9. Python via subprocess bridge if absolutely needed.

### G8 — Jurisdiction-explicit — every routing decision tags exit jurisdiction + threat-model rationale

- ❌ Forbidden: ghost selecting an exit at random or by latency alone.
- ✅ Required: each route decision includes `{exit_jurisdiction, threat_model_tier, rationale}` in the audit log.
- **Why**: orpheus/wraith operate across KR/JP/SG/CH/US — operator must be able to reconstruct, after the fact, "why was that traffic egressing through US?". This is the operational discipline the `recover_research_2026_05_04.ai.md` §5 legal landscape implies.

### Possible additions (open for refinement)

- **G9 (proposed)**: ghost MUST never broadcast a Bitcoin tx itself. (Tx-construction is wraith's job; ghost is only the network egress.) — analog of orpheus C2.
- **G10 (proposed)**: live-mode honesty — when ghost falls back from mixnet to plain VPN due to outage, the audit log MUST record the downgrade and dependent services MUST be notified (so wraith can refuse a sweep broadcast on a degraded tier). Analog of orpheus C5 (qmirror live-vs-mock honesty).

---

## §H. Roadmap conds (`.roadmap.ghost`, draft)

| Cond | Goal | Verifier sketch | Depends on |
|---|---|---|---|
| `ghost.cond.0` | Repo scaffolded; cpre/ files written; README; .roadmap.ghost initialized | `ls cpre/*.ai.md` returns 4; `head -1 .roadmap.ghost` is JSONL header | — |
| `ghost.cond.1` | `modules/network/` chokepoint defined; G1 enforced via grep test | grep for raw socket/DNS calls outside modules/network/ returns empty | cond.0 |
| `ghost.cond.2` | `backend_wireguard/` Mullvad-CLI wrap working; `ghost up --backend=wg --tier=research` returns tunnel-up | `mullvad status` shows connected; leak_test/ shows no leak | cond.0 |
| `ghost.cond.3` | `backend_tor/` system-tor wrap; `ghost up --backend=tor --tier=sweep` returns SOCKS5 endpoint | curl through SOCKS resolves through Tor exit | cond.0 |
| `ghost.cond.4` | `kill_switch/` integrated (macOS pf MVP); G4 enforced — disconnect tunnel and confirm no egress | run `mullvad disconnect`; tail of `nettop` shows zero traffic | cond.2 |
| `ghost.cond.5` | `leak_test/` runs DNS/WebRTC/IPv6 probes; report archived in state/leak_reports/ | `ghost test-leaks` returns clean for all four probe classes | cond.2 |
| `ghost.cond.6` | `policy/` declarative rules + `audit/` JSONL log; G2 + G8 enforced | every `ghost up` produces an audit-log line with jurisdiction+rationale | cond.2 |
| `ghost.cond.7` | `link/orpheus.hexa` + `link/wraith.hexa` contract surfaces wired; orpheus/wraith can request a tier and receive a gated handle | mock orpheus call returns a handle; tier downgrade triggers G4 gate | cond.4, cond.6 |
| `ghost.cond.8` | `link/slipstream.hexa` POST adapter — wraith hands hex, ghost POSTs to Slipstream over fresh-circuit Tor | end-to-end test on a dummy non-broadcast hex | cond.3, cond.7 |
| `ghost.cond.9` | Tor-over-VPN composite mode (cond.2 + cond.3 chained); G8 audit log records both hops + jurisdictions | composite tunnel passes leak_test; audit log shows wg-entry + tor-exit | cond.2, cond.3 |
| `ghost.cond.10` (Phase 2) | `backend_nym/` Nym SDK wrap; mixnet-tier route option for sweep-tier broadcasts | `ghost up --backend=nym --tier=sweep` produces working mixnet egress | cond.6 |
| `ghost.cond.11` (Phase 2) | Customer-facing surface scoped + KR ISMS/PIPA preliminary review documented | doc lands in docs/jurisdiction_matrix_*.ai.md | cond.10 |

`cond.0`–`cond.9` = MVP. `cond.10`–`cond.11` = Phase 2.

---

## §I. Open questions (user decisions before scaffold)

For each: the **recommended default** is in **bold**. Saying "go with defaults" picks the bolds.

1. **Operator-only OR customer-facing?**
   → **Operator-only for MVP**. Customer-facing as Phase 2 only after orpheus monetization is proven and KR ISMS/PIPA cleared. Customer-facing introduces VASP-adjacent regulatory exposure too early.

2. **Wrap WireGuard/Tor/Nym OR build hybrid orchestration?**
   → **Wrap Mullvad CLI (WireGuard layer) + system tor (onion layer); orchestration over them is ghost's core SSOT. Nym SDK as Phase 2 optional `backend_nym/`.** Mirrors how orpheus wraps collider/keyhuntM1CPU rather than re-implementing secp256k1.

3. **Single-hop VPN OR mandatory multi-hop / mixnet?**
   → **Tier-based: research-tier defaults to multi-hop WireGuard (Mullvad MultiHop + DAITA); sweep-tier defaults to fresh-circuit Tor over WireGuard; high-value sweep (#135-class) optionally upgrades to Nym mixnet (Phase 2).** Mandatory mixnet everywhere kills usability without payoff for the §C.4 generic-browse use case.

4. **KR-resident infrastructure OR foreign-only exit?**
   → **Foreign-only exit for sweep + sensitive research. JP / SG / CH / SE preferred. Never run a Tor exit from a KR IP.** KR-side infrastructure for non-sensitive ops only (e.g., reaching Korbit OTC desk where KR-source traffic is expected).

5. **Free / internal-only OR monetized SaaS?**
   → **Free / internal-only for ghost MVP.** SaaS layer is a separate Phase 2 product and triggers KR ISMS/PIPA + likely VASP-adjacent posture if crypto-paid. Don't bundle the regulatory cost into v0.

6. **Glyph 🕶️ OK as final?**
   → **Yes** — already decided per orpheus README + cpre/identity.ai.md (2026-05-04). Locked.

---

## Recommended scaffold path

When the user says "go with that": the next bg agent creates `../ghost/` mirroring orpheus's structure exactly — write `cpre/{intent,scope,contracts,identity}.ai.md` (intent: network-layer hide for orpheus+wraith trio; scope: operator-only MVP per §C.1+§C.2+§C.4, defer customer-facing per §C.3; contracts: G1–G8 from §G; identity: 🕶️, name origin, paired-trio reading), write `README.md` (mirroring orpheus README's structure with the trio table from `cpre/identity.ai.md`), initialize `.roadmap.ghost` JSONL with the 12 conds from §H (cond.0 = scaffold itself, marked closed by the scaffold commit), create empty `modules/{core,backend_wireguard,backend_tor,policy,network,kill_switch,audit,leak_test,link}/` directories each with a `module.ai.md` placeholder describing the §F SSOT-level intent, drop `docs/architecture_<DATE>.ai.md` derived from this design doc, and **move this design doc from `orpheus/docs/sibling_ghost_design_2026_05_04.ai.md` to `ghost/docs/sibling_ghost_design_2026_05_04.ai.md`** as the founding research artifact. No `.hexa` code in the scaffold round — that's cond.2+ work. This mirrors how orpheus + wraith-wallet started: cpre + module SSOTs first, code second.

---

> Cross-references:
> - orpheus README: `../orpheus/README.md`
> - orpheus cpre: `../orpheus/cpre/{intent,scope,contracts,identity}.ai.md`
> - orpheus architecture ADR: `../orpheus/docs/architecture_2026_05_04.ai.md`
> - Korean market context: `../orpheus/docs/recover_research_2026_05_04.ai.md` §2.4, §5.3
> - MEV-killshot context: `../orpheus/docs/puzzle_research_2026_05_04.ai.md` §I.5, §4 case studies, §5 risks
