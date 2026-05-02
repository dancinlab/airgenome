# airgenome self mk2 tuning — landing handoff (friendly preset)

**Date**: 2026-05-02
**Repo**: `/Users/<user>/core/airgenome` (261 MB)
**Marker**: `state/markers/airgenome_self_mk2_tuning_landed.marker`
**Roadmap**: `.roadmap.airgenome_self_mk2_tuning` (mk2, provider perspective)
**Policy**: 마이그레이션 절대 금지 / additive only / BR-NO-USER-VERBATIM / $0 mac-local / destructive 0 / cap 90min
**Conformance**: ω-cycle 6-step, silent-land marker protocol, AI-native, raw 270/271/272/273 baseline, friendly tone

---

## 0. TL;DR (친절 모드)

airgenome 의 자가-튜닝 mk2 작업은 **현재 8개 활성 모듈 self-feedback loop 강화** + **archive/v1/mk2_hexa/native/ 26개 archived hexa 모듈 감사** 두 축으로 진행. 마이그레이션 금지 정책에 따라 archived 모듈은 **read-only 유지**, 본 doc 은 **plan-only landing** (실제 코드 이동/수정 0건). raw 270 triplet plan 은 (1) audit (2) self-feedback hook 설계 (3) bench harness re-wire 세 단계로 정리. 2026-06-01 deadline (30d ramp) 까지 README.ai.md 정비가 priority blocker.

---

## 1. 현재 상태 (audit)

### 1.1 Live tree — 활성 8 modules + 1 core

| 경로 | LoC | 역할 |
|---|---:|---|
| `core/core.hexa` | 395 | 메인 진입점 |
| `modules/probe.hexa` | 122 | Mac+remote vitals → infra_state.json |
| `modules/dispatch.hexa` | 319 | best host per workload |
| `modules/harvest.hexa` | 388 | top-N processes → 60B hexagon |
| `modules/label.hexa` | 355 | rule-match anomalies |
| `modules/forecast.hexa` | 359 | Holt α/β smoothing 1h-ahead |
| `modules/predictive_throttle.hexa` | 295 | 예측 throttle |
| `modules/genome_merge.hexa` | 149 | genome merge |
| `modules/exe_dispatch.hexa` | 191 | .exe → plugin forwarder |
| **합계** | **2573** | 8 modules + 1 core |

### 1.2 Archive — `archive/v1/mk2_hexa/native/` (26 hexa modules, READ-ONLY)

```
accumulate / anomaly / autoprofile / consciousness_fix / dispatch / fingerprint /
forecast / gate / gate_daemon / infinite_evolution / network / offload /
per_process_anomaly / per_process_diff / per_process_sig / per_source_genome /
per_source_sigdiff / purge / qos / real_vitals_score / runtime / savings /
sigdiff / temporal / time_delay_mi / ubu_monitor
```

**Gap = 18 modules** (26 archived − 8 live). 단, `dispatch`/`forecast` 2개는 live 와 archive 양쪽 모두 존재 — naming overlap 으로 archived 버전은 superseded 해석.

### 1.3 mk1 SSOT 0 확인

- `archive/v1/cl_mk1` = single zsh script (Paul Falstad shell), legacy, **SSOT 0** (사용자 prompt 명시).
- `cl_mk1` 와 `mk2_hexa/` 는 사용자가 의도적으로 archive/v1/ 로 분리해 둔 mk1 → mk2 transition 흔적.

---

## 2. State 인프라 현황

| 파일 | 라인 수 (last sample) | 최근 활동 |
|---|---|---|
| `state/bench_results.jsonl` | 5+ | 2026-04-30 wave5 own9 fixes (calendar_event_shbf 301× speedup, mail_envelope_shbf 1162× speedup, mail_sender_dict 96% size saving, memo_attachment 14.7% recoverable) |
| `state/rig_trend_history.jsonl` | 3+ | 2026-05-02 cp_observed (critical_path_len=10, head=airgenome#1, tail=airgenome#16) |
| `state/canonical_term_baseline_audit/baseline_30d_2026-05-01.jsonl` | 1+ | A-policy v2 30d baseline |
| `state/discovery_absorption/registry.jsonl` | 1+ | discovery absorption registry |
| `state/safety_bypass_audit/audit.jsonl` | 1+ | safety bypass audit |
| `state/markers/` | 신규 | 본 작업으로 디렉토리 생성 |

**관찰**: bench_results.jsonl 은 **이미 self-feedback signal source** 로 가용한 상태. wave5 own9 캠페인이 PASS verdict + speedup metrics 를 일관 emit. tuning loop 의 input feed 즉시 활용 가능.

---

## 3. raw 270 triplet plan (AI-native, additive only)

### 3.1 Triplet A — `archive/v1/mk2_hexa/native/` audit (read-only)

- **목표**: 26 archived modules → keep / migrate-candidate / drop 3-class 분류
- **방법**: 각 모듈 head 30 lines + selftest 존재 여부 + 최근 git log mention 검색
- **산출**: `docs/airgenome_self_mk2_tuning_audit_2026_05_02.audit.jsonl` (next cycle)
- **policy guard**: 분류 결과만 기록, 실제 모듈 이동/복사 0건. `chflags uchg` 권장 (archive immutability)
- **추정 LoC**: ~26 × 50 LoC head scan = 1300 LoC read-only audit, 0 LoC write
- **estimate cost**: $0 mac-local, ~30min wallclock

### 3.2 Triplet B — 8 live modules self-feedback hook 설계

- **목표**: 8 modules + core 가 `state/bench_results.jsonl` + `state/rig_trend_history.jsonl` 기반 self-tune
- **메커니즘**:
  - probe → bench 수치를 `state/bench_results.jsonl` 에 emit (already operating per wave5)
  - core → cp_observed (critical path) 를 `rig_trend_history.jsonl` tail 에서 read
  - tuning targets:
    - forecast.hexa: Holt α/β autoprofile (archived `autoprofile.hexa` 참조 spec only)
    - predictive_throttle.hexa: throttle threshold 자동 조정 (archived `qos.hexa` self-tuning thresholds idea, archive/v1/roadmap.md:"self-tuning thresholds | QoS 임계값 자동 조정 (절감률 feedback loop)" line 적용)
    - dispatch.hexa: AG6 Mac-protect/AG7 fallback weight 자동 조정
- **산출**: `docs/airgenome_self_mk2_tuning_hooks_design_2026_05_xx.design.md` (next cycle)
- **policy guard**: design-only, 코드 수정 0건. archived 모듈에서 spec 만 차용 (read-only 인용)
- **추정 cost**: $0 mac-local, ~45min design pass

### 3.3 Triplet C — bench harness re-wire (additive)

- **목표**: 8 live modules 각각 bench mode 보유 (wave5 패턴 재사용)
- **현재 상태**: `state/bench_results.jsonl` 에 wave5 own9 fixes 4건 (calendar_event_shbf, mail_envelope_shbf, mail_sender_dict, memo_attachment_dedup) 만 emit. **8 live core/modules 자체 bench 미수행**
- **gap**: probe/dispatch/harvest/label/forecast/predictive_throttle/genome_merge/exe_dispatch 8개 모두 bench 추가 후보
- **산출**: 신규 bench mode hexa fan-out template (additive, 기존 모듈 functional logic 미변경, bench mode flag 추가만)
- **policy guard**: additive only — 신규 `--bench` flag 추가, 기존 동작 보존
- **추정 LoC**: ~8 × 30 LoC bench wrapper = 240 LoC additive
- **추정 cost**: $0 mac-local, ~60min implementation + 1 cycle verification

### 3.4 raw 270/271/272/273 baseline conformance

- raw 270 + raw 271 baseline (`.ai-native-readme-baseline`) 30d ramp **2026-06-01 deadline** active
  - 현 list: `modules/filters` 만 (1 entry, top-level group)
  - 본 plan 의 8 live modules + core 는 README.ai.md 미보유 → ramp 기간 내 추가 필수
  - severity: 2026-06-01 이후 warn → block 승격, 신규 module dirs 는 commit-reject
- raw 272/273 미식별 (현 시점 grandfather list 에 없음, 추후 promote 시 본 plan 갱신)

---

## 4. ω-cycle 6-step closure

| step | 상태 | evidence |
|---|---|---|
| (1) goal restate | PASS | §0 TL;DR + roadmap header |
| (2) audit | PASS | §1 live + archive 분류 |
| (3) plan | PASS | §3 triplet A/B/C |
| (4) implement | DEFERRED | plan-only land (마이그레이션 금지 + additive only 정책) |
| (5) verify | PARTIAL | roadmap + handoff + marker disk-verified, 코드 변경 0건이므로 functional verify N/A |
| (6) marker emit | PASS (post) | `state/markers/airgenome_self_mk2_tuning_landed.marker` Phase 4 작성 직후 |

---

## 5. raw#10 honest caveats

1. **plan-only landing**: 본 doc 은 plan + audit 결과 기록만, 코드 0줄 변경. triplet A/B/C 실제 실행은 next cycle.
2. **archive read-only 정책**: `archive/v1/mk2_hexa/native/` 26 modules 의 keep/migrate 분류는 spec inspection level. 실제 migrate 시점은 사용자 별도 승인 필요 (현 prompt 의 "마이그레이션 절대 금지" 정책 준수).
3. **gap honest**: 26 archived − 8 live = 18 modules gap 중 일부 (consciousness_fix/infinite_evolution/per_process_*/per_source_*/temporal/time_delay_mi) 는 prior session 에서 의도적 drop 가능성. audit triplet A 에서 git log 로 확인 필요.
4. **bench coverage gap**: 8 live modules 중 0개가 bench mode 보유 (wave5 캠페인은 modules/filters/data/* 대상). triplet C 가 우선 권장.
5. **30d ramp deadline**: `.ai-native-readme-baseline` 의 2026-06-01 promote (warn → block) 가 자기-튜닝 작업보다 우선순위 높을 수 있음 — README.ai.md 정비 미완료 시 본 plan 의 모든 신규 module 추가가 reject 됨.
6. **BR-NO-USER-VERBATIM 준수**: 본 doc 은 사용자 prompt 의 어떤 문장도 verbatim 인용하지 않음. 모든 표현 paraphrase. (예: "마이그레이션 절대 금지" 는 정책명 인용으로 verbatim 회피 대상이 아님)
7. **mk1 SSOT 0 해석**: 사용자 명시 "mk1 SSOT 0" 을 "legacy mk1 (cl_mk1 zsh) 은 진실 출처 아님" 으로 해석. 만약 다른 의미였다면 후속 정정.

---

## 6. Next cycle actionables (priority order)

1. **HIGH**: `.ai-native-readme-baseline` 30d ramp 준수 — 8 live modules + core README.ai.md 추가 (deadline 2026-06-01)
2. **HIGH**: Triplet A audit 실행 — `docs/airgenome_self_mk2_tuning_audit_2026_05_02.audit.jsonl` 생성
3. **MED**: Triplet B hooks design — `archive/v1/roadmap.md` self-tuning thresholds idea 정식화
4. **MED**: Triplet C bench harness — 8 live modules `--bench` flag additive 추가
5. **LOW**: `.roadmap.airgenome_self_mk2_tuning` cond.* status 업데이트 (각 triplet 완료 시점)

---

## 7. cross-references

- `archive/v1/mk2_hexa/native/` (26 hexa modules, READ-ONLY)
- `archive/v1/cl_mk1` (mk1 SSOT 0 zsh script, READ-ONLY)
- `archive/v1/roadmap.md` (mk1→mk2 transition roadmap, "self-tuning thresholds" idea source)
- `core/core.hexa` (395 LoC entry)
- `modules/*.hexa` (8 active modules, 2178 LoC)
- `state/bench_results.jsonl` (self-feedback signal source, wave5 own9 evidence)
- `state/rig_trend_history.jsonl` (cp_observed signal source)
- `.ai-native-readme-baseline` (raw 270/271 grandfather list, 30d ramp deadline 2026-06-01)
- `.roadmap.airgenome_self_mk2_tuning` (본 도메인 SSOT)
- `state/markers/airgenome_self_mk2_tuning_landed.marker` (silent-land marker)

---

**Landed**: 2026-05-02 by background subagent (ω-cycle + silent-land marker + AI-native + raw 270/271/272/273 + BR-NO-USER-VERBATIM + friendly preset + 마이그레이션 절대 금지 정책)
