# AG-Q15 — Managed Agents 분산 mesh (3단계)

**Status**: 설계 + 프로토타입 skeleton 완성. 실측은 ANTHROPIC_API_KEY 조달 후 보류.
**Date**: 2026-04-19
**Depends on**: AG6 (Mac Compute ZERO), AG7 (load balancer), M11e (cross-host claude), 2단계 local queue + remote worker (진행중 · 별도 agent)

---

## 0. TL;DR

1. **Managed Agents API = Beta (GA 이전, `managed-agents-2026-04-01` beta 헤더).** 2026-04-01 release. SDK(Py/TS/Go/Ruby/Java/PHP + cURL) 전부 지원. C#만 미지원.
2. **계정 블로커**: airgenome 의 12 Max 서브스크립션은 **OAuth 토큰**(`~/.claude-claudeN/.credentials.json` + keychain)으로만 사용 가능. Managed Agents 는 `x-api-key`(Console API key) 필요 → **Max 로는 절대 못 씀**. pay-as-you-go Console 계정 + API key 별도 조달해야 함.
3. **설계 원칙**: 2단계 `airgenome dispatch -p "..."` 인터페이스 100% 유지 + `--managed` flag 만 추가. backend 는 routing layer 에서 분기 — tool-light task 는 Managed Agents, tool-heavy(cx/cl/hexa) 는 로컬 worker.
4. **비용 기대**: 전형 airgenome 작업 ~6K input (system+context cached) + ~2K output, Opus 4.7 기준 대략 **$0.035/task** (cache hit 기준). Max subscription (이미 지출) 대비 추가비용 — break-even 은 Max 한도 소진 시에만.
5. **프로토타입 skeleton**: `bin/airgenome-managed` (node, 확장자 없음, shebang 로 node 실행). `airgenome dispatch --managed -p "..."` 래퍼는 2단계 agent 에게 맡김 (flag forwarding).

---

## 1. Managed Agents API 현황 (claude-api skill 기반)

| 항목 | 값 | 출처 |
|---|---|---|
| Release | Beta — 2026-04-01 | SDK README, beta header `managed-agents-2026-04-01` |
| Endpoint | `POST /v1/agents`, `POST /v1/sessions`, `POST /v1/sessions/{id}/events`, `GET /v1/sessions/{id}/events/stream` | `shared/managed-agents-api-reference.md` |
| SDK 지원 | Python, TS, Go, Ruby, Java, PHP, cURL | `SKILL.md` Language-Specific Feature Support |
| C# 지원 | ❌ — raw HTTP only | ditto |
| Anthropic CLI (`ant`) | 지원. YAML 로 agent 정의 가능 | `shared/live-sources.md` |
| Auth | `x-api-key: <Console API key>` + `anthropic-version: 2023-06-01` + `anthropic-beta: managed-agents-2026-04-01` | curl README |
| Bedrock/Vertex/Foundry | ❌ 불가 — 1P only | `SKILL.md` |
| Rate limit (관리 콜) | create: 60 RPM/org, 기타: 600 RPM/org. Env 동시: 5 | `managed-agents-api-reference.md` Rate Limits |
| Rate limit (inference) | 계정 ITPM/OTPM 일반 한도 | ditto |
| Container (per-session) | 1 CPU, 5 GiB RAM, 5 GiB disk, 30일 지속 가능 (재사용 가능) | `shared/tool-use-concepts.md` |
| Tool set | `agent_toolset_20260401` (bash / read / write / edit / glob / grep / web_fetch / web_search) + MCP + custom | `shared/managed-agents-tools.md` |
| File mount | ≤500MB/file, ≤999 resources/session. `/mnt/session/outputs/` 자동 캡쳐 | `shared/managed-agents-environments.md` |
| Session 영속 | container 30일, `files.list(scope_id=session.id)` 로 산출물 수집 | ditto |
| Versioning | agent 는 persistent + versioned. `{type:"agent", id, version}` 로 핀 가능 | `managed-agents-core.md` |

### 1-1. 모델 가격 (caching · adaptive thinking 가정)

| Model | Input $/1M | Output $/1M | Cache read $/1M | Cache write (5m) $/1M |
|---|---|---|---|---|
| claude-opus-4-7 | 5.00 | 25.00 | 0.50 | 6.25 |
| claude-sonnet-4-6 | 3.00 | 15.00 | 0.30 | 3.75 |
| claude-haiku-4-5 | 1.00 | 5.00 | 0.10 | 1.25 |

(cache 쓰기 1.25× / 읽기 0.1× · `shared/prompt-caching.md`)

---

## 2. 계정 접근 가능성

| 계정 유형 | Managed Agents 사용? | 이유 |
|---|---|---|
| 12 Max subscription (claude1..12) | ❌ 불가 | Max 는 OAuth 기반. keychain `Claude Code-credentials` + `~/.claude-claudeN/.credentials.json`. Managed Agents API 는 **Console API key (`sk-ant-...`)만 수락**. Max OAuth 토큰으로 `/v1/agents` 호출 시 401. |
| Console pay-as-you-go | ✅ (API key 생성 시) | 별도 Console 계정 필요. Tier 는 RPM/TPM 에만 영향. |
| Vertex/Bedrock | ❌ | 3P 프로바이더 지원 불가 |

**현재 airgenome 상태**:

```
$ANTHROPIC_API_KEY        = unset
~/.anthropic/api_key      = nonexistent
~/Dev/secret/anthropic*   = nonexistent
keychain anthropic-api-key = not found
keychain ANTHROPIC_API_KEY = not found
```

→ **3단계 실측 진행 불가**. 설계 + prototype skeleton 만 가능.

**요청**: Console 로그인 → [API Keys](https://console.anthropic.com/settings/keys) → 새 키 생성 → `~/Dev/secret/anthropic_api_key` 에 저장 (기존 `x-api.md` 와 같은 폴더, gitignore 확인) 또는 `security add-generic-password -s anthropic-api-key -a $USER -w sk-ant-xxx`. 그 다음 본 Q15 프로토타입 `bin/airgenome-managed --probe` 실행 → 실측 보고.

---

## 3. Architecture

### 3-1. 현재 (M11e + 진행중 2단계)

```
cl → claudx (pool.js best-pick) → cx (priority-first ubu→ubu2→mac) → ssh → claude (container)
                                                                        ↑
                                                                  Max OAuth
```

2단계 (진행중, 별도 agent): `airgenome dispatch -p "prompt" --host=auto` = local queue enqueue → remote worker(ubu/ubu2/htz) dequeue → `claude -p` 실행 → 결과 회수.

### 3-2. 3단계 (Managed Agents 추가)

```
airgenome dispatch -p "..."                          # 기본: 2단계 local worker (claude CLI + Max OAuth)
airgenome dispatch --managed -p "..."                # Q15 backend: Managed Agents API
airgenome dispatch --auto -p "..."                   # classifier 가 자동 선택 (cost/tool 요구 기반)

┌── flag routing (bin/airgenome-managed 또는 dispatch hexa 핸들러) ──┐
│                                                                    │
│  flag=--managed  → bin/airgenome-managed (node+Anthropic SDK)      │
│       ├─ agents.create 는 setup 1회 (agent_id 영속화)              │
│       ├─ sessions.create (environment reused)                      │
│       ├─ events.send + stream                                      │
│       └─ stdout 로 응답 + metadata jsonl 적재                      │
│                                                                    │
│  flag=default    → 2단계 queue → ssh remote claude (M11e)          │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### 3-3. State files

```
~/.airgenome/managed/
├── agent.json            # {agent_id, version, created_at, config_hash}
├── environment.json      # {env_id, networking, created_at}
├── sessions.jsonl        # append-only: {ts, session_id, prompt, tokens, $cost, duration}
└── rotations.jsonl       # 429 / overload 이벤트
```

`agent.json` 이 setup SSOT. 존재하면 재활용 — `agents.create()` 는 hot path 에서 절대 안 부름 (skill §Common Pitfalls "Agent ONCE, not every run").

---

## 4. 2단계 CLI 인터페이스 호환

2단계 (진행중 agent) 가 정할 CLI 는 예상:

```bash
airgenome dispatch -p "prompt"                    # blocking
airgenome dispatch -p "prompt" --advisory         # returns job_id
airgenome dispatch --status=job_abc
airgenome dispatch --resume=job_abc
airgenome worker --host=ubu                       # remote worker loop
```

Q15 가 추가하는 flag:

```bash
airgenome dispatch --managed -p "prompt"          # force Managed Agents backend
airgenome dispatch --auto -p "prompt"             # heuristic routing
airgenome managed-probe                           # API 왕복 테스트
airgenome managed-agent --create                  # setup (run once)
airgenome managed-agent --show                    # agent/env ID 출력
```

**계약**: 2단계 가 `dispatch` 엔트리를 구현할 때 본 Q15 flag 를 env 스위치로 수신:

```bash
# bin/airgenome-dispatch-shim (개념) — 2단계 agent 가 작성:
case "$1" in
    --managed) exec "$AIRGENOME/bin/airgenome-managed" "${@:2}" ;;
    --auto)    exec "$AIRGENOME/bin/airgenome-dispatch-router" "${@:2}" ;;
    *)         # 기존 local queue 경로
esac
```

2단계 dispatch hexa 가 먼저 `--managed` flag 를 foreign arg 로 pass-through 하면 Q15 wrapper 가 가로챔. 2단계 agent 에게 요구사항: `--managed`/`--auto` flag 를 추가 허용하고 `bin/airgenome-managed`로 forward.

---

## 5. Migration path (점진 적용)

1. **Phase A (현재)**: Max OAuth + cx/claudx/interceptor. tool-heavy (hexa 실행, 파일 편집) 커버. Managed Agents 없음.
2. **Phase B (Q15 프로토타입 도착)**: `airgenome managed-probe` 동작. API key 1개, 1 agent, 1 env. `bin/airgenome-managed -p "..."` 수동 호출.
3. **Phase C (2단계 통합)**: 2단계 `airgenome dispatch` 에 `--managed` flag hookup. 모든 호출에 옵트인.
4. **Phase D (Hybrid 자동 라우팅)**: classifier 가 task 특성 (kw, 길이, tool 필요 여부) 으로 자동 분기:
   - tool-light Q&A / 1-turn 분류 / 요약 → Managed Agents (stateless, 빠름)
   - tool-heavy 개발 작업 (airgenome 파일 편집, hexa build, cx routing) → 로컬 worker (Max 소진 용)
5. **Phase E (full hybrid with metrics)**: `forge/managed_genome.jsonl` 로 실제 latency/cost/tokens 축적 → routing decision 자동 튜닝.

**Kill switch**: `~/.airgenome/managed.off` 파일 존재 시 `--managed` flag 무효화 → 자동 로컬 폴백. AG6 규칙과 동일 패턴.

---

## 6. 비용 모델

### 6-1. 단일 호출 예상 (Opus 4.7, cache hit)

| 구성요소 | tokens | unit $/1M | sub-cost |
|---|---|---|---|
| system prompt (cached, docker_session_prompt 40줄 + 부가 ≈ 2000 tok) | 2000 cache_read | $0.50 | $0.001 |
| user prompt (평균 200 tok) | 200 input | $5.00 | $0.001 |
| output (평균 800 tok) | 800 output | $25.00 | $0.020 |
| adaptive thinking (비가시 overhead ~500 tok output) | 500 output | $25.00 | $0.0125 |
| **합계 (per task)** | | | **~$0.035** |

Cache write 1회 오버헤드 (Phase B 시작 시): 2000 × $6.25/1M = $0.0125 (일회성).

### 6-2. 월간 기대

2단계 dispatch 빈도 가정: 100 task/day × 30 = 3000/mo.
- Managed Agents only: 3000 × $0.035 = **$105/mo**
- Hybrid (30% managed, 70% Max): 900 × $0.035 = **$31.5/mo** + Max 고정 $ (이미 지출)
- Max only (현재): $0 추가 but 한도 소진 때 세션 중단 + 수동 rotation 부담

### 6-3. Break-even

- Max 1인 한도 (주간) 소진 빈도가 높으면 Hybrid 가 승리 (Mac 세션 중단 방지).
- 소진 거의 없으면 Managed 추가는 pure overhead — Phase D classifier 가 중요.

---

## 7. 보안

### 7-1. API key 관리

- **절대 commit 금지**: `.gitignore` 에 `shared/config/anthropic_key*` 추가 필요. `~/Dev/secret/` 는 이미 secret 폴더로 분리되어 있음 (`x-api.md` 등).
- **Keychain 우선**: `security add-generic-password -s anthropic-api-key -a $USER -w <key>`. `bin/airgenome-managed` 가 `security find-generic-password -s anthropic-api-key -w` 로 로드.
- **Env fallback**: `$ANTHROPIC_API_KEY` 존재 시 우선. 개발 편의.
- **File fallback**: `~/Dev/secret/anthropic_api_key` (600 perms, chmod 확인).

### 7-2. Task 격리

- Session per task — container 는 isolated (5 GiB disk, no network egress without MCP declared).
- Session `metadata.task_id` 에 airgenome request id 주입 → 추후 audit.
- `permission_policy: always_ask` 는 사용 X — blocking 이므로 throughput 저하. 기본 `always_allow`.
- 민감 파일 업로드는 필요할 때만. `resources` 에 `~/Dev/secret/*` 절대 마운트 금지.

### 7-3. 프롬프트 인젝션

- 컨테이너 network policy = `unrestricted` 로 가면 data exfil 경로 발생 가능. 일반 작업은 `package_managers_and_custom` + 필요 host 화이트리스트로 제한 권장.
- 최소시작: `unrestricted` 로 시작 → airgenome workload 확정 후 lockdown.

---

## 8. 프로토타입 (bin/airgenome-managed)

- **경로**: `/Users/ghost/Dev/airgenome/bin/airgenome-managed`
- **확장자**: 없음 (요구사항)
- **엔진**: node (shebang `#!/usr/bin/env node`) — 이미 claudx interceptor 가 node 임. airgenome 에서 node 는 이미 used. bash-free, hexa-dispatch-free, curl 은 fallback.
- **SDK**: `@anthropic-ai/sdk` — node 설치 필요. 우선 **raw HTTPS** (node built-in `https`) 로 외부 dep 제로. SDK 는 성능/디버그 필요해질 때 도입.
- **기능**:
  - `--probe` — API key + /v1/models 왕복 테스트 + 지연 측정
  - `--setup` — agent.json 없으면 agents.create + environments.create 하고 ~/.airgenome/managed/ 에 저장
  - `--show` — 현재 agent/env ID 표시
  - `-p <prompt>` — 세션 생성 → user.message → stream → 마지막 assistant text + metadata
  - `--stream` — 토큰 실시간 stdout
  - `--cache` — system prompt 로 `docker_session_prompt.txt` 사용 (캐시 hit 유도)

실제 HTTP 호출은 API key 없으므로 test 안 됨. 아래 skeleton 은 key 확보 후 즉시 실행 가능.

(파일: `bin/airgenome-managed` 참고)

---

## 9. 프롬프트 캐싱 전략

system prompt = `shared/config/docker_session_prompt.txt` (35 줄, ~1K tok) — 호출마다 동일.

1. **agent 레벨에서 system 지정** (Managed Agents API 의 agent.system 필드) — Managed Agents 는 agent 생성 시 한 번만 system 을 저장. 사용자 per-session 추가 가능하지만 cache 목적으로는 agent-level SSOT 가 최적.
2. **user.message 내용만 per-call 바뀜** — cache prefix 는 system + agent tool registry. cache hit 90%+ 기대.
3. Managed Agents 는 built-in prompt caching 이 활성 — 클라이언트가 cache_control breakpoint 관리할 필요 없음 (`managed-agents-core.md`: "Prompt caching — historical repeated tokens are cached, reducing processing time and cost").
4. cache read tokens 는 `span.model_request_end` 이벤트의 `model_usage.cache_read_input_tokens` 로 확인.

---

## 10. 검증 절차 (API key 확보 후)

```bash
# 0. API key 저장
security add-generic-password -s anthropic-api-key -a $USER -w sk-ant-xxxxx

# 1. 왕복 probe
bin/airgenome-managed --probe
# expected: {"ok":true, "model_count":N, "latency_ms":200}

# 2. setup (agent + env 영속화)
bin/airgenome-managed --setup
# expected: {"agent_id":"agent_...", "env_id":"env_...", "reused":false}

# 3. 테스트 호출
bin/airgenome-managed -p "one word hi"
# expected stdout: "hi" (plus metadata jsonl)

# 4. 성능 측정
time bin/airgenome-managed -p "Summarize airgenome in one sentence"
# expected: <5s total, tokens report under 1K
```

`--probe` 실패 시 원인 로그:
- `401 authentication_error` → key 자체 invalid
- `403 permission_error` → key 에 Managed Agents beta 권한 없음 (Console 에서 beta 활성화 확인)
- `429 rate_limit_error` → Tier 업그레이드 필요
- `timeout` → 네트워크/방화벽

---

## 11. 제한사항 + Hybrid routing 가이드

| Task 유형 | Backend 권장 | 이유 |
|---|---|---|
| 1-turn Q&A, 분류, 요약 | **Managed Agents** | stateless, 빠름, Max 아낌 |
| 코드 리뷰 (repo 마운트) | **Managed Agents** (`github_repository` resource) | 컨테이너 클론 + bash/read/grep 네이티브 |
| airgenome 파일 편집 (cx/cl/hexa) | **로컬 worker (M11e)** | Managed container 에 airgenome repo/tools 없음 — 매번 mount 하면 overhead 큼 |
| forge genome append, systemd 조작 | **로컬 worker** | macOS/Linux 시스템 호출 필수 |
| 긴 research / web browsing | **Managed Agents** (web_search + web_fetch) | 서버 툴 무료 |
| 이미지 분석, PDF 요약 | **Managed Agents** (files API) | 파일 업로드 재사용 캐시 |
| 실시간 TUI session (cl) | **로컬 Max** | 대화형 + keychain 경량 |

규칙: airgenome repo/서비스를 만지는 작업은 로컬, 외부/지식 작업은 Managed.

---

## 12. TODO (3단계 골화까지)

- [ ] **ANTHROPIC_API_KEY 조달** (user task)
- [ ] `bin/airgenome-managed --probe` 실행 + 결과 보고
- [ ] `bin/airgenome-managed --setup` 1회 실행 + agent.json 영속화
- [ ] 2단계 agent 가 `dispatch` 에 `--managed` flag 수용하도록 수정 요청
- [ ] `bin/airgenome-managed --stream` 구현 완성 (현재는 blocking 만)
- [ ] `managed_genome.jsonl` 로 비용/latency accumulation
- [ ] Phase D classifier: 토큰 추정 + tool keyword 로 자동 라우팅
- [ ] MCP 서버 정의 — airgenome forge/hosts 를 MCP tool 로 expose 하면 Managed Agents 가 airgenome 내부 상태 조회 가능 (advanced)
- [ ] `--docker` session prompt 로 같은 context 캐시 공유 가능성 검증 (Max 쪽 docker 세션과 system 통일)
- [ ] C# 미지원 이슈는 해당 없음 (airgenome = hexa + node + bash)
- [ ] Error handling: 401 → 즉시 abort, 429 → exponential backoff (SDK 기본 2회), 529 → 폴백 로컬 worker
- [ ] gitignore 에 `shared/config/anthropic_key*`, `~/.airgenome/managed/` 추가

---

## 13. 파일 인덱스

| 역할 | 경로 |
|---|---|
| 설계 (본 문서) | `docs/AG-Q15_managed_agents_mesh.md` |
| 프로토타입 entry | `bin/airgenome-managed` (확장자 없음, node shebang) |
| Agent/env 영속 | `~/.airgenome/managed/agent.json`, `environment.json` |
| 로그 | `~/.airgenome/managed/sessions.jsonl`, `rotations.jsonl` |
| System prompt (재사용) | `shared/config/docker_session_prompt.txt` |
| API key 저장 | keychain `anthropic-api-key` (preferred) or env `$ANTHROPIC_API_KEY` or `~/Dev/secret/anthropic_api_key` |

---

## 14. 참고

- Anthropic claude-api skill (`/private/tmp/claude-501/bundled-skills/2.1.112/.../claude-api/`):
  - `shared/managed-agents-overview.md`
  - `shared/managed-agents-core.md`
  - `shared/managed-agents-api-reference.md`
  - `curl/managed-agents.md`
  - `typescript/managed-agents/README.md`
- airgenome 기존 구조:
  - `shared/config/hosts.json` (호스트 SSOT)
  - `bin/claudx` / `bin/cx` (Max 분산)
  - `shared/claudx/pool.js` (best-pick)
  - `modules/dispatch.hexa` (host selector, AG7)
- Memory: `project_m11e_cross_host.md`, `project_cx_priority_first.md`, `feedback_mac_compute_ban.md` (AG6)
