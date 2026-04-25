# airgenome

mac-local resource manager — Mac vitals 6축 hexagon (60바이트) 게놈으로 투사, 패턴 누적, anomaly 검출 + 라벨링.

**Cross-host execution (ubu1 / ubu2 / hetzner) 은 [hive](https://github.com/need-singularity/hive) 로 이관됨**
(`~/core/hive` → `/resource list|score|route|ping` menu, .resource SSOT, docker-exec channel).

**Status**: scope-reduced 2026-04-25 — see `.roadmap` M26.

## Layout

```
core/                  # 분리된 라이브러리 — Vitals, sample, assess, AdaptiveThrottle
  core.hexa
  test/core_test.hexa
modules/               # mac-local milestone 모듈 — use "../core/core" 만
  probe.hexa             — mac CPU/RAM/swap → nexus/infra_state.json
  harvest.hexa           — top-N processes → 60-byte hexagon → forge/genomes.ring
  label.hexa             — genomes.ring → rule 매치 → forge/labeled_anomaly.jsonl
  predictive_throttle.hexa — adaptive batch size throttle
  filters/{data,process,transport}/  — claude/safari/calendar/finder 등 mac-local filters
launchd/               # com.airgenome.*.plist (mac-local 만 live)
archive/v1/            # v1 시점 모든 코드/데이터 (read-only)
nexus/                 # cross-project SSOT (별도 프로젝트)
CLAUDE.md              # 프로젝트 인스트럭션
```

## Commands

```bash
# core self-test
hexa run core/test/core_test.hexa

# probe — mac-local vitals → nexus/infra_state.json
hexa run modules/probe.hexa self-test
hexa run modules/probe.hexa

# harvest — top-N processes → 60-byte hexagon → forge/genomes.ring
hexa run modules/harvest.hexa self-test
hexa run modules/harvest.hexa

# label — genomes.ring → rule 매치 → forge/labeled_anomaly.jsonl
hexa run modules/label.hexa self-test
hexa run modules/label.hexa

# CLI 단일 진입점
bin/airgenome --help
bin/airgenome status        # supervisor + guard + 산출물 freshness
bin/airgenome logs probe    # tail probe.stderr.log
```

Cross-host 실행이 필요하면:

```bash
cd ~/core/hive && hive
> /resource list                              # 4 호스트 인벤토리
> /resource ping host-ubu1                    # 호스트 reachability
> /resource route gpu,cuda13 8 -- hexa drill  # docker exec 라인 emit
```

## Meta-evolution engine

12-tool self-observing scanner suite — design spec:
[`docs/airgenome_meta_evolution_proposal_20260423.md`](docs/airgenome_meta_evolution_proposal_20260423.md).
Read-only: ring/forge files are never mutated; outputs land in `state/ag_*.json` (gitignored).

```bash
bin/ag_meta help              # list subcommands
bin/ag_meta selftest          # --selftest every scanner (fast path)
bin/ag_meta doctor            # run all scanners + aggregators
bin/ag_meta health            # 0-100 score from state/ag_*.json
bin/ag_meta ring              # ring JSONL integrity
bin/ag_meta forge             # forge log health
bin/ag_meta rules             # rule fire count map
bin/ag_meta infra             # launchd/systemd/docker parity
bin/ag_meta divergence        # 3-ring Jaccard (pid/comm)
bin/ag_meta velocity          # genome rate + drift
bin/ag_meta cost              # compute cost proxy
bin/ag_meta motif             # top-K process signatures
bin/ag_meta blockers          # prioritized inventory
bin/ag_meta roi               # loss-free cleanup candidates
bin/ag_meta continuous-scan   # doctor + snapshot state/history/
bin/ag_meta telemetry         # per-tool runtime summary
bin/ag_meta gap               # emit scanner proposals
bin/ag_meta dsl               # run scanners/*.meta.hexa specs
bin/ag_meta build             # native-compile every scanner (2-4× faster)
bin/ag_meta report            # markdown dashboard (--stdout for pipe)
```

Declarative scanners live in `scanners/*.meta.hexa` (key=value specs).
Add a spec there, run `ag_meta dsl`, and its verdict lands in
`state/ag_dsl_<name>.json` — no Hexa code required.

## Menubar (V5, ObjC launcher)

macOS menubar 가 meta-evolution 의 관찰자 UI surface (Ω fixpoint + host bars).

**구조 (2026-04-24)**
- `bin/menubar_launcher.m` — ObjC NSApplicationMain 진입. NSStatusItem +
  NSTimer(5s) 로 `state/*.json` 직접 read → title + dropdown menu.
- `bin/menubar.hexa` — hexa 진입 (`hexa_autogen_main` init only).
- `bin/build_menubar.sh` — hexa_v2 transpile → C → perl post-process → ObjC link.
- `bin/build_app.sh` — bundle + adhoc codesign + /Applications/Airgenome.app deploy.
- `bin/test_menubar.sh` — V5 스모크 게이트.
- `scanners/menubar_liveness.meta.hexa` — heartbeat age threshold 60s liveness.

```bash
bin/build_app.sh                  # 빌드 + codesign + deploy + 재기동
DEPLOY=skip bin/build_app.sh      # 빌드만 (deploy/launch 생략)
bin/test_menubar.sh               # 스모크 (Aqua 세션이면 heartbeat 검증)
airgenome menubar                 # launchd ensure
```

## Archive

v1 의 모든 코드는 [`archive/v1/`](archive/v1/) 에 동결. 부활 절차는 [`archive/v1/README.md`](archive/v1/README.md).

## Related projects

- [hive](https://github.com/need-singularity/hive) — cross-host execution + .resource SSOT (airgenome 의 cross-host 책임을 흡수)
- [nexus](https://github.com/need-singularity/nexus) — cross-project SSOT (L0 lockdown, 규칙)
- [hexa-lang](https://github.com/need-singularity/hexa-lang) — airgenome 이 의존하는 self-hosted 언어 + tool/{resource_scorer,workload_router,load_balancer}.hexa

---

## Roadmap

| ID  | Milestone                                    | Status     | Note                                                |
|-----|----------------------------------------------|------------|-----------------------------------------------------|
| M0  | v1 동결 + core 분리                          | ✅ done    | archive/v1/ + core/core.hexa                        |
| M1  | L0 guard parse-check (phantom 차단)          | ✅ done    | nexus l0_guard                                      |
| M2  | probe — vitals → infra_state                 | ⊘ dropped  | cross-host vitals migrated to hive                  |
| M3  | dispatch — infra_state → best host           | ⊘ dropped  | host selection migrated to hive workload_router     |
| M4  | harvest — 60-byte hexagon per process        | ✅ done    | mac-local 유효                                       |
| M5  | label — anomaly → behavior 라벨              | ✅ done    | mac-local rule subset (M11d host_filter 제거)        |
| M6  | predict — 7d 추세 → 1h 예측                  | ⊘ dropped  | 3-host genome 합성 의존; mac-only 재설계는 별도      |
| M7  | launchctl bootstrap (5 plist)                | ⊘ dropped  | mac-local 4 plist 만 잔존                            |
| M8  | end-to-end chain 실데이터                    | ⊘ dropped  | 5-stage cross-host pipeline 폐기                     |
| M9  | per-process gpu/npu/power axes               | ⊘ dropped  | hive resource_scorer 흡수                            |
| M10 | forecast real eval                           | ⊘ dropped  | M6 의존                                              |
| M11 | cross-host genome 합성                       | ⊘ dropped  | hive .resource SSOT                                  |
| M12 | dashboard — menubar + web 관찰               | ⏳ planned | mac UI 유지                                          |
| M13 | hook framework — self-hosted event bus 확장  | ⏳ planned | mac-local event bus 도 유효                          |
| M14-M20 | ops convergence skeleton                 | ⊘ dropped  | hive 관할                                            |
| M21-M25 | AGI-ready ops skeleton                   | ⊘ dropped  | hive substrate 로 이관                               |
| M26 | mac-local resource manager — scope-reduce    | 🟢 active  | 본 시점 (2026-04-25)                                 |

SSOT: [`.roadmap`](./.roadmap) (live, locked).

### Invariants (config/roadmap/airgenome.json#invariants)

1. `core/core.hexa` 는 외부 hexa 파일 import 안 한다 (self-contained)
2. 신규 module 은 `use "../core/core"` 만 허용 — module 끼리 직접 import 금지
3. L0 자격 = 파일 존재 + hexa parse 통과 + self-test 통과 (3중)
4. `archive/v1/` 는 read-only — 부활은 PR + roadmap 등록 + L0 갱신
5. `.roadmap` 에 없는 코드는 작성 금지
6. cross-host 실행이 필요하면 hive (~/core/hive) → `/resource` 사용 — airgenome 에 ssh/scp/rsync/docker-H 추가 금지
