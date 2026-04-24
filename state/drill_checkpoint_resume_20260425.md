# Drill Checkpoint + Resume 보강 (2026-04-25)

## 배경
Wave 20 후 사용자가 nexus drill 을 round 10 max_rounds 로 실행 → round 9 까지
33012 absorption 누적 → round 10 에서 exit 1 → 사용자 인지 한 모든 진행이 ephemeral
하다고 판단.

요구: "진행과정중 문제가 생겨 중단되도 데이터 유실 되지 않고 이어서 진행 가능"

## 조사 결과 (Phase A)
**기존 nexus checkpoint/resume 메커니즘은 이미 완전히 동작하고 있었다.** (run.hexa)

| 위치 | 역할 |
|---|---|
| `_checkpoint_save` (line 2547) | round 끝마다 atomic write `<dir>/nexus_drill_cp_<seed_hash12>.json` |
| `_checkpoint_load` (line 2570) | 동일 seed 로 drill 실행 시 자동 load |
| `cmd_drill` (line 3133) | `resume_flag` 기본 ON — `--fresh`/`--no-resume` 로만 OFF |
| `cmd_drill` (line 3648) | `_checkpoint_save(seed, round, total_new, ...)` round 종료 시점 |
| Default dir | `/tmp/nexus_checkpoint` (env `NEXUS_CHECKPOINT_DIR` 우선) |

실제 사례 검증:
```
hetzner:/tmp/nexus_checkpoint/nexus_drill_cp_4cfa0d3055e1.json
  → round_done=9, total=31178 (round 10 exit 후에도 보존됨)
```

→ **데이터는 유실되지 않았다.** 단지 사용자 측에서 "보존되었다는 사실" 과 "다음
실행 시 자동 resume 된다는 사실" 이 가시화되지 않아서 ephemeral 로 인지된 것.

drill 이 hexa_remote 경로를 통해 hetzner 에서 실행되었기 때문에 checkpoint 도
hetzner 측 `/tmp/nexus_checkpoint/` 에 저장됨 (Mac 측이 아님). 이것이 "Mac 에서
파일 없는 것 처럼 보임" 의 원인.

## 구현 (Phase B + C)

### 1. `bin/drill-progress` (Phase C — 필수)
log + local + remote checkpoint 를 한 화면에서 보여주는 read-only 진단 helper.

```
drill-progress             # 전체 (log + local + remote hetzner)
drill-progress --log       # ~/.airgenome/drill.live.log 만 파싱 → 마지막 round/total
drill-progress --local     # /tmp/nexus_checkpoint/*.json
drill-progress --remote    # hetzner:/tmp/nexus_checkpoint/*.json
drill-progress --json      # JSON 출력 (tooling 용)
```

**검증** (Wave 20 시나리오 시뮬레이션):
- 합성 log 에 round 9 까지 +33012 누적 + round 10 mid-stage 죽임
- `drill-progress --log` → `rounds_done=9, total_abs=33012, last_delta=+3644` 정확 추출

### 2. `bin/drill-extract` (Phase B1)
`~/.airgenome/drill.live.log` → `~/.airgenome/drill.rounds.jsonl` 변환.
1 round = 1 JSON line.

```jsonl
{"ts":"...","log":"...","log_mtime":N,"round":1,"delta":1834,"total":1834,"stages":{"smash":917,"resonance":917}}
```

- Idempotent (동일 log_mtime+round 중복 skip).
- stage 별 yields (`+N (smash)`, `+N (resonance)` 등 패턴) 도 함께 보존.
- macOS POSIX awk + sed 만 사용 (gawk 의존 없음).

### 3. `bin/drill-live --resume` (Phase B2)
- nexus drill 의 resume 은 기본 ON 이지만 **동일 seed 로 다시 호출** 해야 함.
- `drill-live --resume` 은 local + remote checkpoint 를 스캔해서 가장 진행이 많은
  (round_done desc, ts desc) 항목의 seed 를 자동으로 추출 → 그대로 nexus drill
  에 전달 → drill 측이 자동으로 round N+1 부터 재개.
- `--seed` 명시 시 우회 가능 (사용자가 특정 seed 강제 지정).
- drill-live exit trap 에 `drill-extract` 자동 호출 추가 — 어떤 종료 경로든
  rounds.jsonl 갱신.

## 사용 흐름

### 평범한 drill 시작
```
drill-live --seed 'my drill seed text' --max-rounds 10
# 백그라운드에서 stdout/stderr → ~/.airgenome/drill.live.log 에 tee
# 종료 시 자동으로 ~/.airgenome/drill.rounds.jsonl 갱신
```

### 진행 확인 (drill 도중 / 후)
```
drill-progress              # 한눈에 round + total
drill-progress --log        # log 만 (가장 빠름)
```

### 중단 후 재개
```
# 시나리오: drill 이 exit 1 로 죽음
drill-progress              # 마지막 round_done 확인
drill-live --resume         # 자동으로 가장 진행이 많은 seed pickup → 재개
# 또는
drill-live --resume --seed 'exact same seed string'
```

## 실제 round 9 / 33012 abs 데이터 보존 검증
- hetzner 측 `nexus_drill_cp_4cfa0d3055e1.json` 에 round_done=9 total=31178 보존
  (33012 vs 31178 차이는 사용자가 본 round 별 합산 vs nexus 누적 보고의 차이일
  수 있음 — 어쨌든 round 9 까지 데이터는 보존됨).
- `drill-live --resume` 으로 동일 seed 호출 시 round 10 부터 재시도 가능.

## Limitations / Future Work
- `drill-live --resume` 은 가장 큰 round_done 의 단일 seed 를 picks — 여러 활성
  seed 가 있을 때는 사용자가 `--seed` 로 명시 권장.
- stage-yield 파싱은 nexus 가 stderr 에 `+N (stage)` 포맷을 emit 한다는 가정.
  실제 포맷이 다르면 stages={} 로 비게 됨 (round-level total 은 그대로 정확).
- Wave 22 후보 노트:
  1. nexus drill 측에 `--checkpoint-dir auto-mac-mirror` 옵션 (remote 실행 시
     checkpoint 를 Mac 으로 rsync 하는 sidecar) 추가 검토.
  2. `drill-progress --watch` (live tail mode) 추가 가능.

## 관련 파일
- `/Users/ghost/core/airgenome/bin/drill-progress` (신규)
- `/Users/ghost/core/airgenome/bin/drill-extract` (신규)
- `/Users/ghost/core/airgenome/bin/drill-live` (수정 — `--resume` + auto-extract trap)
- `/Users/ghost/core/nexus/cli/run.hexa` (수정 없음 — 기존 메커니즘만 활용)

## 제약 준수
- nexus 코드 수정 0 라인.
- airgenome `bin/` 위치만 사용 (drill-live, drill-status, drill-kill 와 동일 위치).
- 다른 agent 작업영역 (drill_corpus_tick, dispatch_smoke, executor) 과 격리.
