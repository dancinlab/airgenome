# Changelog

Chronological log of notable changes. One section per ship batch, date-keyed.

For the full audit trail, see `git log`.

---

## 2026-05-23

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
