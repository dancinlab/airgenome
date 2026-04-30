# own 10 — process gate site-axis (S1-S6) — DRAFT

**일자**: 2026-04-30
**status**: DRAFT — main agent 가 .own 에 append (본 파일 수정 0)
**source**: `docs/process_gate_bench_2026-04-30.md` §3 (wave 2, 7 process filter production-test, agent a94c4efd 산출)
**대상**: `modules/filters/process/{calendar,finder,mail,memo,safari,telegram}.hexa` 의 hot-path 6 site
**precedent**: own 5 (.own L126-155 harvest stage) / own 6 (forecast stage) / own 7 (label stage) / own 8 (predictive_throttle stage)

---

## 1. own 10 본문 draft (own 5 동일 형식)

```
own 10 new "airgenome-local: gate/filter ROI 직접 적용 사이트 명시 (process gate 6 filter hot-path 6 site, S1~S6)"
  slug airgenome-gate-filter-direct-site-application-process
  base raw 91 honest-C3-measure-dont-guess + raw 95 triad-mandate + own 5 + own 6 + own 7 + own 8 (인접 — own 10 = process gate stage site-axis, 4번째 stage)
  since 2026-04-30 (own 9 BENCHMARK-COMPLETE 직후, process gate 7 filter wave 2 measurement 완료)
  scope modules/filters/process/{calendar,finder,mail,memo,safari,telegram}.hexa M-process hot-path 6개 site — bg analysis: ps awk pipe + lsappinfo frontmost + claude per-instance 3-fork chain + session_now.json substring chain + helper pattern split. compute.hexa (L0/AG6 frozen) + claude.hexa (session_now.json 외부 의존) 면제. 단 site-S4/S5 는 claude.hexa 가 dependency declaration 갖춰지면 재포함.
  rule 다음 6 site 는 own 5 와 동일 5-tuple 측정 절차로 직접 적용 대상으로 명시한다:
    site-S1: 모든 7 filter STATE_LOG append (`exec("echo '...' >> $STATE_LOG")` per cycle, single-line) — exception (이미 cycle 당 1회, marginal). own 5 site-3 / own 6 site-8 batch 패턴 가치 < 측정 비용. ROI 매핑: #43 (이미 충족).
    site-S2: 모든 7 filter ps awk pipe (`ps -axo ... | awk '...' | grep -E '...'` single fork chain) — hexa native ps reader 도입 (ps 1회 read + hexa-side line scan + token slice). own 6 site-6 (jq → hexa-split, 1649×) 의 process 변종. 7 filter 공통 → 가장 큰 누적 win 후보. ROI 매핑: #5 slice view + #1 string slice view + #64 memcmp (helper 매칭).
    site-S3: calendar/mail/memo/safari/telegram 5 filter 의 lsappinfo frontmost (`lsappinfo info -only name "$(lsappinfo front)" | awk ...` 조건부 fork) — airgenome native frontmost cache (NSWorkspace.frontmostApplication via tap process IPC, env-cache 일부 구현). 5 filter 중복 fork 제거. ROI 매핑: #43 N→1 (cache hit) + tap IPC.
    site-S4: claude.hexa per-instance ls + stat + date 3-fork chain (`ls -t '$dir'/*.jsonl | head -1` + `stat -f %m` + `date +%s` 매 instance N회) — hexa native readdir + mtime → 0 fork. A13 (`pfs_readdir_sorted` / `pfs_mtime` / `pfs_now_sec`) builtin upstream 후 본 site 로 land. claude.hexa session_now.json dependency 해소 후 적용 (own 9 exception 풀린 후). ROI 매핑: #54 batch + A13 builtin.
    site-S5: claude.hexa session_now.json substring chain (`e.split("\"pid\":")[1].split(",")[0].trim()` 9 field × N instance) — A14 (`json_field_str` / `json_field_int` / `json_field_float`) builtin upstream 후 single-pass scan 1회 / field. own 5 site-2 (vit_at, single-key 614×) 의 multi-key 일반화. ROI 매핑: #1 string slice view + A14 builtin.
    site-S6: safari/telegram 2 filter 의 helper pattern split per ps line (`HELPERS.split("|")` + `comm.contains(hp)` × N processes × M patterns, O(NM)) — Aho-Corasick precompiled multi-pattern matcher (own 6/7 wave 1 F58 trie 와 같은 구조). N>10 procs 구간만 의미. ROI 매핑: #64 memcmp / Aho-Corasick.
  enforcement own 5 enforcement 와 동일 — site-N + ROI# + hexa baseline ns + post-change ns + lossless differential test 5-tuple 명시 mandatory. process gate filter 의 production output (state_*.jsonl entry + recs JSONL line) byte-identical 검증으로 충족. site-S2 는 7 filter 공통이라 단일 PR 로 묶지 말고 filter 단위 split (calendar / finder / mail / memo / safari / telegram 6 PR).
  exception modules/filters/process/{compute,claude}.hexa 변경 면제 — compute = L0/AG6 frozen (own 9 exception 등록), claude = session_now.json 외부 의존 (own 9 2B 등록). claude 의 site-S4/S5 는 dependency declaration 후 재포함 가능. modules/filters/data/* 및 modules/filters/transport/* 변경 면제 (별도 stage own).
  bans modules/filters/process/* 신규 코드에서 ps + awk + grep 3-fork chain 추가 — site-S2 native ps reader mandate
  bans modules/filters/process/{calendar,mail,memo,safari,telegram}.hexa 신규 lsappinfo per-cycle fork 추가 (env-cache 미경유) — site-S3 cache mandate
  bans modules/filters/process/claude.hexa 신규 ls/stat/date 3-fork chain 추가 — site-S4 A13 builtin 도래 후 mandate
  bans modules/filters/process/claude.hexa 신규 session_now.json substring chain (9+ field 반복) — site-S5 A14 builtin 도래 후 mandate
  bans modules/filters/process/{safari,telegram}.hexa 신규 O(NM) helper match 추가 (N>5 인 경우) — site-S6 Aho-Corasick mandate
  bans modules/filters/process/* STATE_LOG 의 cycle 당 다중 append — site-S1 exception 정신 (이미 single-line 보장)
  bans docs/gate_filter_bench_results.md 의 Bun 측정값 직접 인용 — own 5/6/7/8 동일 ban
  why bg analysis (docs/process_gate_bench_2026-04-30.md §3 wave 2) 결과 process gate 6 filter 의 fork 의존도: ps awk pipe ~5-10× wall (1.5s→0.2-0.3s 추정, 7 filter 공통이라 누적 가장 큰 절대 win), claude per-instance 3-fork × N instance, helper pattern split O(NM). 단 site-S2 의 절대 win 은 production cycle 비율 의존 — wave 2 측정에서 7 filter wall 1.47-1.66s 였으므로 site-S2 적용 후 0.2-0.3s 도달 시 cycle 당 ~1.3s × 7 filter 절감. raw 91 honest C3 — site 명시 후 측정. own 5 (614× single-field) / own 6 (1649× / 50×) / own 7 (3269× / 141×) / own 8 (88×) 가 검증한 패턴 (anchor + slice / batch append / append_file builtin) 의 process stage 이식. own 4 placement-axis (process-pre-vs-post) 와 동시 만족. own 5/6/7/8/10 = capture/forecast/label/predictive/process 5-stage site-axis 완성.
  proof docs/process_gate_bench_2026-04-30.md §3 wave 2 (7 filter exit=0 + ps_raw 결과 + recs + STATE_LOG entry, agent a94c4efd 산출)
  proof docs/process_gate_bench_2026-04-30.md §6 후속 wave 권장 (own 10 site-1/2/3 명시)
  proof docs/hexa_lang_upstream_candidates.md A13 (pfs_readdir/mtime/now_sec) + A14 (json_field_*) — site-S4/S5 unblock
  proof own 6 site-6 (jq → hexa-split 1649×) + own 7 site-9 (jq → hexa-split 3269×) — site-S2/S5 동일 패턴 검증된 win
  severity warn
  enforce-layer advisory
  enforce-layer-rationale "advisory tier — own 5/6/7/8 패턴 재사용. raw 95 triad satisfied via {advisory + 6 filter 별 self_test 또는 production --mode=run-once exit=0 + recs JSONL byte-identical diff_test + future PR-template lint}"
  note own 5 = harvest, own 6 = forecast, own 7 = label, own 8 = predictive_throttle, own 10 = process gate. capture/forecast/label/predictive/process 5-stage site-axis 완성. own 4 placement-axis (각 stage pre-vs-post) 와 직교 — gate-cycle dispatch dimension (role × placement × stage × site × runtime) 5축 분리 유지.
  note site-S2 의 7 filter 공통 win 은 own 5 site-2 (614× single field) 의 7× 분산 적용 — 단일 site 누적 win 절대값으로는 own 7 site-9 (100K calls × 3269×) 다음으로 큰 후보.
  note site-S4/S5 는 hexa-lang upstream A13/A14 land 후 진행 — 본 own 10 등록 시점에서는 "후보 등록 + dependency 명시" 만, 실제 적용은 후속 cycle.
  follow-up modules/filters/process/{calendar,finder,mail,memo,safari,telegram}.hexa 자체 self_test 또는 --mode=run-once 측정 자동화 (production exit=0 + state_*.jsonl byte-identical)
  follow-up site-S2 단일 PR 단위 split — filter 6개 별 별도 PR (calendar / finder / mail / memo / safari / telegram), 각 PR 에 wave 2 baseline (1.47-1.66s wall) + post ns + 5-tuple 명시
  follow-up A13 (pfs_readdir/mtime/now_sec) + A14 (json_field_*) hexa-lang upstream RFC land 후 site-S4/S5 재개
  follow-up site-S6 Aho-Corasick precompiled matcher tool/bench/bench_siteS6.hexa 추가 — N=10/30/100 procs scaling 측정
```

---

## 2. site-S1~S6 description (1줄 per site)

| site | filter | hot path | baseline (wave 2) | expected post (own 5/6/7 ROI 추정) | lossless verification |
|---|---|---|---|---|---|
| S1 | 모든 7 | STATE_LOG append (single-line) | cycle 당 1회 fork | exception (이미 충족, marginal) | state_*.jsonl byte-identical |
| S2 | 모든 7 | `ps -axo \| awk \| grep` 3-fork chain | wall 1.47-1.66s/cycle (7 filter 공통) | ~5-10× wall (0.2-0.3s/cycle, fork 제거) | recs JSONL byte-identical + state_*.jsonl 동일 |
| S3 | 5 filter (calendar/mail/memo/safari/telegram) | lsappinfo frontmost fork (조건부) | 측정 미실시 (env-cache 부분 우회) | ~1.5-2× cache hit 시 (fork 제거) | frontmost 식별 결과 동일 |
| S4 | claude.hexa | `ls -t + stat + date` 3-fork × N instance | N=5 instance 시 15 fork/cycle | ~50× per instance (A13 builtin 도래 후) | session_now.json mtime 동일 |
| S5 | claude.hexa | session_now.json substring chain (9 field × N) | own 5 site-2 의 9N 배 (~614× × 9 = ~5500× 누적) | ~100× / field (A14 builtin 도래 후) | extracted field byte-identical |
| S6 | safari/telegram | helper pattern split O(NM) | N=26 procs × M=10 patterns (safari) | ~10-30× (Aho-Corasick precompiled) | helper detection 결과 동일 |

---

## 3. 등록 권장 표 (raw 95 triad / paired-roadmap-id / falsifier)

| dimension | own 10 mapping |
|---|---|
| **raw 95 triad** | (1) advisory enforce-layer + (2) filter self_test 또는 --mode=run-once exit=0 + state_*.jsonl byte-identical + (3) future PR-template site-N+ROI# enforce-layer-1 lint |
| **paired roadmap-id** | own 5 (harvest) + own 6 (forecast) + own 7 (label) + own 8 (predictive_throttle) + own 10 (process gate) — 5-stage site-axis dispatch |
| **base raws** | raw 91 (honest C3 measure don't guess) + raw 95 (triad mandate) + own 5/6/7/8 (인접 stage site-axis precedent) |
| **falsifier F-O10-1** | site-S2 적용 후 7 filter 중 ≥1 의 wall 시간이 baseline 동일 또는 증가 (own 6 site-7 N/A 사례 동일 — small workload 에서 in-process 가 native exec 보다 느림) → site-S2 본 filter 면제 등록 |
| **falsifier F-O10-2** | A13/A14 land 후 90d 경과해도 site-S4/S5 적용 PR 0건 = mandate ineffective, scope 재검토 |
| **falsifier F-O10-3** | site-S2 적용 후 recs JSONL 출력 byte-identical 깨짐 (state mismatch) = 즉시 revert, lossless test 강화 |
| **counter-example C-O10-1** | site-S1 (STATE_LOG single-line) — 이미 충족, 본 own 의 enforcement 면제 (exception 명시) |
| **counter-example C-O10-2** | compute.hexa (L0/AG6 frozen) — own 10 scope 외, own 9 exception 그대로 유지 |
| **counter-example C-O10-3** | claude.hexa session_now.json 외부 의존 — site-S4/S5 는 dependency declaration 도래 전까지 후보 등록만, 적용 면제 |
| **bench evidence** | docs/process_gate_bench_2026-04-30.md wave 2 (7 filter exit=0 / wall 1.47-2.52s / panic 0) — own 10 baseline |

---

## 4. 5-stage site-axis 완성 (own 5/6/7/8/10 종합)

| own | stage | filter/module | site count | status |
|---|---|---|---|---|
| own 5 | harvest (capture) | modules/harvest.hexa | 5 (site-1~5) | DONE 4 / N/A 1 (site-4) |
| own 6 | forecast | modules/forecast.hexa + genome_merge | 4 (site-6/7/8/8b) | DONE 3 / N/A 1 (site-7) |
| own 7 | label | modules/label.hexa | 4 (site-9~12) | DONE 3 / N/A 1 (site-11) |
| own 8 | predictive_throttle | modules/predictive_throttle.hexa | 2 (site-13/14) | DONE 2 |
| **own 10** | **process gate** | **modules/filters/process/{6 filter}.hexa** | **6 (site-S1~S6)** | **DRAFT (S1 exception, S2~S6 등록 권장)** |

---

## 5. 절대 금지 selfcheck

- 코드 수정 0 (drafts only)
- git commit 0 (main agent 가 commit)
- hive / hexa-lang touch 0
- 기존 .own ledger 수정 0 (drafts only — actual append 는 main agent)
- airgenome 코드 수정 0 (drafts only)
- launchctl 0 / 백그라운드 spawn 0
- raw 175 영문 본문 + raw 33 carve-out (한국어 인용은 docs/process_gate_bench_2026-04-30.md / .own / docs/hexa_lang_upstream_candidates.md 발췌만)
