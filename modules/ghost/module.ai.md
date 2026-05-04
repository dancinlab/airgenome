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

## Surface (mk1 — airgenome layer entry)

### airgenome bash CLI (operator-facing)

```
airgenome ghost up [tier]      enable VPN — Mullvad MultiHop SE→JP + DAITA + Lockdown
                                 tier ∈ research (default) | sweep | broadcast_high_value
                                 mk1 = Mullvad only; non-research tiers fall-back with
                                 explicit "ok degraded" surface (G10 audit downgrade)
airgenome ghost down            disable VPN
airgenome ghost status          state label: up | connecting | down | unknown
airgenome ghost health          alias of status
airgenome ghost tunnel-alive    exit 0 if alive / exit 1 if down (wraith W4 gate)
airgenome ghost selftest        wrap_mullvad + route smoke test
airgenome ghost available       does the system have `mullvad` binary?
```

### hexa-side surface (route.hexa, called by airgenome CLI)

`route.hexa` exposes mk1 functions; orchestration shells out to `wrap_mullvad.hexa`
subcommands via subprocess (workaround for hexa stage1 import-as-alias void bug —
mirrors orpheus `blk.3`).

```
ghost_up(tier: str) -> str          "ok: ..." / "ok degraded: ..." / "unavailable: ..."
ghost_down() -> str                 "ok" / "unavailable"
ghost_health() -> str               "up" | "connecting" | "down" | "unknown"
ghost_tunnel_alive() -> bool        cross-repo G4↔W4 gate
selftest() -> void                  emits __GHOST_ROUTE__ <PASS|FAIL|SKIP>
```

### wrap_mullvad.hexa CLI (G1 chokepoint, 직접 호출 권장 X)

```
hexa run modules/ghost/wrap_mullvad.hexa <sub>
  self-test | health | available
  connect | disconnect | reconnect
  relay-set <country>           e.g. jp / se / ch / sg
  multihop-set <entry> <on|off>
  daita-set <on|off>
  lockdown-set <on|off>
```

route.hexa 가 위 subcommands 를 subprocess 로 호출 — 일반 호출자는 `airgenome ghost`
또는 `route.hexa` 의 ghost_* 함수만 사용.

## Cross-repo gate (cond.6 paired)

wraith-wallet 의 W4 broadcast policy gate 는 broadcast 직전 다음 호출:

```bash
# wraith side (예시)
if ! airgenome ghost tunnel-alive; then
    echo "broadcast denied: ghost tunnel down (G4)" >&2
    exit 1
fi
# proceed with broadcast through ghost::route(tier=sweep)
```

orpheus 의 외부 HTTP 호출도 동일 패턴 — research tier 가 활성 상태인지 먼저 확인.

## Tier ↔ backend mapping (mk1)

| tier | backend (mk1) | backend (mk2 candidate) | 정책 |
|---|---|---|---|
| research | Mullvad MultiHop SE→JP + DAITA + Lockdown | + Proton secure-core (cond.12+) | 기본값 |
| sweep | (mk1) Mullvad fall-back + G10 downgrade record | Tor over Mullvad (cond.3) | 카드결제 voucher 권장 |
| broadcast_high_value | (mk1) Mullvad fall-back + G10 | Nym mixnet 5-hop (cond.10) | cash/Monero only |
| customer (DEFER) | — (Phase 2 only) | Nym mixnet | KR ISMS/PIPA review 후 |

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
