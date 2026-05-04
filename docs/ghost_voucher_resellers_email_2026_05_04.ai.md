---
doc: airgenome.docs.ghost_voucher_resellers_email
kind: shopping_reference
audience: [human, agent]
date: 2026-05-04
mk: 1
status: draft
contributes_to: [ghost.cond.5, ghost.cond.6]
related: [docs/ghost_payment_strategy_2026_05_04.ai.md, docs/ghost_backend_comparison_2026_05_04.ai.md]
---

# 🕶️ ghost — Mullvad voucher 구매처 (이메일 발송 only, 실물 카드 제외)

KR operator 가 카드결제 ↔ Mullvad 16자리 link 끊고 싶을 때 쓰는 reseller 리스트. **실물 카드 우편배송 (Amazon Prime 등) 은 제외** — 우편 시간/주소 노출 둘 다 KR 기준 비현실적.

## §A 한눈 결정 매트릭스 (2026-05-04 시점)

| 우선순위 | 리셀러 | 카드 | 발송 | 가격 (Mullvad 6mo) | 현재 상태 | KR 접근 |
|---|---|---|---|---|---|---|
| 🥇 **1순위** | **Cryptvice** | Visa/MC/AmEx/Maestro/PayPal/Apple/Google Pay/BTC | Email · **Signal** · WhatsApp · Telegram | **€25.00** (12mo €55) | ✅ 동작 중 | worldwide, 12언어 |
| 🥈 2순위 | SerialCart (오스트리아) | Visa/MC/PayPal | Email digital (~12hr) | $32.05+ (25% off) | ✅ 동작 중 | 외 EU 가능 (VAT 면제) |
| 🥉 3순위 | GiftCardFlix | Visa/MC/Apple/Google Pay/crypto | Email instant | $50–$250 USD | ⚠️ "System Upgrade in Progress — Payments temporarily disabled" | 미명시 (USD 카드면 보통 OK) |
| 보조 | CoinGate | Visa/MC/Apple/Google Pay/SEPA/crypto | Email avg 63s | (가변) | ⚠️ Out-of-stock — restock 알림 신청 가능 | 미명시 |
| (참조) | Mullvad 직판 | Visa/MC + KRW Stripe | 즉시 (계정 활성화) | €5/월 직판 | ✅ 동작 중 | KR 카드사 ↔ Mullvad **단일 hop link** — 격상 효과 0 |

> 📌 **첫 가입은 Cryptvice Signal 발송 권장**. 단일 hop (직판) 보다 KR 정부 카드사 자료 추적이 한 단계 더 멀어짐.

## §B 리셀러 상세

### B.1 🥇 Cryptvice — 권장

| 항목 | 값 |
|---|---|
| URL | https://www.cryptvice.com/shop/mullvad-vpn-voucher-subsciption/ |
| 본사 | EU (정확한 국가 미공시) |
| 결제 | Visa, Mastercard, AmEx, Maestro, PayPal, Apple Pay, Google Pay, Bitcoin, 추가 crypto |
| **발송 채널** | **Email · Signal · WhatsApp · Telegram · 우편** (5개 옵션 — Signal 권장) |
| 가격 | **6mo €25.00 / 12mo €55.00** (12mo 는 1년짜리 voucher 2개로 분할 발급) |
| 환불 | 31일 returns (조건 미상세 — 결제 후 미사용 voucher 한정 추정) |
| 익명성 | "no personal details required" 명시 |
| KR 사용자 | worldwide 표시, 12개 언어 (영/덴/네/프/이/폴/스/스웨/터/포/독). 한국어 X — 영어 결제 |
| 처리시간 | 결제 승인 후 즉시 (Signal 발송 시 매우 빠름) |

**구매 절차** (KR 사용자 표준):
1. https://www.cryptvice.com/shop/mullvad-vpn-voucher-subsciption/ 접속
2. License 선택 (6mo / 12mo)
3. **Voucher Send** 옵션에서 **Signal** 선택 (이메일조차 우회 — 카드사 자료에 reseller 다음 단계 추적 더 어려움)
4. Signal 번호 입력 (별도 burner 번호 권장 — KR SKT/KT/LG 본인명의 X)
5. Visa/MC 결제 → 승인 후 Signal 으로 voucher 코드 도착

**redeem 절차**:
1. **24-48시간 대기** (결제↔redeem timing correlation 회피)
2. mullvad.net 접속 → **새 16자리 계정 생성** (research용 기존 계정과 분리하려면 별개)
3. account 페이지 → "Redeem voucher" → 코드 입력 → 6/12개월 활성화

### B.2 🥈 SerialCart — 백업 (오스트리아)

| 항목 | 값 |
|---|---|
| URL | https://serialcart.com/purchase/mullvad-vpn |
| 본사 | 오스트리아 (EU) |
| 결제 | Visa, Mastercard, PayPal |
| 발송 채널 | Email digital (자동) |
| 가격 | $32.05+ (excl. VAT, "25% discount" 광고) — 1년 단위. 3년 구매 시 1-year voucher 3장 분리 발급 |
| 처리시간 | 90% 가 12시간 이내, 최대 2 영업일 (Cryptvice 보다 느림) |
| KR 접근 | EU 외부 구매 시 VAT 면제 명시 (UK 사례) — KR도 동일 처리 추정 |
| 단점 | Signal/메신저 발송 X. 이메일 단일 채널 |

**언제 SerialCart**: Cryptvice 다운/매진 시. 또는 1년 단위 한꺼번에 사고 싶고 25% 할인 효과 활용 시.

### B.3 🥉 GiftCardFlix — 결제 정상화 후 사용

| 항목 | 값 |
|---|---|
| URL | https://giftcardflix.com/Shop/mullvad-vpn/ |
| 본사 | 미국 (전화 +1 917 720 5339) |
| 결제 | Visa, Mastercard, Apple Pay, Google Pay, BTC, ETH, LTC, USDC, USDT |
| 발송 채널 | Email instant |
| 가격 | $50 / $75 / $100 / $150 / $200 / $250 USD denominations |
| 현재 상태 | ⚠️ **"System Upgrade in Progress — Payments are temporarily disabled"** (2026-05-04 시점) — 결제 불가 |
| 재시도 | 정상화 후 1순위 후보 (denominations 다양 + Apple/Google Pay 빠름) |

### B.4 보조 — CoinGate

| 항목 | 값 |
|---|---|
| URL | https://coingate.com/gift-cards/mullvad-vpn |
| 본사 | 리투아니아 (EU PSD2 PCI-DSS L1) |
| 결제 | Visa, Mastercard, Apple Pay, Google Pay, SEPA, crypto 다수 |
| 발송 채널 | Email instant (avg 63s) |
| 가격 | (가변 denominations) — 현재 미공시 |
| 현재 상태 | ⚠️ **Out-of-stock** — restock notification 가입 가능 |
| 평판 | 538,500+ orders, 1,007,200+ gift cards sold, 4.3/5 |

## §C KR 사용자 특별 고려사항

### C.1 카드사 자료 추적 시나리오

| 시나리오 | 추적 가능 정보 |
|---|---|
| Mullvad **직판** Stripe 결제 | KR 카드사 → Stripe → "Mullvad 가입자 = 본인" 단일 hop 확인 |
| Cryptvice **Signal 발송** | KR 카드사 → Cryptvice → "voucher 샀음" 까지만. **redeem 16자리는 Cryptvice도 모름** |
| SerialCart Email | 카드사 → SerialCart → "voucher 샀음". 이메일 발송 시 Gmail/Naver 메타데이터 추가 link 가능 |
| Cryptvice **Signal + 24h 대기 + burner 번호** | 카드사 → Cryptvice → "Signal 으로 보냈음". Signal 번호↔본인 link 별도 |

### C.2 Signal 번호 권장 옵션

KR 본인명의 휴대폰 번호로 Signal 받으면 최종 link 완성 → 권장 X:
- **eSIM 해외 임시 번호** (Airalo/Holafly 등) — 결제 1회용 가능
- **VoIP 번호** (TextNow, Hushed 등) — 무료/저렴
- **mailbox.org** 같은 익명 가능 이메일 → Cryptvice "Email" 옵션 (Signal 보다 한 단계 약함, 그래도 본인명의 휴대 X)

### C.3 KRW vs EUR 환율 비교 (2026-05-04 추정)

| 옵션 | 가격 | 월 환산 | KRW (1EUR≈1480원, 1USD≈1380원) |
|---|---|---|---|
| Mullvad 직판 | €5 / 월 | €5 | ~7,400원/월 |
| Cryptvice 6mo | €25 | €4.17 | ~6,170원/월 (17% 절약) |
| Cryptvice 12mo | €55 | €4.58 | ~6,780원/월 (8% 절약) |
| SerialCart 1yr | $32.05 | $2.67 | ~3,690원/월 (50% 절약 — VAT 면제 시) |

> SerialCart 는 가격 가장 좋음, Cryptvice 는 발송 채널 + 익명성 더 좋음. **mk1 입문 = Cryptvice, 가격 최적화 = SerialCart 1년 단위**.

## §D 표준 구매-redeem 절차 (KR mk1)

### D.1 첫 voucher 구매 (Cryptvice)

```
Day 0   Cryptvice.com 접속 → Mullvad 6mo (€25)
        결제: Visa 또는 MC (KR 카드 OK)
        발송: Signal (burner 번호 권장)
        도착: 결제 승인 후 즉시 (수 분)

Day 1+  voucher 코드 받음. 24-48시간 보관 (timing correlation 회피)
```

### D.2 redeem (별개 16자리)

```
Day 2-3  mullvad.net → "Generate account number" → 새 16자리 받음
         (research용 기존 계정과 분리하려면 별개 계정 — 하나로 통일도 가능)
         "Redeem voucher" → 코드 입력 → 6개월 활성화

         16자리 안전 보관 (1Password / Bitwarden / 종이 메모 + 금고)
         이 번호 잃어버리면 계정 영구 손실 (이메일/비번 없음 → 복구 불가)
```

### D.3 활성 사용

```
Day 4+   wrap_mullvad.hexa 의 mullvad_connect() 호출 시
         이 16자리 계정 token 으로 daemon 인증
         → Mullvad VPN 정상 동작
         → ghost::route(tier=research) 통해 일상 사용
```

## §E 비상 옵션 (모든 reseller down 시)

상위 3 곳 모두 매진/다운 시:

1. **Mullvad 직판 Stripe** — 가장 단순, 격상 효과는 없음. mk1 입문에 한해 OK.
2. **Cash 봉투** — €60 (12mo) cash + 16자리 적힌 종이 → Mullvad 본사 (스웨덴 GoteBorg) 우편. 도착까지 1-2주. 가장 강한 익명성.
3. **Monero 직접** — XMR 보유 시 mullvad.net 에서 XMR 결제 가능. KR 거래소는 XMR 상장폐지 (Travel Rule) → 해외거래소 (Kraken/CakeWallet swap) 우회 필요.

## §F 변동성 대응

이 doc 는 2026-05-04 fetched 정보. reseller 가격/재고/결제수단은 자주 변경. 재구매 시 (3-6개월 후):
1. 이 doc 의 §A 매트릭스 재검증 — 각 URL 접속 + 결제수단 확인
2. 변경사항 발견 시 mk2 또는 별도 inbox doc 으로 갱신
3. cond.5 policy.hexa 의 payment_source 분류는 reseller 변동에 영향받지 않음 (라벨만 사용)

## §G References

- [Cryptvice Mullvad VPN Voucher](https://www.cryptvice.com/shop/mullvad-vpn-voucher-subsciption/) — 2026-05-04 (fetched)
- [GiftCardFlix Mullvad VPN](https://giftcardflix.com/Shop/mullvad-vpn/) — 2026-05-04 (fetched)
- [CoinGate Mullvad VPN Gift Card](https://coingate.com/gift-cards/mullvad-vpn) — 2026-05-04 (fetched)
- [SerialCart Mullvad VPN](https://serialcart.com/purchase/mullvad-vpn) — 2026-05-04 (fetched)
- [Mullvad Pricing (Stripe direct, KRW supported)](https://mullvad.net/en/pricing) — 2026-05-04
- [Mullvad: Partnerships and Resellers (공식 리셀러 리스트)](https://mullvad.net/en/help/partnerships-and-resellers) — 2026-05-04
- [Mullvad blog: removing card subscription](https://mullvad.net/en/blog/were-removing-the-option-to-create-new-subscriptions) — 2022-06 (still applies 2026-05-04)
