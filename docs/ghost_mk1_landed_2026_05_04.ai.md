---
doc: airgenome.docs.ghost_mk1_landed
kind: handoff_landed
audience: [human, agent]
date: 2026-05-04
mk: 1
status: landed
contributes_to: [ghost.cond.0, ghost.cond.1, ghost.cond.2, ghost.cond.3, ghost.cond.4, ghost.cond.5, ghost.cond.6, ghost.cond.7, ghost.cond.8, ghost.cond.9, ghost.cond.10, ghost.cond.11]
related: [docs/ghost_feature_design_inbox_2026_05_04.ai.md, docs/ghost_backend_comparison_2026_05_04.ai.md, docs/ghost_payment_strategy_2026_05_04.ai.md, docs/ghost_voucher_resellers_email_2026_05_04.ai.md]
---

# 🕶️ ghost mk1 — closure handoff (12-cond, single VPN backend)

**Date**: 2026-05-04
**Subdomain**: `airgenome/modules/ghost/`
**Roadmap**: `airgenome/modules/ghost/.roadmap.ghost`
**mk1 backend lock**: Mullvad CLI sole VPN backend (Proton / IVPN deferred to mk2)
**Trio**: `🗝️ orpheus → 🫥 wraith-wallet → 🕶️ ghost`
**Conformance**: ω-cycle 6-step, AI-native cpre + moduler, G1–G10, additive-only

---

## 1. Headline

ghost mk1 — the network-layer hide for the orpheus + wraith-wallet trio — is **landed across all 12 conds, 11 met + 1 design-done-pending-operator**. mk1 is locked to a **single VPN backend (Mullvad CLI)** per the 2026-05-04 mandate; Proton secure-core and IVPN dynamic-multihop are explicit mk2 candidates documented inline. The subdomain ships eight `.hexa` modules under `airgenome/modules/ghost/` (cpre + module SSOT + 7 implementation files), an `airgenome ghost` bash CLI surface on the airgenome layer, two cross-repo `link/ghost.hexa` adapters (one in `orpheus/`, one in `wraith-wallet/`), the wraith W4 broadcast gate that consults `ghost tunnel-alive` before any non-dry-run send, and three append-only G2-clean JSONL audit streams under `airgenome/state/`.

mk1's posture is **fail-closed by default** — every wrap exits `SKIP` under sandbox (mullvad / tor / nym binaries absent), every leak probe exits `FAIL` cleanly when DNS / IPv6 escapes the tunnel, and every cross-repo gate refuses on `tunnel_alive=no`. Live PASS verification on the operator host is a single follow-up task (install Mullvad CLI + redeem voucher + run `airgenome ghost up`). cond.9 (kernel-level pf kill-switch) renders the anchor template + sudo recipe to stdout but never invokes `sudo` itself — operator activation is intentionally outside `.hexa` control per the opt-in mandate.

---

## 2. cond status table (12 rows)

All landed 2026-05-04.

| cond | desc | status | key file | sentinel |
|---|---|---|---|---|
| cond.0 | research doc landed (status >= draft_inbox) | met | `docs/ghost_feature_design_inbox_2026_05_04.ai.md` | frontmatter grep |
| cond.1 | skeleton — cpre/4 + module.ai.md + 7 stubs + .roadmap.ghost | met | `modules/ghost/` | file existence |
| cond.2 | wrap_mullvad.hexa — Mullvad CLI G1 single edit point | met | `modules/ghost/wrap_mullvad.hexa` | `__GHOST_WRAP_MULLVAD__` |
| cond.3 | wrap_tor.hexa — system Tor G1, KR exit hard-deny | met | `modules/ghost/wrap_tor.hexa` | `__GHOST_WRAP_TOR__` |
| cond.4 | route.hexa + airgenome ghost CLI dispatch | met | `modules/ghost/route.hexa`, `bin/airgenome cmd_ghost` | `__GHOST_ROUTE__` |
| cond.5 | policy.hexa pure-logic gate (5 fns + 5 consts) | met | `modules/ghost/policy.hexa` | `__GHOST_POLICY__` |
| cond.6 | kill-switch — wraith W4 cross-repo gate | met | `bin/airgenome cmd_ghost tunnel-alive`, `wraith-wallet/cli/wraith.hexa::cmd_tx_broadcast` | rc 0/1 + W4 grep |
| cond.7 | audit.hexa — G2 metadata-only JSONL emit | met | `modules/ghost/audit.hexa` → `state/ghost_audit*.jsonl` | `__GHOST_AUDIT__` |
| cond.8 | selftest.hexa — DNS/IPv6/WebRTC/SNI leak preflight | met | `modules/ghost/selftest.hexa` → `state/leak_reports/` | `__GHOST_SELFTEST__` |
| cond.9 | capability flag — kernel-level pf opt-in | **design_done_pending_operator** | `modules/ghost/{policy,route,audit}.hexa` | `capability status\|set\|engage` |
| cond.10 | wrap_nym.hexa Phase-2 mk1 — NymVPN subprocess wrap | met | `modules/ghost/wrap_nym.hexa` | `__GHOST_WRAP_NYM__` |
| cond.11 | orpheus + wraith link/ghost.hexa adapters (cross-repo) | met | `orpheus/modules/link/ghost.hexa`, `wraith-wallet/modules/link/ghost.hexa` | `__*_LINK_GHOST__` PASS\|SKIP |

---

## 3. Layer architecture

```
operator
   │  airgenome ghost up sweep
   ▼
bin/airgenome  (bash CLI — cmd_ghost dispatch, $hexa_bin / $ag_root resolution)
   │  hexa run modules/ghost/route.hexa <subcmd>
   ▼
route.hexa  (orchestrator — tier policy + lifecycle + G10 downgrade audit)
   │  exec subprocess (NOT import-as-alias — hexa stage1 void workaround,
   │                    mirrors orpheus blk.3 resolution pattern)
   ▼
wrap_mullvad.hexa  ────  wrap_tor.hexa  ────  wrap_nym.hexa
   │   G1 single edit       G1 single edit       G1 single edit
   │   chokepoint            chokepoint           chokepoint
   ▼                          ▼                    ▼
system mullvad CLI        system tor             NymVPN client
(daemon: operator-managed)  (daemon: operator-managed)  (daemon: operator-managed)
```

Two horizontal feeds:

```
   policy.hexa  (pure logic — exit allowlist, KR Tor hard-deny, payment compat,
   ────────────  G10 downgrade matrix, capability flag read/write)
       │  no I/O — only stdin/stdout
       ▼
   route.hexa  (consults policy before every tier transition)

   audit.hexa  (G2 metadata-only emit — append-only JSONL, mode 0600)
       │  state/ghost_audit.jsonl       ← route decisions
       │  state/ghost_audit_downgrades.jsonl  ← G10 events
       │  state/ghost_audit_capability.jsonl  ← capability toggles
       ▼  state/leak_reports/<ts>.jsonl ← preflight verdicts
```

The **subprocess pattern** for wrap_*.hexa invocation (not import-as-alias) is a deliberate mk1 choice — hexa stage1's import-as-alias path silently voids the imported namespace, the same bug orpheus hit at blk.3 and resolved with the same pattern. This is documented inline at `route.hexa` and called out in cond.4 evidence.

---

## 4. Surface — operator-facing CLI

### `airgenome ghost <subcmd>`

| subcmd | description | exit semantics |
|---|---|---|
| `up [tier]` | enable VPN at requested tier (default `research`) | 0 ok / 1 unavailable; tier ∈ research / sweep / broadcast_high_value |
| `down` | disable VPN (release tunnel + audit emit) | 0 ok / 1 unavailable |
| `status` | state label | stdout ∈ up / connecting / down / unknown |
| `health` | alias of status | (same) |
| `tunnel-alive` | cross-repo G4 gate for wraith W4 / orpheus | exit 0 alive / exit 1 down |
| `selftest` | route + wrap_mullvad smoke + leak preflight | sentinels emitted, JSONL leak report written |
| `available` | does the host have `mullvad` binary? | yes / no |
| `capability status` | read `~/.airgenome/ghost_capability` flag | enabled / disabled |
| `capability set kill_switch on\|off` | atomic mv via tmp file + audit toggle event | ok / reject reason |
| `capability engage` | render pf anchor + emit sudo recipe to stdout | (operator runs printed `pfctl -a ghost-killswitch -f ...`) |
| `capability disengage` | emit pf flush recipe to stdout | (operator runs printed `pfctl -a ghost-killswitch -F all`) |

`bin/airgenome` is the only place that shells out to `hexa run modules/ghost/route.hexa`; downstream callers (orpheus, wraith-wallet) reach ghost via their respective `link/ghost.hexa` adapters which themselves shell out to `airgenome ghost ...` — single edit point preserved on every layer.

---

## 5. Surface — cross-repo gates

### wraith W4 broadcast gate (cond.6 paired sub-cond — wraith.cond.11)

```
wraith-wallet/cli/wraith.hexa::cmd_tx_broadcast
  ├── if route == "never_broadcast_dry_run":
  │       skip ghost gate, proceed with dry-run audit
  └── else:
        out = $(hexa run modules/link/ghost.hexa tunnel-alive)
        if "yes" not in out:
            exit(65)
            verdict = "ghost_tunnel_down_g4_w4"
            stderr = "REFUSED: ghost tunnel down (G4 cross-repo with W4)"
            audit_emit(...)
        else:
            proceed with broadcast through ghost::route(tier=sweep)
```

### orpheus link adapter (cond.11 (a) — orpheus side)

```
orpheus/modules/link/ghost.hexa  (270 lines, sentinel __ORPHEUS_LINK_GHOST__)
  ├── ghost_available()       ← does airgenome bin resolve?
  ├── ghost_tunnel_alive()    ← C5/G4-honored gate
  ├── ghost_route_research()  ← tier=research routing
  └── ghost_health_label()    ← C1/C5 honored — label only, no IP

3 caller integrations (gate before external HTTP):
  - orpheus/modules/puzzle_atlas/fetch.hexa
  - orpheus/modules/puzzle_atlas/verify.hexa
  - orpheus/modules/wallet_search/dormant_atlas.hexa

ORPHEUS_GHOST_GATE=0  ← escape hatch for fixture / cached paths
```

Both repos honor a G1-equivalent grep invariant — `'"airgenome"|exec.*airgenome'` returns empty outside `link/ghost.hexa`. Single edit point preserved at every cross-repo seam.

---

## 6. Tier policy (mk1)

| tier | mk1 backend chain | notes |
|---|---|---|
| `research` | Mullvad MultiHop SE→JP + DAITA + Lockdown | default tier; foreign-exit allowlist enforced (JP/SG/CH/SE per §G8) |
| `sweep` | Mullvad inner + Tor outer + fresh circuit per broadcast | `wrap_tor.hexa` operator-managed daemon; KR exit hard-deny via `torrc` `ExcludeExitNodes {kr}` grep |
| `broadcast_high_value` | Mullvad inner + Nym 5-hop NGM (Phase 2 — subprocess wrap) | G10 fall-back: Nym down → sweep tier (audit downgrade); both Nym + Tor down → research-degraded (double downgrade emit) |
| `customer` | **DEFER** to mk2 — KR ISMS / PIPA / VASP-adjacent review pending | scope.ai.md hard-line; never invoked in mk1 |

The G10 fall-back chain at `broadcast_high_value` is wired explicitly in `route.hexa::_apply_broadcast_high_value_config` — three sub-paths (Nym up; Nym down + Tor up; both down), each emitting an `audit_emit_downgrade` event with `reason ∈ {nym_unavailable, nym_and_tor_unavailable}` so the operator sees `health=degraded` (not `up`) until the originally requested tier recovers.

---

## 7. Operator activation steps (mk1 onboarding)

Run-once steps per fresh host:

1. **Install Mullvad CLI** — `brew install --cask mullvadvpn` (macOS Tahoe-26 verified). Daemon under launchd; CLI on `$PATH`.
2. **Buy Mullvad voucher** — recommend Cryptvice with **Signal delivery** (voucher reseller doc §B.1; €25 / 6mo or €55 / 12mo). Two-hop link breaks the single-hop KR-card-to-Mullvad trace. Direct card on `mullvad.net` works but exposes the merchant string to KR card issuer (5y+ retention).
3. **Generate 16-digit account** — `mullvad.net` (Tor browser preferred) → "Create account" → no PII → save 16-digit.
4. **Redeem voucher** — `mullvad account login <16-digit>` then `mullvad account redeem <voucher-code>`.
5. **First activation** — `airgenome ghost up` (default tier=research). Expected: `ok: research mullvad up multihop=se->jp daita=on lockdown=on`. Audit appends to `state/ghost_audit.jsonl`.
6. **(Optional) sweep tier** — `brew install tor && brew services start tor`; append `ExcludeExitNodes {kr}` to `/opt/homebrew/etc/tor/torrc`; `brew services restart tor`; `airgenome ghost up sweep`.
7. **(Optional) broadcast_high_value tier — Phase 2** — install NymVPN client (`brew install nym-vpn-core` or download from nym.com); `nymvpn-x daemon-start`; `airgenome ghost up broadcast_high_value`. NymVPN binary / port / flags speculative in mk1 (§10.3).
8. **(Optional cond.9 kernel kill-switch)** — `airgenome ghost capability set kill_switch on` → `airgenome ghost capability engage`. Stdout prints rendered pf anchor at `state/ghost_capability_pf_anchor.conf` + exact `sudo pfctl -a ghost-killswitch -f <path>` recipe + optional `/etc/pf.anchors/ghost-killswitch` persistence. `.hexa` never invokes `sudo`.

---

## 8. Contracts honored (G1–G10)

| contract | one-line evidence |
|---|---|
| **G1** Egress only via `wrap_*.hexa` | grep `'exec.*<bin>\|"<bin>"'` filter excluding wrap file returns empty for mullvad / tor / nym; same invariant in `link/ghost.hexa` for `airgenome` |
| **G2** No cleartext traffic logging | `audit_g2_assert_metadata_only` rejects URL / IPv4 / IPv6 pre-emit; schema = `{ts, requester, tier, backend, exit_jurisdiction, rationale, health, no_content:true}` |
| **G3** No deanonymizing telemetry | `*_health` returns `up\|connecting\|down\|degraded\|unknown` labels only — IP / DNS / ASN discarded at probe boundary |
| **G4** Kill-switch cross-repo with W4 | `airgenome ghost tunnel-alive` rc 0/1 wired into wraith `cmd_tx_broadcast`; non-dry-run refuses + emits `ghost_tunnel_down_g4_w4` |
| **G5** Separation-of-knowledge | `link/ghost.hexa` accepts tier label only; `policy_check_g5_clean` rejects tx-hex-shaped payloads |
| **G6** AI-native doc cadence | `module.ai.md` + this doc + 4 sibling `docs/ghost_*_2026_05_04.ai.md` + `.roadmap.ghost` evidence current |
| **G7** No `.py` committed | `find modules/ghost/ -name "*.py"` empty; tor control via `printf \| nc -w 2`, no stem |
| **G8** Jurisdiction-explicit + KR Tor hard-deny | `ALLOW_KR_TOR_EXIT=false` invariant asserted in selftest; exit allowlist `JP\|SG\|CH\|SE` for sweep / bhv |
| **G9** ghost never broadcasts a tx | no `sendrawtransaction` / `bitcoin-cli` ref in `modules/ghost/`; egress is HTTP transport only |
| **G10** Live-mode honesty | every fall-back emits `audit_emit_downgrade {from,to,reason}`; reports `health=degraded` until original tier recovers |

---

## 9. Cross-repo trio dependency map

```
                    ┌──────────────────────────────────────┐
                    │       🗝️ orpheus (private repo)       │
                    │  produces key (puzzle / recovery)     │
                    │  modules/link/ghost.hexa  (adapter)   │
                    └─────────────┬────────────────────────┘
                                  │  HTTP via airgenome ghost up research
                                  ▼
   ┌──────────────────────────────────────────────────────┐
   │       🕶️ ghost (airgenome/modules/ghost/)             │
   │  network-layer hide (VPN/Tor/Nym wrap)                │
   │  airgenome ghost {up\|down\|status\|tunnel-alive\|...}│
   │  state/ghost_audit*.jsonl  (G2 clean ledger)          │
   └─────────────┬────────────────────────┬───────────────┘
                 ▲                         │
                 │  tunnel-alive gate      │  HTTP via airgenome ghost up sweep
                 │  (G4 ↔ W4)              ▼
   ┌─────────────┴─────────────────────────────────────────┐
   │       🫥 wraith-wallet (private repo)                  │
   │  custodies + signs + broadcasts                        │
   │  modules/link/ghost.hexa  (adapter)                    │
   │  cli/wraith.hexa::cmd_tx_broadcast  (W4 gate)          │
   └────────────────────────────────────────────────────────┘
```

**G5 invariant — no single layer ever sees all three knowledges**:
- ghost knows traffic patterns (tier label, backend health) — never recovery context, never wallet keys
- orpheus knows recovery context (puzzle id, BIP39 candidate state) — never tx hex, never sees ghost beyond `tier=research`
- wraith-wallet knows wallet keys (xprv, signed tx hex) — never sees orpheus puzzle context, never sees ghost beyond `tier=sweep`

A compromise of any single layer must not collapse the trio. The cross-repo `link/ghost.hexa` adapters enforce this surface contract structurally — the only API ghost exposes is `{tier, status, tunnel_alive}`.

---

## 10. Known limitations + mk2 candidates

1. **Proton VPN secure-core** — protocol-level G8 jurisdiction-pin (Mullvad enforces via relay-set + multihop config; Proton bakes secure-core into the WireGuard handshake). **mk2 cond.12 candidate** — adds `wrap_proton.hexa` as a second G1 chokepoint.
2. **IVPN dynamic-multihop** — session-time chain rotation (Mullvad multihop is config-time fixed). **mk2 cond.13 candidate** — adds `wrap_ivpn.hexa` + tier-level rotation in `policy.hexa`.
3. **NymVPN client version pinning** — mk1's PROBE list (`nym-vpn-cli` / `nymvpn-cli` / `nymvpn-x` / `nym-vpnd`), daemon port (`8080`, some `53181`), and mode flags (`--enable-poisson-process` / `--use-two-hop-mixnet`) are speculative. Pin a verified version in mk2.
4. **cond.6 host-mode live PASS** — gate wire + dry-run + REFUSED branches landed; live PASS on a host with mullvad CLI + wraith broadcast firing is an operator step. Helper `scripts/ghost_live_verify.sh` is a separate task.
5. **cond.9 operator pf activation** — `pfctl -a ghost-killswitch -f <path>` runs once and persists if `/etc/pf.anchors/ghost-killswitch` is wired; persistence documented, not landed.
6. **WebRTC + SNI leak probes** — `GUIDANCE`-only in mk1; full PASS / FAIL needs application-layer cooperation (browser + ECH server). Phase 2.
7. **`customer` tier** — out of mk1 scope per KR ISMS / PIPA / VASP review hard line in `cpre/scope.ai.md`. Revisit at mk2.
8. **hexa-strict auto-invoke** — orpheus flagged `fn main() auto-called by hexa-strict + top-level main() found`; adapters are fail-closed against it, but reconciliation is a trio-wide follow-up.

---

## 11. Ledger artifacts

Files written by ghost during operation, all under `airgenome/state/`:

| path | kind | mode | producer |
|---|---|---|---|
| `state/ghost_audit.jsonl` | route decisions (`up` / `down` / `degraded`) | append, 0600 | `audit.hexa::audit_emit` ← every state transition in `route.hexa` |
| `state/ghost_audit_downgrades.jsonl` | G10 fall-back events `{from,to,reason}` | append, 0600 | `audit.hexa::audit_emit_downgrade` ← G10 paths in `route.hexa` |
| `state/ghost_audit_capability.jsonl` | capability flag toggles | append, 0600 | `audit.hexa::audit_emit_capability` ← `policy.hexa::policy_capability_set` |
| `state/ghost_capability_pf_anchor.conf` | rendered pf anchor (operator-runnable) | 0600 | `route.hexa::capability_engage_kill_switch` — never auto-loaded |
| `state/leak_reports/<ts>.jsonl` | DNS / IPv6 / WebRTC / SNI leak verdicts | 0600 | `selftest.hexa::selftest_run_all` ← invoked at sweep / broadcast tier upshift |

All five streams are G2-clean by construction (whitelist-only fields, pattern detectors for URL / IPv4 / IPv6 in the audit emit path). `_ensure_state_dir` reaffirms `chmod 0600` on every emit — idempotent, so a manually relaxed mode self-corrects on next write.

---

## 12. References

- Mullvad CLI 2026.2 docs — `https://mullvad.net/en/help/install-and-use-mullvad-app-macos`
- Mullvad MultiHop + DAITA + Lockdown — `https://mullvad.net/en/help/wireguard-and-mullvad-vpn`
- Tor Project control protocol — `https://spec.torproject.org/control-spec/`
- Tor `ExcludeExitNodes` / `ExitNodes` — `https://www.torproject.org/docs/tor-manual.html`
- NymVPN client docs — `https://nym.com/docs/operators/nymvpn` (mk1 unpinned — see §10.3)
- macOS pf anchor format — `man pf.conf` / `man pfctl` (Tahoe-26 base)
- MARA Slipstream private mempool relay — referenced in `cpre/scope.ai.md` §sweep tier
- backend comparison + payment strategy — sibling docs in `airgenome/docs/ghost_*_2026_05_04.ai.md`

---

**Landed**: 2026-05-04 by ghost mk1 closure round-3 (cpre + moduler in `airgenome/modules/ghost/` + cross-repo `link/ghost.hexa` adapters in `orpheus/` and `wraith-wallet/` + airgenome layer entry via `bin/airgenome cmd_ghost`). Mullvad single VPN backend locked. Operator activation per §7.
