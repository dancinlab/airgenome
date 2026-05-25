#!/usr/bin/env tape
# NEXUS.tape — airgenome intra-project reuse lattice (SSOT)
# Canonical structured SSOT of the intra-repo module reuse graph.
# Migrated from the README "NEXUS — reuse lattice" section (now a pointer to this file).
# Governance: commons @D g67 (universal · intra-project ONLY).
# Structure: airgenome is a SINGLE-HUB (hub-and-spoke) — every module fans out
#   radially from `airgenome/core/airgenome` (the 60-byte genome core); modules
#   never cross-import each other (README invariant #2). The lattice is therefore
#   shallow by design; §candidate edges promote to REAL on future commonization.
# Scope: intra-project ONLY — never link domains across repos (@D g67).
#
# Block legend:
#   @I nexus              — identity (kind · scope · single-hub note)
#   @X e<n> :: reuse-edge       — a VERIFIED reuse edge (one provides -> one reused_by)
#   @X p<n> :: provides         — a module's provides[] registry (primitives it offers)
#   @X c<n> :: reuse-candidate  — a conceptual edge, no code reuse yet (proposed)
#   @N n<n> :: note             — usage protocol / human ASCII graph view
# Block type is @X (External-citation / declarative, one of the closed 17-type
# alphabet @S@U@A@T@R@H@D@K@P@?@I@X@F@N@C@L@V). Body keys are free-form (the
# @D-only do/dont field restriction does NOT apply to @X). Lints clean v1.2.

@V := "tape" :: spec [active]
  version = "1.2"

@I nexus := "airgenome intra-project reuse lattice" :: identity [active]
  kind      = "intra-repo module reuse graph — verified primitives shared between sibling modules"
  scope     = "intra-project ONLY — never link domains across repos (@D g67)"
  structure = "single-hub (hub-and-spoke) — all modules fan out from airgenome/core/airgenome; no cross-module import (README invariant #2)"
  ssot      = "this file (NEXUS.tape) · README NEXUS section is a pointer to it"
  governs   = "commons @D g67 (universal)"

# ── 1. VERIFIED reuse edges (provides -> reused_by, with evidence) ──

@X e1 := "airgenome genome core -> 28 modules" :: reuse-edge [active]
  provides  = "airgenome/core/airgenome"
  primitive = "60-byte genome core (Vitals · sample · assess · AdaptiveThrottle)"
  reused_by = "28 modules — predictive_throttle · filters x5 · run · core_test · bench x~21"
  evidence  = "use \"...airgenome/core/airgenome\" x 28 (README invariant #2)"

@X e2 := "bench_lib -> 4 bench modules" :: reuse-edge [active]
  provides  = "tool/bench/bench_lib"
  primitive = "5B-stage bench common helper (ns timing · synth ring · result report)"
  reused_by = "bench_f64 · bench_f65 · bench_f45 · bench_f66"
  evidence  = "use \"./bench_lib\" x 4"

@X e3 := "safari_active_throttle_signal -> bench_f64_active_signal" :: reuse-edge [active]
  provides  = "filters/module/process/safari_active_throttle_signal"
  primitive = "safari active-throttle signal filter"
  reused_by = "tool/bench/bench_f64_active_signal"
  evidence  = "// Target: declaration"

@X e4 := "safari_bg_tab_throttle_genome -> bench_f45_safari_genome" :: reuse-edge [active]
  provides  = "filters/module/data/safari_bg_tab_throttle_genome"
  primitive = "safari bg-tab throttle genome filter"
  reused_by = "tool/bench/bench_f45_safari_genome"
  evidence  = "// Target: declaration"

@X e5 := "safari_youtube_gpu_filter -> bench_f65_youtube_gpu" :: reuse-edge [active]
  provides  = "filters/module/process/safari_youtube_gpu_filter"
  primitive = "safari youtube-gpu filter"
  reused_by = "tool/bench/bench_f65_youtube_gpu"
  evidence  = "// Target: declaration"

@X e6 := "safari_battery_freeze_filter -> bench_f66_battery_freeze" :: reuse-edge [active]
  provides  = "filters/module/process/safari_battery_freeze_filter"
  primitive = "safari battery-freeze filter"
  reused_by = "tool/bench/bench_f66_battery_freeze"
  evidence  = "// Target: declaration"

# REAL edges = 6 (core hub 1 + bench_lib 1 + bench<->filter verify-pair 4).

# ── 2. provides[] registry (per-module offered primitives) ──

@X p1 := "airgenome/core/airgenome provides" :: provides [active]
  domain     = "airgenome/core/airgenome"
  primitives = "60-byte genome core · Vitals · sample · assess · AdaptiveThrottle (all-module hub)"

@X p2 := "tool/bench/bench_lib provides" :: provides [active]
  domain     = "tool/bench/bench_lib"
  primitives = "bench common helper (ns diff · synth ring · 5-tuple report standard)"

@X p3 := "columnar_projection provides" :: provides [candidate active]
  domain     = "filters/module/data/columnar_projection"
  primitives = "JSONL columnar projection (2x-9x vs jq full-scan) — repeated-query cache pattern"
  note       = "candidate reused-by"

@X p4 := "trie_mmap provides" :: provides [candidate active]
  domain     = "filters/module/data/prefix_trie_mmap (PTBF) · autocomplete_trie_mmap (APBF)"
  primitives = "prefix-trie / pool blob mmap generalization primitive"
  note       = "candidate reused-by"

@X p5 := "transport/base provides" :: provides [candidate active]
  domain     = "filters/module/transport/base"
  primitives = "hook-gate common utils (safe_exec · state freshness)"
  note       = "candidate reused-by"

# ── 3. candidate edges (conceptual · no code reuse yet) ──

@X c1 := "columnar_projection <-> bench/forecast append pattern" :: reuse-candidate [proposed draft]
  note = "columnar cache pattern could be reused by genomes.ring / forecast.jsonl queries — unverified"

@X c2 := "prefix_trie_mmap (PTBF) <-> autocomplete_trie_mmap (APBF)" :: reuse-candidate [proposed draft]
  note = "same trie-blob family — could merge into a shared mmap-layout primitive — unverified"

@X c3 := "transport/base gate utils <-> filters/data modules" :: reuse-candidate [proposed draft]
  note = "safe_exec · state-freshness could be commonized — currently inlined per module — unverified"

@X c4 := "remaining ~77 bench <-> filters/data filters" :: reuse-candidate [proposed draft]
  note = "only 4 bench<->filter 1:1 verify-pairs carry // Target:; most bench are synth-only (loose filter coupling) — pair unfixed"

# ── 4. usage protocol (atlas-first · @D g67) ──

@N n1 := "reuse protocol" :: note [active]
  step1 = "before building a primitive — `hexa atlas lookup --prefix=<topic>` + sibling-module grep (`grep -rl '<primitive>' --include=\"*.hexa\"`)"
  step2 = "on reuse stamp the module header — `// Target:` (bench) or `use \"...\"` (import)"
  step3 = "add the edge here (one @X e<n> reuse-edge block) — this file is the SSOT"

@N n2 := "single-hub honesty note" :: note [active]
  text = "airgenome's real lattice is core/ 1-hub + bench harness, so the cross-module lattice is shallow (intended invariant #2 — no module-to-module import). §candidate promotes to REAL on future commonization."

@N n3 := "human ASCII graph view" :: note [active]
  graph <<~GRAPH
                          +--> predictive_throttle/module
                          +--> filters/module/process · data  (5 direct imports)
  airgenome/core/airgenome +--> run.hexa
     (60-byte genome hub)  +--> airgenome/core/test/core_test
                          +--> tool/bench/* (28 modules total)
                                     |
  tool/bench/bench_lib --common helper--+ (4 bench import)
                                     | Target:
  filters/module/process · data <--verify pair-- tool/bench/bench_f{45,64,65,66}
  GRAPH
