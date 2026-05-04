---
doc: ghost.cpre.scope
kind: core_preamble
audience: [human, agent]
mk: 1
since: 2026-05-04
parent: airgenome.modules.ghost
---

# Scope — what is in, what is out

## In scope (allowed work)

### Operator-side opsec (PRIMARY MVP — see `intent.ai.md` tier=research)

- Researching puzzle addresses (privatekeys.pw, btcpuzzle.info)
- Querying mempool for #135 pubkey extraction
- Hitting Tor-blocked endpoints (some btcrecover docs, bitcointalk threads)
- Vast.ai / cloud-burst orchestration calls
- Any RPC node call that touches a watched address

**Backend default**: Mullvad MultiHop + DAITA. Foreign exit only — JP / SG / CH / SE.

### Sweep-tx broadcast routing (CRITICAL — see `intent.ai.md` tier=sweep)

The hand-off chain:

1. **wraith-wallet** builds the sweep tx OFFLINE; never calls local `sendrawtransaction`.
2. **ghost** routes the hand-off to a private relay (e.g. MARA Slipstream's web form) via a fresh Tor circuit over Mullvad — so the relay + ISP see traffic from the anonymous network only.
3. **Private relay** ingests directly into a non-public mempool, bypassing front-runners.

ghost's role is **network-layer egress only**. ghost does not construct, sign, or store transactions (G9).

### Generic operator browsing / research

Buying compute on Vast.ai, accessing exchange OTC desks, KYC-adjacent research, hitting CN/RU sources for academic papers. Throughput-priority, latency-tolerant.

**Backend default**: single-hop or multi-hop Mullvad WireGuard.

## Out of scope (hard line — never)

- **Customer-facing SaaS**. ghost stays operator-internal in MVP. SaaS triggers KR ISMS + PIPA + likely VASP-adjacent posture if crypto-paid. Phase 2 only after orpheus monetization is proven and KR regulatory review documented (cond.11).
- **Tor exit operation from a KR IP**. KR has aggressive KCSC/KCC takedown culture. Bridge or middle relay: lower risk; exit: do not.
- **VPN-over-Tor**. The reverse setup makes the VPN exit a fixed correlation endpoint — strictly weaker than Tor-over-VPN against timing/volume correlation (per design research §A.2). ghost will refuse this composition.
- **Cleartext traffic logging** of any kind (G2). ghost MUST NOT log request bodies, response bodies, full URLs, DNS qnames, or any payload byte. Only route metadata.
- **Telemetry that could deanonymize** (G3). ghost MUST NOT report operator IP / exit IP / public DNS results to orpheus or wraith-wallet. Status reports are tier+backend+health only.
- **Co-locating all three knowledges** (G5). ghost knows traffic patterns; orpheus knows recovery context; wraith knows wallet keys. No layer should know all three. ghost MUST NOT accept callbacks that include puzzle ids, BIP39 candidate positions, owner-proof contents, or signed tx hex.
- **AML / KYC evasion**. ghost is a privacy layer for legitimate operator opsec, not a tool for evading lawful disclosure. The same line wraith-wallet draws (W8 jurisdiction labeling) applies upstream of ghost: ghost's `link/` adapters cannot route traffic that would otherwise require W8 labeling without that labeling having occurred.
- **Mining**, **exchange targeting**, **phishing / malware delivery**, **adversarial privacy-coin tracing**. Same hard line orpheus and wraith-wallet draw.

## Why the hard line matters

ghost pairs with orpheus 🗝️ + wraith-wallet 🫥. All three are private repos / private modules. Their value depends on a clean operational thesis: "we recover lost value with consent or with creator's invitation, and we keep the operator's footprint defensible end-to-end." The moment that line softens, the project loses both its legal footing and the operator's ability to defend it. **Future-you (or future-agent) reading this:** if you find yourself debating whether a route qualifies, the answer is no.

## Korean jurisdictional posture (recap)

- VPNs are legal in KR. Mullvad routing through JP/SG/CH/SE is permitted for operator opsec.
- Tor is legal. Running a Tor exit FROM a KR IP is risky (no specific case law, but aggressive takedown culture). ghost will not configure a Tor relay or exit.
- Customer-facing scope (Phase 2) crosses ISMS + PIPA + possible VASP — kept out of MVP by design.

(Full table: design research doc §E.)
