# Changelog

Chronological log of notable changes. One section per ship batch, date-keyed.

For the full audit trail, see `git log`.

---

## 2026-06-16

- **`airgenome flix` — Chrome DRM-video router** (supersedes the Safari watch-mode below) — `cmd_flix()` reworked to open the service (Netflix/Disney+/Prime/`<url>`) in a Chromium browser (Google Chrome → Microsoft Edge → Brave) launched with `--disable-gpu` + a seeded `hardware_acceleration_mode=off` pref inside a **dedicated** profile (`~/.airgenome/flix-profile`). Chrome/Edge use Widevine L3, and with HW-accel off they drop the HDCP-hardware requirement → protected video plays **with every DisplayLink screen still on** (720p cap) — the only software fix that keeps multi-screen. Dedicated profile = user's main Chrome settings/login untouched + flag applies reliably; `airgenome flix reset` wipes it. The Safari watch-mode (suspending DisplayLink) was scrapped because it forced external screens dark while watching. Verified: bash -n clean, browser-detect + no-browser error + reset paths exercised.
- **`airgenome flix` — Safari DRM-video watch mode** (superseded same day by the Chrome router above) — initial `cmd_flix()` + dispatch (`flix|netflix`) + help. Root cause (verified, DisplayLink KB 830301): an attached DisplayLink screen has no HDCP path, so macOS blocks FairPlay-protected video (Netflix/Disney+/Prime in **Safari**) on **all** displays session-wide; Safari has no hardware-accel toggle, so the only Safari-compatible remedy is official workaround #1 — temporarily remove the DisplayLink screens. `flix on` software-disconnected DisplayLink (pkill agent, mirroring native `displaylink_stop()`) + opened the service in Safari; `flix off` relaunched the agent. Dropped in favour of the Chrome route, which keeps external screens on.

---

## 2026-06-15

- **harness perfect setup** — brought the repo to full [dancinlab/harness](https://github.com/dancinlab/harness) (hardcore) compliance. Initialized the `.harness-engine` submodule; declared L0 lockdown files (`airgenome/core/airgenome.hexa` · `run.hexa` · `install.hexa`) and a root-scoped `docs` block (`scopeDirs:[""]` + `allow` for README variants and the scatter-named `TAPE-AUDIT.md`) in `harness.config.json`. Rewrote `ARCHITECTURE.md` as the English architecture SSOT (6-axis hexagon · 60-byte genome · Banach 1/3 fixed point) and replaced the `CLAUDE.md → project.tape` symlink with a standard harness `CLAUDE.md` (H1 + description + `## Structure` tree + governance + `## Harness` quick reference; `project.tape` retained). Added SSOT quickref pointers to the remaining root docs. Result: `harness docs check` → `docs: ok`, `harness lint` → `lint: ok`, CLAUDE-MD violations = 0.

---

## 2026-05-23

- **HUSH 도메인 + `airgenome hush`** — macOS 부하 완화 묶음을 `bin/airgenome` `cmd_hush()` 로 통합. `airgenome init` 동행 호출 + `hx install airgenome` 의 `install.hexa` 후행 호출 (single source of truth · idempotent). 항목: XProtect 정의 자동갱신 OFF · 보안 응답 자동설치 OFF · macOS 자동 다운로드·설치 OFF · `AutoInstallProductKeys` 비움 · Spotlight 전역 인덱싱 OFF + mds/mds_stores/mdworker 종료 · `~/.hexa-cache` 인덱싱 차단 · `~/Downloads` quarantine xattr 제거 · Mullvad split-tunnel OFF · `searchpartyuseragent`(Find My) bootout. 진단·배경: `HUSH.md` · `HUSH.log.md`.
- **`AIRGENOME_ROOT` symlink-aware 해석** — `bin/airgenome` 가 `BASH_SOURCE` symlink chain 을 따라가도록 수정. `~/.hx/bin/airgenome` → `~/.hx/packages/airgenome/bin/airgenome` 형태의 hx pkg 설치 경유 호출에서 ROOT 가 잘못 잡혀 `plist source missing` 으로 실패하던 문제 해소.
- **`cmd_hush` — Mission Control "Displays have separate Spaces" ON** — `defaults write com.apple.spaces spans-displays -bool false` 추가. 풀스크린 시 외 모니터가 검정으로 마스킹되던 macOS 기본 동작을 해소 (각 디스플레이가 독립 Space). 적용에는 로그아웃 후 재로그인 필요.
- **`cmd_hush` — Siri/Apple Intelligence/Biome/CoreSpotlight 위성 데몬 disable + UniversalControl OFF** — Siri 비활성 사용자 대상. `launchctl disable gui/UID/` 로 `com.apple.BiomeAgent` · `com.apple.biomesyncd` · `com.apple.suggestd` · `com.apple.corespotlightd` 영구 disable. 이들은 SIP-protected 라 bootout 자체가 차단됨 → 좀비 양산 가능성 0. UniversalControl 은 `defaults write com.apple.universalcontrol Disable -bool true` (Mac↔iPad 마우스 공유 OFF). 모두 다음 로그인부터 적용.
- **`cmd_hush` — Reduce Transparency + Reduce Motion ON** — WindowServer GPU 부하 감축 (blur/투명 합성 · 전환 애니메이션 제거). `com.apple.universalaccess` 는 cfprefsd 독점 관리라 일반 `defaults write` 가 거부됨 → `plutil -replace` 로 plist 직접 수정 후 `killall cfprefsd` flush. 이미 ON 이면 skip (idempotent).
- **Claude Code 통합 폐기** — MCP 서버 · 자체 hook bus(`hooks/`) · `claude_*` 필터 25개 · `cl` 멀티계정 런처 · improve 루프 · AG10 룰 · `~/.claude/settings.json` 렌더러 전면 제거. airgenome 은 Claude Code 하니스에 더 이상 관여하지 않음 — 부하 시 Claude Code CLI 에 자원 우선권을 주는 overload-watch(native)만 예외로 유지.
- **hexa-lang gate 결합 절단** — launchd 하드코딩 `core/hexa-lang/hexa` 경로 → 설치본 `~/.hx/bin/hexa` 로 전환 · `tool/airgenome_init.hexa`(hook/MCP/workspace 부트스트랩) 삭제 · `install.hexa` 는 native 앱 설치만 담당 · hook-watch·tg-bot launchd 잡 제거.
- **규칙 정리** — `l0_paths` 메타데이터 필드를 전 규칙에서 제거 (uchg 동결 메커니즘 폐기에 따른 죽은 필드).
- **hive safety gate 제거** — hive 프로젝트 폐기에 따라 git `core.hooksPath` 훅(커밋 전 개인경로·credential 스캔)을 해제하고 `scripts/safety/` · `state/safety_bypass_audit/` 제거.

## 2026-05-22

- **scope-reduce — mac-local-only** (PR #89) — the cross-host layer removed; airgenome runs mac-local only.
- **project.tape SSOT** — project identity + governance consolidated into `project.tape`; interim Spec Kit scaffolding removed, `AGENTS.tape` archived.
- **DESIGN doc split** — `design.md` → `DESIGN.log.md` (decision audit trail) + `DESIGN.md` live pointer.

## 2026-05-21

- **org rename** — owning org `need-singularity` → `dancinlab`.
- **constitution v1.0.0** — OS Genome Scanner · 6-axis · hexa-native.

## 2026-05-20

- **launcher — snippet auto-input** — direct `CGEventKeyboardSetUnicodeString` typing so snippet content never lands on the system clipboard.

## 2026-05-15

- **native menubar** — DisplayLink lifecycle + supervisor async cadence; fixed a supervisor process leak (944 stale procs). Spotlight toggle added then reverted.

## 2026-05-14

- **AGENTS.tape** — `TAPE-AUDIT.md` adoption; `@I id001` enhanced with project-tree fields; README aligned to the atlas 18-block format.

## 2026-05-10

- **overload watch** — load > 80 → Claude Code CLI prioritized: competing PIDs demoted to `taskpolicy_bg`, Claude pinned foreground.
