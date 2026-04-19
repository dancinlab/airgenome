# airgenome

OS 게놈 스캐너 — Mac/원격 vitals 를 6축 hexagon (60바이트) 게놈으로 투사, 패턴 누적, anomaly 검출.

**Status**: rebuild v2 — M0~M6 6개 마일스톤 완료 (2026-04-14). SSOT: [`shared/config/roadmap/airgenome.json`](shared/config/roadmap/airgenome.json).

## Layout

```
core/                  # 분리된 라이브러리 — Vitals, sample, assess, AdaptiveThrottle
  core.hexa
  test/core_test.hexa
modules/               # roadmap milestone 모듈 (M2 이후) — use "../core/core" 만
cl                     # 9줄 약자: exec claude → zshrc claude() → claudx-loop|claudx
bin/
  bootstrap            # fresh Mac 17-tier init (brew → claude → ssh → cl-refresh launchd → ...)
  claudx               # M13 limit-resilient launcher — pool.js + interceptor + loadgate
  claudx-loop          # TUI rotation watchdog (M13e)
  cx                   # cross-host claude router (ssh -t 직결, ControlMaster 의존)
shared/
  claudx/              # pool.js / interceptor.js / loadgate (M13 런타임)
  config/roadmap/      # rebuild v2 SSOT (milestones, invariants)
  config/hosts.json    # cx/dispatch 용 원격 호스트 registry
  launchagents/        # com.airgenome.*.plist (launchd 스케줄)
.session_defaults      # 매 세션 강제 룰 SSOT (plain text, cat → --append-system-prompt)
archive/v1/            # v1 시점 모든 코드/데이터 (read-only)
nexus/                 # cross-project SSOT (별도 프로젝트)
```

## Setup (fresh Mac)

```bash
git clone https://github.com/need-singularity/airgenome ~/Dev/airgenome
~/Dev/airgenome/bin/bootstrap                      # 전 tier 대화형
BOOTSTRAP_YES=1 ~/Dev/airgenome/bin/bootstrap      # 전 tier non-interactive
BOOTSTRAP_ONLY="5,6,14" ~/Dev/airgenome/bin/bootstrap  # tier 5/6/14 만
```

Claude 계정별 `/login` (OAuth 브라우저) 완료 후 `bootstrap` 재실행 → tier 16/17 가
`claude_keychain_map.json` + `accounts.json` 자동 갱신.

## Commands

```bash
# core self-test
hexa run core/test/core_test.hexa

# L0 verify (전 섹션 — 파일 존재 + CODEOWNERS + 브랜치 보호 + parse)
hexa run $NEXUS/shared/harness/l0_guard.hexa verify

# probe — Mac+ubu+htz vitals → nexus/shared/infra_state.json (M2)
hexa run modules/probe.hexa self-test
hexa run modules/probe.hexa

# dispatch — infra_state → best host → nexus/shared/dispatch_state.json (M3)
hexa run modules/dispatch.hexa self-test
hexa run modules/dispatch.hexa

# harvest — top-N processes → 60-byte hexagon → forge/genomes.ring + sigdiff (M4)
hexa run modules/harvest.hexa self-test
hexa run modules/harvest.hexa

# label — genomes.ring → rule 매치 → forge/labeled_anomaly.jsonl (M5)
hexa run modules/label.hexa self-test
hexa run modules/label.hexa

# forecast — Holt's 이중 지수평활 → forge/forecast.jsonl (M6)
hexa run modules/forecast.hexa self-test
hexa run modules/forecast.hexa
```

## Archive

v1 의 모든 코드는 [`archive/v1/`](archive/v1/) 에 동결. 부활 절차는 [`archive/v1/README.md`](archive/v1/README.md).

## Related projects

- [nexus](https://github.com/need-singularity/nexus) — cross-project SSOT (L0 lockdown, 규칙, 자원 관문 `hexa` 래퍼)
- [hexa-lang](https://github.com/need-singularity/hexa-lang) — airgenome 이 의존하는 self-hosted 언어

---

## Roadmap (rebuild v2)

| ID  | Milestone                                    | Priority | Status  | Deps   | Evidence                                                |
|-----|----------------------------------------------|----------|---------|--------|---------------------------------------------------------|
| M0  | v1 동결 + core 분리                          | P0       | ✅ done | —      | airgenome#33 · nexus#33 · 19/0 PASS                     |
| M1  | L0 guard parse-check 추가 (phantom 차단)     | P0       | ✅ done | M0     | nexus#34 · 21/0 PASS (parse 2건)                        |
| M2  | probe — Mac+ubu+htz vitals → infra_state     | P1       | ✅ done | M0, M1 | airgenome#37 · nexus#36 · 24/0 PASS                     |
| M3  | dispatch — infra_state → best host (AG6/AG7) | P1       | ✅ done | M2     | airgenome#39 · self-test PASS · ag6_gate=active 검증    |
| M4  | harvest — 60-byte hexagon per process        | P1       | ✅ done | M2     | airgenome#41 · genomes.ring + sigdiff + AdaptiveThrottle |
| M5  | label — anomaly → behavior 라벨 (T15)        | P2       | ✅ done | M4     | airgenome#42 · 5 rules SSOT · synthetic 3-label 검증     |
| M6  | predict — 7d 추세 → 1h 예측                  | P3       | ✅ done | M4     | airgenome#43 · Holt's 이중 지수평활 · MAE=0% (held-out) |

- Live 상태: `jq '.milestones | map({id, title, status})' shared/config/roadmap/airgenome.json`
- 다음 unblocked 작업: `jq '.milestones | map(select(.status == "todo" and ((.deps | length) == 0)))' shared/config/roadmap/airgenome.json`

### Invariants (shared/config/roadmap/airgenome.json#invariants)

1. `core/core.hexa` 는 외부 hexa 파일 import 안 한다 (self-contained)
2. 신규 module 은 `use "../core/core"` 만 허용 — module 끼리 직접 import 금지
3. L0 자격 = 파일 존재 + hexa parse 통과 + self-test 통과 (3중)
4. `archive/v1/` 는 read-only — 부활은 PR + roadmap 등록 + L0 갱신
5. `milestones` 에 없는 코드는 작성 금지
6. `.session_defaults` 이 매 세션 룰 SSOT — claudx/claudx-loop 가 `--append-system-prompt` 로 자동 주입

## Session defaults (매 세션 강제, M14)

루트 `.session_defaults` (plain text, no extension) 자체가 inject 텍스트. claudx 가
`exec cx` 직전 `cat .session_defaults` → `--append-system-prompt` 로 system prompt
끝에 무손실 주입. 변환·파싱 0 단계. `NEXUS_SESSION_LAX=1` 으로 일괄 우회.

```
$ cat .session_defaults
[airgenome session_defaults — 매 세션 강제. NEXUS_SESSION_LAX=1 로 우회]
S1-TASKS     non-trivial(≥2 step) 작업 시작 시 TaskCreate 필수 ...
S2-BG        독립/장시간(≥30s) 작업은 Agent run_in_background=true ...
S3-NOBLOCK   사용자 메시지엔 ≤2문장 ack 후 즉시 bg 전환 ...
S4-PARALLEL  독립 작업은 한 메시지에 N≥8 동시 발사 ...
S5-CATCHUP   세션 시작/재진입 시 TaskList + 실행중 BG Agent 먼저 조회
```

## Crosshost (M11e → M13)

```
cl → zshrc claude() → claudx-loop(TUI) | claudx(-p) → cx → ssh -t | local claude
```

- `cl` (루트, 9줄): `exec claude "$@"` — 분기는 zshrc `claude()` 함수
- `bin/claudx` (M13, 257줄): `pool.pickBest` → `CLAUDE_CONFIG_DIR` → `NODE_OPTIONS`/`BUN_OPTIONS` interceptor 주입 → cx delegate
  - upstream pin 재검증: `session_pct≥95 / week_all_pct≥100 / _retry_at>now` → re-pick
  - 모든 계정 한도 시 earliest reset 표시 + exit 3 (`CLAUDX_ALLOW_EMPTY=1` 우회)
  - loadgate: critical=abort, danger=60s hold
  - `--dangerously-skip-permissions` 기본 주입 (`CLAUDX_SAFE=1` 로 끔)
- `bin/cx`: ssh -t 직결 (M13c v3, tmux 제거). ControlMaster 로 master 세션 재사용
- 원격 자격증명: Mac keychain → `bin/remote_account_sync` → 원격 `.credentials.json`
- 상태 파일: `~/.airgenome/claudx/{exhausted.json,rotations.jsonl,cost.jsonl}`
- 풀 SSOT: `~/Dev/nexus/shared/.runtime/accounts/{accounts,usage-cache}.json`
