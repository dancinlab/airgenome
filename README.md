# airgenome

OS 게놈 스캐너 — Mac/원격 vitals 를 6축 hexagon (60바이트) 게놈으로 투사, 패턴 누적, anomaly 검출.

**Status**: rebuild v2 — M0~M6 6개 마일스톤 완료 (2026-04-14). SSOT: [`config/roadmap/airgenome.json`](config/roadmap/airgenome.json).

## Layout

```
core/                  # 분리된 라이브러리 — Vitals, sample, assess, AdaptiveThrottle
  core.hexa
  test/core_test.hexa
modules/               # roadmap milestone 모듈 (M2 이후) — use "../core/core" 만
shared/
  config/roadmap/      # rebuild v2 SSOT (milestones, invariants)
  launchagents/        # com.airgenome.*.plist (launchd 스케줄)
archive/v1/            # v1 시점 모든 코드/데이터 (read-only)
nexus/                 # cross-project SSOT (별도 프로젝트)
CLAUDE.md              # 프로젝트 인스트럭션 (Claude Code)
cl                     # claude wrapper
```

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

## Meta-evolution engine

12-tool self-observing scanner suite — design spec:
[`docs/airgenome_meta_evolution_proposal_20260423.md`](docs/airgenome_meta_evolution_proposal_20260423.md).
Read-only: ring/forge files are never mutated; outputs land in
`state/ag_*.json` (gitignored).

```bash
bin/ag_meta help              # list subcommands
bin/ag_meta selftest          # --selftest every scanner (fast path)
bin/ag_meta doctor            # run all scanners + aggregators
bin/ag_meta health            # 0-100 score from state/ag_*.json
bin/ag_meta ring              # Phase 3.1  ring JSONL integrity
bin/ag_meta forge             # Phase 3.2  forge log health
bin/ag_meta dispatch          # Phase 3.3  handler fire count
bin/ag_meta rules             # Phase 3.4  rule fire count map
bin/ag_meta infra             # Phase 3.5  launchd/systemd/docker parity
bin/ag_meta forecast          # Phase 3.6  forecast vs labeled_anomaly
bin/ag_meta divergence        # Phase 3.7  3-ring Jaccard (pid/comm)
bin/ag_meta velocity          # Phase 3.8  genome rate + drift
bin/ag_meta cost              # Phase 3.9  compute cost proxy
bin/ag_meta motif             # Phase 3.10 top-K process signatures
bin/ag_meta blockers          # Phase 1    prioritized inventory
bin/ag_meta roi               # Phase 2    loss-free cleanup candidates
bin/ag_meta continuous-scan   # Phase 5    doctor + snapshot state/history/
bin/ag_meta telemetry         # Phase 6.1  per-tool runtime summary
bin/ag_meta gap               # Phase 6.2  emit scanner proposals
bin/ag_meta dsl               # Phase 6.3  run scanners/*.meta.hexa specs
bin/ag_meta build             # native-compile every scanner (2-4× faster)
bin/ag_meta report            # markdown dashboard (--stdout for pipe)
```

Declarative scanners live in `scanners/*.meta.hexa` (key=value specs).
Add a spec there, run `ag_meta dsl`, and its verdict lands in
`state/ag_dsl_<name>.json` — no Hexa code required.

Schedule continuous-scan every 12h via
`config/launchd/com.airgenome.meta_continuous_scan.plist`:

```bash
cp config/launchd/com.airgenome.meta_continuous_scan.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.airgenome.meta_continuous_scan.plist
```

## Menubar (V5, ObjC launcher)

macOS menubar 가 meta-evolution 의 관찰자 UI surface (Ω fixpoint + host bars).

**구조 (2026-04-24)**
- `bin/menubar_launcher.m` — ObjC NSApplicationMain 진입. `[NSApp run]` 로
  LaunchServices/WindowServer 정상 check-in. NSStatusItem 생성 + NSTimer(5s)
  로 `state/*.json` 직접 read → title `▃ ▂▁▂` (mac/ubu1/ubu2/htz bars,
  부하별 green/yellow/red) + dropdown menu (Ω closure, throttle, hosts).
- `bin/menubar.hexa` — hexa 진입은 `hexa_autogen_main` (init only). 본 main
  은 dead path (V4 호환 보존).
- `bin/build_menubar.sh` — hexa_v2 transpile → C → perl post-process (FFI
  TAG_STR marshalling 보정, u_main 호출 제거) → ObjC launcher 와 link.
- `bin/build_app.sh` — bundle 생성 + adhoc codesign + (DEPLOY=do 기본)
  /Applications/Airgenome.app 자동 deploy + launchd rebootstrap.
- `bin/test_menubar.sh` — V5 스모크 게이트 (binary spawn → heartbeat refresh).
- `scanners/menubar_liveness.meta.hexa` — heartbeat age threshold 60s 로 UI
  liveness 자가 관찰. `ag_meta dsl` 자동 수집.
- `airgenome menubar` (run.hexa) — launchd agent ensure (bootstrap if 미실행).

```bash
bin/build_app.sh                  # 빌드 + codesign + deploy + 재기동
DEPLOY=skip bin/build_app.sh      # 빌드만 (deploy/launch 생략)
bin/test_menubar.sh               # 스모크 (Aqua 세션이면 heartbeat 검증)
airgenome menubar                 # launchd ensure
airgenome doctor                  # menubar liveness 포함 6 체크
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

- Live 상태: `jq '.milestones | map({id, title, status})' config/roadmap/airgenome.json`
- 다음 unblocked 작업: `jq '.milestones | map(select(.status == "todo" and ((.deps | length) == 0)))' config/roadmap/airgenome.json`

### Invariants (config/roadmap/airgenome.json#invariants)

1. `core/core.hexa` 는 외부 hexa 파일 import 안 한다 (self-contained)
2. 신규 module 은 `use "../core/core"` 만 허용 — module 끼리 직접 import 금지
3. L0 자격 = 파일 존재 + hexa parse 통과 + self-test 통과 (3중)
4. `archive/v1/` 는 read-only — 부활은 PR + roadmap 등록 + L0 갱신
5. `milestones` 에 없는 코드는 작성 금지
