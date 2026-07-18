# MacBook Air M3 — 3대 모니터 구성 가이드 (Studio Display + LG ×2)

작성일: 2026-05-12

## 0. 환경 요약

| 항목 | 값 |
|---|---|
| 호스트 | MacBook Air M3 (10코어 GPU, TB/USB4 ×2) |
| 모니터 1 | Apple Studio Display 5120×2880 (TB3 일체형 케이블) |
| 모니터 2 | LG Ultrafine (5120×2880, 회전 90° 사용 중) |
| 모니터 3 | LG (추가 예정) |
| 허브 | CalDigit Element 5 Hub (TB5) |
| 사용 형태 | **클램셸 모드** (MBA 뚜껑 닫힘) |

---

## 1. 초기 진단 — Studio Display 연결 상태

```bash
system_profiler SPDisplaysDataType
system_profiler SPThunderboltDataType
```

확인된 사실:
- Studio Display: Retina LCD 5120×2880, Main Display, Online
- TB/USB4 Bus 0 Receptacle 1: Studio Display 연결 (40Gb/s, TB3 모드)
- TB/USB4 Bus 1 Receptacle 2: 비어있음

→ 한 포트는 Studio Display가 차지, 다른 포트는 LG 추가 가능.

---

## 2. LG 모니터 연결 시도 — 무엇이 동작했는가

| 시도 경로 | 영상 통과 | 이유 |
|---|---|---|
| LG → Studio Display 뒷면 USB-C 3포트 | ❌ | Studio Display의 USB-C는 **USB 2.0 데이터 전용** — DP Alt Mode 미지원, Apple이 의도적으로 패스스루 차단 |
| LG → 일반 USB-C 허브 | ❌ | DP Alt Mode 패스스루나 DisplayLink 칩 없으면 영상 신호 못 옮김 |
| LG → MBA 직결 (USB-C/HDMI 허브 경유) | ✅ | MacBook USB-C 포트가 **DP Alt Mode**로 영상 직출력 |
| 모니터 뒷면 "USB Upstream" 포트 | ❌ | 이건 모니터 USB 허브를 호스트에 연결하는 데이터 포트. 영상 입력 아님 |

**핵심 교훈:**
- Studio Display는 **데이지체인 종단 장치** — 다운스트림 영상 출력 없음
- 일반 USB 허브로는 절대 두 번째 모니터 못 연결
- TB(Thunderbolt) 또는 DP Alt Mode 지원 USB-C 또는 DisplayLink만이 영상 가능

---

## 3. CalDigit Element 5 Hub로 토폴로지 통합

### 3.1 Element 5 Hub 사양

| 항목 | 값 |
|---|---|
| 호스트 포트 | TB5 ×1 (뒷면, 컴퓨터 아이콘 ⬅) |
| 다운스트림 | TB5 ×3 |
| 부가 | USB-A 10Gbps ×3 (전면) |
| PD to 호스트 | 90W |
| 전원 어댑터 | 180W 내장 |

### 3.2 권장 토폴로지 (모니터 2대까지 — 네이티브)

```
벽전원 → Element 5 어댑터 (180W) → 허브 DC 입력

[HOST 💻]  ── TB5 케이블 ──→ MBA (TB 포트 1)
[TB5-1]    ── TB3 일체형  ──→ Studio Display
[TB5-2]    ── TB/USB-C   ──→ LG #1
[TB5-3]    (비움 — 외장 SSD/카메라 등 확장)

전면 USB-A ×3 → 키보드/마우스/유선 헤드셋
```

### 3.3 연결 순서 (PD 협상 안정화)

1. Element 5 어댑터 → 벽전원 (허브 LED 켜짐 확인)
2. 키보드/마우스 → 허브 USB-A
3. Studio Display, LG → 허브 TB5 포트
4. MBA → 허브 HOST 포트 (MBA 뚜껑 **열린 상태**로)
5. 두 모니터 활성화 확인
6. MBA 뚜껑 닫기 → 자동 클램셸 전환

### 3.4 체크리스트

- [ ] MBA → Studio Display **직결 케이블 분리** (이중 PD 협상 방지)
- [ ] 박스 동봉 **TB5 케이블** 사용 (다른 USB-C는 TB3로 다운네고)
- [ ] HOST 포트(컴퓨터 아이콘)에만 MBA 꽂기 — 다른 TB5 포트에 꽂으면 인식 안 됨
- [ ] PD 90W → MBA 충전 (정품 35W의 2.5배, 충분)

---

## 4. M3 MacBook Air 외부 모니터 상한

| 조건 | 외부 모니터 최대 | 출처 |
|---|---|---|
| 뚜껑 열림 | **1대** | Apple 공식 사양 |
| 뚜껑 닫힘 (클램셸) + 전원 연결 | **2대** (각 최대 5K @ 60Hz) | macOS Sonoma 14.6+ 부터 정식 지원 |
| 클램셸 + DisplayLink 어댑터 | **3대 이상** (최대 5대까지 가능) | DisplayLink 우회 |

### 4.1 클램셸 모드 요건
- MBA 뚜껑 완전 닫힘 (안 닫히면 내장 디스플레이가 외부 1대를 잡아먹음)
- 전원 공급 필수
- 외부 키보드/마우스 필수 (BT 또는 USB-A)
- Touch ID, 내장 스피커/캠 사용 불가

### 4.2 클램셸 성능 저하
- 일부 사용자 리포트: 최대 50% 성능 드랍 (열 제한)
- 원인: 책상 면에 본체 밑면이 닿아 방열 면적 감소
- **완화책:** 수직 거치대 (Twelve South BookArc 등)로 옆면 방열 면적 확보

---

## 5. 3대 모니터 구성 — DisplayLink 우회

사용자 요구: Studio Display ×1 + LG ×2 = 총 3대 외부 모니터
M3 MBA 네이티브 한계: 2대
→ **3번째는 DisplayLink 어댑터로 추가**

### 5.1 DisplayLink 제약

| 항목 | 내용 |
|---|---|
| 리프레시 | 60Hz 캡 (120Hz 불가) |
| 지연 | 10~20ms 추가 (게임/영상편집/3D 부적합) |
| HDCP | **Netflix/Disney+/Apple TV+ 등 DRM 콘텐츠 차단** |
| 드라이버 | DisplayLink Manager 앱 설치 + 화면 기록 권한 필수 |
| 성능 | CPU/GPU 부하 (특히 4K 풀스크린) |
| macOS Sequoia/Tahoe | 권한 모델 까다로움 — 업데이트 후 권한 재허용 필요 사례 |

### 5.2 모니터 배정 전략

| 모니터 | 추천 연결 | 이유 |
|---|---|---|
| Studio Display 5K | **네이티브** (TB5 허브) | 5K 대역폭 필요, DisplayLink로 손실 |
| LG #1 (주작업, 코드/영상/색감) | **네이티브** | 풀 60Hz/HDCP, 지연 없음 |
| LG #2 (보조 — Slack, 음악, 모니터링) | **DisplayLink** | 텍스트 위주면 페널티 무감 |

### 5.3 최종 토폴로지 (3대 구성)

```
벽전원 → Element 5 어댑터 (180W)
            │
            ↓
   ┌──[CalDigit Element 5 Hub]──┐
   │                            │
[HOST 💻]──TB5──→ MBA (TB 포트 1)
[TB5-1]──TB3──→ Studio Display
[TB5-2]──TB──→ LG #1
[TB5-3] (비움)
   │                            │
   └────────────────────────────┘

MBA (TB 포트 2) ──→ DisplayLink USB-C 어댑터 ──HDMI──→ LG #2
```

---

## 6. DisplayLink 어댑터 제품 비교

| 모델 | 출력 | 가격 | 특징 | 추천 시나리오 |
|---|---|---|---|---|
| **Plugable USBC-6950M** ⭐ | HDMI ×2 (4K@60Hz) | $90~96 | 컴팩트 85g, DL-6950 칩, M5/Neo까지 공식 지원 | 가장 무난, 가성비 최고 |
| **OWC USB-C Dual HDMI** | HDMI ×2 (4K@60Hz) | $95 | **PD 패스스루 포함** (충전 동시) | MBA 남는 포트가 충전도 겸할 때 |
| **Sonnet USB3 Dual HDMI** | HDMI ×2 (4K@60Hz) | $109 | 1440p/1080p에서 144Hz 지원 | 보조 모니터가 144Hz 게이밍급 |
| **Cable Matters Dual HDMI** | HDMI ×2 (4K@60Hz) | $70~80 | 가성비 | 예산 최우선 |
| **ACASIS Dual HDMI 도크** | HDMI ×2 + USB-A ×3 + PD 100W | $90~100 | USB 허브 일체형 | 케이블 정리도 같이 |

→ 단일 HDMI 저가 모델(예: j5create JCA379)은 4K@30Hz 캡인 구형 다수. 비추.
→ **추천: Plugable USBC-6950M** — 듀얼 모델이라 한쪽 남는 포트로 향후 4번째 모니터 확장 가능.

---

## 7. DisplayLink 설치 단계

1. **앱 다운로드:**
   https://www.synaptics.com/products/displaylink-graphics/downloads/macos
   (macOS Sonoma/Sequoia/Tahoe용 최신 버전)

2. **권한 부여 (필수):**
   - 시스템 설정 → 개인정보 보호 및 보안 → **화면 및 시스템 오디오 녹음** → DisplayLink Manager 허용
   - 미허용 시 검은 화면만 나옴 (가장 흔한 트러블)

3. **자동 실행 설정:**
   DisplayLink Manager 앱 환경설정 → "로그인 시 자동 시작" 켜기

4. **물리 연결:**
   - DisplayLink 어댑터 → MBA 남는 TB 포트
   - HDMI 케이블 → LG #2

---

## 8. 클램셸 부팅 / 깨우기

- **부팅:** 뚜껑 열고 모든 연결 완료 → 두 모니터 활성화 확인 → 뚜껑 닫기
- **깨우기:** 외부 키보드 키 또는 마우스 움직임
  - 블루투스 키보드도 가능 (펌웨어가 BT 유지)
- **디스플레이 배치:** 시스템 설정 → 디스플레이 → 정렬(Arrange) → 모니터 아이콘 드래그
- **메인 디스플레이 변경:** 상단 흰 막대를 원하는 모니터로 이동 (Dock/메뉴바 표시 위치)

---

## 9. 검증 명령

```bash
# 디스플레이 확인 — 3대 모두 Online 잡혀야 함
system_profiler SPDisplaysDataType

# Thunderbolt 체인 확인 — Element 5 Hub, Studio Display, LG 모두 보여야 함
system_profiler SPThunderboltDataType | grep -E "Device Name|Status|Speed"

# 정상 시 Speed: 40Gb/s 이상, Status: Device connected
```

---

## 10. 트러블슈팅 빠른 참조

| 증상 | 원인 / 조치 |
|---|---|
| 클램셸인데 모니터 1대만 잡힘 | 뚜껑이 완전히 안 닫힘 / 전원 미연결 확인 |
| DisplayLink 화면이 검은색 | DisplayLink Manager 화면 기록 권한 재허용 |
| Element 5 Hub 인식 안 됨 | MBA를 **HOST 포트**(컴퓨터 아이콘)에 꽂았는지 확인 |
| Studio Display PD 충돌 | MBA 직결 케이블 분리, 허브 경유로만 연결 |
| 외부 모니터에서 Netflix 검은 화면 | DisplayLink는 HDCP 차단 — 네이티브 모니터로 창 이동 |
| 클램셸 성능 저하 체감 | 수직 거치대 사용, 책상 평면 노출 회피 |
| macOS 업데이트 후 DisplayLink 안 됨 | 권한 재설정, DisplayLink Manager 재설치 |

---

## DRM 영상 + DisplayLink (수동 Chrome 우회)

(구 airgenome README 에서 이관 — airgenome 은 DisplayLink 관련 기능을 폐기했다.)

**DisplayLink 화면이 하나라도 연결되면** macOS 는 FairPlay 보호 영상(Safari 의
Netflix · Disney+ · Prime)을 **모든** 디스플레이에서 차단한다 — DisplayLink 가상
디스플레이에는 HDCP 경로가 없어 미디어 스택이 세션 전체에서 보호 서피스를 거부한다
([DisplayLink KB 830301](https://support.displaylink.com/knowledgebase/articles/830301-content-protected-video-does-not-play-on-mac-while)).
Safari 는 하드웨어 가속 토글이 **없어** 우회 불가; Chrome/Edge 는 Widevine L3(소프트
DRM)를 써서 하드웨어 가속을 끄면 **DisplayLink 화면을 켠 채로** 보호 영상을 재생한다
(720p 상한).

airgenome 명령은 없다 — 브라우저에서 한 번 직접 설정한다:

1. `chrome://settings/system` (또는 `edge://settings/system`) 열기.
2. **"Use hardware acceleration when available"** 끄기.
3. **Relaunch** 클릭. 해당 브라우저에서 Netflix/Disney+/Prime 재생됨.

(토글을 다시 켜면 원복. Firefox 에는 이 토글이 없다.)

---

## 참고 자료

- [Apple 공식 — M3 MacBook Air 듀얼 모니터 가이드](https://support.apple.com/en-us/117373)
- [Plugable — M3 MacBook Air 모니터 2~3대 추가](https://plugable.com/blogs/news/how-to-add-two-or-three-extra-screens-to-your-m3-macbook-air)
- [Plugable Apple Silicon 호환성 페이지](https://plugable.com/pages/apple-silicon-macs-and-plugable-products)
- [DisplayLink Manager 다운로드 (Synaptics)](https://www.synaptics.com/products/displaylink-graphics/downloads/macos)
- [Plugable USBC-6950M 제품 페이지](https://plugable.com/products/usbc-6950m)
- [OWC USB-C Dual HDMI Display Adapter](https://eshop.macsales.com/item/OWC/CADPDL2HDMI/)
- [Sonnet USB3 Dual HDMI Adapter](https://www.sonnettech.com/product/usb3-displaylink-to-dual-4k-60hz-hdmi-adapter/overview.html)
- [Cable Matters Dual HDMI DisplayLink](https://www.cablematters.com/pc-1820-125-displaylink-usb-c-to-dual-hdmi-adapter-supports-dual-4k-60hz-on-macos-windows.aspx)
- [Macworld — Apple Silicon Mac 다중 모니터 가이드](https://www.macworld.com/article/675869/how-to-connect-two-or-more-external-displays-to-apple-silicon-m1-macs.html)
- [TechRadar — M3 MBA 클램셸 성능 저하 리포트](https://www.techradar.com/computing/macbooks/m3-macbook-air-said-to-lose-50-of-its-performance-in-clamshell-mode-so-much-for-that-cool-new-dual-monitor-setup-you-wanted)
- [StarTech — M3 멀티 모니터 솔루션](https://www.startech.com/en-us/tools-and-resources/solutions/m3-display-solutions)
