# raw 241 Strengthening Proposal — 2026-04-30

**Origin**: airgenome session 2026-04-30. raw 241 (`launchd-single-binary-tcc-entry-mandate`, commit 5c8db8c60) was just promoted in current Ω-cycle. User directive 2026-04-30 Korean verbatim demands `carve-out 0`, `예외 0`, `모호성 0` reading of the mandate. This proposal drafts a `strengthening 2026-04-30 absolute-no-multi-launchd-per-package` clause to be appended to raw 241 in the hive `.raw` registry.

**Scope guard (read-only mandate)**: this file is a draft only. `/Users/ghost/core/hive/.raw` and `/Users/ghost/core/hexa-lang/.raw` are NOT touched in this session. Application path = explicit user / hive-cli registration commit referencing this proposal. raw 102 STRENGTHEN-existing pattern (autonomous + raw 91 honest C3).

Self-applied raw 117 5-check + raw 95 triad + raw 192 paired-lint atomicity declared inline at §6, §7.

---

## 1. Current raw 241 verbatim (commit 5c8db8c60)

```
raw 241 new "launchd-single-binary-tcc-entry-mandate - every macOS launchd-resident
package consisting of multiple logical modules (harvest / forecast / label / hotkey
/ menubar / dispatcher / etc) MUST expose exactly one .app bundle, exactly one
launchd plist, exactly one TCC client identity per package install. Subsequent
modules dispatch in-process (raw 99 canonical-CLI subcommand pattern) NOT as
separate plists. Banned: per-module com.<vendor>.<module>.plist proliferation.
Banned: split LaunchAgents that each request Accessibility / AppleEvents /
FullDisk independently. Distinct from raw 177 (single-TCC-grant-entry per
project) — raw 241 = launchd plist count + bundle count specialization at
deployment time. Sourced from airgenome 2026-04-30 cycle — initial design
proposed separate plist per module (com.airgenome.harvest / forecast / label) but
user directive 'macos 손쉬운 사용승인에 막 여러가지 뜨면안되고' + 'airgenome
단독 진입점임' forced single-bundle dispatch (commit b143e3ca in-process
dispatcher scaffold + 6f1a3138 single-binary launchd design). Genus slug per raw
106. Cross-repo per raw 47."
```

Existing field set carried over (slug / enforce / enforce-layer triad / scope /
realization-channels / cognitive-frameworks / counter-examples / falsifiers /
measurement-axis) is left as-is by this proposal — strengthening only ADDs a
`strengthening 2026-04-30 absolute-no-multi-launchd-per-package` clause and
extends ban-list / measurement-axis / falsifier set per raw 49 additive-first.

---

## 2. User directive verbatim (raw 33 carve-out)

> "각각ㄱ각각 launched 다수는 절대 안되"
> "단일 진입점 무조건 지키도록"
> "raw 에 확실히 기준을 잡자"

Reading: `무조건` = no carve-out. `절대` = no exception. `확실히` = no
ambiguity. Interpretation collapses to absolute single-entry mandate per package
install on the launchd surface.

---

## 3. Strengthening clause — body (raw 102 STRENGTHEN-existing pattern)

To be inserted into raw 241 entry as an indented continuation line under the
existing entry (mirror raw 1 V2 + raw 42 stage-4 + raw 3 promote-verify-PARTIAL
existing strengthening-note formatting):

```
  strengthening 2026-04-30 absolute-no-multi-launchd-per-package (raw 102
  STRENGTHEN-existing autonomous + raw 91 honest C3 + raw 49 additive-first):
  per user directives 2026-04-30 verbatim "각각ㄱ각각 launched 다수는 절대
  안되" + "단일 진입점 무조건 지키도록" + "raw 에 확실히 기준을 잡자" — raw 241
  scope EXTENDED to make `single launchd plist per package install` invariant
  carve-out-zero / exception-zero / ambiguity-zero on three new surfaces: (a)
  same-prefix Label grouping under one package's CFBundleIdentifier prefix
  (e.g. `com.airgenome.*`) is now a direct violation regardless of intent — N
  plists with shared package prefix = N TCC client identities = N prompts; (b)
  any commit adding a new launchd `*.plist` file that does not also retire an
  existing plist of the same package in the same commit fails the registration
  gate (paired with raw 239 commit-trailer-convergence + raw 192 paired-lint
  atomicity); (c) supervisor / watcher launchd plists that spawn N child plists
  are banned regardless of count (raw 244 watcher-of-watchers extension to
  plist surface). Carve-outs (raw 91 honest C3 disclosure §5) limited to:
  distinct packages with distinct bundle ids and distinct cdhash; same-binary
  sub-mode dispatch via subcommand argv (`--mode=tap` / `--mode=loop` /
  `--mode=run-once`); in-process child process spawn under one supervising
  binary's PID hierarchy (no new plist filed). Witness via state/launchd_
  single_binary_audit/audit.jsonl raw 241 strengthening rows from 2026-04-30
  onward.
```

Remaining sections (4–7 below) enumerate the components referenced inside the
clause.

---

## 4. Six strengthening items (enumerated)

### 4.1 Ban-list extension (raw 230 positive-canonical-only — intent-keyed, not name-enumerated)

Ban-list refinements (each phrased as the violating intent / mechanism, not as a
prose list of names per raw 230):

1. New launchd plist added in a PR without same-commit retire (`bootout` +
   `rm`) of an existing plist of the same package = reject.
2. Install hook (`install.hexa` / `setup.sh` / pkg post-install) calling
   `launchctl bootstrap` without a pre-call `existing-plist-count == 0`
   assertion = reject (paired with raw 243 no-auto-bootstrap-from-tool-script).
3. New launchd plist whose Label shares the existing package prefix (e.g.
   `com.airgenome.*`) is a direct raw 241 violation — Label-prefix-grouping is
   itself a same-package split signal.
4. One launchd plist spawning N child plists (supervisor self-replicate
   pattern) banned regardless of safety-net composition (extension to raw 244
   watcher-of-watchers ban onto the plist DAG surface).

### 4.2 Enforcement layer extension (raw 95 triad → quad with hard-gate at install hook)

Existing enforce-layer triad (advisory + cli-lint + paired-roadmap-id) extended
with:

- **pre-commit hook**: any commit adding `*.plist` under `**/launchd/**` or
  `**/LaunchAgents/**` requires (a) `Convergence: <id>` trailer per raw 239;
  (b) demonstration of an existing plist `bootout` + `rm` happening in the same
  commit (or this is a brand-new package with no prior plist).
- **runtime check**: post-install verification step asserts `launchctl print
  gui/$UID | grep <package-prefix> | wc -l == 1`; count > 1 fails the install
  hook immediately.
- **design-doc lint**: any `launchd_*.md` / `install_*.md` doc must declare
  current plist count and intended future plist count (target = 1, asserted =
  1); absence fails design-doc lint.

### 4.3 Measurement-axis extension (existing axis set augmented)

Existing axis set (`tcc-prompts-per-install <= 1`, `plists-per-package <= 1`,
`cfbundleid-per-package == 1`) extended with:

- `launchd-plist-count-per-package` — count of active plists with Label
  matching package prefix; **target = 1 strict**.
- `tcc-prompt-count-per-package-install` — accessibility / input-monitoring /
  apple-events / full-disk / screen-capture prompts cumulatively triggered by
  one `hx install <pkg>` invocation; **target = 1 strict**.
- `commit-with-new-plist-without-retire-count` — count of commits adding a new
  plist file without same-commit retire of an existing plist of the same
  package over a 30d rolling window; **target = 0**.

### 4.4 Falsifier extension (raw 71 ≥3 → ≥6 total post-strengthening)

Existing falsifiers F-RAW241-1 / F-RAW241-2 / F-RAW241-3 (TCC prompt count >
1; legitimate multi-bundle suite false-positive; cdhash-rotation
re-prompt-regression) extended with:

- `F-RAW241-4` 30d post: airgenome OR sister repo (anima / n6 / nexus / hive)
  commit lands a new `com.<vendor>.<sub>.plist` plist after raw 241
  strengthening cutoff = **retire OR scope expansion**.
- `F-RAW241-5` 60d post: `launchctl print gui/$UID` reports ≥2 active plists
  sharing package prefix on any installed sister-repo machine = mandate
  bypass detected = **retire**.
- `F-RAW241-6` 90d post: pre-commit hook fails to fire on a same-commit
  new-plist-without-retire pattern OR is bypassed at frequency N/30d > 0 =
  **mandate erosion** triggering V3 redesign cycle (escalate enforce-layer to
  os-level fs-lock per raw 195 chflags-uchg pattern on the launchd dir).

### 4.5 Carve-out disclosure (raw 91 honest C3 — user `carve-out 0` intent surface)

User directive demands `carve-out 0`. Honest disclosure: even after this
strengthening, the following remain OUTSIDE the violation surface (= NOT raw
241 violations) and are therefore mandate-orthogonal, not mandate-circumvention:

- Plists belonging to **different packages** (different bundle ids, different
  cdhash, different package install lifecycle) — raw 241 mandate is
  per-package.
- Same single binary spawned in **different sub-modes via argv** (e.g.
  `--mode=tap` / `--mode=loop` / `--mode=run-once`) — sub-mode branching of one
  binary is not a new plist.
- An in-process dispatcher (e.g. `airgenome.app` loop dispatcher
  `posix_spawn`-ing `hexa run modules/*.hexa` worker children) producing
  **child processes under one PID hierarchy** — these are child processes, not
  new launchd-registered plists.

These three are intended design surfaces, NOT bypass paths. If empirical
evidence shows any of the three drift into mandate erosion (e.g. carve-out (1)
weaponized as "we just renamed to a 'different package'" workaround), an
additional V3 strengthening cycle is triggered.

### 4.6 Cross-reference cluster (raw cluster: deployment-single-entry-mandate-suite)

raw 241 strengthening forms part of a 7-raw cluster covering deployment
integrity at the single-entry surface:

- **raw 99**  canonical-CLI single entry per project (runtime CLI scope)
- **raw 177** single-TCC-grant entry per project (TCC consent scope)
- **raw 241** launchd plist count per package (this raw — deployment plist
  surface)
- **raw 243** no auto-bootstrap from tool-script (install-hook registration
  scope)
- **raw 244** no watcher-of-watchers (process-graph topology scope)
- **raw 246** `hx install` single entry point (package install pipeline scope)
- **raw 230** positive-canonical-only (banlist hygiene; consumed by §4.1
  intent-keyed phrasing)
- **raw 239** commit-trailer-convergence (consumed by §4.2 pre-commit hook)

Together these define the deployment integrity stack across the install
pipeline → registration → process graph → consent → runtime CLI surface.

---

## 5. Honest C3 disclosure (raw 91)

- **(a) `chflags uchg` is not used at the launchd plist surface in this
  strengthening.** Deferred — escalation to os-level fs-lock is the §4.4
  F-RAW241-6 V3 trigger condition, not the V1 strengthening surface (raw 168
  minimum-viable trade-off accepted).
- **(b) `launchctl print gui/$UID` runtime check is observational at install
  time** and does not detect mid-session out-of-band `launchctl bootstrap`
  invocations after the install hook returns. Mid-session detection is a
  separate axis (continuous audit ledger per raw 77, follow-up cycle).
- **(c) Pre-commit hook adds friction to legitimate plist refactors** (the
  retire-and-readd same-commit pattern is mandatory). Accepted trade-off — the
  friction is the point: same-commit retire makes `prior plist count` and
  `post plist count` both observable in the diff.
- **(d) Carve-out (1) (different packages) cannot prevent
  package-fragmentation as bypass.** If a future PR splits airgenome into
  airgenome-harvest + airgenome-forecast as separate packages (separate
  bundle ids / separate cdhash), each becomes a single-plist-package and
  mandate is satisfied per-package — but at the user TCC consent surface, this
  IS prompt cascade. Cross-axis defense via raw 177 (single-TCC-grant entry
  per project) and raw 99 (canonical-CLI per project) — raw 241 alone does not
  enforce; the 7-raw cluster jointly does.
- **(e) Sister-repo propagation (raw 47 30d ramp) requires per-repo install
  hook + pre-commit hook + design-doc lint to be carried.** Not all sister
  repos currently ship the launchd-plist surface; the strengthening only
  applies once a sister adds one. anima / n6 / nexus / hive each require their
  own bootstrap PR.
- **(f) F-RAW241-6 90d post falsifier is observational only at registration
  time.** It does not block hot-path violations between commit and 90d audit;
  bridge gap covered by §4.2 runtime check.

---

## 6. Verification procedure (raw 192 paired-lint atomicity)

The strengthening clause is registered in the SAME hive commit as:

1. **`tool/raw241_strengthening_2026-04-30_lint.hexa`** — paired lint extending
   the existing `tool/launchd_single_binary_lint.hexa` — see §7 spec.
2. **`tool/raw241_strengthening_2026-04-30_lint.hexa --selftest`** PASS —
   selftest fixture set (≥4 fixtures): F1 single-plist PASS / F2 same-prefix
   ≥2-plist FAIL / F3 new-plist-without-retire-commit FAIL / F4
   supervisor-spawning-N-children FAIL.
3. **`Convergence: <id>`** trailer per raw 239 with id resolving to
   `convergence/INDEX.jsonl` and `<id>.convergence` on disk per raw 234.
4. **`paired-roadmap-id`** entry pointing to airgenome roadmap row tracking
   strengthening adoption (anchored to this proposal file path).
5. **State bootstrap**: `state/launchd_single_binary_audit/audit.jsonl` schema
   already exists per raw 241 entry; strengthening adds `axis` field values
   `launchd-plist-count-per-package` / `tcc-prompt-count-per-package-install`
   / `commit-with-new-plist-without-retire-count` (raw 77 schema additive).

Pre-commit hook implementation outline (advisory wording — implementation
deferred to hive `bin/hexa-commit` strengthening cycle, not airgenome scope):

```
on commit-prepare:
  if any added file matches **/launchd/*.plist or **/LaunchAgents/*.plist:
    require:
      - Convergence: <id> trailer present
      - same-commit diff shows either (a) bootout + rm of an existing same-
        prefix plist OR (b) brand-new package with no prior plist
      - design-doc (launchd_*.md OR install_*.md) updated with plist count
        line in same commit
    on missing requirement:
      reject with raw 241 strengthening 2026-04-30 ai-native trailer (raw 66)
```

---

## 7. Paired tool spec — `tool/raw241_strengthening_2026-04-30_lint.hexa`

(Hexa-lang lint module spec — not implemented in this proposal; spec only.
Implementation lands in the registration commit per raw 192.)

### 7.1 Inputs

- repo working tree
- last commit ref (HEAD)
- staged diff (when invoked from pre-commit context)
- launchd plist directory glob (`**/launchd/**/*.plist` ∪
  `**/LaunchAgents/**/*.plist` ∪ `~/Library/LaunchAgents/*.plist` for runtime
  variant)

### 7.2 Checks (each independently selftested)

- **C1 plist-count-per-prefix**: parse Label of every active plist; group by
  prefix (`com.<vendor>` two-segment match); report any prefix with count > 1.
- **C2 new-plist-without-retire-in-commit**: scan staged diff for `+++`
  paths matching plist glob; for each, require either
  `--- a/<old-plist-path>` (rm) of a same-prefix plist OR no pre-existing
  same-prefix plist in tree.
- **C3 install-hook-bootstrap-without-assertion**: scan `install.hexa` /
  `setup.sh` / `*.post-install` for `launchctl bootstrap` calls; for each,
  require an immediately preceding `launchctl print gui/$UID | grep <prefix>
  | wc -l == 0` assertion (regex-detected).
- **C4 supervisor-spawning-children-plists**: parse plist `ProgramArguments`;
  flag any plist whose program path produces another `launchctl bootstrap`
  call as part of its runtime (heuristic: program path matches a known
  supervisor pattern AND another plist exists with `WatchPaths` pointing
  back).
- **C5 design-doc-plist-count-declared**: scan `docs/launchd_*.md` and
  `docs/install_*.md`; require a line matching `plist-count: <N>` with N == 1
  (or explicit `plist-count: N + rationale: <multi-bundle-suite-clause>` for
  declared exempt).

### 7.3 Selftest fixtures (≥4 fixtures, raw 192 atomicity)

- **F1 PASS** single-plist-package (1 plist `com.airgenome.plist`, 0 same-
  prefix siblings) → C1 PASS / C2 N/A / C3 N/A / C4 PASS / C5 PASS.
- **F2 FAIL** same-prefix multi-plist (`com.airgenome.harvest.plist` +
  `com.airgenome.forecast.plist`) → C1 FAIL.
- **F3 FAIL** new-plist-without-retire commit (added
  `com.airgenome.label.plist` while `com.airgenome.plist` remains) → C2 FAIL.
- **F4 FAIL** supervisor-spawning-children (plist `com.airgenome.supervisor`
  whose ProgramArguments runs `launchctl bootstrap` on a child plist) → C4
  FAIL.

### 7.4 Output

JSONL rows appended to `state/launchd_single_binary_audit/audit.jsonl`:

```
{"ts": "...", "axis": "launchd-plist-count-per-package", "package": "...",
 "value": <N>, "target": 1, "verdict": "PASS"|"FAIL", "check": "C1"|...,
 "fixture": null|"F1"|...}
```

raw 77 schema-conformant. raw 95 triad-satisfied (cli-lint + advisory + paired-
roadmap; install-hook gate elevates to hard-gate at `hx install` execution
time).

---

## 8. Raw 117 5-check self-application (mandatory at registration time)

- **genus-naming (raw 106)**: `launchd-single-binary-tcc-entry-mandate` (no
  `-via/-with/-api` species suffix; composite genus) — preserved. The
  strengthening clause adopts the additional sub-genus
  `absolute-no-multi-launchd-per-package` consistent with raw 106.
- **≥5 cognitive frameworks**: TCC client identity stability (Apple-
  process-identity-keyed prompt model) / Conway's-law (org module split
  bleeding into deployment plist split) / canonical-entry-point (raw 99 +
  raw 177 + raw 246) / write-barrier (commit-time pre-commit gate as semantic
  write barrier for plist surface) / explicit-consent (user directive
  `carve-out 0` collapsing all interpretation channels).
- **≥5 realization channels**: pre-commit lint (`tool/raw241_strengthening_
  2026-04-30_lint.hexa`) / `launchctl print` runtime post-install check /
  install-hook hard-gate at `hx install <pkg>` / design-doc lint asserting
  `plist-count: 1` / commit-trailer convergence (raw 239 `Convergence: <id>`).
- **≥3 counter-examples**: distinct packages with distinct bundle ids
  (different cdhash) / same single-binary sub-mode argv branching / in-process
  child process spawn under one PID hierarchy. Listed in §4.5 as carve-outs
  with explicit honest disclosure that they are mandate-orthogonal not
  bypass.
- **≥3 falsifiers (raw 71)**: F-RAW241-4 (sister-repo new
  `com.<vendor>.<sub>.plist` 30d post) / F-RAW241-5 (`launchctl print` ≥2
  active same-prefix plists 60d post) / F-RAW241-6 (pre-commit-hook bypass
  frequency N/30d > 0 90d post). Total ≥6 falsifiers post-strengthening
  (existing F-RAW241-1 / -2 / -3 carried forward).
- **raw 95 triad**: advisory (existing) + cli-lint (existing + extended) +
  paired-roadmap-id (existing) + ADD: install-hook hard-gate (new tier — quad
  rather than triad post-strengthening, raw 95 triad satisfied a fortiori).

---

## 9. Hard guards / scope (this proposal)

- This file is the only artifact written by this session.
- `/Users/ghost/core/hive/.raw` and `/Users/ghost/core/hexa-lang/.raw` are NOT
  modified.
- No `launchctl bootstrap` / `launchctl load` invocation in this proposal or
  any tool/script referenced.
- No background process spawned.
- English body only (raw 175); Korean limited to user verbatim quotes (raw 33
  carve-out) at §2 and inside the strengthening clause body §3.

---

## 10. Application path

When the user (or hive-cli registration commit) decides to land this
strengthening:

1. Bundle `tool/raw241_strengthening_2026-04-30_lint.hexa` (paired lint per
   §7) IN the same commit (raw 192 atomicity).
2. Append the §3 clause as a continuation line under the raw 241 entry in
   `/Users/ghost/core/hive/.raw`.
3. Bump audit ledger schema in `state/launchd_single_binary_audit/audit.jsonl`
   to include the three new axes (§4.3) per raw 77.
4. Add the §6 pre-commit hook integration to `bin/hexa-commit` in hive (or
   defer to a separate hive cycle if scope-creep blocked).
5. Convergence: `<id>` trailer (raw 239) referencing
   `convergence/INDEX.jsonl` row pointing to a `r<NN>_2026_04_30_raw241_
   strengthening_absolute_no_multi_launchd.convergence` file per raw 234.
6. Cross-repo ramp (raw 47 30d) — anima / n6 / nexus / hive each carry their
   own per-repo bootstrap once they ship a launchd plist surface.

End of proposal.
