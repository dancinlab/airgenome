# EDID — DisplayLink USB 모니터 해상도 옵션 노출

@goal: DisplayLink USB 로 연결된 LG UltraFine 4K portrait 모니터에 macOS 가 기본 숨기는 HiDPI 스케일 + 1:1 native 모드를 EDID override 로 노출 — 시스템 설정에서 선택 가능하게.

## 적용 대상

| 항목 | 값 |
|---|---|
| 모니터 | LG UltraFine 4K (DisplayLink USB 연결, portrait rotation) |
| Vendor ID | `0x1e6d` (LG Electronics) |
| Product ID | `0x5cbb` |
| 단위 수 | 2 (둘 다 같은 product code → single override 가 양쪽 적용) |
| 패널 네이티브 | 2160 × 3840 |
| 발견 방법 | `CGGetActiveDisplayList` Swift probe (ioreg 는 DisplayLink 가상 디스플레이 미노출) |

## Override 파일

```
/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-1e6d/DisplayProductID-5cbb
```

- 소유자: `root:wheel`
- 모드: `644`
- 크기: 750 bytes
- 포맷: XML plist
- 작성 권한: `sudo` 필요

## 노출되는 7 모드

| # | 폭 × 높이 | HiDPI | 용도 |
|---|---|---|---|
| 1 | 1080 × 1920 | 2× | 기본 (macOS 디폴트와 동일) |
| 2 | 960 × 1707 | 2× | 약간 타이트한 UI |
| 3 | 864 × 1536 | 2× | 더 작은 UI |
| 4 | 810 × 1440 | 2× | 가장 작은 실용 HiDPI |
| 5 | 2160 × 3840 | 1:1 | 패널 네이티브 (UI 최소, framebuffer 그대로) |
| 6 | 1620 × 2880 | 1:1 | 1:1 중간 |
| 7 | 1080 × 1920 | 1:1 | 1:1 작은 (framebuffer 1/4) |

## 적용 방법

### A. airgenome init (권장 — 통합 setup)

```
airgenome init
```

내부적으로 `cmd_hush` 후 `cmd_display_override` 호출. sudo prompt 1회.

### B. 단독 호출

```
airgenome display-override
```

idempotent — 이미 airgenome-managed 마커가 있으면 skip.

### C. 적용 후 단계

1. 재부팅 (필수 — macOS 가 부팅 시 EDID override 캐시 등록)
2. 시스템 설정 → 디스플레이 → LG UltraFine 선택
3. Option(⌥) 누른 채 "해상도" 클릭 → 새 7개 모드 노출
4. 원하는 모드 선택

## 한계

| 한계 | 설명 |
|---|---|
| CPU pump 감소 미보장 | DisplayLink USB framebuffer 크기는 firmware 가 패널 네이티브 (2160×3840) 로 강제. EDID override 는 UI scale 모드만 추가 노출. |
| 재부팅 필수 | EDID 캐시는 부팅 시점에 macOS 가 1회 읽음. 런타임 핫리로드 없음. |
| 패널 네이티브 변경 불가 | 일반 HDMI/DP 모니터와 달리 DisplayLink 는 panel native 자체를 override 못 함. |

## 롤백

```
sudo rm /Library/Displays/Contents/Resources/Overrides/DisplayVendorID-1e6d/DisplayProductID-5cbb
```

재부팅하면 macOS 기본 동작 복원.

## 구현 위치

| 표면 | 내용 |
|---|---|
| `bin/airgenome` | `cmd_display_override` 함수 (66줄) + `cmd_init` 통합 + dispatch 등록 |
| 인코딩 | python3 plistlib · 16-byte big-endian entries per scaled-resolution |
| Idempotency | airgenome-managed grep 마커 |

## 관련

- [[AIRGENOME]] — 전체 airgenome 도메인
- [[HUSH]] — `cmd_hush` (macOS 부하 완화) 와 `cmd_init` 안에서 sequential 적용
- DisplayLink 식별자 발견: `swift /tmp/list_displays.swift` (CoreGraphics CGGetActiveDisplayList)
- macOS Sequoia 의 `/System/Library/Displays/...` 는 SIP, 사용자 측은 `/Library/Displays/...` (자동 mkdir)
