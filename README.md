# airgenome

OS 게놈 스캐너 — Mac/원격 vitals 를 6축 hexagon (60바이트) 게놈으로 투사, 패턴 누적, anomaly 검출.

**Status**: rebuild v2 — M0~M6 6개 마일스톤 완료 (2026-04-14). SSOT: [`.roadmap`](.roadmap).

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

- Live 상태: `grep -E '^roadmap [0-9]+ (planned|active|done|blocked|deferred)' .roadmap`
- 트랙별 필터: `awk '/^roadmap /{r=$0} /^  track/{print r" ["$2"]"}' .roadmap`

### Invariants

1. `core/core.hexa` 는 외부 hexa 파일 import 안 한다 (self-contained)
2. 신규 module 은 `use "../core/core"` 만 허용 — module 끼리 직접 import 금지
3. L0 자격 = 파일 존재 + hexa parse 통과 + self-test 통과 (3중)
4. `archive/v1/` 는 read-only — 부활은 PR + roadmap 등록 + L0 갱신

> **Utility 면제**: `track=util` 모듈/도구 (보조 런처·tooling 등) 은 roadmap 등록 면제 — invariant 1-4 만 만족하면 됨. MAIN/cell/lora 정합성 요구 안 함.

---

## raw 258 amendment v2 A-policy (2026-05-01) — kick canonical single-entry

`kick` is the sole canonical CLI surface (`nexus kick <topic>`) for the kick cluster.
Six terms (`drill / smash / blowup / free / meta-closure / absolute`) are absorbed into
`kick` as internal saturation phases and are not exposed as external `--phase` flags.

- Canonical : `nexus kick <topic>`
- Help      : `nexus kick --help`
- Banned    : direct `.hexa` invocation, deprecated direct subcommands (`nexus drill --seed`, etc.)
- Mapping   : `airgenome/docs/raw_canonical_tool_term_canonical_mapping_2026-05-01.jsonl` (schema v2)
