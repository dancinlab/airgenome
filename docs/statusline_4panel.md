# Claude Code statusLine — 4-panel design (맥락 · 세션 · 창발 · 경제)

Status: **draft**, single-line first. Box rendering deferred.
Scope: replace current linear stack renderer (`hexa-lang/gate/claude_statusline.{hexa,jq}`) with a 4-panel layout. Non-breaking — new sibling file.

## 1. Panels

| id | label | 변화 속도 | 의도 |
|----|-------|-----------|------|
| LEFT   | 맥락 | slow  | "내가 지금 어디에 서 있나" — git + active roadmap |
| CENTER | 세션 | fast  | CC 런타임 상태 — ctx% · model · turn |
| 3rd    | 창발 | bursty | 이 프로젝트의 novelty / convergence / anomaly 신호 |
| RIGHT  | 경제 | medium | 시간·비용 — idle · cost |

## 2. 렌더 (박스 없음, 1-line)

구분자는 `··` (double middle-dot). 내부 field 구분은 ` · ` (single).

### FULL (COLUMNS ≥ 120)
```
⎇ fix/roadmap-2 ±1 · R8 ·· 🧠 47% · opus4.7 · t12 ·· 🌱 raw#30 ·2h ·· ⏱ 2m · 💸 $0.42
```

### COMPACT (90–119)
```
⎇ fix/roadmap ±1 · R8 ·· 🧠 47% opus t12 ·· 🌱 raw#30 ·· ⏱ 2m 💸 $.42
```

### NARROW (< 90)
```
⎇ fix ±1 · 🧠 47% · 🌱 #30 · 💸 $.42
```

Priority 드롭 순서: repo → phase id → mode → idle → branch detail. **창발 panel 은 마지막까지 유지**.

## 3. 데이터 소스

| panel | 소스 | 비용 |
|-------|------|------|
| LEFT   | `git symbolic-ref HEAD` + `git status --porcelain=v2 \| wc -l` + `.roadmap` active id | ~15ms, SHA-캐시 60s |
| CENTER | CC stdin JSON (`model.display_name`, `session_id`) + `transcript_path` tail (`usage` 최종 1줄) | ~30ms |
| 창발   | `.raw`/`.meta2-cert/` + airgenome `state/rig_trend_history.jsonl` tail (mtime-driven) | ~5ms |
| RIGHT  | CENTER 와 동일 transcript parse 재활용 (`usage` 누적 + 마지막 user ts) | ~0ms |

합: ≈ 50ms. CC 300ms 예산의 1/6.

## 4. 창발 panel — priority calculus

3 축, 이벤트 마다 score 매기고 top-1 표시.

```
score = novelty_weight × recency_decay(Δt) × phase_relevance
novelty_weight: raw=4, cert=3, same_structure=2, transfer=1.5, roadmap_status=1
recency_decay: exp(-Δt / halflife),  halflife raw=24h  cert=72h  anomaly=1h
phase_relevance: 현재 MAIN phase(P1/P2/P3) 와 일치 시 ×1.5
```

표시 포맷 (top-1):
- `🌱 raw#30 ·2h`            (novelty)
- `🔬 cert×9 +1`             (convergence)
- `⚠ htz offline 5m`         (anomaly — red)
- `✨ P1 lora16/19 cell3/5`  (phase feed)
- `🔁 transfer 3/4`          (cross-framework)

이벤트 없을 때 fallback: 기존 `active.json` stack renderer 결과 1줄.

## 5. Anomaly → color (ANSI)
- red: anomaly axis (probe offline, MAE 급증, uchg drift)
- yellow: convergence last-step (18/19 → 19/19 직전)
- green flash (1 turn): novelty 이벤트 방금 landed
- bold: critical path 단축

## 6. 구현 위치 & migration
- 신규: `/Users/ghost/core/hexa-lang/gate/claude_statusline_4panel.hexa` (+ `.jq`)
- 기존 `claude_statusline.{hexa,jq}` 유지 — `active.json` stack 전용 sub-mode 로 흡수 (창발 fallback 경로)
- swap 포인트: `~/.claude/settings.json` 의 `statusLine.command` 만 새 경로로
- settings.json 직접 편집 금지 (H-NOHOOK/AG10). `airgenome-init` / `hexa-lang` init 툴이 re-render

## 7. 폭 적응
env `COLUMNS` 먼저 확인. 없으면 `tput cols` fallback. `TERM=dumb` / `LANG=C` 은 ASCII 전용 degrade (⎇ → `*`, 🧠 → `ctx`, 🌱 → `new`, 💸 → `$`).

## 8. 박스 렌더 (deferred)
CC statusLine 은 multi-line 지원 확인 필요 — 지원 시 3줄 박스 가능. 단:
- wcwidth 로 panel 내부 padding 계산 필수 (한글 2-cell, 이모지 가변)
- `COLUMNS < 120` 시 깨짐 → 자동 1-line fallback
- 현재 1-line 확정 후 phase 2 로 보류

## 9. 관측성
각 호출을 `.hook-statusline.jsonl` 에 1줄 append (ts, render_ms, columns, panel_active, event_shown). 1주치로 priority 계수 재조정.

## 10. 안티패턴 (제외)
- 토큰 수 절댓값, 시각, 외부 위젯, 전체 commit hash, 풀센텐스 해설, emoji parade (>5), P1/P2 의 순수 색 encode (접근성)

## 11. 테스트
- unit: fixture stdin JSON × `.raw`/`state/*.jsonl` 고정 → snapshot 일치
- width: `COLUMNS=80,100,140` golden file
- degraded: `.raw` 제거 / git 제거 / transcript 없음 → fallback 경로
- budget: `time` 랩퍼 p99 < 300ms

## 12. 다음 스텝
1. `claude_statusline_4panel.hexa` prototype — LEFT + 창발 2 panel 부터
2. wcwidth 유틸 (`nexus/shared/stdlib/wcwidth.hexa`?) 유무 확인, 없으면 포팅
3. CC multi-line 지원 여부 live probe (별건, 박스 단계에서)
4. `.statusline-events.jsonl` 관측 개시 → 1주 후 priority 재튜닝
