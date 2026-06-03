# C-PORT — append-only step log

## 2026-06-03 — init + winctl-geometry split (forge-secp256k1-SPLIT)

- Read all 8 authored Objective-C sources in native/src/ (8055 LOC total).
- Classified: 7/8 = Cocoa/AppKit/CGEvent/AX side-effect floor (irreducible).
- Identified the single cleanest pure-logic island: `winctl_target_rect` in
  airgenome_winctl.m — a pure rect transform (action id + visibleFrame + current
  window → target rect by float arithmetic; zero Cocoa symbols).
- Ported it to native/kernel/winctl_geometry.hexa (hexa-native, airgenome argv
  convention, %.6f output) — SSOT spec for the geometry.
- Lifted the C math 1:1 into native/kernel/winctl_geometry_ref.c (CGRect →
  4-double struct; identical operators + 100.0/120.0 literal + clamp order) so it
  builds with plain `cc` (no Cocoa link).
- RUNEQ: native/kernel/runeq_winctl.sh sweeps a real corpus — 5 window actions +
  identity(case 6/0) × 7 real screens (1080p/1440p/4K/MBP14-notch/MBP16/secondary
  +1920 origin/ultrawide) × 5 windows (incl. oversized→clamp + tiny). Result:
  **245/245 value-exact byte-identical. 🟢 RUNEQ PASS.**
- Verdict persisted verbatim → .verdicts/c-port/winctl-geometry-runeq.txt.
- Cited the kernel SSOT + RUNEQ lock in airgenome_winctl.m's winctl_target_rect
  header (in-process C copy must keep runeq_winctl.sh green).
- Deferred: overload is_claude/is_protected NSString predicates — a thin pure
  candidate, but intertwined with the ps/dispatch pipeline; not the cleanest split
  this round.
