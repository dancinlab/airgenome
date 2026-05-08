# Safari/YouTube voice glitch ("치치직") — investigation 2026-05-08

## 증상
Safari 에서 YouTube 재생 중 가끔 voice 가 "치치직" 거림.

## 결론
**airgenome safari 필터들은 직접 원인 아님.** 모두 emit-only.
주 원인 후보: **출력장치 sample rate 불일치 (44.1 kHz ↔ 48 kHz)** + USB 2.0 대역폭 경합.

---

## airgenome 측 검토 (음성 영향 가능성)

### Safari 관련 4개 필터 — 모두 measurement / signal-emit only
| 모듈 | 주기 | 출력 |
|---|---|---|
| `filters/module/data/safari_bg_tab_throttle_genome.hexa` (F45) | 60s | `forge/safari_tabs.ring` (axes 게놈) |
| `filters/module/process/safari_active_throttle_signal.hexa` (F64) | 60s | `forge/throttle_signals.ring` (signal) |
| `filters/module/process/safari_battery_freeze_filter.hexa` (F66) | 60s | 동상 |
| `filters/module/process/safari_youtube_gpu_filter.hexa` (F65) | 120s | 동상 |

- 4개 모두 `is_hard_never()` 가드: `Safari/WebContent/coreaudiod/WindowServer/kernel_task` 등 시스템 본체 제외.
- 출력 ring `forge/throttle_signals.ring` **파일이 존재하지 않음** → enforcer 0.
- 실제 `taskpolicy_bg / kill / SIGSTOP / freeze` 호출 0.

### renice 점검
- `airgenome/core/airgenome.hexa:84` `renice_top3()` — **정의만, 호출자 0**.
- `nexus/shared/bin/ssh_gate:164` renice — SSH 원격 (Hetzner/Ubuntu) 대상, 로컬 Mac 무관.

### supervisor (`com.airgenome.supervisor`, PID nice=-15)
- `bin/airgenome run` 60s tick: probe → dispatch → harvest → label → (5tick마다) forecast.
- fork+exec storm 자체가 coreaudiod scheduling deadline 을 microscopic 하게 밀 *가능성*은 있으나, 가드된 필터들이라 직접 audio 차단은 0.
- `safari_youtube_gpu_filter` 는 YouTube 감지시 추가 `lsof -i 4 -p <Safari WebContent PIDs>` — 의심되면 토글로 분리 검증.

---

## 외부 (macOS) 측 진짜 의심 지점

### 1. 샘플레이트 불일치 (★ primary 가설)
조사 시점 출력 장치 상태:
```
LG ULTRAFINE          (HDMI)  48000 Hz
Studio Display 스피커 (USB)   44100 Hz   ← system default
MacBook Air 스피커    (built) 48000 Hz
```
YouTube 원본 = Opus/AAC 48 kHz. 기본 출력이 44.1 kHz 라 coreaudiod 가 매번 실시간 리샘플 →
fork-storm/USB 경합 시 deadline miss → 글리치.

### 2. USB 2.0 hub 대역폭 경합 (보조 가설)
`ioreg -p IOUSB`:
```
USB2 Hub@20100000
  +-o Studio Display@20140000
```
Studio Display 는 **카메라 + 마이크 + 스피커 + 디스플레이 USB-C upstream** 을
단일 USB 2.0 hub 로 공유. 카메라 활성/타이핑/마우스 트래픽과 경합 가능.

---

## 1차 조치 — 48 kHz 강제 명령

### `bin/audio_force_rate` 추가 (Swift / CoreAudio HAL 직접)
```bash
audio_force_rate                              # default: "Studio Display" → 48000
audio_force_rate "<이름 substring>" <rate>    # 임의 출력 + rate
audio_force_rate --list                       # 모든 장치 + 현재 rate
audio_force_rate --available "<이름>"          # 지원 rate 목록
```

**핵심 동작**
- `kAudioDevicePropertyNominalSampleRate` 직접 set (`AudioObjectSetPropertyData`).
- set 은 비동기 — 최대 1s read-back 폴 (`waitFor`).
- `--available` 미지원 rate 거부.
- 동일 rate 시 `noop`.
- **NBSP (U+00A0) 정규화** — CoreAudio 가 device 이름에 NBSP 를 끼워넣음 (예: `Studio<NBSP>Display 스피커`). `normalize()` 로 양쪽 일반 공백 변환 후 매칭.

### 실측
```
$ bin/audio_force_rate
ok   Studio Display 스피커: 44100 → 48000 Hz

$ bin/audio_force_rate --available "Studio Display"
Studio Display 스피커: [44100, 48000, 88200, 96000]
```

### 영속성 — supervisor 자동 적용 (적용 완료)
재부팅 / 장치 재연결 / 외부 도구가 44.1 로 되돌리는 모든 경우 5분 내 자동 복원.

`config/launchd/supervisor.jobs.tsv` 에 추가된 row:
```
audio-rate-pin	interval:300	/Users/ghost/core/airgenome	~/.airgenome/audio_rate_pin.stdout.log	~/.airgenome/audio_rate_pin.stderr.log	-	-	60	bin/audio_force_rate
```
- mode `interval:300` (5분 polling)
- throttle 60s
- script idempotent — 동일 rate 면 `noop` 즉시 종료 (~3s, fork 비용 무시 가능)
- `kill -HUP <supervisor-pid>` 로 즉시 reload (재배포 불필요)

검증 (2026-05-08T11:34:57Z):
```
[supervisor] reload: 'audio-rate-pin' newly added
[wrap audio-rate-pin] spawn (interval=300s)
[wrap audio-rate-pin] child exited rc=0 dur=3s
→ stdout: "noop Studio Display 스피커: already 48000 Hz"
```

---

## 다음 단계 후보
1. **검증** — 1~2일 YouTube 재생하며 "치치직" 재현 여부 모니터. 사라지면 샘플레이트가 원인 확정.
2. 재현시 **`safari_youtube_gpu_filter` 토글** 추가 (env `AG_DISABLE_YT_GPU_FILTER=1`) → fork-storm 영향 분리.
3. 보조: **coreaudiod glitch counter 모니터** — `log show --predicate '...'` 으로 실시간 underrun 카운트.
