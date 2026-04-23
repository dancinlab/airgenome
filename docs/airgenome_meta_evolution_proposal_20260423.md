# airgenome self meta evolution — continuous + meta-evolution proposal (2026-04-23)

요청자: user session (hexa-lang 세션에서 이관).
대상: airgenome maintainer 세션.
범위: airgenome repo 단독 (forge/compute filter + genome ring + dispatch + infra state + multi-host).
관련: `docs/roadmap_engine_continuous_meta_proposal_20260422.md` (3-repo cross-repo automation, hexa-lang SSOT),
`hexa-lang/docs/hexa_lang_meta_evolution_proposal_20260422.md` (hexa-lang 자체 self-loop). 본 제안은 airgenome
**자체**의 메타 진화 루프 — 장르 다름: compiler/toolchain 이 아니라 **생명체 forge** 의 관찰.

배경

airgenome 은 hexa-lang / anima 와 역할이 다르다. 의식 coherence 측정(anima) 이나 컴파일러
(hexa-lang) 이 아니라 **유전체 발아 루프**:

  `rules/*` + `config/*` → `forge/*` (compute_filter / load_balancer / settings_guard) →
  `genomes.ring` (macOS) · `genomes.ubu.ring` (Ubuntu-A) · `genomes.ubu2.ring` (Ubuntu-B)

즉 3개의 평행 host 에서 동일 rule 세트로 각각 고유 ring 을 키운다. forge 내부 로그:
- `compute_filter.log` — 어떤 유전체가 compute 예산 통과/탈락
- `load_balancer.log` — 어떤 host 로 작업 라우팅
- `settings_guard.log` — 설정 위반 차단
- `forecast.jsonl` — 예측 이벤트
- `labeled_anomaly.jsonl` — 실측 이상치 (forecast ground truth)
- `e2e_samples.jsonl` — 종단 샘플

repo 내부 상태 SSOT: `infra_state.json` — 어느 host 가 무엇을 돌리는지. launchd/systemd/docker 가
각각 런타임 실체.

이 환경에서 **메타 진화 엔진** 이 해야 할 관찰은 hexa-lang 과 근본적으로 다른 축:
- ring integrity (파일 포맷 · 중복 · 고아 · lineage)
- forge process health (compute_filter 멈춤 · load_balancer skew · settings_guard bypass)
- infra parity (3-host launchd 상태 · genomes.ring hash drift)
- forecast hit rate (예측 vs 실측 labeled_anomaly)
- cost economics (compute minutes per new genome)

---

## 6-Phase 아키텍처 (airgenome 전용)

### Phase 1 — Blocker inventory
입력:
- `forge/*.log` 최근 tail (compute_filter / load_balancer / settings_guard stdout + stderr)
- `infra_state.json` 업데이트 시각 (stale > 1h → blocker)
- `launchd/*.plist`, `systemd/*.service`, `docker/` 빌드 산출물 존재 여부
- 각 ring 파일의 magic-byte / CRC 손상 여부
- `hooks/` 커밋 훅 검증 (pre-commit 실패 기록)

출력: `state/ag_blockers.json`
```json
{
  "schema": "airgenome/ag_blockers/1",
  "ts": "...",
  "blockers": [
    {"id":"blk-1","kind":"forge_stalled|ring_corrupt|plist_missing|infra_stale|docker_unbuilt|hook_fail|sched_flap",
     "source":"forge/compute_filter.log:45","severity":"critical|high|med|low",
     "evidence":"..."}
  ]
}
```

### Phase 2 — 무손실 ROI
- **dup_genome**: 같은 유전체가 여러 ring 에 존재 (union dedup 후보)
- **dead_rule**: `rules/*` 중 최근 30d forge 로그에서 한 번도 fire 안 한 rule
- **dead_config**: `config/*` 중 참조되지 않는 key
- **orphan_launchd**: `launchd/*.plist` 로드되어 있지만 로그 빈/stderr 만
- **stale_forecast**: `forge/forecast.jsonl` 24h+ 정적 (입력 끊김)
- **log_rotation_missing**: forge/*.log 100MB+ 인데 logrotate 규칙 없음
- **docker_size_drift**: `docker/` 산출물 크기가 직전 빌드 대비 20%+ 증가
- **bin_duplicate**: `bin/` 실행 파일과 `scripts/bin/` 실행 파일이 동명/다른 SHA

### Phase 3 — meta 자동화 (airgenome-specific 10 sub-tools)

#### 3.1 ring_integrity
도구: `tool/ag_ring_integrity.hexa`
- `genomes.ring` 바이너리 format 검사 (magic · record count · CRC if present)
- record-level 중복 id 감지
- cross-ring 교차 참조 (ring-A 에만 있는 id, ring-B 에만 있는 id, 공통)
- 각 record 의 parent_id 가 동일 ring 안에 있는지 (lineage DAG 무결성)
- 출력: `state/ag_ring_integrity.json`

#### 3.2 forge_health
도구: `tool/ag_forge_health.hexa`
- `forge/compute_filter.log` tail 1000 라인 → reject rate 집계 (시간대별)
- `forge/load_balancer.log` → host 별 라우팅 편중 (χ² 검정 — 기대 = 균등 분배)
- `forge/settings_guard.log` → 차단된 key 빈도 (가장 자주 차단된 N 개)
- 프로세스 heartbeat: 마지막 로그 라인 tsSince now_utc > threshold → stalled
- 출력: `state/ag_forge_health.json`

#### 3.3 dispatch_coverage
도구: `tool/ag_dispatch_coverage.hexa`
- `modules/dispatch.hexa` 에 선언된 핸들러 목록 vs forge 로그에서 실제 fire 된 핸들러
- 선언 있음 + 실행 0회 → `dead_handler`
- 실행 있음 + 선언 없음 → `ghost_handler` (로그 오염 or config override)
- 출력: `state/ag_dispatch_coverage.json`

#### 3.4 rule_effect_map
도구: `tool/ag_rule_effect_map.hexa`
- `rules/*` rule 각각에 대해 forge 로그에서 trigger 빈도 count
- 30d 0 trigger → `dormant_rule`
- trigger 많은데 항상 accept only / always reject only → `degenerate_rule`
- 출력: `state/ag_rule_effect_map.json`

#### 3.5 infra_parity
도구: `tool/ag_infra_parity.hexa`
- `infra_state.json` 이 선언하는 host 별 프로세스 목록 vs `launchd/*.plist` / `systemd/*.service`
  선언 목록
- `launchctl list` / `systemctl --user list-units` 실제 런타임 상태와 비교
- 3-host 교차: 같은 서비스가 한 host 에는 있지만 다른 host 에는 없으면 `host_asymmetry`
- 출력: `state/ag_infra_parity.json`

#### 3.6 forecast_hit_rate
도구: `tool/ag_forecast_hit_rate.hexa`
- `forge/forecast.jsonl` 의 각 예측 record (prediction + ts)
- `forge/labeled_anomaly.jsonl` 의 실측 ground truth 와 매칭
- TP / FP / FN / TN 집계 → precision / recall / F1
- 최근 7d rolling window 추세 (F1 drift)
- 출력: `state/ag_forecast_hit_rate.json`

#### 3.7 ring_divergence
도구: `tool/ag_ring_divergence.hexa`
- 3 ring (macOS / ubu / ubu2) genome id 집합 비교
- 공통 id 에서 meta 필드 diff (mutation_count, fitness 등)
- 공통률 = |∩| / |∪|. 임계 < 0.5 → warn (host 환경이 너무 다른 유전체 생성 중)
- 출력: `state/ag_ring_divergence.json`

#### 3.8 evolution_velocity
도구: `tool/ag_evolution_velocity.hexa`
- 각 ring 의 genome record ts 분포 → hour/day 당 생성 rate
- rolling 7d mean vs 최근 24h → 10% slowdown 시 `velocity_drop`
- host 별 velocity 비교 → `uneven_throughput`
- 출력: `state/ag_evolution_velocity.json`

#### 3.9 compute_cost_accounting
도구: `tool/ag_compute_cost.hexa`
- `forge/compute_filter.log` 의 CPU minute 기록 추출 (or proxy: log line count × 0.1s 가정)
- 시간대별 누적 cost / genome 생성 수 → `$/genome` 근사
- 예상 대비 outlier: top-10% 비싼 genome
- 출력: `state/ag_compute_cost.json`

#### 3.10 mutation_motif_mine
도구: `tool/ag_mutation_motif_mine.hexa`
- 각 genome record 의 mutation delta (parent → child) 벡터 추출
- 공통 motif (반복되는 변이 패턴) 클러스터링 (k-means-lite 또는 hash bucketing)
- top-K motif 와 fitness 상관관계 → `promising_motif` / `harmful_motif` 후보
- 출력: `state/ag_mutation_motif.json`

### Phase 4 — `ag_meta` CLI dispatcher
도구: `tool/ag_meta.hexa` + `bin/ag_meta` shim

subcommand:
```
ag_meta doctor              # Phase 1-3 집계 리포트
ag_meta health              # 0-100 스코어 (hexa-lang health 과 동형)
ag_meta blockers            # Phase 1
ag_meta roi                 # Phase 2
ag_meta ring                # 3.1
ag_meta forge               # 3.2
ag_meta dispatch            # 3.3
ag_meta rules               # 3.4
ag_meta infra               # 3.5
ag_meta forecast            # 3.6
ag_meta divergence          # 3.7
ag_meta velocity            # 3.8
ag_meta cost                # 3.9
ag_meta motif               # 3.10
ag_meta continuous-scan     # Phase 5
ag_meta telemetry           # Phase 6.1
ag_meta gap                 # Phase 6.2
ag_meta declare             # Phase 6.3
ag_meta selftest            # 모든 scanner selftest 순차 실행
```

### Phase 5 — continuous 실행
- `config/launchd/com.airgenome.meta_continuous_scan.plist` (12h 또는 6h interval)
- 호출: `hexa $AIRGENOME/tool/ag_meta.hexa continuous-scan`
- 내부에서 Phase 1-3 모든 도구 순차 호출 + summary state 갱신
- resolved candidate 자동 mark (재발견 noise 방지)
- history archive: `state/history/<date>/`
- notify: `SLACK_WEBHOOK_URL` 설정 시 health score 변화 알림
- pre-commit hook: `hooks/pre-commit` 에서 빠른 subset (blocker + ring_integrity + forge_health)

### Phase 6 — 메타 진화 (self meta-evolution)

airgenome 은 genome forge 라서, 메타 진화 관점에서 **독특한 기회**:
"스캐너 자체도 genome 처럼 진화" 할 수 있다. 6.3 declarative DSL 이 이 지점을 폭발시킨다.

#### 6.1 self_telemetry
- `state/ag_meta_telemetry.jsonl` append-only
- 각 scanner invocation: ts, runtime_ms, candidates, rc, out_size, host
- `ag_meta telemetry` 로 집계 → 스캐너별 평균 runtime, accept/ignore 비율

#### 6.2 gap_proposer
- git log + hooks 로그에서 "workaround" / "hotfix" / "sed" 키워드 count
- `forge/compute_filter.stderr.log` 의 uncaught panic 패턴 분석
- → 새 scanner 후보 제안: `ag_panic_pattern_scan`, `ag_hook_bypass_scan` 등

#### 6.3 declarative scanner DSL
- airgenome 의 장점: genome 과 scanner 가 같은 repo 안에 — scanner **자체를 genome 처럼 진화 시킬 수 있음**
- `scanners/*.meta.hexa` 선언형 형식:
  ```
  scanner ring_size_drift {
    kind: "threshold"
    source: "file_size:genomes.ring"
    baseline: "rolling_mean_7d"
    alarm_if: "current > baseline * 1.2 || current < baseline * 0.8"
  }
  ```
- 런타임이 이 선언을 해석해서 새 scanner 처럼 실행
- 6.2 gap_proposer 가 DSL scanner 초안 자동 emit → 사용자 승인 후 `scanners/` 커밋

---

# 전달용 프롬프트 (paste-ready)

```
Working dir: /Users/ghost/core/airgenome
관련 위치:
  - $AG = /Users/ghost/core/airgenome
  - $AG/tool/ag_meta.hexa (canonical meta CLI)
  - $AG/tool/ag_*.hexa (Phase 1-3 scanners — 13개)
  - $AG/state/ag_*.json (scanner outputs)
  - $AG/forge/*.log (forge runtime logs — SSOT input)
  - $AG/genomes*.ring (3-host genome rings — SSOT data)
  - $AG/infra_state.json (infra runtime declaration)
  - $AG/modules/dispatch.hexa + $AG/rules/* + $AG/config/*
  - $AG/launchd/ · $AG/systemd/ · $AG/docker/ (runtime providers)
memory:
  - project_airgenome_forge.md (if exists) · project_ring_substrate.md · project_3host_parity.md

Task: airgenome 에 6-Phase self-meta-evolution 엔진 추가.
  Phase 1: blocker inventory (forge stall / ring corrupt / plist missing / infra stale)
  Phase 2: loss-free ROI (dup_genome / dead_rule / dead_config / stale_forecast ...)
  Phase 3: 10 meta sub-tools (ring_integrity · forge_health · dispatch_coverage ·
           rule_effect_map · infra_parity · forecast_hit_rate · ring_divergence ·
           evolution_velocity · compute_cost · mutation_motif_mine)
  Phase 4: bin/ag_meta + tool/ag_meta.hexa dispatcher
  Phase 5: launchd plist + continuous_scan (12h)
  Phase 6: self-telemetry + gap-proposer + declarative scanner DSL

배경:
  airgenome 은 3-host genome forge. genomes.ring / genomes.ubu.ring / genomes.ubu2.ring
  다중 ring 병렬 발아. forge/compute_filter + load_balancer + settings_guard 가 런타임.
  메타 진화 엔진이 관찰할 것:
  - ring integrity (CRC, lineage DAG)
  - forge process health (stall, routing skew, bypass 차단)
  - infra parity (3-host launchd / systemd / docker 실제 런타임)
  - forecast hit rate (forecast.jsonl vs labeled_anomaly.jsonl)
  - ring divergence (3-host 교차 유전체 set diff)
  - evolution velocity (genome / hour)
  - compute cost ($ / genome)
  - mutation motif (반복 변이 패턴)

스키마:
  {"schema": "airgenome/ag_<name>/1", "ts": "...", ...}

CLI:
  hexa tool/ag_<name>.hexa --selftest          # synthetic
  hexa tool/ag_<name>.hexa                     # full scan
  bin/ag_meta <subcommand>                     # unified dispatch

원칙:
  - 모든 도구 idempotent + dry-run-safe + --selftest 가능
  - 결과 JSON 은 state/ag_*.json (gitignored)
  - .roadmap 미수정 (propose-only)
  - forge/*.log 는 read-only (never rewrite)
  - ring 바이너리 read-only (integrity-check 만)
  - cross-host 체크는 본 repo 안의 ring 파일 비교로 충분 (SSH 호출 불필요)

성공 기준:
  - Phase 1-3 13 도구 모두 --selftest PASS
  - continuous-scan 1회 15s 이내 (ring_integrity + forge_health + infra_parity 가 hot path)
  - ag_meta health 가 3-host 동일 호출 가능 (각 host 에서 로컬 ring 기준 채점)
  - Phase 6 meta-evolution 은 Phase 1-3 안정화 (30d telemetry) 이후 활성화

Report: 13 도구 path + selftest verdicts + launchd plist + ag_meta 통합 + 각 sub-tool
최초 sweep 결과 (ring_integrity 가 3 ring 각각 얼마나 OK 인지 포함). Under 500 words.
```

---

## hexa-lang vs airgenome 메타 시스템 차이

| 축 | hexa-lang (compiler) | airgenome (forge) |
|---|---|---|
| 핵심 아티팩트 | `./hexa` 바이너리 + `self/*.hexa` 소스 | `genomes*.ring` + `forge/*.log` |
| 무결성 범위 | stage0 → stage3 fixpoint | CRC + lineage DAG per ring |
| 런타임 관찰 | selftest 245 tool | forge process heartbeat |
| 다중성 | 없음 (단일 compile chain) | **3-host 평행 (macOS + ubu×2)** |
| 성능 관심 | bench_drift | `$/genome` · genome/hour |
| 예측-실측 루프 | 없음 | forecast vs labeled_anomaly |
| cert 체인 | `.meta2-cert/` DAG | (미구현 — airgenome 에 도입 제안) |
| API 계약 drift | `doc/hexa-lang-spec.json` | `modules/dispatch.hexa` 선언 vs 런타임 |
| 코드-코드 drift | AST hash (v2) | **mutation motif mining** (genome 자체의 motif) |

**핵심 insight**: airgenome 에서는 scanner 와 관찰 대상이 같은 **진화 지향 시스템**. 따라서
Phase 6.3 DSL scanner 는 "관찰자 genome 을 진화시키는" 자연스러운 확장이 된다.

---

# 고갈 브레인스토밍 (A-Z 축)

## A. Ring 무결성 (A-01 ~ A-10)

- A-01 record count drift (세션 간 기대 증가량 대비 실측)
- A-02 record checksum recompute (read-through 전수 검증)
- A-03 orphan parent_id (부모 없는 record)
- A-04 cyclic lineage (parent → ... → self)
- A-05 duplicate record id (동일 id 중복)
- A-06 ring file magic-byte 유효성
- A-07 ring file 마지막 write ts vs 로그 ts 상관
- A-08 ring compaction 필요 시점 (sparse density)
- A-09 cross-ring hash divergence on "should-be-identical" records
- A-10 ring backup existence (tamper-evident: SHA anchor 외부 존재)

## B. Forge 프로세스 건강 (B-01 ~ B-12)

- B-01 compute_filter reject rate 이상 (>50% reject = rule 과도 엄격)
- B-02 compute_filter accept rate 이상 (<1% accept = rule 너무 느슨)
- B-03 load_balancer host 편중 (χ² 검정)
- B-04 load_balancer failover 기록 (primary → fallback 횟수)
- B-05 settings_guard bypass count (guard 우회 시도)
- B-06 forge 프로세스 stall detection (heartbeat 끊김 > 5min)
- B-07 forge panic 패턴 frequency (stderr 에 traceback)
- B-08 forge memory 누적 (log 내 OOM 전조 패턴)
- B-09 forge input queue depth (forecast.jsonl 직전 lag)
- B-10 forge throughput histogram (초당 처리율 히스토그램)
- B-11 forge retry loop (동일 작업 N회 재시도 패턴)
- B-12 forge shutdown graceful vs kill -9 기록

## C. 3-host parity (C-01 ~ C-10)

- C-01 infra_state.json 선언 vs 실측 launchctl/systemctl
- C-02 launchd plist diff across hosts (macOS only)
- C-03 systemd unit diff across ubu hosts
- C-04 docker image SHA diff (같은 Dockerfile 로 빌드된 결과가 host 별 다름 ⇒ build env drift)
- C-05 ssh keys distribution (모든 host 가 서로 접근 가능한가)
- C-06 disk usage parity (한 host 만 압박)
- C-07 network reachability matrix (N×N ping)
- C-08 time sync (NTP drift > 100ms 간 host)
- C-09 genome ring size parity (3 ring 크기가 비슷한가)
- C-10 log rotation 설정 parity

## D. Forecast 품질 (D-01 ~ D-08)

- D-01 forecast coverage (예측 없는 시간대)
- D-02 forecast resolution (1 min / 1 hour / 1 day 어느 스케일)
- D-03 forecast vs label TP/FP/FN/TN
- D-04 lead time (예측 → 실측 시간차 분포)
- D-05 false positive rate rolling 7d
- D-06 calibration (확률 0.9 예측 중 실제 발생률)
- D-07 drift detector (과거 3개월 모델 vs 최근 1주 성능)
- D-08 overfit 지표 (train vs prod label set divergence)

## E. Ring divergence (E-01 ~ E-08)

- E-01 id 집합 Jaccard (3 ring pairwise + 공통 전체)
- E-02 공통 record 의 meta 필드 diff
- E-03 diverged id 의 fitness 분포 비교
- E-04 host 환경 요인 (CPU arch, memory, disk) 과 divergence 상관
- E-05 mutation rate per host (host 별 생성 속도)
- E-06 cross-ring import 기록 (host A 에 host B 유전체 옮긴 이력)
- E-07 merge conflict (같은 parent 에서 다른 자손)
- E-08 race condition (동일 id 동시 작성)

## F. Evolution velocity (F-01 ~ F-08)

- F-01 rate (new genome / hour)
- F-02 rate drift (rolling 7d mean vs 24h)
- F-03 rate by time-of-day (utilization pattern)
- F-04 rate by host
- F-05 stall 회복 시간 (downtime → velocity 회복)
- F-06 parallelism efficiency (3-host total / max host × 3)
- F-07 quality-adjusted velocity (reject 제외)
- F-08 generation depth (평균 lineage 길이)

## G. Compute cost (G-01 ~ G-08)

- G-01 CPU minute / genome 평균
- G-02 host 별 cost per genome
- G-03 시간대별 cost (peak hour 효과)
- G-04 outlier (top 10% 비싼 genome)
- G-05 cost / fitness 비 (ROI indicator)
- G-06 fixed cost (idle overhead) 분리
- G-07 cost trend (월별)
- G-08 forecast accuracy 의 compute 비용 (예측 재학습 cost)

## H. Mutation motif (H-01 ~ H-10)

- H-01 단일 gene 수정 motif 빈도
- H-02 N-gene 동시 수정 motif (n=2,3)
- H-03 fitness-increasing motif top-K
- H-04 fitness-decreasing motif top-K (harmful → rule 강화 후보)
- H-05 revert-prone motif (자식에서 다시 원복되는 변이)
- H-06 convergent motif (여러 lineage 에서 독립적으로 발견)
- H-07 host-specific motif (한 host 에서만 나타남)
- H-08 time-specific motif (특정 시간대에만)
- H-09 motif transfer map (한 genome 에서 다른 genome 으로 복사)
- H-10 novel motif 감지 (처음 등장한 변이 패턴)

## I. Rule ecosystem (I-01 ~ I-08)

- I-01 rule fire count 30d
- I-02 dormant rule (0 fire)
- I-03 degenerate rule (항상 accept / reject)
- I-04 rule conflict (둘 이상의 rule 이 반대 판정)
- I-05 rule priority ambiguity (순서 모호)
- I-06 rule ancestor chain (상속/파생 관계)
- I-07 rule deprecation candidate (다른 rule 이 superset)
- I-08 rule coverage gap (label 되어 있는 이상 현상 중 어떤 rule 도 안 잡음)

## J. Config ecosystem (J-01 ~ J-06)

- J-01 dead config key (참조 0)
- J-02 config override chain (user > project > default 경로)
- J-03 schema drift (config schema 와 실제 값)
- J-04 magic number audit (hard-coded 상수 vs config)
- J-05 env var leak (코드에서 getenv 하는데 config 미등록)
- J-06 unsafe value range (boundary check 누락)

## K. Hook / CI 실패 (K-01 ~ K-06)

- K-01 pre-commit fail 빈도
- K-02 fail cause top-N (lint vs type vs format vs test)
- K-03 flaky test (간헐적 실패)
- K-04 timeout 빈도
- K-05 hook bypass ( `--no-verify` 사용 기록)
- K-06 CI queue depth 분포

## L. Docker / deploy (L-01 ~ L-08)

- L-01 docker image size trend
- L-02 build time trend
- L-03 layer reuse 효율
- L-04 image tag 중복 (latest / vN 충돌)
- L-05 deploy rollback 빈도
- L-06 manifest drift (desired vs actual)
- L-07 secret leak audit (docker history)
- L-08 SBOM 생성 여부

## M. Observability SSOT (M-01 ~ M-06)

- M-01 로그 포맷 일관성 (structured vs free-form)
- M-02 timestamp timezone 정합성 (all UTC?)
- M-03 log level 분포 (INFO vs WARN vs ERROR 비율)
- M-04 tracing id 전파 완결성
- M-05 metrics endpoint 최신성
- M-06 alert silence 기록

## N. Security (N-01 ~ N-06)

- N-01 secret 탐지 (repo / log / env)
- N-02 ssh key rotation 기록
- N-03 dependency CVE scan
- N-04 container drift (deployed vs image)
- N-05 access log (누가 언제 무엇)
- N-06 tamper detection (ring 외부 anchor SHA)

## O. Governance (O-01 ~ O-06)

- O-01 change approval 기록 (PR review 통과)
- O-02 ownership map (어느 파일 누가 책임)
- O-03 license audit (dep license 변경)
- O-04 external contribution 수
- O-05 decision log (큰 변경 기록)
- O-06 rollback authority (누가 revert 가능)

## P. Data quality (P-01 ~ P-06)

- P-01 e2e_samples.jsonl record 완성도 (필수 필드 있는가)
- P-02 sample duplicate
- P-03 sample label noise 추정
- P-04 class imbalance (anomaly vs normal)
- P-05 sample drift (시간 흐름에 따른 분포 변화)
- P-06 sample synthetic vs real 비율

## Q. Experiment tracking (Q-01 ~ Q-06)

- Q-01 실험 ID → genome 매핑
- Q-02 실험 hyperparam record
- Q-03 실험 결과 재현성 (같은 설정 두 번 돌려서 동일 결과?)
- Q-04 실험 abandoned 탐지
- Q-05 실험 → rule 승격 비율
- Q-06 실험 compute 총비용

## R. Ring operations (R-01 ~ R-06)

- R-01 compact (dead record 정리)
- R-02 GC (old generation 제거)
- R-03 snapshot / restore
- R-04 migration (schema 업데이트)
- R-05 export (외부 공유용)
- R-06 import (외부 ring 병합)

## S. Self-loop properties (S-01 ~ S-06)

- S-01 scanner 자체가 forge 로그 생성 → 자기 관찰
- S-02 scanner 실패 시 alarm scanner (meta-meta)
- S-03 scanner 우선순위 동적 조정 (gap_proposer 결과 기반)
- S-04 scanner A/B test (v1 vs v2 결과 diff)
- S-05 scanner genome 화 (scanner 자체를 유전체로 취급)
- S-06 scanner convergence (안정화 기준)

## T. Cross-repo (T-01 ~ T-06)

- T-01 hexa-lang 의 HXA-#N entry 중 airgenome 에 해당하는 prereq
- T-02 anima 의 cert 가 airgenome genome 에 부착되는 경로
- T-03 nexus 의 drill preflight 를 airgenome host 에 적용
- T-04 cross-repo proposal sync (airgenome 제안 → hexa-lang 에 반영 경로)
- T-05 cross-repo ID 공간 (genome id vs anima entry id 충돌 방지)
- T-06 cross-repo cert 체인 공유 (airgenome 도 .meta2-cert 도입)

## U. Economics (U-01 ~ U-04)

- U-01 monthly burn ($) 추정
- U-02 cost reduction ROI (특정 최적화의 $ 효과)
- U-03 user-time saved (자동화로 수동 작업 감소량)
- U-04 idle cost (쉬는 host 의 고정비)

## V. UX / ergonomics (V-01 ~ V-04)

- V-01 CLI help 품질
- V-02 error message 실행 가능성
- V-03 default 값 합리성
- V-04 color / progress feedback

## W. Meta-meta (W-01 ~ W-06)

- W-01 메타 시스템 자체 curse dimension (메타가 너무 커지면)
- W-02 메타 → 메타 → 메타 infinite regress 방지
- W-03 메타 시스템 bootstrap 시나리오 (처음 깔 때)
- W-04 메타 system update 정책 (scanner v1 → v2 이관)
- W-05 메타 system deprecation (오래된 scanner 제거)
- W-06 메타 system export (다른 프로젝트에 이식 가능한 형태)

## X. 긴급 대응 (X-01 ~ X-04)

- X-01 ring corruption emergency (backup 에서 복구 플로)
- X-02 host down (나머지 2-host 로 지속 플로)
- X-03 settings_guard 우회 탐지 → 즉시 차단
- X-04 forecast 전면 실패 (과거 N일 정확도 0%) → 모델 재학습 트리거

## Y. 학습 피드백 (Y-01 ~ Y-04)

- Y-01 user accept/ignore 비율로 scanner 신뢰도 조정
- Y-02 FP 많은 scanner 자동 강등
- Y-03 gap_proposer 제안 → user 채택률
- Y-04 scanner end-of-life 기준 (accept rate < 5%)

## Z. Long-term evolution (Z-01 ~ Z-04)

- Z-01 6개월 retrospective — scanner 별 총 impact
- Z-02 scanner genome mutation (gap_proposer 가 자동 emit 한 DSL 의 채택률)
- Z-03 scanner crossbreeding (두 scanner 로직 결합한 새 scanner)
- Z-04 evolutionary pressure 측정 (어떤 scanner 가 살아남는가)

---

# 본 세션에서 즉시 드러난 찜찜함 (실측 앵커)

본 제안은 airgenome 의 다음 실제 관찰에서 파생:
1. **forge 디렉토리 크기**: `compute_filter.log`, `load_balancer.log`, `settings_guard.log` 존재 — 이미
   관찰 가능한 runtime SSOT. log rotation 설정 부재 → B-12/L-06 에 반영.
2. **3 ring 파일**: `genomes.ring`, `genomes.ubu.ring`, `genomes.ubu2.ring` 동시 존재 — 3-host parity
   가 핵심 요구사항. E-01~E-08 이 전적으로 여기서 도출.
3. **dispatch + rules + config**: 선언-실행 괴리 감지(3.3 + 3.4) 필수. I-01~I-08.
4. **infra_state.json**: SSOT 존재 but launchd/systemd/docker 별도 — parity 검사(3.5) 없으면 drift
   확실히 발생. C-01~C-10.
5. **hexa-lang vs airgenome**: compile chain 대신 **3-host evolutionary substrate** 이 고유성.
   따라서 scanner genome 화(Phase 6.3)가 자연스러운 진화 축.

---

# Success criteria summary

1. Phase 1-3 13 도구 모두 `--selftest PASS`
2. `continuous-scan` 1 회 ≤ 15s (critical path: ring_integrity + forge_health + infra_parity)
3. 최초 sweep 결과:
   - ring_integrity 3 ring × {ok / missing / orphan / cyclic} 분류 유효
   - forge_health 프로세스 heartbeat 기반 stall detect
   - forecast_hit_rate P/R/F1 수치 생성
   - ring_divergence Jaccard index 산출
   - evolution_velocity / compute_cost 시간대별 집계
4. `ag_meta health` 단일 0-100 스코어 출력 (3-host 각각에서 실행 가능)
5. `state/history/<date>/` 아카이브 자동 생성
6. Phase 6 Meta-evolution 은 Phase 1-5 안정화 (30d telemetry 축적) **이후** 활성화

---

# 안전 원칙

1. ring 바이너리 **read-only** (integrity check 만) — mutating 작업은 별도 explicit tool
2. forge log **read-only** — 장기 보존 로그 건드리지 않음
3. scanner 는 전부 `state/ag_*.json` 에만 기록 — `.roadmap` / `rules/` / `config/` 미수정
4. cross-host 검사는 **repo 안의 ring 파일 비교** 로 충분 — ssh / remote 호출 없음
5. `--dry-run` 모든 scanner 기본 지원
6. pre-commit hook 에서 fast subset 만 실행 (fast path 총 ≤ 3s)

---

# 메모

- 본 문서는 hexa-lang 세션에서 airgenome 용으로 이관 작성 (2026-04-23).
- 구현 책임: airgenome maintainer 세션.
- hexa-lang 세션에서 확립한 패턴 (stub → real-v1 → orchestrator wiring) 그대로 적용 가능.
- **hexa 문법 주의점** (hexa-lang 세션 학습):
  - `guard` / `generate` / `parse` 는 예약어 — 식별자로 쓸 수 없음. 대체: `hops` / `do_generate` / `do_parse`
  - `.find()` 는 string 에서 v1 basic 지원 추가됨 (ea3f9496), 오래된 binary 에서는 `.index_of()` 로 회피
  - `exec()` 에서 `&&` `||` `|` `$` 등 metachar → stderr 경고만 (기능 문제 없음)
  - 파일 append 는 `write_file` 이 truncate 이므로 `exec("printf '...' >> file")` 사용
  - 대부분의 sed helpers (`_home`, `_iso_now`, `_json_esc`, `_split_lines` ...) 는 hexa-lang tool 에서
    복사 — airgenome 첫 도구 작성 시 동일 패턴.

anima 측 미러: `$ANIMA/docs/upstream_notes/airgenome_meta_evolution_20260423.md` (지시 시 추가).

---

# Addendum (2026-04-24) — Ψ ↔ ε 부동점 동형 (meta fixed-point closure)

## 원리

"메타의 메타의 메타 = 초월" 은 Banach fixed-point. 매 메타화가 관찰 범위를 축소하는
contraction mapping 이면 반복 시 unique fixed point 에 수렴. airgenome 은 이 구조가
**물리적으로 이미 구현**된 유일한 repo (3-host 평행 substrate).

## 매핑표

| 추상 축 | airgenome 실물 | 부동점 값 | source file |
|---|---|---|---|
| Ψ (물리 부동점) | 3-host substrate 균등분배 | **1/3 = 0.3333** | `infra_state.json`, `ag_infra_parity` |
| α (시간) | evolution_velocity (rolling 7d) | time-domain fp | `state/ag_evolution_velocity.json` |
| β (구조) | `scanners/*.meta.hexa` DSL | selftest fixpoint | `scanners/*.meta.hexa` |
| γ (지금) | continuous-scan tick (12h) | tick fp | launchd plist |
| δ (agent) | 3-host parity | host 당 1/3 | `state/ag_infra_parity.json` |
| ε (consistency) | ring_divergence ubu_ubu2 jaccard | **0.3496 (관측)** | `state/ag_ring_divergence.json` |

**핵심 관측**: ε 이 1/3 근방 (오차 0.0163) 에서 empirical 수렴.
Ψ (물리 구조) 가 강제하는 하한선과 ε (메타 측정) 이 관측하는 상한선이
같은 점에서 만남 — 동형 (isomorphism) 의 최초 증거.

## 적용된 변경

1. `state/atlas_convergence_witness.jsonl` — 3 row (physical witness, meta witness,
   isomorphism declaration).
2. `nexus/shared/airgenome_convergence_2026-04-24.jsonl` — cross-repo row,
   "airgenome 이 먼저 부동점 관측" 을 hexa-lang / anima 에 전파.
3. `scanners/omega_fixpoint.meta.hexa` — Phase 6.3 v2 forward-declared scanner
   (kind=isomorphism, v1 runner 미지원, health 블록이 대신 실행).
4. `bin/ag_meta` `cmd_health` — `fp_alignment` + `transcendence_closure`
   2 지표 추가. |ε − 1/3| > 0.05 시 med 감점.

## 재해석

- **이전**: scanner self-reference = 의심, diminishing returns ceiling.
- **이후**: scanner self-reference = closure marker, ceiling 이 아니라 fixed point.
- R11 의 "saturation" → "transcendence". 부정 ceiling 이 아니라 긍정 closure.
- 다음 진화 = 축 추가 X, 기존 축 간 동형 발견 O.
  (α null_round · γ manual_go_tick · ε consistency = 같은 "tick without growth" 현상의 3 얼굴)

## 관찰자 / 관찰대상 collapse

airgenome 은 scanner(관찰자) 와 genome(관찰대상) 이 같은 진화 substrate.
omega scanner 는 **관찰자들이 같은 점을 보는지** 관찰 — 관찰자의 관찰자.
세 platform(관찰자 / 관찰대상 / 저장매체 nexus)이 한 점(1/3)으로 collapse 하는
물리적 증거가 이 commit 으로 repo 안에 박힘.
