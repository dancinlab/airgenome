# Claude Code statusLine — 4-panel design (맥락 · 세션 · EMERGENCE · 경제)

Status: **draft**, single-line first. Box rendering deferred.
Scope: replace current linear stack renderer (`hexa-lang/gate/claude_statusline.{hexa,jq}`) with a 4-panel layout. Non-breaking — new sibling file.

## 1. Panels

| id | label | 변화 속도 | 의도 |
|----|-------|-----------|------|
| CONTEXT   | 맥락 | slow  | "내가 지금 어디에 서 있나" — git + active roadmap |
| SESSION | 세션 | fast  | CC 런타임 상태 — ctx% · model · turn |
| EMERGENCE | 창발 | bursty | 이 프로젝트의 novelty / convergence / anomaly 신호 |
| ECONOMY  | 경제 | medium | 시간·비용 — idle · cost |

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

Priority 드롭 순서: repo → phase id → mode → idle → branch detail. **EMERGENCE panel 은 마지막까지 유지**.

## 3. 데이터 소스

| panel | 소스 | 비용 |
|-------|------|------|
| CONTEXT   | `git symbolic-ref HEAD` + `git status --porcelain=v2 \| wc -l` + `.roadmap` active id | ~15ms, SHA-캐시 60s |
| SESSION | CC stdin JSON (`model.display_name`, `session_id`) + `transcript_path` tail (`usage` 최종 1줄) | ~30ms |
| EMERGENCE   | `.raw`/`.meta2-cert/` + airgenome `state/rig_trend_history.jsonl` tail (mtime-driven) | ~5ms |
| ECONOMY  | SESSION 와 동일 transcript parse 재활용 (`usage` 누적 + 마지막 user ts) | ~0ms |

합: ≈ 50ms. CC 300ms 예산의 1/6.

## 4. EMERGENCE panel — priority calculus

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
- 기존 `claude_statusline.{hexa,jq}` 유지 — `active.json` stack 전용 sub-mode 로 흡수 (EMERGENCE fallback 경로)
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
1. `claude_statusline_4panel.hexa` prototype — CONTEXT + EMERGENCE 2 panel 부터
2. wcwidth 유틸 (`nexus/shared/stdlib/wcwidth.hexa`?) 유무 확인, 없으면 포팅
3. CC multi-line 지원 여부 live probe (별건, 박스 단계에서)
4. `.statusline-events.jsonl` 관측 개시 → 1주 후 priority 재튜닝

---

# Part II — Implementation

## 13. 파일 / 모듈 구조
```
hexa-lang/gate/
  claude_statusline_4panel.hexa       # entry
  claude_statusline_4panel.jq         # transcript + stdin 파서
  panels/
    context.hexa
    session.hexa
    emergence.hexa
    economy.hexa
  lib/
    wcwidth.hexa                      # cell-width (없으면 포팅)
    columns.hexa                      # tput / env / fallback
    ansi.hexa                         # color / strip helpers
    cache.hexa                        # git SHA 캐시 60s
  events/
    emergence_ranker.hexa             # score fn + recency decay
    sources.hexa                      # file → Event adapter
  observability/
    statusline_log.hexa               # .hook-statusline.jsonl appender
```
기존 `claude_statusline.{hexa,jq}` 는 EMERGENCE fallback 경로로 호출만 유지.

## 14. CC stdin JSON (실측 스키마)
```json
{
  "session_id":"uuid",
  "transcript_path":"/Users/ghost/.claude-claudeN/projects/<slug>/<uuid>.jsonl",
  "cwd":"/Users/ghost/core/airgenome",
  "model":{"id":"claude-opus-4-7","display_name":"Opus 4.7"},
  "workspace":{"current_dir":"…","project_dir":"…"},
  "version":"1.0.x",
  "output_style":{"name":"default"}
}
```
사용:
- `cwd` → git root 검증
- `model.display_name` → SESSION
- `transcript_path` → ctx%, turn count, usage, last_user_ts
- `session_id` → `.hook-statusline.jsonl` 파티션 키, flicker 상태 분리 저장

## 15. Git 상태 캡처 — edge cases
1회 fork: `git status --porcelain=v2 --branch --ahead-behind 2>/dev/null` — branch/ahead/behind/dirty 일괄.
| 케이스 | 처리 |
|---|---|
| detached HEAD | `⎇ @abc1234` |
| init 직후 | `⎇ (init)` |
| no remote / no upstream | `↑?` 생략 |
| submodule | 가장 바깥 repo 만 |
| worktree | `rev-parse --show-toplevel` 결과 그대로 |
| stash | 표시 안 함 |
| git 없음 | CONTEXT 전체 drop |

## 16. Transcript 파싱 — ctx% / turn / cost
- Transcript jsonl 각 줄: `{role, content, usage:{input_tokens, cache_read_input_tokens, cache_creation_input_tokens, output_tokens}}`
- **ctx%** = (input + cache_read + cache_creation) / context_window. 모델 윈도우: opus-4-7 기본 200K, `[1m]` 변형 1M, sonnet 200K, haiku 200K
- 비용: 마지막 1KB 에서 마지막 assistant line parse — 전체 스캔 불필요
- **turn** = `grep -c '"role":"assistant"' transcript.jsonl` (<10ms)
- **cost** (hardcoded 표):
```
opus-4-7:   $15/M in,  $75/M out,  cache_read $1.50,  cache_write $18.75
sonnet-4-6: $3/M  in,  $15/M out,  cache_read $0.30,  cache_write $3.75
haiku-4-5:  $0.25/M,   $1.25/M,    cache_read $0.025, cache_write $0.30
```
전체 누적은 1 jq stream fork, 캐시 (last_calc_ts + delta 재계산).

## 17. Roadmap active id 파싱
`.roadmap` 에서 `^roadmap N active` 매칭, 복수일 때 MAIN track 우선 (track 이 `hybrid` 또는 feeds-main 존재). mtime 캐시.

## 18. EMERGENCE 이벤트 — 소스/필드 매트릭스
| type | 파일 | 추출 | weight |
|---|---|---|---|
| raw | `$HEXA_LANG/.raw` | 마지막 `^raw #(\d+)` + mtime | 4 |
| cert | `$HEXA_LANG/.meta2-cert/*.json` | count + newest mtime | 3 |
| same_structure | `$HEXA_LANG/.raw-audit` | `SAME_STRUCTURE` count | 2 |
| transfer | `.meta2-cert/transfer_*.json` | count | 1.5 |
| roadmap_feed | airgenome `state/roadmap_progress.json` | phase delta | 1 |
| cp | airgenome `state/rig_trend_history.jsonl` | tail `critical_path_len`, head↔tail | 1 |
| host_offline | airgenome `infra_state.json` | host.status != "active" | anomaly ×5 |
| forecast_mae | airgenome `state/forecast_eval.jsonl` | MAE > threshold | anomaly ×4 |
| uchg_drift | `stat -f %f ~/.claude/settings.json` | uchg bit 없음 | anomaly ×3 |

각 source adapter: `source.snapshot() -> Event | null`
```hexa
struct Event { type: string, ts: int, label: string, weight: float }
```

## 19. Priority 계산 (ranker)
```hexa
fn score(e: Event, now: int, phase: string) -> float {
    let halflife = halflife_for(e.type)   // raw 86400, cert 259200, anomaly 3600
    let recency  = exp(-(now - e.ts) as f64 / halflife)
    let phase_rel = if phase_matches(e.type, phase) { 1.5 } else { 1.0 }
    return e.weight * recency * phase_rel
}
```
Top-1 선택. tie-break = 최근 ts.

**Anti-flicker**: 연속 2 turn 다른 type 이 번갈면 직전 type 에 +10% boost (hysteresis).
`.statusline-state.json` 에 `last_shown_type` + `last_shown_ts` 저장 (session_id per partition).

## 20. wcwidth
hexa-lang stdlib 미존재 시 Python `wcwidth` 의 East Asian Width + Emoji Presentation 테이블을 `lib/wcwidth.hexa` 로 포팅. 최소 API:
```
fn display_cells(s: string) -> int
fn pad_right(s: string, target_cells: int) -> string
```
4-panel 이모지 셋 (🧠 🌱 🔬 ⚠ ⏱ 💸 ✨ 🔁 ⎇) 은 hardcode 2-cell + `️` 붙여 명시적 wide 처리 우회도 가능.

## 21. COLUMNS / TERM / locale
우선순위: `$COLUMNS` → `tput cols` → `stty size` → 80. CC 가 TTY 제공 안 하면 `COLUMNS` 주입 확인, 없으면 COMPACT (100) 고정.
`TERM=dumb` 또는 `NO_COLOR` 설정 시 monochrome + ASCII. `STATUSLINE_NO_EMOJI=1` 수동 opt-out.
`LC_ALL=C.UTF-8 LANG=C.UTF-8` 강제.

## 22. 캐시 `.statusline-cache.json`
```json
{
  "git_sha":"…","git_line":"⎇ fix ±1 · R8","git_ts":…,
  "roadmap_mtime":…,"roadmap_line":"R8",
  "last_shown_type":"raw","last_shown_ts":…
}
```
TTL: git 60s, roadmap mtime-driven, EMERGENCE mtime-driven, SESSION 항상 재계산.
Atomic: `write temp → rename`.

## 23. 동시성
- `.hook-statusline.jsonl` append = 1 line < PIPE_BUF(512) → write(2) atomic
- `.statusline-cache.json` 은 session_id partition 으로 분리 저장해 flicker 독립
- 기존 `.hook-commands/*.tmp` 패턴 재사용

## 24. Per-project plugin
`cwd` → project 매핑:
```
/Users/ghost/core/airgenome  → airgenome
/Users/ghost/core/hexa-lang  → hexa-lang
/Users/ghost/core/anima      → anima
else                         → generic
```
EMERGENCE panel 만 plugin 으로 교체 (`gate/statusline_plugins/<project>.hexa`). CONTEXT/SESSION/ECONOMY 공통.

## 25. Settings 통합 (AG10 준수, Claude 금지)
1. `tool/airgenome_init.hexa::ensure_statusline()` 기본값 변경
2. `rules/claude_settings_shape.json` SSOT 갱신
3. 유저 수동: `airgenome-init` 실행 → settings.json 재생성 → `chflags uchg` 재잠금
- A/B swap: 환경변수 `STATUSLINE_V=legacy|4panel` 로 ensure_statusline 분기

## 26. Migration 스텝
1. prototype `claude_statusline_4panel.hexa` — CONTEXT+SESSION 만, 나머지 `—`
2. 수동 렌더 확인: `echo '<stdin>' | hexa claude_statusline_4panel.hexa`
3. EMERGENCE, ECONOMY 점진 추가 → 단계별 snapshot test
4. env `STATUSLINE_V=4panel` A/B 로 1주 dogfood
5. linear stack renderer → EMERGENCE fallback 으로 demotion
6. SSOT default 변경

## 27. 테스트 harness
```
tests/statusline/
  fixtures/
    stdin_opus_bypass.json
    stdin_sonnet_plan.json
    transcript_short.jsonl
    transcript_long.jsonl
    raw_with_raw30.txt
    rig_trend_recent.jsonl
    infra_state_htz_down.json
  golden/
    full_140cols.txt
    compact_100cols.txt
    narrow_80cols.txt
    degraded_no_git.txt
    anomaly_htz_down.txt
  run.hexa
```
CI: p99 render_ms < 200ms (여유 100ms).

## 28. 관측성 로그 스키마 `.hook-statusline.jsonl`
```json
{
  "ts":"2026-04-22T13:50:00Z","session":"uuid",
  "render_ms":47,"columns":140,
  "panels":["ctx","sess","emerg","econ"],
  "event_type":"raw","event_label":"raw#30",
  "cost_cum":0.42,"ctx_pct":47,"turn":12
}
```
1주 후 분석: 최빈 type, 평균 render_ms, anomaly 비율, COLUMNS 분포.

## 29. 성능 예산 강제
Per-panel timeout (ms): CONTEXT 50, SESSION 80, EMERGENCE 50, ECONOMY 30. 초과 시 last-good + `⌛` + log.
구현: `exec_with_timeout(cmd, ms)` 또는 `timeout(1)` 래핑.

## 30. Binary 의존 / degraded
`jq`, `git` 필수. `tput`, `timeout` 선택. 한 번만 probe → `.statusline-deps.json` 캐시. 부재 시 해당 panel drop.
| 실패 | 대응 |
|---|---|
| jq | bash-only renderer, EMERGENCE = active.json stack 만 |
| git | CONTEXT drop |
| transcript read | SESSION `🧠 ?` |
| `.raw` | EMERGENCE → active.json fallback |
| 렌더 > 300ms | last-good + `⌛` |
| stdin 파싱 실패 | CONTEXT/EMERGENCE/ECONOMY 만 |

## 31. 롤백
```
export STATUSLINE_V=legacy
airgenome-init
```
또는 `statusLine.command` 를 `claude_statusline.hexa` 로 복구 + uchg 재잠금.

## 32. Hook framework 통합 (M13 landed 후)
- event bus 구독 → file polling 제거
- `.statusline-events.jsonl` 을 bus publish → statusline 은 tail `-c 2048`
- cross-host events → 원격 호스트 probe 결과도 local statusline 표시

## 33. Dogfood 메트릭
- p50 / p99 render_ms
- COLUMNS 분포
- degraded 경로 빈도 (<1% 목표)
- EMERGENCE panel 공란 turn 비율 (<30% 목표)
- cost_cum vs CC usage summary ±5%

## 34. 보안 / PII
- transcript 내용 읽지 않음 — `usage` + line count 만
- branch 이름 `SECRET_*` prefix → `⎇ ****` 치환 (옵션)
- 로그 로컬 전용

## 35. Cross-platform
- macOS 전용 (`stat -f`, `chflags`) 분기
- Linux: uchg_drift 소스 skip, 나머지 POSIX 공통

## 36. 완성도 체크리스트
```
[x] 4 panel renderer 각각 동작
[ ] wcwidth 정렬 정확                     # deferred — needed when box-drawing activates
[x] 3-tier COLUMNS 적응                   # env COLUMNS → tput → stty → 100 (§21)
[x] anti-flicker hysteresis               # /tmp/sl-state-<session>, +10% boost
[~] cache (git sha + roadmap mtime + event mtime)  # CONTEXT 60s cache wired; roadmap/emergence mtime-driven invalidation pending
[x] degraded paths 6종                    # jq/git/transcript/.raw/timeout/stdin-parse
[x] observability log                     # .hook-statusline.jsonl + render_ms
[x] per-panel timeout                     # CONTEXT 150ms, EMERGENCE 150ms, bundle 200ms
[~] fixture × golden 테스트               # smoke harness landed (test/t_statusline_4panel.hexa); golden-file level deferred (needs frozen clock)
[x] A/B env var swap                      # STATUSLINE_V=legacy|4panel
[x] init tool 연동 + uchg 재잠금          # tool/airgenome_init.hexa
[x] 롤백 1-step                           # STATUSLINE_V=legacy airgenome-init
[ ] dogfood 1주                           # time-based (starts post-merge)
[x] linear stack renderer demotion        # claude_statusline.jq → EMERGENCE fallback (spec §26 step 5)
```

## 37. 범위 밖 (의도적 제외)
- Rust/Go 재작성 (overkill)
- MCP server 경유 (CC → MCP 로 statusline 호출 불가)
- Web dashboard sync (M12 후)
- Interactive statusline (CC 지원 안 함)
- LLM in-the-loop re-ranking (300ms 못 맞춤)
