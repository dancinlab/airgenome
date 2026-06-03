# C-PORT — current state

@title: 🔁 C-PORT — airgenome C-family → hexa-native extraction

@goal: airgenome 의 authored C-family 소스(8 Objective-C 파일, native/src/*.m[m])에서
**순수 로직 커널**을 hexa-native 로 추출하고 RUNEQ value-exact 게이트로 잠근다. Cocoa/AppKit/
CGEvent/AX FFI 호출은 얇은 Obj-C shim 으로 남긴다(irreducible platform floor). forge-secp256k1-SPLIT
패턴 — 한 라운드 한 커널, 가장 깨끗한 분리부터.

## inventory — 8 authored Objective-C sources (native/src/)

| file | LOC | nature | pure-logic island? |
|------|----:|--------|--------------------|
| airgenome_winctl.m   |  ~301 | AX window arrange + Dock reset | ✅ `winctl_target_rect` (rect geometry math) — EXTRACTED |
| airgenome_overload.m |   419 | load watcher · taskpolicy · notify | ⚪ side-effect floor (popen/ps · taskpolicy · NSUserNotification · dispatch timer); is_claude/is_protected are NSString-bound predicates, not cleanly liftable this round |
| airgenome_hotkey.m   |   910 | CGEventTap chord remap | ⚪ Cocoa-FFI (CGEventTap · SkyLight activation · NSWorkspace) |
| airgenome_launcher.m | 2616 | menubar app / status item | ⚪ Cocoa-FFI (NSStatusItem · NSMenu · app lifecycle) |
| airgenome_loop.m     | 1310 | per-app throttle loop driver | ⚪ Cocoa-FFI (NSWorkspace · dispatch · shell-out) |
| airgenome_tap.m      | 2216 | CGEventTap install + routing | ⚪ Cocoa-FFI (CGEventTap · TCC · AX) |
| airgenome_notify.m   |   151 | NSUserNotification helper | ⚪ pure Cocoa side-effect |
| airgenome_helper.mm  |   142 | privileged helper FFI | ⚪ pure Cocoa/CF side-effect |

7/8 = Cocoa-FFI-irreducible (platform floor). 1/8 has a cleanly separable pure-logic island.

## @goal milestones

- [x] inventory 8 native/src/*.m[m] · classify pure-logic vs Cocoa-floor
- [x] extract winctl_target_rect geometry → native/kernel/winctl_geometry.hexa
- [x] C reference harness (native/kernel/winctl_geometry_ref.c) lifted 1:1 from .m
- [x] RUNEQ sweep 245 cases (5 actions × 7 real screens × 5 windows + identity) → 🟢 PASS value-exact
- [x] FFI-shim cite: winctl.m winctl_target_rect documents the hexa kernel SSOT + RUNEQ lock
- [x] C-PORT domain + verdict (.verdicts/c-port/winctl-geometry-runeq.txt)
- [ ] (deferred) overload is_claude/is_protected predicate kernel — needs a hexa string-match harness fed from a real `ps` corpus; not this round's cleanest split

## closure status

- 🟢 **winctl-geometry**: TERMINAL. winctl_target_rect pure rect transform ported to
  hexa-native + RUNEQ value-exact (245/245, %.6f byte-identical) vs the C reference lifted
  straight from the .m. Cocoa stays in the shim (AXUIElement · NSScreen · CGEvent). The
  in-process C copy is RUNEQ-locked to the kernel SSOT (runeq_winctl.sh must stay green).
- ⚪ remaining 7 sources = pure Cocoa/AppKit/CGEvent/AX side-effect = irreducible platform
  floor. No further cleanly-separable pure-logic island this round (overload predicates are a
  thin candidate but NSString-bound + intertwined with the dispatch/ps pipeline — deferred).

tier counts: 1 🟢 extracted+RUNEQ · 7 ⚪ Cocoa-floor (1 of those, overload, holds a deferred
thin candidate). airgenome authored C-family = NOT yet terminal (one deferred candidate remains).
