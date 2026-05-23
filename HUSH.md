# HUSH — macOS 부하 완화

시스템 데몬·백그라운드 서비스의 CPU/배터리/팬 부하를 줄이는 작업 도메인.

## 자동 적용 — `airgenome init` / `airgenome hush`

`airgenome init` 실행 시 hush 단계가 동행 호출됨 (idempotent).
단독 실행은 `airgenome hush`. sudo prompt 한번, 거부 시 die.
수행 내용 — `bin/airgenome` `cmd_hush()` 정의 참조.

## 현재 적용된 완화

| 대상 | 조치 | 상태 |
|---|---|---|
| XProtect 정의 업데이트 | `ConfigDataInstall = 0` · `CriticalUpdateInstall = 0` | ✅ |
| Spotlight 전역 인덱싱 | `mdutil -a -i off` → `kMDConfigSearchLevelFSSearchOnly` | ✅ (검색 UI는 파일명 폴백) |
| mds / mds_stores / mdworker_shared | Spotlight OFF 후 자동 종료 | ✅ |
| XprotectService | 트리거 사라져 자동 idle | ✅ (간접) |
| `~/.hexa-cache` 인덱싱 차단 | `.metadata_never_index` flag · `xattr -cr` | ✅ |
| `~/Downloads` quarantine xattr | `xattr -dr com.apple.quarantine` | ✅ |
| Mullvad `split-tunnel` | `mullvad split-tunnel set off` — ESF subscriber 떠오르지 않음 (검증) | ✅ 유지 |
| Mullvad daemon (root) | 유지 — split-tunnel off면 ES hook 부하 거의 0 | ✅ trade-off 해소 |
| macOS 자동 다운로드 | `AutomaticDownload=false` · `AutomaticallyInstallMacOSUpdates=false` · `AutoInstallProductKeys=[]` — softwareupdated 21% → 0% | ✅ |
| `xprotectd` / `XProtectUpdateService` / `XProtectBridgeService` | SIP-protected · 정의 갱신 차단 후 0% idle | ⏸ Recovery 필요 시 |

## 진단 — 진짜 원인 사슬

```
claude / hexa fork·exec 폭주
   └─→ Mullvad eslogger (ESF subscriber, 18.8% CPU)
         └─→ XprotectService (yara 평가, 50% CPU)
         └─→ syspolicyd     (코드서명 검증, 15% CPU)
```

- `XprotectService`는 **파일 스캔이 아닌 ES 이벤트 트리거**로 깨어남 (fs_usage 빈 결과 + sample CPU만 회전이 증거)
- Mullvad split-tunnel 기능이 ESF 구독 채널 유지 — daemon 종료가 근본 차단

## 후속 대기 — SIP off 시 자동 실행

```bash
sudo launchctl bootout system/com.apple.XProtect.daemon.scan
sudo launchctl disable system/com.apple.XProtect.daemon.scan
sudo launchctl bootout system/com.apple.XProtect.daemon.scan.startup
sudo launchctl disable system/com.apple.XProtect.daemon.scan.startup
sudo launchctl bootout system/com.apple.XprotectFramework.PluginService
sudo launchctl disable system/com.apple.XprotectFramework.PluginService
```

## 추가 조사 결과 (2026-05-23)

| daemon | %CPU | 진단 |
|---|---|---|
| `XprotectService` | ~70% | claude/clang fork 폭증이 yara 트리거 폭증 (Mullvad split-tunnel off 후에도) |
| `WindowServer` | ~50% | 외장 모니터 + 활성 작업 화면 갱신 폭주 |
| `syspolicyd` | ~12% | 매 exec 코드서명 검증 — clang fork 짝 |
| `softwareupdated` | 0% (was 21%) | hush 적용으로 idle 회귀 |
| `clang -cc1` | 20~25% × N | `hexa run`이 매번 C 생성 → 컴파일 |
| `Python vastai search` | ~20% | anima 백그라운드 (claude 트리거) |
| `DisplayLink Manager` | ~19% | 외장 모니터 필요 |
| `_driverkit AppleBCMWLAN` | ~14% | Wi-Fi (claude 네트워크 폭증 영향) |
| `replayd` | ~2.5% | Screen recording XPC — 정리 후보 |
| iCloud/Geo/Analytics 데몬 | 0.0% | 이미 idle — 끄기 불필요 |

**진짜 부하 원인**: claude × 6 세션이 hexa run · clang fork · 네트워크 spawn 폭증.
시스템 보안 데몬 (XProtect/syspolicyd) 부하는 결과지 원인이 아님.

**가능한 추가 감축**:
- claude 동시 세션 줄이기 (사용자 결정)
- hexa `hexa_run.<ns>.c` 캐시 키 안정화 (각 실행마다 다른 ns → 캐시 무효)
- `replayd` disable (Screen recording 안 쓸 때)

## 다음 정리 후보

- [ ] `replayd` 영구 disable (Screen recording 안 쓸 때)
- [ ] LaunchAgent 정리 (`com.anima.*` 다수 · 사용 여부 점검)
- [ ] `nsurlsessiond` 백그라운드 다운로드 (현재 0.0% — 폭주 시 검토)

## 원칙

- SIP-protected 데몬은 반드시 Recovery → `csrutil disable` 선행
- 정의/사전 파일 갱신 차단(`defaults write`)이 데몬 OFF 없이 가능한 1차 완화
- 영구 OFF 전에 임시 kill 또는 unload로 영향 측정 후 결정
