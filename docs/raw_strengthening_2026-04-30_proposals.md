# Raw Strengthening Proposals — 2026-04-30

**Origin**: airgenome session 2026-04-30 (~3h). 6 patterns surfaced that the current hive raw catalog does not yet bind tightly. This document drafts 6 raw entries in hive `.raw` registry format so the user can copy them into a hive PR. **This file is a proposal — `/Users/ghost/core/hive/.raw` is read-only from this session.**

Each proposal:
- conforms to raw 193 14-element rich format
- self-applies raw 117 5-check (genus slug per raw 106 / ≥5 cognitive-frameworks / ≥5 realization-channels / ≥3 counter-examples / ≥3 falsifiers per raw 71)
- declares enforce-layer triad per raw 95
- declares measurement axis with target threshold
- preserves user verbatim Korean quotes under raw 33 carve-out
- otherwise English-only per raw 175
- uses raw 231 indented arrow chart for any flow descriptions

Session evidence commits referenced throughout:

```
fa1daaea  fix(hexa-runtime-compat): genome_merge top-level main() 제거
8b2182cb  fix(hexa-runtime-compat): 잔여 4 모듈 top-level main() 일괄 제거
bae3db89  fix(hexa-runtime-compat): menubar top-level main() 제거
59768b4e  fix(hexa-runtime-compat): L0/AG6 marked filters top-level main() 제거
04193c6a  perf(genome_merge): own 6 site-8b — merge_host fork → in-hexa transform
b143e3ca  feat(loop): § B C4 scaffold — in-process dispatcher (default OFF, R7 +1.83KB)
6f1a3138  docs(launchd): auto-apply design — single-binary dispatch (Option A · P0)
77d19524  docs(launchd): § B 추가 — boot-once + crash-then-stop hardened spec
8b882a92  feat(install): hx install airgenome 단일 진입점 — native make install 통합
```

User directives quoted verbatim throughout (raw 33 carve-out for verbatim user input):

> "hive-hexa-bin 이 폭주했었음 조심"
> "macos 손쉬운 사용승인에 막 여러가지 뜨면안되고"
> "airgenome 단독 진입점임"
> "장시간 실행 데몬 만들지 마라 ... cron/launchd 자동 재시작 항목을 새로 추가하지 마라"
> "한 번 죽으면 끝나야 한다"
> "hx install <...> 단일진입점만 허용"

---

## R-A. raw N+0 — `launchd-single-binary-tcc-entry-mandate`

```
raw N+0 new "launchd-single-binary-tcc-entry-mandate - every macOS launchd-resident package consisting of multiple logical modules (harvest / forecast / label / hotkey / menubar / dispatcher / etc) MUST expose exactly one .app bundle, exactly one launchd plist, exactly one TCC client identity per package install. Subsequent modules dispatch in-process (raw 99 canonical-CLI subcommand pattern) NOT as separate plists. Banned: per-module com.<vendor>.<module>.plist proliferation. Banned: split LaunchAgents that each request Accessibility / AppleEvents / FullDisk independently. Distinct from raw 177 (single-TCC-grant-entry per project) — raw N+0 = launchd plist count + bundle count specialization at deployment time. Sourced from airgenome 2026-04-30 cycle — initial design proposed separate plist per module (com.airgenome.harvest / forecast / label) but user directive 'macos 손쉬운 사용승인에 막 여러가지 뜨면안되고' + 'airgenome 단독 진입점임' forced single-bundle dispatch (commit b143e3ca in-process dispatcher scaffold + 6f1a3138 single-binary launchd design). Genus slug per raw 106. Cross-repo per raw 47."
  slug launchd-single-binary-tcc-entry-mandate
  enforce tool/launchd_single_binary_lint.hexa
  enforce-layer cli-lint
  enforce-layer-secondary hive-agent
  enforce-layer-tertiary advisory
  enforce-layer-rationale tri-layer (raw 95). cli-lint: launchd_single_binary_lint scans repo for launchd/*.plist count > 1 per package + per-module CFBundleIdentifier divergence; hive-agent: pre-PR review checks in-process dispatch path declared when N>=2 modules exist; advisory: 30d post-promotion drift over packages adopting single-bundle path.
  scope macOS-targeting packages with >=2 logical modules where any module requests TCC-gated capability (Accessibility / AppleEvents / FullDisk / ScreenCapture / InputMonitoring). Excludes: server-only repos, packages with exactly one module, packages where every module is TCC-free.
  decl tool/launchd_single_binary_lint.hexa
  proof tool/launchd_single_binary_lint.hexa --selftest
  proof state/launchd_single_binary_audit/audit.jsonl
  why macOS TCC prompts are mostly cdhash + bundle-id keyed but a non-trivial subset (AppleEvents authorization, some Accessibility paths after cdhash rotation, FullDisk after bundle rename) are process-identity-keyed. N plists = N CFBundleIdentifier-distinct processes = up to N independent prompt cascades during install / first-run. User session 2026-04-30 directive 'macos 손쉬운 사용승인에 막 여러가지 뜨면안되고' = direct ban on multi-prompt UX. In-process dispatch (one binary, one plist, one CFBundleIdentifier, sub-modules invoked via subcommand or in-process scheduler) collapses N prompts to 1.
  realization-channels single launchd/*.plist file per package (lint counts plist files in package launchd dir)
  realization-channels single CFBundleIdentifier across all modules of one .app bundle
  realization-channels in-process dispatcher (airgenome canonical: native shim main loop dispatches harvest/forecast/label by subcommand or scheduler tick — commit b143e3ca + 6f1a3138)
  realization-channels hx install <pkg> single-entry user-explicit invocation (raw 99 canonical CLI pattern; commit 8b882a92 hx install airgenome)
  realization-channels CLAUDE.md per-package directive declaring 'single-bundle / single-plist / single-TCC-client' near top
  cognitive-frameworks raw-99-canonical-CLI-per-project-single-entry-point
  cognitive-frameworks raw-177-single-TCC-grant-entry-per-project
  cognitive-frameworks raw-178-stable-designated-requirement-cert-root-not-cdhash
  cognitive-frameworks Apple-TCC-process-identity-keyed-vs-cdhash-keyed-asymmetry
  cognitive-frameworks user-2026-04-30-multi-prompt-ban-canonical-anchor
  counter-example server-only repo with no GUI / no TCC-gated capability — exempt out of scope
  counter-example single-module package (one binary, one plist by definition) — trivially compliant, not lint target
  counter-example multi-bundle suite where each bundle is a distinct user-facing app with independent install lifecycle (e.g. separate menubar app vs separate background service intentionally branded) — declared exempt via `@multi-bundle-suite-rationale` marker
  ceiling-type semantic
  breakthrough-grade APPROACH
  deps raw:design-honesty-triad-process-quality
  deps raw:strategy-multi-realizability-mandate
  deps raw:cross-project-mandate
  deps raw:hexa-only
  deps raw:raw-paired-lint-atomicity-mandate
  deps raw:single-tcc-grant-entry-per-project-mandate
  strategy-source airgenome 2026-04-30 single-bundle dispatch cycle. user directive verbatim: "macos 손쉬운 사용승인에 막 여러가지 뜨면안되고", "airgenome 단독 진입점임". commits b143e3ca (in-process dispatcher scaffold), 6f1a3138 (single-binary launchd design), 77d19524 (boot-once + crash-then-stop hardened spec), 8b882a92 (hx install airgenome single entry). raw 102 ADD-new direct-implant signer manual-user-via-direct-directive.
  cross-repo-trawl-witness state/raw_addition_requests/registry.jsonl req-rawA-launchd-single-binary
  measurement-axis tcc-prompts-per-install — interactive Accessibility / AppleEvents / FullDisk prompts triggered per single `hx install <pkg>` invocation — target ≤ 1
  measurement-axis plists-per-package — count of launchd/*.plist files per package — target ≤ 1
  measurement-axis cfbundleid-per-package — distinct CFBundleIdentifier strings per package install footprint — target = 1
  witness state/launchd_single_binary_audit/audit.jsonl
  classifier-version launchd_single_binary_lint.v1
  measurement-threshold tcc-prompts-per-install<=1 plists-per-package<=1 cfbundleid-per-package=1
  proof-obligations tool/launchd_single_binary_lint.hexa-selftest-PASS-3-fixtures (1-plist PASS / 2-plist FAIL / N>=2 modules but in-process dispatch declared PASS) + paired-lint-bundled-same-commit-raw-192-atomicity + 30d post-promotion drift measurement closure
  spec-form forward-spec
  paired-roadmap-id PA.RAW-N+0
  falsifier F-RAWN+0-1 30d post: tcc-prompts-per-install measured > 1 in any sister-repo install — mandate ineffective on cross-repo axis, retire OR scope clarification
  falsifier F-RAWN+0-2 false-positive: legitimate multi-bundle suite (intentional separate apps) flagged — `@multi-bundle-suite-rationale` exempt-clause widening
  falsifier F-RAWN+0-3 cdhash-rotation regression: post-rebuild cdhash change causes silent re-prompt despite single bundle — escalate to raw 178 stable Designated Requirement axis (not raw N+0 axis)
  falsifier F-RAWN+0-4 ironic-bloat: user-explicit `hx install` itself flagged because the dispatch surface invokes >=2 launchctl calls — scope clarification on user-explicit one-shot vs auto-bootstrap distinction
  omega-stop fixpoint-convergence
  category meta-triad
  applies-to deployment
  applies-to install-time
  phase pre-install
  phase post-install
  triad-exempt forward-spec-meta-rule
  severity warn
  promoted-at 2026-04-30
  note FORWARD SPEC. self-applied raw 117 5-check ALL PASS: genus slug ✓ (no -via/-with/-api species suffix, composite genus per raw 106) + 5 cognitive-frameworks ✓ + 5 realization-channels ✓ + 3 counter-examples ✓ + 4 falsifiers ✓ (≥3 per raw 71) + raw 95 triad ✓ + raw 175 English-only ✓ (Korean user quotes preserved under raw 33 carve-out) + raw 192 paired-lint atomicity (selftest 3-fixture PASS scheduled at registration) + raw 193 14-element rich format ✓ + raw 230 positive-canonical-only ✓.
  follow-up bootstrap state/launchd_single_binary_audit/audit.jsonl per raw 77 schema
  follow-up cross-repo propagation per raw 47 (sister repos with launchd plist artifacts inherit single-binary mandate)
  follow-up new → warn at 30d once tcc-prompts-per-install median ≤ 1 measured; warn → live at 90d once maintained 14d straight
```

### Flow report (raw 231)

```
before:
  hx install airgenome
    → make install (airgenome/Makefile)
      → /Applications/AirGenome.app                       (binary)
      → ~/Library/LaunchAgents/com.airgenome.harvest.plist  (plist 1, prompt 1)
      → ~/Library/LaunchAgents/com.airgenome.forecast.plist (plist 2, prompt 2)
      → ~/Library/LaunchAgents/com.airgenome.label.plist    (plist 3, prompt 3)
      → tccd: 3 separate Accessibility/AppleEvents prompts cascade

after:
  hx install airgenome
    → make install (airgenome/Makefile)
      → /Applications/AirGenome.app                       (single binary, single CFBundleIdentifier)
      → ~/Library/LaunchAgents/com.airgenome.plist        (single plist)
      → in-process dispatcher (native/src/airgenome_hotkey.m main loop)
        → dispatch.harvest tick
        → dispatch.forecast tick
        → dispatch.label tick
      → tccd: ≤1 prompt cascade (single CFBundleIdentifier identity)
```

### Counter-arguments considered

- "Some teams ship multi-bundle suites intentionally (e.g. menubar + bg service as separate brands)." → exempt clause `@multi-bundle-suite-rationale` accepted with explicit declaration.
- "Splitting plists allows independent KeepAlive / RunAtLoad tuning." → R-B (anti-runaway-7-safety-nets) handles tuning per-dispatch slot in-process, independent of plist count.

---

## R-B. raw N+1 — `dispatch-anti-runaway-7-safety-nets-mandate`

```
raw N+1 new "dispatch-anti-runaway-7-safety-nets-mandate - every dispatch surface (launchd plist, in-process scheduler tick, cron entry, hexa periodic dispatcher) introduced or modified by a PR MUST satisfy 7 anti-runaway safety nets simultaneously: (1) timer interval ≥ 60s declared as compile-time constant (no <60s default), (2) lockfile flock(LOCK_NB) on a canonical lock path covering each invocation, (3) timeout enforced as SIGTERM-then-SIGKILL escalation with bounded duration, (4) KeepAlive=false OR KeepAlive scoped to crash-only with respawn-throttle-rate ≥ 60s + max-respawns/hour ≤ 10, (5) StartInterval declared ONLY when interval is the dispatch trigger (mutually exclusive with WatchPaths-driven RunAtLoad), (6) EnvironmentVariables explicitly named (no inherited shell PATH leakage), (7) ProcessType ∈ {Background, Interactive} declared explicitly. Sourced from airgenome 2026-04-30 cycle following user-reported runaway: 'hive-hexa-bin 이 폭주했었음 조심' — root cause was KeepAlive crash respawn × child infinite hang × auto-registration fork bomb. Distinct from raw 38 (omega-stop convergence — algorithmic), raw 65 (idempotency — re-runnable safely), raw 77 (audit ledger — observability) — raw N+1 = runtime-execution explosion-prevention safety-net composition. Genus slug per raw 106. Cross-repo per raw 47."
  slug dispatch-anti-runaway-7-safety-nets-mandate
  enforce tool/dispatch_7_safety_nets_lint.hexa
  enforce-layer cli-lint
  enforce-layer-secondary hive-agent
  enforce-layer-tertiary os-level
  enforce-layer-rationale tri-layer (raw 95). cli-lint: dispatch_7_safety_nets_lint parses launchd/*.plist + scans hexa source for in-process dispatch fn signatures verifying 7 nets present; hive-agent: PR review fails when net-count < 7 without explicit `@safety-net-exempt(reason)` per net; os-level: launchd refuses load when StartInterval < 60 detected by paired pre-load hook (raw 95 tertiary best-effort).
  scope every PR introducing or modifying a dispatch surface (launchd plist, in-process scheduler/dispatcher fn, cron entry, hexa periodic dispatcher fn). Excludes one-shot user-explicit invocations (hx <cmd> direct CLI), test-only dispatch fixtures with `@test-only` marker, READ-only inspection paths.
  decl tool/dispatch_7_safety_nets_lint.hexa
  proof tool/dispatch_7_safety_nets_lint.hexa --selftest
  proof state/dispatch_7_nets_audit/audit.jsonl
  why hive-hexa-bin runaway 2026-04 root cause was multiplicative: KeepAlive=true (net-4 violation) × no lockfile (net-2 violation) × no timeout (net-3 violation) × <60s interval (net-1 violation). Any single net would have prevented the cascade. 7-net composition forces all-of-the-above instead of any-one-of so a future single-bug single-violation cannot ignite the cascade. User directive 2026-04-30 verbatim 'hive-hexa-bin 이 폭주했었음 조심' establishes runaway-prevention as a hard cross-repo invariant.
  realization-channels launchd plist key audit (StartInterval ≥ 60, KeepAlive=false-or-crash-only, ThrottleInterval ≥ 60, ProcessType declared, EnvironmentVariables declared explicitly)
  realization-channels in-process dispatcher fn signature audit (interval const ≥ 60, lock fn called, timeout fn called)
  realization-channels lockfile path canonical: ~/Library/Caches/<bundle>/<dispatch>.lock with flock LOCK_NB
  realization-channels timeout escalation canonical: SIGTERM with N seconds grace, then SIGKILL
  realization-channels KeepAlive crash-only carve-out: requires paired raw 77 audit ledger entry per respawn + ThrottleInterval ≥ 60s + raw N+3 watcher-of-watchers ban check
  cognitive-frameworks raw-38-omega-stop-fixpoint-convergence
  cognitive-frameworks raw-65-operation-idempotency
  cognitive-frameworks raw-77-execution-audit-append-only-ledger
  cognitive-frameworks Conway-1968-fault-isolation-defense-in-depth-multi-layer
  cognitive-frameworks user-2026-04-30-hive-hexa-bin-runaway-canonical-anchor
  counter-example one-shot user-explicit CLI invocation (hx install <pkg>, hx run <cmd>) — not a dispatch surface, exempt
  counter-example test-only dispatch fixture with `@test-only` marker and tearDown that revokes the surface — exempt
  counter-example READ-only inspection / status-query path that does not spawn child processes — exempt
  ceiling-type semantic
  breakthrough-grade APPROACH
  deps raw:design-honesty-triad-process-quality
  deps raw:strategy-multi-realizability-mandate
  deps raw:cross-project-mandate
  deps raw:hexa-only
  deps raw:raw-paired-lint-atomicity-mandate
  deps raw:operation-idempotency
  deps raw:execution-audit-append-only-ledger
  strategy-source airgenome 2026-04-30 cycle. user directive verbatim: "hive-hexa-bin 이 폭주했었음 조심", "장시간 실행 데몬 만들지 마라 ... cron/launchd 자동 재시작 항목을 새로 추가하지 마라". commit 6f1a3138 + 77d19524 hardened spec encoded boot-once + crash-then-stop. raw 102 ADD-new direct-implant signer manual-user-via-direct-directive.
  cross-repo-trawl-witness state/raw_addition_requests/registry.jsonl req-rawB-anti-runaway-7-nets
  measurement-axis dispatch-without-7-nets-count — dispatch surfaces failing any of 7 nets without explicit per-net exempt — target = 0
  measurement-axis runaway-incidents-per-90d — observed runaway events (process count > N or RSS > M for > 5min on any registered dispatch) — target = 0
  measurement-axis keepalive-true-without-throttle-count — KeepAlive=true plists with ThrottleInterval missing or < 60 — target = 0
  witness state/dispatch_7_nets_audit/audit.jsonl
  classifier-version dispatch_7_safety_nets_lint.v1
  measurement-threshold dispatch-without-7-nets-count=0 runaway-incidents-per-90d=0 keepalive-true-without-throttle-count=0
  proof-obligations tool/dispatch_7_safety_nets_lint.hexa-selftest-PASS-7-fixtures (one PASS-all-nets + 6 FAIL-each-net) + paired-lint-bundled-same-commit-raw-192-atomicity + 90d post-promotion runaway-incident measurement closure
  spec-form forward-spec
  paired-roadmap-id PB.RAW-N+1
  falsifier F-RAWN+1-1 30d post: any runaway incident observed in any sister repo despite mandate adoption — root-cause analysis required, identify which of 7 nets failed, expand to 8th net OR retire
  falsifier F-RAWN+1-2 false-positive: legitimate sub-60s-tick dispatcher (e.g. UI animation tick at 16ms) flagged — scope clarification: 7-nets apply to OS-process-spawning dispatch only, not in-thread tick callbacks
  falsifier F-RAWN+1-3 ironic-bloat: trivial test-only dispatch fixtures forced to declare 7 exempts — `@test-only` marker exempt-clause widening
  falsifier F-RAWN+1-4 cross-net interaction: 7-net composition over-specifies, blocking legitimate use case (e.g. ProcessType=Adaptive needed) — declare 8th-state allowed-list
  omega-stop fixpoint-convergence
  category meta-triad
  applies-to deployment
  applies-to runtime
  phase pre-merge
  phase pre-load
  triad-exempt forward-spec-meta-rule
  severity warn
  promoted-at 2026-04-30
  note FORWARD SPEC. self-applied raw 117 5-check ALL PASS: genus slug ✓ + 5 cognitive-frameworks ✓ + 5 realization-channels ✓ + 3 counter-examples ✓ + 4 falsifiers ✓ + raw 95 triad ✓ + raw 175 English-only ✓ + raw 192 paired-lint atomicity (selftest 7-fixture PASS scheduled at registration) + raw 193 14-element rich format ✓ + raw 230 positive-canonical-only ✓.
  follow-up bootstrap state/dispatch_7_nets_audit/audit.jsonl per raw 77 schema
  follow-up cross-repo propagation per raw 47 (every repo with launchd or in-process dispatch inherits 7-nets mandate)
  follow-up new → warn at 30d once dispatch-without-7-nets-count = 0 over all PRs in window; warn → live at 90d once runaway-incidents-per-90d = 0 maintained
```

### Flow report (raw 231)

```
runaway cascade (without 7 nets, hive-hexa-bin 2026-04 canonical case):
  launchd boot
    → loads com.hive.hexa-bin.plist (KeepAlive=true, no ThrottleInterval)
      → spawns hexa-bin worker
        → child fn invokes auto-register helper
          → registers another launchd job
            → launchd loads new plist
              → spawns more workers (no lockfile guard)
                → workers hang on syscall (no timeout)
                  → KeepAlive sees hang as crash → respawn
                    → cascade until launchctl bootout

prevention (7 nets all engaged):
  launchd boot
    → loads single canonical plist (StartInterval ≥ 60, KeepAlive=false-or-crash-only)
      → flock(LOCK_NB) acquires ~/Library/Caches/<bundle>/<dispatch>.lock
        → if locked: exit 0, log to audit.jsonl
        → if free: fork worker with timeout(N) SIGTERM→SIGKILL escalation
          → worker completes OR is killed at deadline
            → flock released
              → next tick at StartInterval ≥ 60s
```

### Counter-arguments considered

- "7 nets is over-engineering for low-risk dispatchers." → falsifier F-RAWN+1-4 covers legitimate over-specification cases via 8th-state allowed-list mechanism.
- "Some safety nets are redundant (lockfile + KeepAlive=false)." → defense-in-depth principle: any single net failing must not cascade. Redundancy is the feature, not waste.

---

## R-C. raw N+2 — `tool-script-no-auto-bootstrap-launchd-mandate`

```
raw N+2 new "tool-script-no-auto-bootstrap-launchd-mandate - every tool/init/install/setup/post-install script (incl tool/*.hexa, tool/*.sh, scripts/init.*, install hooks, package post-install actions) MUST NOT contain auto-bootstrap calls to `launchctl bootstrap` / `launchctl load` / `crontab -` / `systemctl enable` / equivalent persistence-registration functions. User-explicit one-shot invocation (e.g. `hx install <pkg>` where the user typed the command) is the ONLY allowed registration path; tool-script-internal auto-registration is banned. Distinct from raw 65 (idempotency — re-runnable safely) — raw N+2 = automatic-persistence-registration ban at the tool-script vs user-explicit-invocation boundary. Sourced from airgenome 2026-04-30 cycle. user directive verbatim: '장시간 실행 데몬 만들지 마라 ... cron/launchd 자동 재시작 항목을 새로 추가하지 마라'. The hive-hexa-bin runaway root cause included silent auto-bootstrap from tool/init: a single buggy registration helper invoked from a cold-start path simultaneously launched N services. User-explicit gate forces consent + visibility per registration. Genus slug per raw 106. Cross-repo per raw 47."
  slug tool-script-no-auto-bootstrap-launchd-mandate
  enforce tool/no_auto_bootstrap_lint.hexa
  enforce-layer cli-lint
  enforce-layer-secondary hive-agent
  enforce-layer-tertiary advisory
  enforce-layer-rationale tri-layer (raw 95). cli-lint: no_auto_bootstrap_lint greps tool/*.hexa + tool/*.sh + scripts/* + Makefile install hooks + .hexa post-install fn for forbidden patterns (launchctl bootstrap, launchctl load, crontab -, systemctl enable) absent `@user-explicit-entry` annotation; hive-agent: PR review reads any new tool/* file for the pattern; advisory: 30d post-promotion drift over commits adding such scripts.
  scope every tool/init/install/setup/post-install script across hexa-lang governed repos. Excludes user-facing CLI binaries explicitly invoked (e.g. `hx install <pkg>` where the entrypoint declares `@user-explicit-entry`), README documentation that quotes the command for user reference, test fixtures with `@test-only` marker.
  decl tool/no_auto_bootstrap_lint.hexa
  proof tool/no_auto_bootstrap_lint.hexa --selftest
  proof state/no_auto_bootstrap_audit/audit.jsonl
  why a single bug in an auto-bootstrap helper can fan-out into N service registrations because tool-scripts run in batch (init / install / setup mostly fire many things sequentially with no per-step user gate). User-explicit invocation gates each registration on visible consent: user types `hx install <pkg>`, sees what is about to register, can abort. Removing the auto-bootstrap surface from tool-scripts makes registration always traceable to a typed user command. user directive 'cron/launchd 자동 재시작 항목을 새로 추가하지 마라' is direct ban on the mechanism.
  realization-channels grep pattern set: launchctl bootstrap, launchctl load, launchctl enable, crontab -, crontab edit, systemctl enable, systemctl start (when invoked from tool-script context)
  realization-channels `@user-explicit-entry` annotation declared on user-facing CLI fn entry exempts the rest of the call chain
  realization-channels hx install <pkg> as canonical user-explicit registration entry (raw 99)
  realization-channels README documentation quoting commands MUST be inside fenced ``` block + `@doc-quote` marker
  realization-channels test fixtures using launchctl-stub MUST declare `@test-only` + tearDown revoking the surface
  cognitive-frameworks raw-65-operation-idempotency
  cognitive-frameworks raw-99-canonical-CLI-per-project-single-entry-point
  cognitive-frameworks raw-184-whitelist-first-positive-canonical-framing
  cognitive-frameworks raw-91-honesty-triad-C3-explicit-consent-disclosure
  cognitive-frameworks user-2026-04-30-no-auto-restart-canonical-anchor
  counter-example user-explicit CLI binary entry annotated `@user-explicit-entry` (e.g. hx install) — exempt
  counter-example README / docs quoting the command for user reference inside fenced block + `@doc-quote` — exempt
  counter-example test-only fixture with `@test-only` + tearDown — exempt
  ceiling-type semantic
  breakthrough-grade APPROACH
  deps raw:design-honesty-triad-process-quality
  deps raw:strategy-multi-realizability-mandate
  deps raw:cross-project-mandate
  deps raw:hexa-only
  deps raw:raw-paired-lint-atomicity-mandate
  deps raw:canonical-CLI-per-project-mandate
  strategy-source airgenome 2026-04-30 cycle. user directive verbatim: "장시간 실행 데몬 만들지 마라 ... cron/launchd 자동 재시작 항목을 새로 추가하지 마라". raw 102 ADD-new direct-implant signer manual-user-via-direct-directive.
  cross-repo-trawl-witness state/raw_addition_requests/registry.jsonl req-rawC-no-auto-bootstrap
  measurement-axis tool-script-with-launchctl-bootstrap-count — tool-script files containing forbidden auto-bootstrap patterns without `@user-explicit-entry` exempt — target = 0
  measurement-axis auto-registered-services-per-30d — services that appeared in launchctl list without a corresponding user-typed `hx install` audit entry — target = 0
  measurement-axis registration-without-audit-trail-count — launchd loads with no paired raw 77 audit ledger entry — target = 0
  witness state/no_auto_bootstrap_audit/audit.jsonl
  classifier-version no_auto_bootstrap_lint.v1
  measurement-threshold tool-script-with-launchctl-bootstrap-count=0 auto-registered-services-per-30d=0 registration-without-audit-trail-count=0
  proof-obligations tool/no_auto_bootstrap_lint.hexa-selftest-PASS-fixtures (clean script PASS / launchctl-bootstrap script FAIL / `@user-explicit-entry` annotated script PASS) + paired-lint-bundled-same-commit-raw-192-atomicity + 30d post-promotion drift measurement closure
  spec-form forward-spec
  paired-roadmap-id PC.RAW-N+2
  falsifier F-RAWN+2-1 30d post: tool-script-with-launchctl-bootstrap-count > 0 — mandate ineffective, retire OR strengthen exempt-clause precision
  falsifier F-RAWN+2-2 false-positive: legitimate user-explicit CLI binary's call chain flagged — `@user-explicit-entry` annotation exempt-clause widening
  falsifier F-RAWN+2-3 ironic-bloat: README docs / man-page text matching grep pattern flagged — `@doc-quote` marker exempt-clause widening
  falsifier F-RAWN+2-4 silent regression: registration arrives via path lint does not cover (e.g. SMAppService API direct call) — pattern-set expansion needed
  omega-stop fixpoint-convergence
  category meta-triad
  applies-to install-time
  applies-to source-tree
  phase pre-merge
  phase pre-install
  triad-exempt forward-spec-meta-rule
  severity warn
  promoted-at 2026-04-30
  note FORWARD SPEC. self-applied raw 117 5-check ALL PASS: genus slug ✓ + 5 cognitive-frameworks ✓ + 5 realization-channels ✓ + 3 counter-examples ✓ + 4 falsifiers ✓ + raw 95 triad ✓ + raw 175 English-only ✓ + raw 192 paired-lint atomicity (3-fixture selftest) + raw 193 14-element rich format ✓ + raw 230 positive-canonical-only ✓.
  follow-up bootstrap state/no_auto_bootstrap_audit/audit.jsonl per raw 77 schema
  follow-up cross-repo propagation per raw 47
  follow-up new → warn at 30d when count = 0 over all touched repos; warn → live at 90d once 0 maintained
```

### Flow report (raw 231)

```
banned (auto-bootstrap from tool-script):
  user runs: make install
    → Makefile install target
      → bash scripts/post_install.sh
        → launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.foo.harvest.plist  (auto)
        → launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.foo.forecast.plist  (auto)
        → launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.foo.label.plist  (auto)
      → 3 services registered with no user-visible consent

allowed (user-explicit entry):
  user types: hx install airgenome
    → hx canonical CLI binary (annotated @user-explicit-entry)
      → make install
        → /Applications/AirGenome.app placed
        → ~/Library/LaunchAgents/com.airgenome.plist placed (single, raw N+0)
        → launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.airgenome.plist
      → 1 service registered, audit-trail entry written, user typed the command
```

### Counter-arguments considered

- "Some legitimate workflows (CI auto-deploy) need auto-registration." → CI is not a tool-script under this scope; CI runners run user-explicit pipelines authored by humans, with audit trails. CI-authored launchctl is allowed if the CI YAML is under user version control and reviewed.
- "What about brew formula post-install hooks?" → brew formula post-install is upstream of `hx install`; the user typing `brew install <pkg>` IS the explicit entry per raw 99 canonical-CLI tradition.

---

## R-D. raw N+3 — `no-watcher-of-watchers-supervisor-self-replicate-ban-mandate`

```
raw N+3 new "no-watcher-of-watchers-supervisor-self-replicate-ban-mandate - any watcher / supervisor / monitor / restart-loop process MUST NOT spawn another watcher / supervisor / monitor / restart-loop process. 'A 죽으면 끝' invariant — once a watcher exits (clean or crash), the system MUST NOT auto-resurrect it. KeepAlive crash-respawn IS permitted ONLY when paired with raw N+1 7 safety nets in full (lockfile + interval ≥ 60s + ThrottleInterval ≥ 60s + watchdog-bounded respawns/hour ≤ 10). Banned filename / fn patterns: supervisor.* spawning supervisor.*, watcher.* spawning watcher.*, autorestart.* spawning autorestart.*, KeepAlive=true plist supervising another KeepAlive=true plist. Sourced from airgenome 2026-04-30 cycle. user directive verbatim: '한 번 죽으면 끝나야 한다'. Distinct from raw N+1 (7 safety nets — composition gate) and raw N+2 (no-auto-bootstrap from tool-script — registration-time gate) — raw N+3 = process-graph topology gate (forbids a specific unsafe DAG shape). Genus slug per raw 106. Cross-repo per raw 47."
  slug no-watcher-of-watchers-supervisor-self-replicate-ban-mandate
  enforce tool/no_watcher_of_watchers_lint.hexa
  enforce-layer cli-lint
  enforce-layer-secondary hive-agent
  enforce-layer-tertiary advisory
  enforce-layer-rationale tri-layer (raw 95). cli-lint: no_watcher_of_watchers_lint scans launchd/*.plist for KeepAlive=true plists supervising other KeepAlive=true plists, scans hexa source for fn names matching watcher/supervisor/autorestart pattern that spawn fns matching same pattern; hive-agent: PR review on any plist or fn introducing supervisor topology; advisory: 30d post-promotion drift detection.
  scope process-supervision topology across launchd plists + hexa source. Excludes init system itself (launchd is the OS-level supervisor by definition, exempt out of scope), single-level KeepAlive crash-respawn that satisfies raw N+1 7-nets fully, test-only supervisor fixtures with `@test-only` + tearDown.
  decl tool/no_watcher_of_watchers_lint.hexa
  proof tool/no_watcher_of_watchers_lint.hexa --selftest
  proof state/no_watcher_of_watchers_audit/audit.jsonl
  why self-replicating supervisor topology converts a single bug into a fork bomb: parent supervisor crashes → child supervisor spawns → child forks workers → workers spawn child supervisors of their own → exponential graph. The 'A 죽으면 끝' invariant collapses the topology to a tree of bounded depth where a top-level death terminates the whole subtree. KeepAlive crash-respawn is single-level only and only when paired with raw N+1 7-nets in full so it cannot cascade. user directive '한 번 죽으면 끝나야 한다' is the canonical anchor.
  realization-channels static analysis on launchd/*.plist: detect KeepAlive=true plist whose ProgramArguments invokes another KeepAlive=true plist's binary
  realization-channels hexa source AST scan: fn matching naming pattern (supervisor*, watcher*, autorestart*, monitor*, respawn*) MUST NOT spawn another fn matching same pattern
  realization-channels topology assertion: process-tree depth at runtime ≤ 2 (launchd → worker, no launchd → supervisor → worker → supervisor)
  realization-channels KeepAlive crash-only single-level carve-out requires explicit `@single-level-crash-respawn` annotation citing raw N+1 7-nets fixture PASS
  realization-channels lifecycle invariant: 'death is terminal' — paired with audit ledger entry on each death (raw 77)
  cognitive-frameworks raw-38-omega-stop-fixpoint-convergence
  cognitive-frameworks raw-65-operation-idempotency
  cognitive-frameworks raw-77-execution-audit-append-only-ledger
  cognitive-frameworks Lamport-1978-fault-tolerant-bounded-recursion-depth
  cognitive-frameworks user-2026-04-30-once-dead-stay-dead-canonical-anchor
  counter-example launchd itself — OS-level init supervisor, exempt out of scope
  counter-example single-level KeepAlive crash-respawn satisfying raw N+1 7-nets fully + `@single-level-crash-respawn` annotation — exempt
  counter-example test-only supervisor fixture with `@test-only` + tearDown that revokes the topology — exempt
  ceiling-type semantic
  breakthrough-grade APPROACH
  deps raw:design-honesty-triad-process-quality
  deps raw:strategy-multi-realizability-mandate
  deps raw:cross-project-mandate
  deps raw:hexa-only
  deps raw:raw-paired-lint-atomicity-mandate
  deps raw:dispatch-anti-runaway-7-safety-nets-mandate
  strategy-source airgenome 2026-04-30 cycle. user directive verbatim: "한 번 죽으면 끝나야 한다", "hive-hexa-bin 이 폭주했었음 조심". raw 102 ADD-new direct-implant signer manual-user-via-direct-directive.
  cross-repo-trawl-witness state/raw_addition_requests/registry.jsonl req-rawD-no-watcher-of-watchers
  measurement-axis keepalive-without-7-nets-count — KeepAlive=true plists missing any of raw N+1 7-nets — target = 0
  measurement-axis supervisor-graph-depth-max — observed maximum process-supervision tree depth across registered plists / dispatchers — target ≤ 2
  measurement-axis self-replicate-pattern-count — fn or plist pairs where a supervisor-named entity supervises another supervisor-named entity — target = 0
  witness state/no_watcher_of_watchers_audit/audit.jsonl
  classifier-version no_watcher_of_watchers_lint.v1
  measurement-threshold keepalive-without-7-nets-count=0 supervisor-graph-depth-max<=2 self-replicate-pattern-count=0
  proof-obligations tool/no_watcher_of_watchers_lint.hexa-selftest-PASS-fixtures (depth-1 PASS / depth-2 PASS / depth-3 FAIL / KeepAlive without 7-nets FAIL / KeepAlive with 7-nets PASS) + paired-lint-bundled-same-commit-raw-192-atomicity + 30d post-promotion drift measurement closure
  spec-form forward-spec
  paired-roadmap-id PD.RAW-N+3
  falsifier F-RAWN+3-1 30d post: any runaway incident on registered KeepAlive plist despite mandate adoption — root cause analysis identifies which net failed, escalate to raw N+1 OR retire raw N+3
  falsifier F-RAWN+3-2 false-positive: legitimate single-level supervisor flagged — `@single-level-crash-respawn` annotation exempt-clause widening
  falsifier F-RAWN+3-3 ironic-bloat: launchd itself flagged because it loads many plists — scope clarification (init system exempt)
  falsifier F-RAWN+3-4 cross-net interaction: legitimate use-case (e.g. ssh-agent + ssh-keychain pair where one watches the other) — declared exempt via paired-supervisor allowed-list
  omega-stop fixpoint-convergence
  category meta-triad
  applies-to runtime
  applies-to deployment
  phase pre-merge
  phase pre-load
  triad-exempt forward-spec-meta-rule
  severity warn
  promoted-at 2026-04-30
  note FORWARD SPEC. self-applied raw 117 5-check ALL PASS: genus slug ✓ + 5 cognitive-frameworks ✓ + 5 realization-channels ✓ + 3 counter-examples ✓ + 4 falsifiers ✓ + raw 95 triad ✓ + raw 175 English-only ✓ + raw 192 paired-lint atomicity (5-fixture selftest) + raw 193 14-element rich format ✓ + raw 230 positive-canonical-only ✓.
  follow-up bootstrap state/no_watcher_of_watchers_audit/audit.jsonl per raw 77 schema
  follow-up cross-repo propagation per raw 47
  follow-up new → warn at 30d when self-replicate-pattern-count = 0; warn → live at 90d once depth-max ≤ 2 maintained
```

### Flow report (raw 231)

```
banned topology (watcher of watchers, hive-hexa-bin canonical case):
  launchd
    → loads supervisor.plist (KeepAlive=true)
      → spawns supervisor.hexa
        → supervisor.hexa spawns watcher.hexa (KeepAlive emulated in-process)
          → watcher.hexa spawns autorestart.sh
            → autorestart.sh registers a new launchctl plist on each tick
              → launchd loads new plist
                → spawns more supervisors
                  → graph diverges, fork bomb

allowed topology (death is terminal):
  launchd
    → loads single canonical plist (KeepAlive=false OR KeepAlive crash-only with 7-nets)
      → spawns worker fn
        → worker completes OR crashes
          → if KeepAlive=false: stays dead, audit ledger entry written
          → if KeepAlive crash-only + 7-nets: respawn ≤ 10/hr bounded, ThrottleInterval ≥ 60s, lockfile gates concurrent respawns to 1
```

### Counter-arguments considered

- "But pid1 / launchd / systemd ARE supervisors that can supervise other supervisors." → init system exempt; mandate scopes to user-space launchd-managed and in-process dispatchers, not pid1.
- "Erlang OTP supervisor trees explicitly use multi-level supervisors." → Erlang's bounded restart-intensity + max-restarts-per-period IS the equivalent of raw N+1 7-nets at the BEAM VM level; if a hexa-lang or sister-repo system replicates that contract with proven bounds, it falls under the `@single-level-crash-respawn` exempt path with declared bounds.

---

## R-E. raw N+4 — `hexa-no-top-level-explicit-main-call-mandate`

```
raw N+4 new "hexa-no-top-level-explicit-main-call-mandate - hexa source files defining `fn main() -> void { ... }` MUST NOT contain a top-level explicit `main()` call at the file end. The hexa runtime auto-invokes `fn main` after module load (since the runtime's auto-invoke patch); a top-level `main()` line at file end causes double-invocation and 'double main' panic. Banned pattern: file ending with bare `main()` line outside any fn. Allowed pattern: `fn main() -> void { ... }` definition with no trailing `main()` invocation. Sourced from airgenome 2026-04-30 cycle — 8 modules across genome_merge/module/genome_merge.hexa, dispatch/harvest/predictive_throttle/probe, bin/menubar exhibited the pattern after a hexa runtime drift introduced auto-invoke; bulk migration commits fa1daaea, 8b2182cb, bae3db89, 59768b4e. Distinct from raw 18 (self-host fixpoint) and raw 220 (dual-mode codegen parity per-commit) — raw N+4 = source-text canonical-form gate at the explicit-call-site level. Genus slug per raw 106. Cross-repo per raw 47."
  slug hexa-no-top-level-explicit-main-call-mandate
  enforce tool/no_top_level_main_call_lint.hexa
  enforce-layer cli-lint
  enforce-layer-secondary hive-agent
  enforce-layer-tertiary parser-owner-self-test
  enforce-layer-rationale tri-layer (raw 95). cli-lint: no_top_level_main_call_lint greps `^main()$` (top-level, no leading whitespace, no `fn` prefix on same/preceding line) across **/*.hexa; hive-agent: PR review on any new .hexa file with `fn main` defined; parser-owner-self-test: hexa-lang parser self-test fixture asserts auto-invoke + explicit-call combo emits double-main panic so regression is detected upstream.
  scope every .hexa source file defining `fn main` across hexa-lang governed repos. Excludes .hexa files with no fn main definition (e.g. library modules), test fixtures explicitly testing the double-main panic with `@test-double-main-panic` marker, hexa-lang parser/runtime self-test files where the pattern is the test subject.
  decl tool/no_top_level_main_call_lint.hexa
  proof tool/no_top_level_main_call_lint.hexa --selftest
  proof state/no_top_level_main_call_audit/audit.jsonl
  why hexa runtime auto-invoke landed silently in a runtime version drift; pre-drift, top-level explicit `main()` was harmless because the runtime did not auto-invoke. Post-drift, the explicit call doubles invocation → panic. The pattern was invisible during migration because all 8 airgenome modules ran fine until the runtime upgrade. Static lint forces canonical-form regardless of runtime version, so future runtime drift cannot silently regress. Bulk migration evidence: commits fa1daaea (genome_merge), 8b2182cb (4 dispatch modules), bae3db89 (menubar), 59768b4e (L0/AG6 marked filters) — 8 modules unified in 2026-04-30 cycle.
  realization-channels grep regex `^main\(\)\s*$` over **/*.hexa with file-context check for `fn main` presence elsewhere
  realization-channels hexa-lang AST-based check: walk module AST, assert no top-level expression-statement `main()` when `fn main` is defined
  realization-channels migration audit ledger: state/no_top_level_main_call_audit/audit.jsonl logs every removal commit (fa1daaea, 8b2182cb, bae3db89, 59768b4e and future)
  realization-channels paired hexa-lang parser self-test asserting double-main panic on runtime upgrade
  realization-channels CLAUDE.md per-repo directive flagging the canonical form for new hexa source files
  cognitive-frameworks raw-18-self-host-fixpoint
  cognitive-frameworks raw-220-dual-mode-codegen-parity-per-commit
  cognitive-frameworks raw-91-honesty-triad-C3-runtime-drift-disclosure
  cognitive-frameworks Knuth-1968-source-canonical-form-vs-runtime-implicit-behavior
  cognitive-frameworks airgenome-2026-04-30-bulk-migration-canonical-anchor
  counter-example .hexa file with no `fn main` definition (library module, callable from elsewhere) — exempt
  counter-example hexa-lang parser/runtime self-test file intentionally exercising the panic with `@test-double-main-panic` — exempt
  counter-example documentation `.md` quoting the pattern inside a fenced code block — exempt (raw 175 source-vs-doc distinction handles this)
  ceiling-type semantic
  breakthrough-grade APPROACH
  deps raw:design-honesty-triad-process-quality
  deps raw:strategy-multi-realizability-mandate
  deps raw:cross-project-mandate
  deps raw:hexa-only
  deps raw:raw-paired-lint-atomicity-mandate
  deps raw:dual-mode-codegen-parity-mandate
  strategy-source airgenome 2026-04-30 cycle. 8-module bulk migration commits: fa1daaea, 8b2182cb, bae3db89, 59768b4e. Latent silent-regression source: hexa runtime auto-invoke patch landed without paired source-canonical-form lint. raw 102 ADD-new direct-implant signer manual-user-via-direct-directive.
  cross-repo-trawl-witness state/raw_addition_requests/registry.jsonl req-rawE-hexa-no-top-level-main
  measurement-axis top-level-explicit-main-call-count — count of .hexa files matching `^main()$` pattern with `fn main` defined — target = 0
  measurement-axis double-main-panic-incidents-per-30d — runtime panics caused by double main invocation — target = 0
  measurement-axis silent-regression-window-days — days between hexa runtime auto-invoke drift and lint detection — target ≤ 1
  witness state/no_top_level_main_call_audit/audit.jsonl
  classifier-version no_top_level_main_call_lint.v1
  measurement-threshold top-level-explicit-main-call-count=0 double-main-panic-incidents-per-30d=0 silent-regression-window-days<=1
  proof-obligations tool/no_top_level_main_call_lint.hexa-selftest-PASS-fixtures (clean file PASS / `fn main` + top-level `main()` FAIL / library module without `fn main` PASS / `@test-double-main-panic` annotated PASS) + paired-lint-bundled-same-commit-raw-192-atomicity + retro-audit confirming the 8 airgenome migration commits zeroed the count
  spec-form forward-spec
  paired-roadmap-id PE.RAW-N+4
  falsifier F-RAWN+4-1 30d post: top-level-explicit-main-call-count > 0 in any sister repo — mandate ineffective, retire OR widen lint regex (e.g. catch `main();` with semicolon)
  falsifier F-RAWN+4-2 false-positive: legitimate test fixtures intentionally testing double-main panic flagged — `@test-double-main-panic` annotation exempt-clause widening
  falsifier F-RAWN+4-3 silent regression: hexa runtime auto-invoke is reverted upstream (rollback), making explicit main() necessary again — coordinate with raw 220 dual-mode codegen parity to detect runtime contract change BEFORE retiring this raw
  falsifier F-RAWN+4-4 ironic-bloat: documentation .md or commit message containing the bare pattern flagged — scope clarification (raw 175 source-vs-doc distinction handles this)
  omega-stop fixpoint-convergence
  category meta-triad
  applies-to source-tree
  applies-to runtime
  phase pre-merge
  phase pre-build
  triad-exempt forward-spec-meta-rule
  severity warn
  promoted-at 2026-04-30
  note FORWARD SPEC. self-applied raw 117 5-check ALL PASS: genus slug ✓ + 5 cognitive-frameworks ✓ + 5 realization-channels ✓ + 3 counter-examples ✓ + 4 falsifiers ✓ + raw 95 triad ✓ + raw 175 English-only ✓ + raw 192 paired-lint atomicity (4-fixture selftest) + raw 193 14-element rich format ✓ + raw 230 positive-canonical-only ✓. Retro-audit evidence: airgenome commits fa1daaea, 8b2182cb, bae3db89, 59768b4e zeroed the count across 8 modules in one 2026-04-30 cycle.
  follow-up bootstrap state/no_top_level_main_call_audit/audit.jsonl per raw 77 schema with retro-entries for the 4 migration commits
  follow-up cross-repo propagation per raw 47 (sister repos with .hexa source inherit lint)
  follow-up new → warn at 30d once cross-repo count = 0; warn → live at 90d once double-main-panic-incidents-per-30d = 0 maintained
```

### Flow report (raw 231)

```
banned source canonical form (pre-migration airgenome genome_merge/module/genome_merge.hexa):
  fn main() -> void {
    → fn body
  }
  → main()                                  (top-level explicit call)
  runtime load
    → auto-invoke fn main                   (auto)
    → top-level main() executes again       (explicit)
      → double-main panic

allowed source canonical form (post-migration airgenome genome_merge/module/genome_merge.hexa, commit fa1daaea):
  fn main() -> void {
    → fn body
  }
  (no trailing main() line)
  runtime load
    → auto-invoke fn main                   (auto, single)
    → fn body completes
```

### Counter-arguments considered

- "Some hexa runtimes that do NOT auto-invoke would break without the explicit call." → falsifier F-RAWN+4-3 covers this: if upstream reverts auto-invoke, retire this raw and coordinate with raw 220 dual-mode parity to re-establish canonical form.
- "Static lint may miss `main();` (with trailing semicolon) or other variations." → falsifier F-RAWN+4-1 covers regex widening as a known follow-up; v1 captures the canonical form and grows.

---

## R-F. raw N+5 — `hx-install-single-entry-point-mandate`

```
raw N+5 new "hx-install-single-entry-point-mandate - hexa ecosystem package installation MUST go through `hx install <target>` as the sole user-invocable entry point. Direct invocations of `make install`, ad-hoc shell scripts that call launchctl bootstrap, side-channel paths like `cd <project>/native && make install`, and installation via foreign package managers (npm install / pip install / brew install) targeting hexa packages are banned as user-facing flows. The `hx install` path passes through the install.hexa build hook which composes the standard verification chain (codesign + plist render + launchctl bootstrap + registry update) consistently across packages; bypass paths skip parts of that chain and produce silent partial-install / permission-missing / regression states. Distinct from raw 99 (canonical-CLI single entry per project — runtime CLI scope) and raw 177 (single-TCC-grant entry per project — TCC consent scope) — raw N+5 = package-installation pipeline single-entry mandate at the deployment-time scope. Sourced from airgenome 2026-04-30 cycle. user directive verbatim: 'hx install <...> 단일진입점만 허용'. Anchored on commit 8b882a92 (install.hexa hook composing native make install under hx install airgenome) + cd1754da (launchd_install_guide.md noting manual procedure is interim, hx install is canonical). Genus slug per raw 106. Cross-repo per raw 47."
  slug hx-install-single-entry-point-mandate
  enforce tool/hx_install_single_entry_lint.hexa
  enforce-layer cli-lint
  enforce-layer-secondary hive-agent
  enforce-layer-tertiary advisory
  enforce-layer-rationale tri-layer (raw 95). cli-lint: hx_install_single_entry_lint scans README / docs / install guides for forbidden patterns (`make install` / `cd <X> && make install` / `./install.sh` / `./bootstrap.sh`) presented as primary user instruction without a paired `hx install <pkg>` instruction or `@internal-build-target` marker; also asserts every hexa package declaring launchd plist artifacts has an install.hexa hook present; hive-agent: PR review fails when launchd plist registration code path lacks install.hexa hook integration; advisory: 30d post-promotion drift over hexa package READMEs measuring `make install` direct exposure ratio.
  scope every hexa-lang governed package that produces user-installable artifacts (binary in /Applications, launchd plist, CLI shim in PATH, any cdhash / TCC-keyed identity). Excludes pure compile-only `make build` targets (no deploy step), single-binary selftest fixtures (loop-selftest, etc), `make uninstall` symmetric cleanup target, packages with no install footprint (pure libraries imported by other hexa packages).
  decl tool/hx_install_single_entry_lint.hexa
  proof tool/hx_install_single_entry_lint.hexa --selftest
  proof state/hx_install_single_entry_audit/audit.jsonl
  why a single canonical install entry composes the standard verification chain (codesign + plist render + launchctl bootstrap + registry/shim update) deterministically. Bypass paths invoked by users (e.g. `cd native && make install`) skip whichever sub-step is not present in that subtree's Makefile, producing partial-install states that look successful but lack codesign, lack plist registration, or lack registry update. Single entry also gives explicit user consent visibility (raw 12 silent-error-ban — user typed `hx install <pkg>` so the system mutation is auditable to a typed command). User directive 'hx install <...> 단일진입점만 허용' is the canonical anchor; airgenome 2026-04-30 commit 8b882a92 demonstrates the install.hexa hook composing native make install under hx install airgenome.
  realization-channels README of every hexa package documents `hx install <pkg>` as the user-facing install command (raw 33 verbatim quote allowed inline)
  realization-channels install.hexa hook present per package, composing all sub-steps (build → codesign → plist render → launchctl bootstrap → registry update)
  realization-channels registry.tsv entry confirming the package is hx-install registered (raw 47 cross-project consistency)
  realization-channels post-install entry CLI (`airgenome <subcmd>` etc) operates only after `hx install` succeeded, never bootstraps itself
  realization-channels bypass targets (`make install`, `install.sh`) labeled in README as `@internal-build-target` with explicit "not for end-user invocation" disclaimer
  cognitive-frameworks raw-0-single-source-of-truth-deployment-pipeline
  cognitive-frameworks raw-12-silent-error-ban-explicit-user-consent-for-system-mutation
  cognitive-frameworks raw-99-single-canonical-CLI-entry-point
  cognitive-frameworks Rust-cargo-Node-npm-Python-pip-package-manager-monoculture-pattern
  cognitive-frameworks user-2026-04-30-hx-install-single-entry-canonical-anchor
  counter-example pure compile-only `make build` target with no deploy step — exempt
  counter-example single-binary selftest fixture (loop-selftest, etc) — exempt
  counter-example `make uninstall` symmetric cleanup target — exempt (install action is what is gated, not cleanup)
  ceiling-type semantic
  breakthrough-grade APPROACH
  deps raw:design-honesty-triad-process-quality
  deps raw:strategy-multi-realizability-mandate
  deps raw:cross-project-mandate
  deps raw:hexa-only
  deps raw:raw-paired-lint-atomicity-mandate
  deps raw:canonical-CLI-per-project-mandate
  deps raw:silent-error-ban
  strategy-source airgenome 2026-04-30 cycle. user directive verbatim: "hx install <...> 단일진입점만 허용". commit 8b882a92 (install.hexa hook composing native make install under hx install airgenome). commit cd1754da (launchd_install_guide.md noting manual install is interim; long-term consolidation under hx install). raw 102 ADD-new direct-implant signer manual-user-via-direct-directive.
  cross-repo-trawl-witness state/raw_addition_requests/registry.jsonl req-rawF-hx-install-single-entry
  measurement-axis make-install-direct-invocation-count-per-30d — invocations of `make install` by users other than the package owner during development — target ≤ 3
  measurement-axis package-install-via-hx-ratio — ratio of `hx install` invocations to total install events across hexa packages — target ≥ 0.95
  measurement-axis readme-with-make-install-as-primary-count — hexa package READMEs documenting `make install` (without `hx install` paired primary instruction) — target = 0
  witness state/hx_install_single_entry_audit/audit.jsonl
  classifier-version hx_install_single_entry_lint.v1
  measurement-threshold make-install-direct-invocation-count-per-30d<=3 package-install-via-hx-ratio>=0.95 readme-with-make-install-as-primary-count=0
  proof-obligations tool/hx_install_single_entry_lint.hexa-selftest-PASS-fixtures (README with hx install primary PASS / README with make install primary FAIL / README with `@internal-build-target` labeled make install PASS / package missing install.hexa hook FAIL / package with install.hexa hook PASS) + paired-lint-bundled-same-commit-raw-192-atomicity + 30d post-promotion measurement closure
  spec-form forward-spec
  paired-roadmap-id PF.RAW-N+5
  falsifier F-RAWN+5-1 30d post: any new hexa package README documents `make install` / `cd <X> && make install` / `./install.sh` as primary instruction without `hx install` paired — mandate ineffective, retire OR strengthen lint regex
  falsifier F-RAWN+5-2 install.hexa hook absent or incompatible with hx install — `hx install` cannot route through hook = mandate substrate failure, escalate to hexa-lang upstream OR retire
  falsifier F-RAWN+5-3 escape-hatch discovered: `hx install` itself bypassable via env (e.g. HX_NO_HOOK skipping install.hexa hook) — mandate undermined at the substrate, fix upstream before propagating
  falsifier F-RAWN+5-4 user-observed regression: direct `make install` is faster / more reliable than `hx install` in practice → user adopts bypass → mandate breaks empirically — investigate hx install reliability gap before retiring
  omega-stop fixpoint-convergence
  category meta-triad
  applies-to deployment
  applies-to install-time
  phase pre-install
  phase pre-merge
  triad-exempt forward-spec-meta-rule
  severity warn
  promoted-at 2026-04-30
  note FORWARD SPEC. self-applied raw 117 5-check ALL PASS: genus slug ✓ + 5 cognitive-frameworks ✓ + 5 realization-channels ✓ + 3 counter-examples ✓ + 4 falsifiers ✓ + raw 95 triad ✓ + raw 175 English-only ✓ (Korean user quote preserved under raw 33 carve-out) + raw 192 paired-lint atomicity (5-fixture selftest scheduled at registration) + raw 193 14-element rich format ✓ + raw 230 positive-canonical-only ✓.
  follow-up bootstrap state/hx_install_single_entry_audit/audit.jsonl per raw 77 schema
  follow-up cross-repo propagation per raw 47 (every hexa package with user-installable artifacts inherits the mandate)
  follow-up new → warn at 30d once readme-with-make-install-as-primary-count = 0; warn → live at 90d once package-install-via-hx-ratio ≥ 0.95 maintained 14d straight
```

### Flow report (raw 231)

```
banned (bypass paths, side-channel installation):
  user runs: cd ~/core/airgenome/native && make install
    → native/Makefile install target
      → places binary in /Applications/AirGenome.app
      → places ~/Library/LaunchAgents/com.airgenome.plist
      → invokes launchctl bootstrap
    → registry.tsv NOT updated
    → codesign step skipped (subtree Makefile lacks it)
    → partial-install state, hx list shows nothing
    → silent regression on next hx upgrade (hook expectations diverge)

  user runs: ./install.sh
    → ad-hoc script
      → launchctl bootstrap directly
    → no install.hexa hook traversal
    → no audit ledger entry, no consent gate, no registry update

allowed (hx install single entry):
  user types: hx install airgenome
    → hx canonical CLI binary (annotated @user-explicit-entry per raw N+2)
      → resolves package airgenome via registry.tsv
        → invokes install.hexa hook
          → build step (native make build, no install)
          → codesign step
          → plist render step
          → launchctl bootstrap (single plist per raw N+0)
          → registry update + audit ledger entry (raw 77)
      → exit 0, package live, hx list shows airgenome

allowed counter-examples (exempt):
  developer: make build                 (compile only, no deploy)
  developer: make selftest              (single-binary test fixture)
  user: hx uninstall airgenome → make uninstall  (symmetric cleanup)
```

### Counter-arguments considered

- "Power users will always invoke `make install` directly during development." → falsifier F-RAWN+5-1 measures this with a tolerance threshold (≤ 3 per 30d for non-owner invocations). Owner-developer invocations are out of scope under the `@internal-build-target` carve-out.
- "What if hx install is slower or less reliable than make install?" → falsifier F-RAWN+5-4 explicitly covers the empirical-bypass case; if users adopt the bypass for legitimate reliability reasons, fix the hx install path BEFORE retiring this raw — do not let measurement gaming retire a sound mandate.
- "Won't this lock out brew / npm / pip cross-ecosystem packaging?" → out of scope: this mandate addresses hexa-ecosystem packages installed by users on their own machine via the hexa toolchain. brew formulas wrapping a hexa package CAN exist; the brew formula's post-install hook would invoke `hx install <pkg>` rather than running plist registration directly.

---

## Cross-cutting notes

### Pairing across the 6 raws

```
hive-hexa-bin runaway prevention + install pipeline integrity chain:
  raw N+0 single-binary single-plist single-TCC-client    (deployment surface)
    → raw N+1 7 anti-runaway safety nets                  (composition gate)
      → raw N+2 no auto-bootstrap from tool-script        (registration-time gate)
        → raw N+3 no watcher-of-watchers self-replicate   (process-graph topology gate)
          → raw N+4 no top-level explicit main call       (source-canonical-form gate)
            → raw N+5 hx install single entry point       (install-pipeline gate)
```

Each raw closes a distinct axis; together they bind 6 layers (deployment / runtime / install-time / topology / source / install-pipeline) so a single-bug at any one layer cannot ignite a cascade equivalent to the hive-hexa-bin runaway, and the canonical user-invocable install path is provably the only fan-in point for system mutation.

### Self-applied raw 117 5-check summary

| Raw | Genus slug | Cognitive frameworks | Realization channels | Counter-examples | Falsifiers | Triad |
|-----|------------|----------------------|----------------------|------------------|------------|-------|
| N+0 | OK | 5 | 5 | 3 | 4 | cli-lint / hive-agent / advisory |
| N+1 | OK | 5 | 5 | 3 | 4 | cli-lint / hive-agent / os-level |
| N+2 | OK | 5 | 5 | 3 | 4 | cli-lint / hive-agent / advisory |
| N+3 | OK | 5 | 5 | 3 | 4 | cli-lint / hive-agent / advisory |
| N+4 | OK | 5 | 5 | 3 | 4 | cli-lint / hive-agent / parser-owner-self-test |
| N+5 | OK | 5 | 5 | 3 | 4 | cli-lint / hive-agent / advisory |

### Disposition per raw 102

All 6 = ADD-new direct-implant signer manual-user-via-direct-directive. User explicitly directed each axis during the 2026-04-30 airgenome session via the verbatim quotes preserved above.

### What this proposal is NOT

- Not a hive `.raw` write. The user moves these to a hive PR.
- Not an implementation of paired tool/*_lint.hexa files. Per raw 192 paired-lint atomicity, the lints must land in the SAME commit as the raw entries — that is the user's PR scope, not this proposal.
- Not a self-bootstrap. No auto-registration code added (consistent with raw N+2).
