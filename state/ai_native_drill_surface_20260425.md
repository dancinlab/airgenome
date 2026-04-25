# AI-native drill checkpoint surface — AG12-DRILL-CP-SURFACE

**Date**: 2026-04-25
**Layer**: airgenome AG* (project-scoped) + hexa-lang H-* index
**Trigger**: user directive — drill checkpoint 보존돼도 AI 가 인지 못하면 무용지물
**Status**: shipped + tested

## Problem

Phase C drill checkpoint mechanism (Wave 21) preserves data across drill exit-1:

- nexus run.hexa `_checkpoint_save` writes per-round atomic JSON to `/tmp/nexus_checkpoint/`
- `bin/drill-progress` scans local + remote (hetzner) and emits JSON/table
- `bin/drill-live --resume` auto-picks highest round_done seed

**Gap**: Claude Code 새 세션은 drill-progress 가 존재한다는 것을 모름. 사용자가 수동으로 호출하지 않으면 AI 는 'data lost' 로 오판하고 같은 시드로 fresh start 하거나 사용자에게 잘못 보고함.

## Solution — surface as session-start ai-native banner

**Layer choice — airgenome AG\* (project-scoped)**:

- AG10 H-NOHOOK strict: Claude Code hooks/skills/CLAUDE.md 직접 작성 금지
- 허용된 2층 중 prompt 단계가 결정적 surface 위치
- airgenome 한정 정보이므로 global H-* 보다 project AG* 가 적절

**구현**:

1. `airgenome/rules/airgenome.json` 신규 룰 `AG12-DRILL-CP-SURFACE` 등록
2. `hexa-lang/gate/prompt_scan.hexa` `check_drill_cp_surface()` 함수 추가 — main() 에서 `check_proj_all` 직후 호출
3. `hexa-lang/gate/enforcement_registry.json` 신규 H-DRILL-CP-SURFACE 룰 인덱싱 (scope=airgenome)

## Sequence

매 user prompt 마다 prompt_scan.hexa 가:

1. git rev-parse → repo basename 확인 → `airgenome` 만 통과
2. `is_fresh("drill_cp_surface", 600)` — 600s TTL (세션당 1-2회)
3. `bin/drill-progress --local --json` + `--remote --json` 합쳐서
4. jq `fromjson?` 로 malformed cp 라인 skip → `max_by(.round)` 추출
5. `[DRILL-CP] round_done=N total=M host=H hash=... ts=...` + resume/wipe/SSOT/bypass 4줄 출력
6. `mark_fresh` — 600s 동안 재호출 skip

## Bypass

```
AIRGENOME_DRILL_CP_QUIET=1
```

명시적 사용자 요청 시에만.

## Test results (2026-04-25)

```
$ rm -f /tmp/prompt_scan_fresh_drill_cp_surface
$ hexa run $HEXA_LANG/gate/prompt_scan.hexa "test surface"

[DRILL-CP] checkpoint 보존: round_done=9 total=31178 host=hetzner hash=4cfa0d3055e1 ts=1777074314
           seed="준비 완료 — 사용자 다음 drill 즉시 가능. 현재 깨끗 상태: - hetzner: 117GB, dril"
           resume: /Users/ghost/core/airgenome/bin/drill-live --resume
           wipe:   rm /tmp/nexus_checkpoint/cp_*.json (and remote hetzner 동일 경로)
           SSOT: $AIRGENOME/rules/airgenome.json#AG12-DRILL-CP-SURFACE | bypass: AIRGENOME_DRILL_CP_QUIET=1
```

검증:

- 정상 surface — round_done=9, total=31178 (hetzner cp_4cfa0d3055e1.json)
- 600s TTL — 2번째 prompt 에서 skip (no DRILL-CP)
- non-airgenome cwd (/tmp) — skip (no DRILL-CP)
- AIRGENOME_DRILL_CP_QUIET=1 bypass — skip (no DRILL-CP)

## Files modified

- `airgenome/rules/airgenome.json` — AG12-DRILL-CP-SURFACE 룰 추가
- `hexa-lang/gate/prompt_scan.hexa` — `check_drill_cp_surface()` + main() 호출
- `hexa-lang/gate/enforcement_registry.json` — H-DRILL-CP-SURFACE 인덱스

## AG10 compliance

- 새 Claude Code hook / skill / CLAUDE.md 작성 — 없음
- ~/.claude/settings.json 수정 — 없음 (글로벌 dispatcher hook 은 기존 그대로 사용)
- 모든 자동화는 hexa-only 2층 (AG* + H-* prompt_scan) 으로 strict

## Wave 22 후보

- AG-DRILL-CP-AUTO-RESUME — drill 키워드 + 활성 cp 시 `drill-live --resume` 자동 권장
- AG-DRILL-CP-STALE-WARN — 24h 넘은 cp 는 stale 라벨링
- mac → hetzner cp mirror (양방향 sync, drift 0)
