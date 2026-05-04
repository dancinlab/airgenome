---
doc: airgenome.docs.ghost_backend_comparison
kind: feature_research
audience: [human, agent]
date: 2026-05-04
mk: 1
status: draft
contributes_to: [ghost.cond.2, ghost.cond.3, ghost.cond.10]
---

# ghost — backend comparison (network-layer wrap targets), 2026-05-04

> Companion to `ghost_feature_design_inbox_2026_05_04.ai.md`. The design doc
> picked Mullvad CLI + system Tor (Phase 1) + Nym SDK (Phase 2). This doc
> stress-tests that pick against the full 2026 candidate field — IVPN
> dynamic-multihop, Proton secure-core, ExpressVPN Lightway, NordVPN
> Onion-over-VPN, Surfshark Dynamic MultiHop, AirVPN/Eddie, arti, HOPR,
> Lokinet, I2P, Mysterium, Sentinel, Orchid, raw WireGuard, Headscale —
> and asks: do we need to add or swap any? Each row of the matrix is a
> wrap-target candidate; the recommendation in §6 is the actual delta
> against `.roadmap.ghost`.

---

## §1. Headline (TL;DR)

**Phase 1 unchanged.** Mullvad CLI (multi-hop + DAITA) for `tier=research`
and system tor (fresh-circuit-per-broadcast, optionally chained over
Mullvad) for `tier=sweep` remain the right defaults: GotaTun finished its
first independent audit in March 2026 [per https://mullvad.net/en/blog/2026/3/6/a-security-audit-of-gotatun-is-now-available, 2026-05-04],
Mullvad has KR + JP + SG + CH + SE servers [per https://mullvad.net/en/servers, 2026-05-04],
and Tor's Arti 2.0.0 (Feb 2026) is now the modern Rust client surface for
clean integration if/when we re-evaluate [per https://forum.torproject.org/t/arti-1-0-0-is-released-our-rust-tor-implementation-is-ready-for-production-use/4446, 2026-05-04].

**One additive recommendation.** Add **Proton VPN secure-core** as a
*second* `tier=research` backend behind a feature flag (parallel to
Mullvad, not replacing). Reason: secure-core's CH/IS/SE entry-pin gives
G8 jurisdictional discipline without operator-side server-pinning, and
Proton tops independent throughput tables (~950 Mbps WireGuard on
1 Gbit lines [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04]).
Effort is low (CLI wrap, same single-edit-point shape as Mullvad).

**One additive recommendation for sweep tier.** Keep Nym mixnet as the
`broadcast_high_value` Phase-2 default, but **add Nym dVPN 2-hop AmneziaWG
mode as a `tier=sweep` *alternative* path** when mixnet latency is too high
to coordinate with Slipstream's HTTP timeout. Nym dVPN ≈ WireGuard-class
privacy with Nym's noise-generating exit posture
[per https://nym.com/mixnet, 2026-05-04].

**Reject** ExpressVPN, NordVPN, Surfshark, Mysterium, Sentinel, Orchid,
Lokinet, I2P, raw Headscale for ghost. Reasons in §3 / §6.

**Cond impact.** ghost.cond.2 scope widens to *N* WireGuard-class
backends behind a single trait (Mullvad, optionally Proton); cond.3
unchanged; cond.10 splits into cond.10a (Nym mixnet 5-hop, the existing
target) + cond.10b (Nym dVPN 2-hop). Detail in §7.

---

## §2. Comparison matrix

Axes (1) throughput, (2) latency, (3) anonymity tier, (4) multi-hop /
mixing, (5) privacy posture, (6) license, (7) KR posture, (8) integration
effort, (9) YouTube viability, (10) phase fit.

| Backend | (1) Throughput | (2) Latency | (3) Anon tier | (4) Multi-hop / mixing | (5) Privacy posture | (6) License | (7) KR posture | (8) Integration | (9) YouTube | (10) Phase fit |
|---|---|---|---|---|---|---|---|---|---|---|
| **Mullvad** | ~700–900 Mbps WG single-hop, GotaTun zero-copy [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04] | 10–50 ms single-hop; 30–100 ms multi-hop [per https://mullvad.net/en/help/multihop-wireguard, 2026-05-04] | medium (multi-hop) | WG-in-WG MultiHop; user picks entry+exit; DAITA timing pad [per https://mullvad.net/en/blog/announcing-gotatun-the-future-of-wireguard-at-mullvad-vpn, 2026-05-04] | Cash, Monero (10% disc), numbered acct (no email); GotaTun audit Feb 2026 by Assured (no critical/high) [per https://mullvad.net/en/blog/2026/3/6/a-security-audit-of-gotatun-is-now-available, 2026-05-04]; SE jurisdiction; RAM-only servers | GPLv3 client; GotaTun BSD-3 [per https://github.com/mullvad/gotatun, 2026-05-04] | KR + JP + SG + CH + SE servers all present [per https://mullvad.net/en/servers, 2026-05-04]; KR-legal | trivial (CLI shell-out) | 1080p yes, 4K yes | research-tier default |
| **IVPN** | ~500–800 Mbps WG [UNVERIFIED single primary source; cyberinsider has it ≈ Mullvad-class] | 20–60 ms; multi-hop 40–120 ms [UNVERIFIED] | medium | **Dynamic MultiHop**: customer picks any-entry + any-exit pair (more flexible than Mullvad) [per https://www.ivpn.net/en/, 2026-05-04] | Token signup (no email/no PI required); Cure53 audited (low-only findings) + Trail of Bits 2026 (no protocol weakness) [per https://www.ivpn.net/blog/ivpn-no-logging-claim-verified-by-independent-audit, 2026-05-04] [UNVERIFIED-exact-2026-ToB-scope]; Gibraltar jurisdiction; Monero accepted | GPLv3 (clients); server stack closed | KR server [UNVERIFIED — IVPN published list smaller than Mullvad's]; JP/SG/CH/SE all present [per https://www.ivpn.net/en/, 2026-05-04] | trivial (CLI shell-out, similar to Mullvad) | 1080p yes, 4K yes [per https://www.cloudwards.net/ivpn-review/, 2026-05-04] | research-tier alternative; not strictly needed if Proton lands |
| **Proton VPN** | **~950 Mbps WG / 1,548 Mbps on 10G lines** [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04] | 10–40 ms single-hop; secure-core adds 40–120 ms hop into CH/IS/SE [per https://protonvpn.com/support/secure-core-vpn, 2026-05-04] | medium-strong (secure-core multi-hop) | **Secure Core**: forces entry through CH / IS / SE only (jurisdiction-pinned); NetShield DNS filter; Stealth = WG-over-TLS [per https://protonvpn.com/features/secure-core, 2026-05-04] | Securitum no-logs audit 2025; full-disk-encrypted secure-core servers [per https://protonvpn.com/features/no-logs-policy, 2026-05-04] [per https://www.securitum.com/public-reports/securitum-protonvpn-nologs-2025.pdf, 2026-05-04]; Swiss jurisdiction (no 14 Eyes); cash/BTC accepted, Monero limited [per https://www.monero.how/best-vpns-that-accept-monero, 2026-05-04] | GPLv3 clients (open source) [per https://protonvpn.com/, 2026-05-04] | KR servers present [per https://protonvpn.com/, 2026-05-04]; JP/SG present; secure-core through CH/IS/SE only | low (CLI wrap; `protonvpn-cli` exists) | 1080p yes, 4K yes | **propose: research-tier alternative** |
| **ExpressVPN** | high (Lightway-Rust 2024) [UNVERIFIED specific 2026 Mbps] | low | medium | no formal multi-hop mode | Cure53 + Praetorian 2024 audits of Lightway [per https://www.expressvpn.com/blog/cure53-lightway-audit/, 2026-05-04]; BVI jurisdiction (no data retention) [per https://en.wikipedia.org/wiki/ExpressVPN, 2026-05-04]; KYC payment funnel | Lightway core open-source, client closed [per https://github.com/expressvpn/lightway-core, 2026-05-04] | KR servers present [per https://www.expressvpn.com/vpn-server/south-korea-vpn, 2026-05-04] | trivial (CLI wrap) | 1080p yes, 4K yes | **reject** — no multi-hop, weaker payment privacy than Mullvad/IVPN, no clear win over baseline |
| **NordVPN** | **~1,249 Mbps NordLynx** (top-3 fastest) [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04] | low | medium | Double VPN (2-hop, fixed pairs); **Onion-over-VPN** (VPN→3-Tor-hops, but server-side; less flexible than client-side Tor-over-VPN) [per https://nordvpn.com/features/no-log-vpn/, 2026-05-04] | Deloitte no-logs Feb 2026 (6th audit); Cure53 May/Jun/Oct 2025 found 5 high vulns, all fixed [per https://www.techradar.com/vpn/vpn-services/independent-auditors-inspect-nordvpns-security-once-again-heres-what-they-found, 2026-05-04]; **Oct 2024 Panama warrant — payment data turned over (no traffic logs)** [per https://en.wikipedia.org/wiki/NordVPN, 2026-05-04]; Panama jurisdiction | client open-source; server closed | KR servers present | low (CLI wrap) | 1080p yes, 4K yes | **reject** — Panama warrant shows fiat-payment retention; Onion-over-VPN is server-side (less correlation-resistant than ghost's planned client-side Tor-over-Mullvad chain); no advantage over Mullvad+Tor |
| **Surfshark** | high (~950 Mbps WG-class) [UNVERIFIED single primary] | low | medium | **Dynamic MultiHop** (any-entry+any-exit, like IVPN) [per https://www.security.org/vpn/surfshark/review/, 2026-05-04]; NoBorders mode for censored regions | Deloitte no-logs Jun 2025; SecuRing security audit Jan 2026 [per https://www.vice.com/en/article/surfshark-audit-jan-2026/, 2026-05-04]; Netherlands jurisdiction (Nine Eyes) | client open-source; server closed | KR servers present | low (CLI wrap) | 1080p yes, 4K yes | **reject** — NL jurisdiction is 9-Eyes (worse than CH/SE/Panama); Dynamic MultiHop covered by IVPN if we want that pattern |
| **AirVPN** | mid–high (OpenVPN+WG) | low–mid | medium | port forwarding + chosen-server discipline; **no formal multi-hop mode** | OSS client (GPLv3 Eddie); **no independent no-logs audit** [per https://www.safetydetectives.com/best-vpns/airvpn/, 2026-05-04]; **Italy jurisdiction (14 Eyes)** [per https://thebestvpn.com/reviews/airvpn/, 2026-05-04]; activist-run; cash/BTC/Monero | GPLv3 (Eddie + AirVPN client) [per https://github.com/AirVPN/Eddie, 2026-05-04] | [UNVERIFIED for KR-server-presence] | low (Eddie CLI / OpenVPN configs) | 1080p yes, 4K yes | **reject for default**; consider as Phase-3 fallback (OSS-purist optionality), not Phase 1/2 |
| **Tor (system tor / arti)** | per-circuit ~few Mbps (network-aggregate ~25 Gbit exits / ~60 Gbit total) [per https://metrics.torproject.org/bandwidth.html, 2026-05-04] | 300 ms – 2 s typical | strong (3 hops, no node knows both ends) | onion 3-hop default; per-broadcast circuit isolation via control port | BSD-3 OSS; Arti 2.0.0 Feb 2026 production [per https://forum.torproject.org/t/arti-1-0-0-is-released-our-rust-tor-implementation-is-ready-for-production-use/4446, 2026-05-04]; donation-funded; no commercial logs | BSD-3 (system tor); Apache-style (arti) | KR-legal to use; **never run an exit from KR** [per https://www.eff.org/pages/legal-faq-tor-relay-operators, 2026-05-04] | mid (SOCKS5 + ControlPort) | 1080p **no** typically (per-circuit cap); 4K **no** | sweep-tier default (existing) |
| **Nym mixnet (5-hop NGM)** | low — designed for messaging/crypto/email, not browsing [per https://nym.com/mixnet, 2026-05-04] | seconds (cover-traffic + Sphinx mixing) | strongest (cover traffic + Sphinx + nation-state claim [per https://fosdem.org/2026/events/attachments/U3UCKS-nym-mixnet/slides/267338/nym_fosd_x6ixavy.pdf, 2026-05-04]) | 5-hop NGM (entry → 3 mix layers → exit) | Apache-style SDK (Rust + TS) [per https://nym.com/docs/developers/rust, 2026-05-04]; production 2026; ZK payments | Apache-style | [UNVERIFIED for KR-specific block]; ~500 nodes / 50 nations [per https://cybernews.com/best-vpn/nymvpn-review/, 2026-05-04] | mid–high (custom Rust SDK; FFI from hexa) | **no** to streaming | broadcast_high_value-tier (Phase 2 existing target) |
| **Nym dVPN (2-hop AmneziaWG)** | mid (WG-class) [per https://cybernews.com/best-vpn/nymvpn-review/, 2026-05-04] | low–mid | medium (2-hop WG, not mixnet) | 2-hop WG with AmneziaWG obfuscation [per https://nym.com/mixnet, 2026-05-04] | same as Nym mixnet; same SDK | Apache-style | [UNVERIFIED for KR] | mid (NymVPN client wrap or SDK) | 1080p yes, 4K marginal | **propose: sweep-tier alternative** when mixnet latency unworkable |
| **HOPR** | low | high | strong (Sphinx + cover traffic) [per https://docs.hoprnet.org/core/mixnets, 2026-05-04] [per https://docs.hoprnet.org/core/cover-traffic, 2026-05-04] | mixnet pattern; smaller relay set than Nym | OSS [per https://github.com/hoprnet/hoprnet, 2026-05-04]; mcap ~$12M; less SDK polish than Nym | [UNVERIFIED license-exact for full stack — most files Apache/MIT] | [UNVERIFIED for KR] | high (less mature SDK than Nym) | no | **reject for ghost MVP/Phase-2** — Nym dominates same niche with better tooling; revisit if Nym becomes captured |
| **Lokinet** | low | mid | strong (LLARP onion routing; layer-3 IP-level so any TCP/UDP) [per https://github.com/oxen-io/lokinet, 2026-05-04] | onion routing on Oxen Service Node network | OSS; Oxen-economy-tied | OSS | [UNVERIFIED for KR] | mid | **streaming claim only** — independent benchmarks not surfaced [UNVERIFIED] | **reject** — depends on Oxen token economy; smaller security review surface than Tor/Nym |
| **I2P** | low | high | strong (garlic routing) | intra-I2P only by default; no general egress [per https://krebsonsecurity.com/2026/02/kimwolf-botnet-swamps-anonymity-network-i2p/, 2026-05-04] | OSS; v2.11.0 Feb 2026 added PQ ML-KEM+X25519 ratchet (first anonymity net to ship PQ default) [per https://www.sambent.com/i2p-2-11-0-ships-post-quantum-crypto-after-botnet-siege/, 2026-05-04]; but Feb 2026 Kimwolf Sybil flooded the net with 700K nodes vs 18K legitimate [per https://krebsonsecurity.com/2026/02/kimwolf-botnet-swamps-anonymity-network-i2p/, 2026-05-04] | OSS | [UNVERIFIED for KR] | high (no general egress) | no | **reject** — no general egress for ghost's use cases; wait for post-Kimwolf health |
| **Mysterium dVPN** | mid–high (residential IPs, 7,500+ across 100+ countries [per https://www.mysteriumvpn.com/, 2026-05-04]) | mid | medium — **trust random node operators** | open marketplace for IP rental | crypto-payment surface [per https://www.mysteriumvpn.com/vpn-pricing, 2026-05-04]; **no operator audit possible — anyone can become a node** | OSS | KR has node operators [UNVERIFIED count]; KR VASP overhead from crypto-pay surface | mid | 1080p yes, 4K yes | **reject** — node-operator threat (your traffic literally egresses through an unknown's residential ISP); residential IP is *useful* for evading Cloudflare CDN-level VPN blocks but ghost shouldn't route sweep through unknown ops |
| **Sentinel dVPN** | mid (3,500+ nodes [per https://www.privacytools.io/dvpn, 2026-05-04]) | mid | medium | onion-style multi-node | Cosmos chain payment; OSS framework | OSS | [UNVERIFIED for KR] | mid | 1080p yes | **reject** — same node-operator-trust issue as Mysterium |
| **Orchid** | mid | mid | medium | trusted-partner exits (BolehVPN, VPNSecure, etc.) [per https://www.orchid.com/partners/, 2026-05-04] | OXT crypto-payment; partner exits = **same trust model as a regular VPN, with extra crypto step** | OSS | [UNVERIFIED for KR] | mid | 1080p yes | **reject** — adds crypto-payment surface without anonymity over Mullvad/IVPN |
| **Raw WireGuard** | line rate | minimal | **none — single tunnel ≠ anonymity** | self-hosted multi-hop possible (≠ shipping default) | GPL2 kernel; OpenBSD-quality | GPL2 | KR-legal | trivial (config gen) | 1080p yes, 4K yes | building block, **not a backend choice** — useful inside Mullvad/IVPN/Proton/Nym-dVPN |
| **OpenVPN** | mid (5–6× slower than WG) | higher | none alone | can be chained, but slower | mature OSS | GPL2 | KR-legal | trivial | 1080p yes (single-hop), 4K marginal | **reject** — strictly dominated by WireGuard for ghost; no reason to ship it |
| **Headscale + Tailscale** | line rate (peer-to-peer WG mesh) | minimal | **none — operator-controlled relay, not anonymity** | mesh, not multi-hop privacy [per https://github.com/juanfont/headscale, 2026-05-04] | OSS, self-hostable | BSD-3 (Headscale) | KR-legal | mid (control plane) | 1080p yes, 4K yes | **reject as anonymity layer** — useful as *operator-side* relay (vast.ai control-plane, internal mesh) but does not provide IP-hiding from external observers; ghost should not ship it for §C.1/§C.2 |

`[UNVERIFIED]` markers indicate where 2026 primary-source numbers were not surfaced in the available time budget; these are flagged for re-verification before any backend is promoted into a hard cond verifier.

---

## §3. Per-backend deep dives (decision-relevant facts only)

### 3.1 Mullvad — confirmed Phase-1 default

Mullvad's **GotaTun** is the operationally interesting fact for ghost: a
zero-copy Rust WireGuard userspace, BSD-3 licensed, completed its first
external audit (Assured Security Consultants, Sweden, Jan 19–Feb 15
2026) with **no critical/high/medium-severity findings** — only two low
issues (24-bit LFSR + 8-bit counter session-id deviation from WG spec;
both fixed in 0.3.0) and 9 informational notes
[per https://mullvad.net/en/blog/2026/3/6/a-security-audit-of-gotatun-is-now-available, 2026-05-04]
[per https://github.com/mullvad/gotatun/blob/main/audits/2026-02-17-Assured.md, 2026-05-04].
Mullvad plans to expand GotaTun beyond Android to all clients during 2026
[per https://cyberinsider.com/mullvads-new-gotatun-protocol-passes-first-independent-audit/, 2026-05-04].
**DAITA** (Defense Against AI-guided Traffic Analysis) is a timing pad
inside GotaTun. ghost should keep DAITA on for `tier=research` — it's
not a substitute for mixnet cover-traffic but it does raise the bar
against pattern-classifier ISPs.

CLI-wrap shape is settled: `mullvad relay set multihop on`, `mullvad relay set entry location dk cph`, `mullvad relay set location se`, `mullvad status`
shows `Connected Relay: se-got-wg-001 via dk-cph-wg-001 Features: Multihop`
[per https://mullvad.net/en/help/multihop-wireguard, 2026-05-04]. This is
exactly the trivial single-edit-point shape G1 wants. ghost.cond.2
verifier as currently sketched holds.

Payment: cash-by-mail (envelope destroyed after credit), Monero (10%
discount), no email required
[per https://greycoder.com/best-vpns-with-anonymous-payments-bitcoin-monero-gift-cards-cash/, 2026-05-04].

### 3.2 IVPN — strong runner-up; not strictly needed if Proton lands

IVPN's distinguishing feature is **Dynamic MultiHop** — any-entry × any-
exit picking, more flexible than Mullvad's WG-in-WG fixed-pair model
[per https://www.ivpn.net/en/, 2026-05-04]. This matters when sweep
discipline requires a specific entry+exit jurisdictional combo not in
Mullvad's pre-built MultiHop table.

Audit posture is solid: Cure53 in 2019 found only one low (DNS cache,
unrelated to user IDs); Trail of Bits 2026 reportedly praised
conservative crypto and found no protocol weakness, but recommended
tighter key-management and server-reprovisioning automation
[per https://www.ivpn.net/blog/ivpn-no-logging-claim-verified-by-independent-audit, 2026-05-04]
[UNVERIFIED — exact 2026 ToB report URL not surfaced].

Token signup with no email is a real differentiator
[per https://www.safetydetectives.com/best-vpns/ivpn/, 2026-05-04].
Gibraltar jurisdiction is solid for ghost (privacy-friendly, not 14 Eyes
[per https://www.cloudwards.net/ivpn-review/, 2026-05-04]).

**Verdict**: IVPN is the cleanest *direct* alternative to Mullvad. But
adding Proton as the second backend (§3.3) gives ghost a *different
discipline* (jurisdiction-pinned secure-core entry) rather than a
near-clone. Hold IVPN for Phase-3 OSS-purist swap if Mullvad ever
becomes captured.

### 3.3 Proton VPN — propose adding as `tier=research` alternative

Three reasons this is the right addition, not IVPN:

1. **Secure-core jurisdiction-pin.** Every secure-core route forces
   entry through Switzerland / Iceland / Sweden — countries with no
   14 Eyes ties and Switzerland-grade case-law privacy
   [per https://protonvpn.com/features/secure-core, 2026-05-04]
   [per https://protonvpn.com/features/swiss-based, 2026-05-04]. This
   matches G8 (jurisdiction-explicit routing) at the *backend* level
   rather than requiring ghost's policy layer to enforce it manually.
   Mullvad lets the user pick, secure-core *forbids* the user from
   picking the wrong entry.

2. **Throughput.** Proton tops independent 2026 throughput tables —
   ~950 Mbps on 1 Gbit lines, 1,548 Mbps on 10 Gbit lines using
   WireGuard [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04].
   For `tier=research` (vast.ai control-plane, 4K YouTube, large
   bandwidth research dumps), it's the fastest baseline available.

3. **Stealth protocol.** WireGuard-over-TLS for environments where
   bare WG UDP is blocked
   [per https://protonvpn.com/features, 2026-05-04]. Useful if KR
   network conditions ever shift to active VPN-protocol fingerprinting.

Audit: Securitum 2025 no-logs audit, Swiss jurisdiction, full-disk-
encrypted secure-core servers, all clients open-source
[per https://www.securitum.com/public-reports/securitum-protonvpn-nologs-2025.pdf, 2026-05-04]
[per https://protonvpn.com/features/no-logs-policy, 2026-05-04].

**Tradeoff**: Proton's payment privacy is weaker than Mullvad — Monero
support is limited [per https://www.monero.how/best-vpns-that-accept-monero, 2026-05-04].
For payment-anonymous sweep, Mullvad still wins. Proton is the
*throughput + jurisdiction-pinned-entry* option, not the
*payment-anonymous* option.

CLI-wrap shape: Proton ships `protonvpn-cli` (Linux primary, Mac
parity); same trivial shell-out pattern as Mullvad.

### 3.4 ExpressVPN — reject

Lightway is well-engineered (Cure53 + Praetorian audits 2024 of the Rust
rewrite, core open-source [per https://www.expressvpn.com/blog/cure53-lightway-audit/, 2026-05-04]).
But: **no formal multi-hop mode**, KYC-payment funnel, BVI is fine
jurisdictionally but Mullvad/Proton already cover the "outside-14-Eyes"
slot. There's nothing ExpressVPN gives ghost that Mullvad+Proton don't.

### 3.5 NordVPN — reject (one specific signal)

The October 2024 Panama warrant disclosure is the decisive datapoint:
NordVPN provided **payment-related data** under a binding warrant
[per https://en.wikipedia.org/wiki/NordVPN, 2026-05-04]. They had no
traffic logs (audit-supported), but the existence of payment-data
retention shows the privacy-posture gap vs Mullvad's cash-in-envelope
model. NordLynx is fast (~1,249 Mbps top-3 [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04]),
2026 audits are thorough (Deloitte 6th no-logs audit Feb 2026; Cure53
May/Jun/Oct 2025 found 5 highs all fixed [per https://www.techradar.com/vpn/vpn-services/independent-auditors-inspect-nordvpns-security-once-again-heres-what-they-found, 2026-05-04]),
but for a tool whose entire value is *not retaining the link between
operator identity and traffic*, payment-data retention is disqualifying.

Onion-over-VPN sounds like our use case but isn't — Nord's onion-over-
VPN routes through their own servers into Tor, which means the *entry*
is Nord-controlled rather than client-controlled. ghost's planned
Tor-over-Mullvad chain (cond.9) keeps the Tor entry *outside* the VPN
provider's control, which is the correlation-resistance posture we want.

### 3.6 Surfshark — reject

NL jurisdiction = 9 Eyes [per https://www.security.org/vpn/surfshark/review/, 2026-05-04].
Dynamic MultiHop is the same pattern as IVPN's. SecuRing audit Jan 2026
is solid [per https://www.vice.com/en/article/surfshark-audit-jan-2026/, 2026-05-04].
Strict dominance: nothing Surfshark offers beats Mullvad+Proton.

### 3.7 AirVPN — reject for default; consider for Phase-3 OSS-purist mode

Italian jurisdiction is the blocker (14 Eyes
[per https://thebestvpn.com/reviews/airvpn/, 2026-05-04]). Eddie is
GPLv3 OSS with both OpenVPN and WireGuard support
[per https://github.com/AirVPN/Eddie, 2026-05-04], and the activist-run
ethos aligns with ghost's posture, but **no independent no-logs audit**
[per https://www.safetydetectives.com/best-vpns/airvpn/, 2026-05-04]
means it's strictly weaker than Mullvad/Proton on verifiability.

### 3.8 Tor (system tor / arti 2.0) — confirmed Phase-1 sweep-tier default

**Arti 2.0.0 shipped Feb 2 2026** — pure-Rust Tor client implementation,
production-ready
[per https://forum.torproject.org/t/arti-1-0-0-is-released-our-rust-tor-implementation-is-ready-for-production-use/4446, 2026-05-04]
[per https://www.sambent.com/arti-2-0-0-ships-tor-rust-rewrite-hits-major-milestone/, 2026-05-04].
Relay support is still in progress. For ghost's wrap, **system tor** stays
the right choice for now — better SOCKS5 + ControlPort tooling, more
operational documentation, and identical anonymity properties. Migrate
to arti when relay support stabilizes (Phase-3 candidate, not Phase-1).

Per-circuit throughput remains the painful constant: a few Mbps in the
common case [per https://www.h25.io/tools/tor-browser-for-darknet-work-in-2026-a-detailed-overview-of-pros-and-cons/, 2026-05-04].
This makes Tor unfit for `tier=research` everyday browse but exactly
right for `tier=sweep` (one Slipstream POST = small payload, latency
tolerant).

KR posture unchanged: legal to use, **never run an exit from KR**
[per https://www.eff.org/pages/legal-faq-tor-relay-operators, 2026-05-04].

### 3.9 Nym — confirmed Phase-2 broadcast_high_value default; *also* propose Nym dVPN as `tier=sweep` alternative

Two surprising 2026 facts that shift the picture:

1. **Nym dVPN 2-hop AmneziaWG mode exists and is Fast Mode in NymVPN**
   [per https://nym.com/mixnet, 2026-05-04]
   [per https://cybernews.com/best-vpn/nymvpn-review/, 2026-05-04].
   AmneziaWG = WireGuard with traffic-shape obfuscation. This is
   genuinely new since the 2026-05-04 design doc was authored — it
   slots into ghost as a `tier=sweep` *alternative* when Tor latency
   makes a Slipstream POST race a timeout.

2. **The Rust SDK does not expose dVPN mode** — only mixnet
   [per https://nym.com/docs/developers/rust, 2026-05-04]. So
   wrapping NymVPN's dVPN means wrapping the **NymVPN client binary**,
   not embedding the SDK. This is a different integration shape from
   the Phase-2 mixnet plan and warrants its own backend module
   (e.g., `backend_nym_dvpn/`) separate from `backend_nym/`.

Mixnet 5-hop NGM remains the *strongest* anonymity tier and the right
fit for `broadcast_high_value` (#135-class). 500 nodes / 50 nations as
of 2026 [per https://cybernews.com/best-vpn/nymvpn-review/, 2026-05-04];
production-ready.

### 3.10 HOPR / Lokinet / I2P — reject

- **HOPR**: Sphinx + cover traffic, but smaller market cap (~$12M
  [per https://photomadic.com/what-is-hopr-hopr-crypto-coin-a-comprehensive-privacy-guide, 2026-05-04]),
  thinner SDK than Nym, no clear advantage for ghost.
- **Lokinet**: Oxen-token-tied, smaller security review surface. The
  layer-3 IP-level routing claim is interesting but unverifiable for
  ghost's threat model. Reject unless Tor + Nym both become
  unworkable.
- **I2P**: Feb 2026 Kimwolf Sybil flood (700K malicious vs 18K legit
  routers [per https://krebsonsecurity.com/2026/02/kimwolf-botnet-swamps-anonymity-network-i2p/, 2026-05-04])
  + no general-egress-by-default = wrong shape for ghost. v2.11.0
  PQ-default ratchet [per https://www.sambent.com/i2p-2-11-0-ships-post-quantum-crypto-after-botnet-siege/, 2026-05-04]
  is impressive but doesn't change the egress-shape mismatch.

### 3.11 Mysterium / Sentinel / Orchid — reject

The dVPN node-operator-trust model is **anti-aligned with ghost's
threat model**. ghost wants the *fewest unknown egress operators*; dVPNs
maximize them. Mysterium's 7,500+ residential IPs
[per https://www.mysteriumvpn.com/, 2026-05-04] are *useful for evading
Cloudflare CDN-level VPN blocks*, which is a real ghost edge case
(some KR APIs/CDNs block known VPN ASNs). But routing a sweep tx
through a random KR resident's home connection is the wrong direction.

### 3.12 Raw WireGuard / OpenVPN / Headscale — building blocks, not products

- **Raw WG**: useful inside the providers above (every WG-class backend
  uses it). No reason to ship raw WG as a ghost backend.
- **OpenVPN**: strictly dominated by WG.
- **Headscale + Tailscale**: useful for operator-side mesh
  (vast.ai control plane, internal infra) but **not anonymity** — ghost
  should not call this an anonymity backend. Slot it into ghost as
  optional `modules/mesh/` if ever needed; out-of-scope for the wrap-
  target list.

---

## §4. Speed deep-dive (YouTube / streaming use case)

YouTube bandwidth requirements
[per https://www.broadbandsearch.net/blog/good-internet-speed-for-streaming, 2026-05-04]:

- 720p: ≥2.5 Mbps
- 1080p: ≥5 Mbps
- 4K: ≥20 Mbps
- 8K: ≥50 Mbps

Backend throughput (single 1 Gbit operator line as baseline; 2026 numbers
where surfaced):

| Backend / mode | Sustained Mbps (typical) | 1080p YT | 4K YT | Source |
|---|---|---|---|---|
| Proton VPN WireGuard single-hop | ~950 | yes | yes | [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04] |
| NordVPN NordLynx single-hop | ~1,249 | yes | yes | [per https://www.tomsguide.com/best-picks/best-fast-vpn, 2026-05-04] |
| Mullvad GotaTun single-hop | ~700–900 [UNVERIFIED-exact-2026-Mbps] | yes | yes | [per https://github.com/mullvad/gotatun, 2026-05-04] |
| Mullvad MultiHop (WG-in-WG) | ~50–80% of single-hop ≈ 350–700 [UNVERIFIED-exact-2026] | yes | yes | inferred from MultiHop overhead [per https://mullvad.net/en/help/multihop-wireguard, 2026-05-04] |
| Proton secure-core (CH/IS/SE entry pin) | ~50–70% of single-hop ≈ 500–700 [UNVERIFIED-exact-2026] | yes | yes | [per https://protonvpn.com/support/secure-core-vpn, 2026-05-04] |
| IVPN Dynamic MultiHop | ~300–500 [UNVERIFIED-exact-2026] | yes | yes | [per https://www.ivpn.net/en/, 2026-05-04] |
| Nym dVPN 2-hop (Fast Mode) | mid; tested OK for "social media, email, streaming videos from YouTube and Rumble" [per https://cybernews.com/best-vpn/nymvpn-review/, 2026-05-04] | yes | marginal | |
| Tor (single circuit) | a few Mbps, occasionally up to 10–15 | sometimes (best circuits) | **no** | [per https://www.h25.io/tools/tor-browser-for-darknet-work-in-2026-a-detailed-overview-of-pros-and-cons/, 2026-05-04] |
| Tor-over-Mullvad chain | Tor-bound; same as Tor | sometimes | no | analyst synthesis |
| Nym mixnet (5-hop NGM) | sub-Mbps; messaging-class | **no** | no | [per https://nym.com/mixnet, 2026-05-04] |
| HOPR / Lokinet | low | unreliable | no | [per https://docs.hoprnet.org/core/mixnets, 2026-05-04] |
| I2P (intra-net only) | n/a for general egress | n/a | n/a | [per https://i2p.net, 2026-05-04] |

**Practical implication for ghost**: `tier=research` (which is the
"normal browsing + YouTube + vast.ai" path) needs WG-class throughput.
Proton secure-core and Mullvad MultiHop both deliver. Tor and Nym
mixnet do not, and shouldn't be defaults for that tier — only invoked
when the operation explicitly opts into the slow path (sweep / high-
value broadcast). The existing tier model already encodes this
correctly.

---

## §5. Anonymity-vs-speed tradeoff curve (qualitative)

Plotted on a 2D plane (X = throughput, Y = anonymity strength):

```
 anonymity ↑
  strongest │                                   • Nym mixnet 5-hop
            │                                   • HOPR
   strong   │              • Tor over Mullvad
            │              • Tor (single)
            │
   medium-  │      • Proton secure-core
   strong   │      • Mullvad MultiHop + DAITA
            │      • IVPN Dynamic MultiHop
   medium   │  • Nym dVPN 2-hop
            │  • Single-hop Mullvad / Proton / IVPN
            │  • NordVPN / Surfshark / ExpressVPN single-hop
   weak     │  • Raw WireGuard / OpenVPN
            │  • Mysterium / Sentinel / Orchid (operator-trust)
   none     │  • Headscale (mesh, not anonymity)
            └────────────────────────────────────────────→ throughput
              low                              high
```

**ghost's tier model exploits this curve as follows**:

- `tier=research` lives on the high-throughput-medium-anonymity
  shoulder (Mullvad MultiHop, Proton secure-core). Operator can browse
  YouTube, run vast.ai burst, hit mempool — all without a Tor speed
  penalty, while still defending ISP / single-provider compromise.
- `tier=sweep` jumps to high-anonymity (Tor-over-Mullvad chain) at the
  cost of throughput. The payload is a small Slipstream POST; the
  speed cost doesn't matter.
- `tier=broadcast_high_value` jumps to strongest-anonymity (Nym
  mixnet) at the cost of *latency in seconds*. Async one-shot, so
  latency doesn't matter either.
- The Nym-dVPN-2-hop addition fills a gap in the curve: medium-
  anonymity-mid-throughput, useful when a Slipstream POST needs lower
  latency than Tor's circuit setup but more discipline than a plain
  multi-hop VPN.

The shape of the curve is the architecture's value-add. A naive design
would force "high anonymity always" (kills usability) or "high
throughput always" (kills threat coverage). ghost's tier-routing
chooses the right point on the curve per operation.

---

## §6. Recommendation update (per tier)

### 6.1 `tier=research`

- **Keep**: Mullvad MultiHop + DAITA as default.
- **Add**: Proton VPN secure-core as a *second, parallel* backend
  behind a feature flag (`--backend=proton-sc`). Reasons §3.3:
  jurisdiction-pinned entry (CH/IS/SE), top throughput, audited 2025.
- **Reject**: ExpressVPN (no multi-hop), NordVPN (Panama-warrant
  payment-data retention), Surfshark (NL 9-Eyes), AirVPN (Italy 14-
  Eyes, no audit), IVPN (covered by Mullvad+Proton).

### 6.2 `tier=sweep`

- **Keep**: fresh-circuit Tor over Mullvad as default.
- **Add**: Nym dVPN 2-hop AmneziaWG as alternative when latency budget
  is tight. Wrap NymVPN client binary (not the Rust SDK; SDK doesn't
  expose dVPN mode [per https://nym.com/docs/developers/rust, 2026-05-04]).
- **Migrate path**: arti 2.0.0 (Feb 2026) is production-ready
  [per https://forum.torproject.org/t/arti-1-0-0-is-released-our-rust-tor-implementation-is-ready-for-production-use/4446, 2026-05-04];
  evaluate as Phase-3 swap-in for system tor when arti relay support
  ships.

### 6.3 `tier=broadcast_high_value` (Phase 2)

- **Keep**: Nym mixnet 5-hop NGM as default.
- **Reject**: HOPR (smaller mcap, thinner SDK), Lokinet (Oxen-economy-
  tied, smaller review surface), I2P (no general egress).

### 6.4 Generic operator browse (`tier=research` reuse)

No change. Proton secure-core is a happy reuse target for everyday browse
when the operator wants jurisdiction discipline (e.g., reaching CH/EU-
regulated services and wanting the egress to *be* CH/IS/SE).

---

## §7. Cond impact (against `.roadmap.ghost`)

The `.roadmap.ghost` conds in the design doc §H need three small adjustments:

### 7.1 cond.2 widen scope

**Current**: `backend_wireguard/` Mullvad-CLI wrap working;
`ghost up --backend=wg --tier=research` returns tunnel-up.

**Proposed**: `backend_wireguard/` defines a **trait** with N WG-class
backends behind it; Mullvad-CLI is the v0 implementation; Proton-CLI
is the v1 implementation (Phase 2 pre-mixnet). Verifier becomes:
`ghost up --backend=mullvad --tier=research` and
`ghost up --backend=proton-sc --tier=research` both return tunnel-up
with leak-test clean.

This avoids redefining cond.2 mid-flight; existing Mullvad work continues
unchanged, Proton is added as a strict additive milestone (could be
cond.2.1 or a new cond.12).

### 7.2 cond.3 unchanged

System tor wrap remains as-is. arti migration is a separate future
cond, not a redefinition of cond.3.

### 7.3 cond.10 split

**Current**: Phase-2 cond.10 = `backend_nym/` Nym SDK wrap; mixnet-tier
route option for sweep-tier broadcasts.

**Proposed split**:

- **cond.10a** (= existing cond.10): `backend_nym_mixnet/` Rust SDK
  wrap; 5-hop NGM mode for `tier=broadcast_high_value`. Verifier:
  `ghost up --backend=nym-mixnet --tier=broadcast_high_value` produces
  working mixnet egress.
- **cond.10b** (new): `backend_nym_dvpn/` NymVPN client wrap (binary
  shell-out, not SDK); 2-hop AmneziaWG mode for `tier=sweep`
  alternative. Verifier:
  `ghost up --backend=nym-dvpn --tier=sweep` produces working dVPN
  egress with leak-test clean.

The split is justified because the integration shape differs (SDK FFI
vs CLI shell-out) and the threat tier differs (strongest vs medium-
strong). Conflating them would force ghost to ship both before claiming
either Nym posture, doubling MVP-to-Phase-2 latency.

### 7.4 G8 (jurisdiction-explicit) reinforced

Proton secure-core is the **first backend that mechanically enforces G8
at the protocol level** — operator cannot accidentally route entry
through a 14-Eyes jurisdiction. Other backends rely on ghost's
`policy/` module to enforce. Adding Proton lets the audit log record
*"jurisdiction-pinned at backend level, not policy-layer"* as a
stronger rationale class.

### 7.5 No new conds blocked or invalidated

cond.0–cond.9 retain their current shape. cond.11 (Phase-2 customer-
facing surface) still defers to post-MVP. The only redefinitions are
the cond.2 scope-widen and the cond.10 split, both strict additions.

---

## §8. References (deduplicated; access date 2026-05-04)

### Mullvad / GotaTun / DAITA
- https://mullvad.net/en/blog/2026/3/6/a-security-audit-of-gotatun-is-now-available
- https://github.com/mullvad/gotatun/blob/main/audits/2026-02-17-Assured.md
- https://cyberinsider.com/mullvads-new-gotatun-protocol-passes-first-independent-audit/
- https://www.tomsguide.com/computing/vpns/mullvads-new-gotatun-wireguard-implementation-passes-its-first-independent-security-audit-heres-what-you-need-to-know
- https://mullvad.net/en/blog/announcing-gotatun-the-future-of-wireguard-at-mullvad-vpn
- https://github.com/mullvad/gotatun
- https://mullvad.net/en/help/multihop-wireguard
- https://mullvad.net/en/help/cli-command-wg
- https://mullvad.net/en/servers
- https://www.netify.ai/resources/vpns/mullvad-vpn

### IVPN
- https://www.ivpn.net/en/
- https://www.ivpn.net/blog/ivpn-no-logging-claim-verified-by-independent-audit
- https://www.ivpn.net/blog/annual-security-audit-scheduled-2025
- https://www.cloudwards.net/ivpn-review/
- https://www.safetydetectives.com/best-vpns/ivpn/
- https://www.ivpn.net/knowledgebase/general/antitracker-faq/

### Proton VPN
- https://protonvpn.com/features/secure-core
- https://protonvpn.com/features/swiss-based
- https://protonvpn.com/features/no-logs-policy
- https://protonvpn.com/features
- https://protonvpn.com/support/secure-core-vpn
- https://www.securitum.com/public-reports/securitum-protonvpn-nologs-2025.pdf
- https://cybernews.com/vpn/protonvpn-review/

### ExpressVPN / Lightway
- https://www.expressvpn.com/blog/cure53-lightway-audit/
- https://www.expressvpn.com/lightway
- https://github.com/expressvpn/lightway-core
- https://en.wikipedia.org/wiki/ExpressVPN
- https://www.expressvpn.com/vpn-server/south-korea-vpn

### NordVPN
- https://nordvpn.com/features/no-log-vpn/
- https://www.techradar.com/vpn/vpn-services/independent-auditors-inspect-nordvpns-security-once-again-heres-what-they-found
- https://en.wikipedia.org/wiki/NordVPN

### Surfshark
- https://www.security.org/vpn/surfshark/review/
- https://www.vice.com/en/article/surfshark-audit-jan-2026/

### AirVPN / Eddie
- https://airvpn.org/
- https://eddie.website/
- https://github.com/AirVPN/Eddie
- https://www.safetydetectives.com/best-vpns/airvpn/
- https://thebestvpn.com/reviews/airvpn/

### Tor / arti
- https://blog.torproject.org/arti_100_released/
- https://forum.torproject.org/t/arti-1-0-0-is-released-our-rust-tor-implementation-is-ready-for-production-use/4446
- https://www.sambent.com/arti-2-0-0-ships-tor-rust-rewrite-hits-major-milestone/
- https://metrics.torproject.org/bandwidth.html
- https://www.eff.org/pages/legal-faq-tor-relay-operators
- https://www.h25.io/tools/tor-browser-for-darknet-work-in-2026-a-detailed-overview-of-pros-and-cons/

### Nym / NymVPN
- https://nym.com/
- https://nym.com/mixnet
- https://nym.com/docs/developers/rust
- https://nym.com/docs/network
- https://github.com/nymtech/nym-vpn-client
- https://fosdem.org/2026/events/attachments/U3UCKS-nym-mixnet/slides/267338/nym_fosd_x6ixavy.pdf
- https://cybernews.com/best-vpn/nymvpn-review/

### HOPR
- https://docs.hoprnet.org/core/mixnets
- https://docs.hoprnet.org/core/cover-traffic
- https://hoprnet.org/
- https://github.com/hoprnet/hoprnet

### Lokinet / Oxen
- https://github.com/oxen-io/lokinet
- https://docs.oxen.io/oxen-docs/products-built-on-oxen/lokinet
- https://lokinet.org/faq

### I2P
- https://krebsonsecurity.com/2026/02/kimwolf-botnet-swamps-anonymity-network-i2p/
- https://www.sambent.com/i2p-2-11-0-ships-post-quantum-crypto-after-botnet-siege/
- https://i2p.net/

### dVPN — Mysterium / Sentinel / Orchid
- https://www.mysteriumvpn.com/
- https://www.mysterium.network/
- https://www.privacytools.io/dvpn
- https://www.orchid.com/
- https://www.orchid.com/partners/

### Throughput / benchmarks / streaming
- https://www.tomsguide.com/best-picks/best-fast-vpn
- https://www.broadbandsearch.net/blog/good-internet-speed-for-streaming
- https://cybernews.com/vpn/comparison/nordvpn-vs-mullvad/
- https://cyberinsider.com/vpn/comparison/mullvad-vs-proton-vpn/

### Tor-over-VPN / VPN-over-Tor doctrine
- https://factually.co/fact-checks/technology/vpn-before-tor-or-after-tor-vpn-over-tor-vs-tor-over-vpn-anonymity-e3110c
- https://factually.co/fact-checks/technology/tor-vpn-best-practices-anonymity-465eda

### Anonymous payment
- https://www.monero.how/best-vpns-that-accept-monero
- https://greycoder.com/best-vpns-with-anonymous-payments-bitcoin-monero-gift-cards-cash/
- https://kycnot.me/service/mullvad

### KR jurisdiction
- https://www.purevpn.com/blog/is-vpn-legal-in-korea/
- https://www.lexology.com/library/detail.aspx?g=016a929c-ad58-4d1d-8bf6-807b4272863e
- https://www.opennetkorea.org/administrative-censorship
- https://www.newamerica.org/cybersecurity-initiative/c2b/c2b-log/analysis-south-koreas-sni-monitoring/

### Headscale / Tailscale (out-of-scope reference)
- https://github.com/juanfont/headscale
