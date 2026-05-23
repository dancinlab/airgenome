# HUSH log

## 2026-05-23

- [x] XProtect 4종 식별 (XprotectService · xprotectd · XProtectUpdateService · XProtectBridgeService)
- [x] SIP 상태 확인 — enabled (bootout/kill 불가)
- [x] `ConfigDataInstall = false` — XProtect yara 정의 갱신 OFF
- [x] `CriticalUpdateInstall = false` — 보안 응답 자동설치 OFF
- [x] HUSH 도메인 스캐폴드 (HUSH.md + HUSH.log.md)
- [x] fs_usage 진단 — XprotectService 가 `~/.hexa-cache/hexa_run.*` 매 실행마다 스캔 확인 (근본 원인)
- [x] `~/.hexa-cache` `.metadata_never_index` flag + `xattr -cr`
- [x] `~/Downloads` quarantine xattr 일괄 제거
- [x] `sudo mdutil -a -i off` — Spotlight 전역 인덱싱 OFF (검색 UI 는 파일명 폴백)
- [x] `mds` / `mds_stores` / `mdworker_shared` 일괄 종료 (Spotlight OFF 후 자동 idle)
- [x] launchctl bootout 시도 → 예상대로 "Operation not permitted while SIP is engaged"
- [x] CPU 회수 확인 — XprotectService · mds 모두 idle/소멸
- [x] 재발 진단 — XprotectService 50% 부활 · fs_usage 빈 결과 → ES 이벤트 트리거 의심
- [x] **진범 식별** — Mullvad VPN daemon이 `eslogger exec fork exit` 띄워 ESF 구독 중 (fork/exec 폭주 → yara 평가 폭주)
- [x] `mullvad split-tunnel set off` — 1차 감축 (50→35%, 유지)
- [x] `sudo launchctl bootout system/net.mullvad.daemon` — 진단용 측정 (XprotectService 50→0.0% 확인)
- [x] `sudo launchctl bootstrap system /Library/LaunchDaemons/net.mullvad.daemon.plist` — daemon 복구 (VPN 본기능 필요)
- [x] 결론 — Mullvad daemon은 유지, split-tunnel off 만 영구 적용 (eslogger 비용은 수용)
- [x] `bin/airgenome` 에 `cmd_hush()` 추가 + `cmd_init()` 에서 동행 호출 (idempotent)
- [x] 서브커맨드 `airgenome hush` 노출 + help 갱신 + 환경변수 (`AIRGENOME_NO_HUSH` · `AIRGENOME_HUSH_NOSUDO`)
- [x] 추가 daemon 조사 — iCloud/Geo/Analytics 다 0.0% (정리 가치 없음), `replayd` 2.5% (후보)
- [x] 2차 재진단 — `softwareupdated` 21% 발견 → AutomaticDownload/AutomaticallyInstallMacOSUpdates/AutoInstallProductKeys OFF → 0% 회귀
- [x] `cmd_hush` 에 macOS 자동 업데이트 OFF 통합
- [x] 진짜 부하 원인 식별 — claude × 6 세션이 `hexa run` → clang fork 폭증 → XprotectService/syspolicyd 줄줄이 폭주
- [x] hexa-lang inbox 패치 작성 — `inbox/patches/hexa-run-clang-fork-cache-miss-per-invocation.md` (content-addressed cache key 제안)
- [x] 부수 확인 — Mullvad daemon 살아있어도 split-tunnel off 면 eslogger 안 깨어남 (trade-off 비용 ~0)
- [x] hexa-lang fix 도착 — 캐시 디렉토리 `hexa_run.<sha16>_<ver>-dispatch` (content-addressed). 동일 source 3-run 380→100ms (4배 단축)
- [x] 3차 재진단 — load avg **82.81 → 4.46** (-95%) · XprotectService top12 밖 · syspolicyd 21→5%
- [x] sftp-server 24% 정체 — 외부 SSH sftp 세션 (사용자 본인 트래픽, 유지)
- [x] CPU throttling 해소 — P-Cluster 1356→1837 MHz · CPU Power 2294→1853 mW
- [x] 남은 부하는 거의 다 사용자 본인 작업 (claude × 6 · sftp · DisplayLink · Wi-Fi) — 시스템 정리 종결점
- [ ] `replayd` 영구 disable 검토 (Screen recording 사용 여부 확인 후)
- [ ] Recovery → `csrutil disable` (필요 시) → bootout + disable 풀세트
- [ ] 24h 후 재발 여부 관찰 (Spotlight 자동 재활성 / XProtect 정의 자동복구 가능성)
