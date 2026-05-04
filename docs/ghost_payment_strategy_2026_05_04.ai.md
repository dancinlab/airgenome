---
doc: airgenome.docs.ghost_payment_strategy
kind: feature_research
audience: [human, agent]
date: 2026-05-04
mk: 1
status: draft
contributes_to: [ghost.cond.5, ghost.cond.6]
related: [docs/ghost_backend_comparison_2026_05_04.ai.md, docs/ghost_feature_design_inbox_2026_05_04.ai.md]
---

# 🕶️ ghost — payment strategy (Mullvad mk1, KR operator)

> User mandate 2026-05-04: "일단 Mullvad 마음에 들어서 mk1 을 이걸로 하자 / 결제를 카드로 / 직접 카드결제가 아니더라도 / Mullvad voucher 실물발송 말고 이메일 발송".

## §A. Threat model — what does payment leak?

ghost's anonymity guarantee is for **traffic**, not for the **fact-of-being-a-Mullvad-customer**. Card payments expose the latter. The relevant question is **which deanonymization paths a card payment unlocks**.

### A.1 Direct card payment (mullvad.net Stripe)

```
KR cardholder ──Stripe──→ Mullvad
        ↑                     ↑
       카드사 보관 (5y+)      16-digit account (no PII)
                               결제 토큰 단기 보관
```

- **Stripe** sees: card number + cardholder name + billing address + Mullvad merchant + amount.
- **Mullvad** sees: payment success token + 16-digit account number. **No name, no email, no card number.**
- **KR card issuer** sees: 해외결제 — Mullvad/Stripe 머천트 + amount + date.

**Single-hop link**: KR 정부 → KR 카드사 자료 압수 (KR 회계법 5y+ 보관) → "이 사람 Mullvad 결제함" 단일 단계로 확인 가능. Stripe + Mullvad MLAT은 추가로 필요하지 않음 (KR 카드사 단독으로 충분). **트래픽 내용은 별개로 영영 안 새어나감** (Mullvad RAM-only servers + Cure53/Assured no-logs audit certified).

### A.2 Reseller voucher (carded → email/Signal)

```
KR cardholder ──→ reseller (Cryptvice/GiftCardFlix/CoinGate)
                          ↓ voucher 코드 (email/Signal)
                  KR cardholder ──redeem──→ Mullvad 16-digit
```

- **카드사** 가 보는 머천트: Cryptvice / GiftCardFlix / CoinGate (Mullvad 아님).
- **Reseller** 가 본 정보: 카드 결제 정보 + voucher 코드 발행. **하지만 어느 16자리 계정에 redeem 됐는지는 모름.**
- **Mullvad** 가 본 정보: voucher redeem 됨 + 16자리 계정 활성화. **하지만 누가 그 voucher 샀는지는 모름.**

**Two-hop link**: KR 정부 → KR 카드사 → "Cryptvice voucher 샀음" 까지는 갑니다. 하지만 **"Mullvad 16자리=XYZ"** 까지는 reseller↔Mullvad 사이 link가 없어서 자동으론 안 이어짐. Mullvad 트래픽 패턴 외엔 단서 없음.

### A.3 Cash / Monero (참조용 — 카드결제 범위 외)

- **Cash mailed to Sweden** — 봉투 안에 16자리 적어서 보냄. Mullvad 본사 도착 → 그 자리에서 매칭 → 익명성 최강. KR 사용자에겐 우편 시간 + 비용 비현실적.
- **Monero direct** — XMR을 KR 거래소에서 사야 하는데 KR 거래소가 모두 XMR 상장폐지 (Travel Rule). 우회 (해외 거래소 → P2P) 가능하지만 복잡.

## §B. Email-delivered Mullvad voucher resellers (2026-05-04)

| 리셀러 | 카드결제 | 발송 채널 | 가격 (Mullvad 6mo / 12mo) | 결제 처리자 | 평가 |
|---|---|---|---|---|---|
| **Cryptvice** ⭐ | Visa / MC / AmEx / Maestro / PayPal / Apple Pay / Google Pay / BTC | Email · **WhatsApp · Signal · Telegram** · 우편 | €25 / €55 (12mo는 2 코드) | (자체 결제 게이트웨이) | 익명성 명시 / 12언어 / worldwide / 동작 중 [per https://www.cryptvice.com/shop/mullvad-vpn-voucher-subsciption/, 2026-05-04] |
| GiftCardFlix | Visa / MC / Apple Pay / Google Pay / crypto | Email instant | $50 / $75 / $100 / $150 / $200 / $250 USD | (자체 처리) | ⚠️ "System Upgrade in Progress — Payments are temporarily disabled" 2026-05-04 시점 [per https://giftcardflix.com/Shop/mullvad-vpn/, 2026-05-04] |
| CoinGate | Visa / MC / Apple Pay / Google Pay / SEPA / 다양한 crypto | Email avg 63s instant | (out-of-stock — restock 알림) | CoinGate (PCI-DSS L1) | 538K+ orders 평판, 2026-05-04 재고 없음 [per https://coingate.com/gift-cards/mullvad-vpn, 2026-05-04] |
| SerialCart (오스트리아) | Visa / MC | Email digital | 25% off (구체 가격 미확인) | (자체 처리) | 정보 적음 [per https://serialcart.com/purchase/mullvad-vpn, 2026-05-04] |
| Amazon US/UK/DE/etc. (참조) | Visa / MC | **물리 카드 only** (Prime delivery) | $5 단위 | Amazon | KR 미판매 — Amazon US/UK 해외배송 필요. **이메일 발송 X** [per https://mullvad.net/en/blog/mullvads-physical-voucher-cards-are-now-available-in-11-countries-on-amazon, 2026-05-04] |
| Mullvad 직판 | Visa / MC (Stripe) + KRW | (계정 등록 후 즉시 활성화) | €5 / 월 균일 | Stripe | mk1 직판 옵션. layer 분리 0 [per https://mullvad.net/en/pricing, 2026-05-04] |

**KR 사용자 권장**: **Cryptvice** — email/Signal 즉시 발송 + 다양한 카드 + 익명성 명시 + 가격 직판과 동등 (€25/6mo = 월 €4.17, 직판 €5/월보다 17% 저렴).

## §C. Tier-based payment policy

ghost의 tier 모델 (`docs/ghost_feature_design_inbox_2026_05_04.ai.md` §C 참조) 별 결제 등급:

| Tier | 사용 케이스 | 권장 결제 | KR 정부 link 끊는 정도 |
|---|---|---|---|
| **research** | 유튜브, 일상, puzzle 리서치, mempool 조회, GitHub | **직판 카드 OK** (mullvad.net Stripe) | 1-hop (카드사→Mullvad 결제 사실) — 트래픽은 안전 |
| **sweep** | wraith broadcast (Slipstream POST) 직전 단계 | **Cryptvice voucher (카드)** 또는 cash | 2-hop (카드사→Cryptvice→???) — voucher↔16자리 link 끊김 |
| **broadcast_high_value** | #135-class sweep ≥10 BTC | **현금 봉투 (Mullvad 본사) 또는 Monero** | full anonymity — 카드 link 0 |

**핵심 디자인 원칙**: tier가 올라갈수록 결제 layer 분리도 증가. broadcast tier 도달 전에 결제 격상해두면, 막상 broadcast 시점엔 이미 voucher-redeem 된 별개 16자리 계정이 standby 상태.

## §D. KR operator 실용 절차 (mk1)

### D.1 입문 — Tier=research 용 (즉시 시작)

```
Day 0
  mullvad.net → 16자리 계정 생성 (이메일 X, 비번 X)
  mullvad.net/payment → Visa/MC, KRW Stripe → 1개월 €5 (~7,000원)
  → 즉시 활성화. multihop+DAITA 켜고 일상 사용 시작.
```

비용: 7,000원/월. 매월 수동 top-up (자동갱신 X — 2022-06부터 카드 구독 차단).
보안: 트래픽 안전 ✅. 본인↔Mullvad-사용자 link은 KR 정부 압수 시 추적 가능.

### D.2 격상 — Tier=sweep 직전 (broadcast 시점 D-7 이전)

```
Day -7  Cryptvice.com → Mullvad VPN voucher 6mo (€25)
        Visa/MC 결제 → **Signal 발송 옵션** 선택
        (이메일조차 우회 — 카드사 자료에서 reseller 다음 단계 추적 더 어려움)

Day -5  Mullvad.net → **새 16자리 계정 별도 생성** (research용과 분리)
        voucher 코드 redeem → 6개월 활성화 (€4.17/월)
        broadcast 전용 16자리 계정 = standby

Day  0  wraith broadcast 시점:
        ghost::route(tier=sweep) → 새 16자리 계정의 Tor-over-Mullvad 사용
        → research 계정과 traffic pattern 분리, KR 정부 link 두 단계로 끊김
```

추가 timing correlation 회피:
- voucher 구매와 redeem 사이 **24-48시간 텀**.
- redeem 시 이미 첫 16자리 계정 (research용) 으로 mullvad VPN 접속 중인 상태 → 소스 IP가 mullvad-exit 으로 보여 KR 카드사↔redeem 시점 IP correlation 더 끊김.

### D.3 최고 단계 — Tier=broadcast_high_value (#135-class)

```
3-6개월 사전:
  Mullvad 본사 (스웨덴) 우편으로 cash + 새 16자리 봉투 발송
  Cash €60 (12개월) — 자기 손글씨 X (인쇄), 발송 주소도 가공 또는 PO box
  도착 후 매칭되면 12개월 활성화 — KR 정부 link 0
```

비용: cash + 우편비. 시간: 1-2주. 보안: 카드 link 완전 0, full anonymity.
> 이건 진짜 #135-class 시점 이전엔 서두를 필요 없음. mk1 단계에선 D.1 + D.2 만 충분.

## §E. cond.5 policy.hexa 매핑

`modules/ghost/policy.hexa` 가 결제 source 메타데이터를 받아서 tier mismatch 거부할 수 있게 데이터 모델 제안:

```hexa
// payment_source 필드 — 16자리 계정 메타데이터로 보관 (audit 메타에만, 트래픽 X)
//   "card_direct"     — 카드 직판 (research 만 허용)
//   "card_reseller"   — 카드 → reseller voucher (research, sweep 허용)
//   "cash"            — 현금 봉투 (모든 tier 허용)
//   "monero"          — XMR 직접 (모든 tier 허용)

fn policy_payment_tier_compatible(payment_source: str, tier: str) -> bool {
    if tier == "research"            { return true }
    if tier == "sweep" {
        return payment_source != "card_direct"
    }
    if tier == "broadcast_high_value" {
        return payment_source == "cash" || payment_source == "monero"
    }
    return false
}
```

cond.5 verifier 확장안:
```bash
# 기존: exit allowlist + KR Tor deny + G5 guard
# 추가: payment_source ↔ tier compatibility
hexa run modules/ghost/policy.hexa --check-payment=card_direct --tier=broadcast_high_value | grep -q 'reject'
hexa run modules/ghost/policy.hexa --check-payment=cash --tier=broadcast_high_value | grep -q 'allow'
```

이 매핑으로 **운영자가 실수로 카드결제 계정으로 broadcast 트리거** 하는 사고 방지 (G4 + G10 시너지).

## §F. cond.6 cross-repo 영향

wraith-wallet의 W4 broadcast policy gate에 ghost::tunnel_alive() 외에 ghost::payment_tier_compatible() 추가 호출 권장:

```
wraith broadcast 호출 흐름:
  1. ghost::tunnel_alive() → up?            (G4)
  2. ghost::payment_tier_compatible(tier)   ← cond.5 추가 게이트
  3. ghost::route(tier) → handle             (cond.4)
  4. wraith POST via handle                  (W2/W3 envelope)
```

만약 (2) 가 false 면 wraith는 broadcast 거부 → 운영자가 결제 격상 권유 받음. broadcast 시점 직전 잘못된 결제 등급으로 사고 시도 자체를 차단.

## §G. 정리

| 결정 항목 | mk1 결론 |
|---|---|
| Mullvad 가입 결제 | **Cryptvice voucher (Signal 발송)** ← 권장 / 직판 카드도 OK (research 한정) |
| 가격 | €25/6mo (Cryptvice) 또는 €5/월 (직판) |
| 격상 트리거 | sweep tier 사용 시점 D-7 이전 voucher 결제 + 별개 16자리 |
| broadcast_high_value | Phase 2 — cash 봉투 또는 Monero (mk1 단계 작업 X) |
| cond.5 영향 | payment_source ↔ tier 호환성 게이트 추가 |
| cond.6 영향 | wraith W4 broadcast gate에 payment_tier_compatible 호출 추가 |

## §H. References

- [Cryptvice Mullvad VPN Voucher Subscription](https://www.cryptvice.com/shop/mullvad-vpn-voucher-subsciption/) — 2026-05-04
- [GiftCardFlix Mullvad VPN](https://giftcardflix.com/Shop/mullvad-vpn/) — 2026-05-04
- [CoinGate Mullvad VPN Gift Card](https://coingate.com/gift-cards/mullvad-vpn) — 2026-05-04
- [Mullvad Partnerships and Resellers](https://mullvad.net/en/help/partnerships-and-resellers) — 2026-05-04
- [Mullvad Pricing (KRW Stripe)](https://mullvad.net/en/pricing) — 2026-05-04
- [Mullvad voucher cards on Amazon (physical)](https://mullvad.net/en/blog/mullvads-physical-voucher-cards-are-now-available-in-11-countries-on-amazon) — 2026-05-04
- [Mullvad: removing card subscription option (2022-06)](https://mullvad.net/en/blog/were-removing-the-option-to-create-new-subscriptions) — 2022-06 / 2026-05-04 confirmed still applies
- [Mullvad: support for more local currencies (KRW added)](https://mullvad.net/en/blog/support-for-more-local-currencies-when-paying-for-mullvad-when-using-paypal) — 2024-05-06
