// airgenome_hotkey.m — user-defined hotkey → app/system action binder
//
// hive raw 209 sister axis #3 (hotkey-action-binder, deferred per raw 49
// additive-first, activated 2026-04-30 per user mandate).
//
// Inherited foundational mandates (raw 209 composition):
//   raw 177 single TCC entry — REUSE airgenome.app TCC grant (CGEventTap
//                              already armed; this module hooks the same
//                              callback chain via airgenome_tap.m a2 slot)
//   raw 178 stable DR — INHERIT existing cert-root-based DR
//   raw 179 multi-user-safe path — config at NSHomeDirectory/Library/
//                                  Application Support/airgenome/
//   raw 180 capture/restore — NO-OP (binding lookup mutates no system state;
//                             show-desktop posts a synthetic key, doesn't
//                             write defaults)
//   raw 181 install/uninstall symmetry — Makefile uninstall removes config
//                                         (raw 168 follow-up if missing)
//
// Config file: ~/Library/Application Support/airgenome/hotkey_bindings.json
// Schema:
//   {
//     "bindings": [
//       {"hotkey": "ctrl+q", "action": "activate-app",
//        "target": "/Applications/Void.app"}
//     ]
//   }
//
// Action types (single canonical action per user mandate 2026-05-04
// "activate-app 하나로 통일 / 토글기능도 자동으로 같이 갖는거야"):
//   activate-app: 4-state launch / activate / unminimize / hide cycle:
//                  (a) not running               → launch + activate
//                  (b) running, inactive         → activate (raise)
//                  (c) active w/ minimized wins  → unminimize-all + raise
//                  (d) active, all visible       → hide
//                  Use for any app hotkey: switcher, popover, scratchpad.
//                  Pressing the hotkey while the app is foregrounded with
//                  every window visible dismisses it; pressing again
//                  re-activates.
//
// Hardcoded built-ins (see airgenome_hotkey_handle_default_keydown
// below) — NOT user-bindable. User mandate 2026-05-04 round 2 "기본기능
// 으로 구현해야됨 / hotkey 아님" clarifies the same-day mandate: "기본
// 기능" means always-on built-in inside airgenome's own tap, NOT
// "delegate to OS shortcut" (the earlier delete-and-defer interpretation
// was wrong twice — first for fn+F11, then for ⌘`).
//
//   ⌃D            show-desktop  CoreDockSendNotification awake
//   ⌘Esc / ⌘`     cycle-windows AX raise on stable-WID-sorted window list
//
// cycle-windows: round 3 attempt (cf6b42ba v1 cycled only 2 windows on
// Safari n>=3 because kAXWindowsAttribute returns z-order — after raising
// window B it becomes index 0, "next" is always index 1 → oscillates).
// Fix: stable ordering via _AXUIElementGetWindow's CGWindowID + a static
// "last-raised WID" so the next press picks the WID strictly greater
// than last (wrapping to smallest). Independent of post-raise z-order
// changes → cycles cleanly through n>=3 windows. macOS native ⌘` had
// the same n>=3 regression on Tahoe-26 (user mandate 2026-05-04 "보니까
// 2개까지는 되는데 3개부터 또 안됨"), which is why we own this path.
//
// Hotkey conflict policy: CGEventTap consumes matched events (return NULL
// from tap callback), so user-bound combos OVERRIDE the focused app's
// binding (e.g., ctrl+w globally launches Safari even when Chrome would
// have closed its tab on ctrl+w). User mandate 2026-04-30 "글로벌".

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

// SkyLight private API — canonical app activation from background process.
// Symbol still exported on Tahoe-26 SDK (verified at SkyLight.tbd line 928).
// Used by yabai/chunkwm/skhd for ~10 years across macOS 10.x → 26.
//
// Why we need this: AppKit activation paths (NSRunningApplication.activate-
// FromApplication: / NSWorkspace.openApplicationAtURL:) go through "polite
// yield" policy on macOS 14+/Tahoe-26 — when called from a background
// daemon, the OS silently drops the request. Symptom: ⌃R does NOTHING
// (Notes neither raises nor menu-bar-swaps). User report 2026-04-30
// "아예 안나오는 문제 였어". SkyLight bypasses AppKit entirely and posts
// to WindowServer directly with kCPSUserGenerated flag, which marks the
// activation as user-initiated → no background-source rate-limiting.
//
// raw 213 Tier-C exempt: this module already calls private API (Core-
// DockSendNotification for show-desktop, line 414). Single TCC grant
// preserved: SkyLight call is in-process, no AppleEvents, no admin auth.
extern CGError _SLPSSetFrontProcessWithOptions(ProcessSerialNumber *psn,
                                                uint32_t wid, uint32_t mode);
// kCPSUserGenerated 0x200: marks activation as user-initiated → bypasses
// background-source "polite yield". Stable Carbon constant since 10.x.
#ifndef kCPSUserGenerated
#define kCPSUserGenerated 0x200
#endif

// Public API — extern'd by airgenome_tap.m and main() startup.
extern BOOL airgenome_hotkey_handle_keydown(CGEventRef event);
extern BOOL airgenome_hotkey_handle_default_keydown(CGEventRef event);
extern BOOL airgenome_hotkey_handle_pip_keydown(CGEventRef event);
extern void airgenome_hotkey_load_bindings(void);

// Show Desktop: posts the same private Dock notification that Mission
// Control fires on fn+F11. Identified via Mission Control binary string-
// scan; documented across third-party automation tools (yabai #147
// catalogues four such notifications). Synthesizing fn+F11 via
// CGEventPost was tried first (kCGHIDEventTap and kCGSessionEventTap,
// NULL and CombinedSessionState sources) — first press triggers but the
// macOS hotkey dispatcher silently drops the toggle-back. Posting the
// Dock notification directly bypasses the keystroke dispatcher and uses
// the system's own toggle state, so the second ⌃D consistently slides
// windows back. Stable 10.7 → Tahoe-26 per yabai/Hammerspoon usage.
//
// raw 213 Tier-C exempt: in-process private API call. Single TCC grant
// preserved (no AppleEvents, no admin auth).
extern void CoreDockSendNotification(CFStringRef notification, void *unused);

// AX → CGWindowID. Private but stable since 10.5; used by yabai, Hammer-
// spoon, Rectangle, etc. Required for cycle-windows stable ordering:
// kAXWindowsAttribute returns windows in z-order, so the array index of
// any given window changes after every raise. CGWindowID is allocated
// monotonically per-window-creation and never changes for the lifetime
// of the window → gives us a key we can sort by deterministically.
//
// raw 213 Tier-C exempt: in-process private symbol, no TCC delta (AX
// permission already granted via CGEventTap).
extern AXError _AXUIElementGetWindow(AXUIElementRef element,
                                     uint32_t *windowID);

// Forward decl: resolver lives below, but the binding loader (above) calls it.
static BOOL hotkey_resolve_target(NSString *raw, NSString **outPath,
                                  NSString **outBundleID);

// Loaded bindings. Each entry is an NSDictionary with keys:
//   keycode    NSNumber (int kVK_*)
//   modifiers  NSNumber (CGEventFlags packed)
//   target     NSString (bundle path; absent for non-app actions)
//   action     NSString ("activate-app" — the only action type)
//   spec       NSString (original "ctrl+q" form, for diagnostic logs)
static NSMutableArray<NSDictionary *> *g_hotkey_bindings = nil;

// Map a-z → kVK_ANSI_*. Same table as airgenome_launcher.m's local copy;
// raw 168 minimum-viable accepts the duplication (10 lines) over creating
// a shared header just for one constant table. raw 169 surgical follow-up
// can extract to airgenome_keymap.h if a third caller appears.
static int hotkey_letter_to_keycode(char c) {
    static const int map[26] = {
        0x00, 0x0B, 0x08, 0x02, 0x0E, 0x03, 0x05, 0x04,  // a b c d e f g h
        0x22, 0x26, 0x28, 0x25, 0x2E, 0x2D, 0x1F, 0x23,  // i j k l m n o p
        0x0C, 0x0F, 0x01, 0x11, 0x20, 0x09, 0x0D, 0x07,  // q r s t u v w x
        0x10, 0x06                                        // y z
    };
    if (c < 'a' || c > 'z') return -1;
    return map[c - 'a'];
}

// Parse "ctrl+cmd+q" / "alt+space" / "shift+ctrl+escape" into a (modifier-
// flags, keycode) pair. Returns NO if any component is unparsable; the
// loader logs the bad spec and skips that binding (other bindings load OK).
static BOOL hotkey_parse_spec(NSString *spec, int *kc_out,
                              CGEventFlags *flags_out) {
    if (!spec || !kc_out || !flags_out) return NO;
    NSString *low = [spec lowercaseString];
    CGEventFlags flags = 0;
    if ([low rangeOfString:@"ctrl"].location  != NSNotFound) flags |= kCGEventFlagMaskControl;
    if ([low rangeOfString:@"cmd"].location   != NSNotFound) flags |= kCGEventFlagMaskCommand;
    if ([low rangeOfString:@"alt"].location   != NSNotFound) flags |= kCGEventFlagMaskAlternate;
    if ([low rangeOfString:@"opt"].location   != NSNotFound) flags |= kCGEventFlagMaskAlternate;
    if ([low rangeOfString:@"shift"].location != NSNotFound) flags |= kCGEventFlagMaskShift;
    NSRange last = [low rangeOfString:@"+" options:NSBackwardsSearch];
    NSString *keyPart = last.location == NSNotFound
        ? low : [low substringFromIndex:last.location + 1];
    if (keyPart.length == 0 || flags == 0) return NO;
    int kc = -1;
    if      ([keyPart isEqualToString:@"space"])  kc = 0x31;
    else if ([keyPart isEqualToString:@"tab"])    kc = 0x30;
    else if ([keyPart isEqualToString:@"return"]) kc = 0x24;
    else if ([keyPart isEqualToString:@"enter"])  kc = 0x24;
    else if ([keyPart isEqualToString:@"escape"])   kc = 0x35;
    else if ([keyPart isEqualToString:@"esc"])      kc = 0x35;
    else if ([keyPart isEqualToString:@"backtick"]) kc = 0x32;  // kVK_ANSI_Grave
    else if ([keyPart isEqualToString:@"grave"])    kc = 0x32;
    else if (keyPart.length == 1) {
        char c = [keyPart characterAtIndex:0];
        if (c >= 'a' && c <= 'z') {
            kc = hotkey_letter_to_keycode(c);
        } else if (c >= '0' && c <= '9') {
            // kVK_ANSI_<digit> keycodes — separate table because the
            // top-row digit row is non-contiguous on the macOS keymap
            // (e.g. 5/6 swap mid-table).
            static const int dmap[10] = {
                0x1D, 0x12, 0x13, 0x14, 0x15,  // 0 1 2 3 4
                0x17, 0x16, 0x1A, 0x1C, 0x19   // 5 6 7 8 9
            };
            kc = dmap[c - '0'];
        } else if (c == '`') {
            kc = 0x32;  // backtick / grave — also accepted as literal
        }
    }
    if (kc < 0) return NO;
    *kc_out = kc;
    *flags_out = flags;
    return YES;
}

void airgenome_hotkey_load_bindings(void) {
    g_hotkey_bindings = [NSMutableArray array];
    NSString *path = [NSHomeDirectory()
        stringByAppendingPathComponent:
            @"Library/Application Support/airgenome/hotkey_bindings.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        NSLog(@"[airgenome_hotkey] no config at %@ (skipping)", path);
        return;
    }
    NSError *err = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data
                                                 options:0
                                                   error:&err];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[airgenome_hotkey] config not an object: %@",
              err.localizedDescription);
        return;
    }
    NSArray *bindings = ((NSDictionary *)parsed)[@"bindings"];
    if (![bindings isKindOfClass:[NSArray class]]) {
        NSLog(@"[airgenome_hotkey] missing 'bindings' array");
        return;
    }
    for (NSDictionary *b in bindings) {
        if (![b isKindOfClass:[NSDictionary class]]) continue;
        NSString *spec   = b[@"hotkey"];
        NSString *target = b[@"target"];
        NSString *action = b[@"action"] ?: @"activate-app";
        if (![spec isKindOfClass:[NSString class]]) continue;
        BOOL needsTarget = [action isEqualToString:@"activate-app"];
        if (needsTarget && ![target isKindOfClass:[NSString class]]) {
            NSLog(@"[airgenome_hotkey] %@ missing target: %@", action, spec);
            continue;
        }
        int kc = 0;
        CGEventFlags flags = 0;
        if (!hotkey_parse_spec(spec, &kc, &flags)) {
            NSLog(@"[airgenome_hotkey] unparsable hotkey: %@", spec);
            continue;
        }
        NSMutableDictionary *entry = [@{
            @"keycode":   @(kc),
            @"modifiers": @((unsigned long long)flags),
            @"action":    action,
            @"spec":      spec
        } mutableCopy];
        if (needsTarget) {
            NSString *resolvedPath = nil, *resolvedBID = nil;
            if (!hotkey_resolve_target(target, &resolvedPath, &resolvedBID)) {
                NSLog(@"[airgenome_hotkey] %@ unresolvable target '%@' for %@",
                      action, target, spec);
                continue;
            }
            entry[@"target"]    = resolvedPath;
            entry[@"bundle_id"] = resolvedBID;
        }
        [g_hotkey_bindings addObject:entry];
        if (needsTarget) {
            NSLog(@"[airgenome_hotkey] loaded: %@ → %@ %@ [%@]",
                  spec, action, entry[@"target"], entry[@"bundle_id"]);
        } else {
            NSLog(@"[airgenome_hotkey] loaded: %@ → %@", spec, action);
        }
    }
    NSLog(@"[airgenome_hotkey] %lu bindings loaded",
          (unsigned long)g_hotkey_bindings.count);
}

// Resolve a user-supplied `target` string to a canonical (bundlePath,
// bundleIdentifier) pair. User mandate 2026-04-30 "json에 application/
// void.app 이렇게 이름만 바뀌어도 작동해야함 / 하드코딩금지" — config
// must tolerate path-case variations and bare app names without the
// runtime hardcoding a fixed lookup table.
//
// Accepted input forms:
//   "/Applications/Void.app"          — absolute path (existing path wins)
//   "/applications/void.app"          — case-mismatched path (HFS+ case-
//                                       insensitive; literal exists check
//                                       still resolves it on default vols)
//   "Void.app" / "Void" / "void"      — bare app name (delegated to
//                                       NSWorkspace which case-insensitively
//                                       searches /Applications,
//                                       /System/Applications, etc.)
//   "com.apple.Safari"                — bundle identifier (heuristic:
//                                       contains '.' but no '/' and no
//                                       ".app" suffix)
//
// Resolution canonicalises everything to (a) the actual on-disk bundle
// path and (b) the Info.plist bundle identifier. Runtime matching uses
// the bundle ID, which is immune to path/case/symlink variation (Tahoe-26
// cryptex relocation also collapses cleanly because the bundle ID is
// stable across the symlink).
static BOOL hotkey_resolve_target(NSString *raw, NSString **outPath,
                                  NSString **outBundleID) {
    if (![raw isKindOfClass:[NSString class]] || raw.length == 0) return NO;
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSBundle *bundle = nil;

    // Form 1: absolute path that exists on disk (HFS+ default = case-
    // insensitive, so "/applications/void.app" hits the same inode).
    if ([raw hasPrefix:@"/"]
        && [[NSFileManager defaultManager] fileExistsAtPath:raw]) {
        bundle = [NSBundle bundleWithPath:raw];
    }

    // Form 2: bundle identifier (dotted, no slash, no .app suffix).
    if (!bundle
        && [raw containsString:@"."]
        && ![raw containsString:@"/"]
        && ![raw.lowercaseString hasSuffix:@".app"]) {
        NSURL *url = [ws URLForApplicationWithBundleIdentifier:raw];
        if (url) bundle = [NSBundle bundleWithURL:url];
    }

    // Form 3: bare name — strip trailing .app, hand to NSWorkspace which
    // searches the standard application domains case-insensitively.
    if (!bundle) {
        NSString *name = raw.lastPathComponent;
        if ([name.lowercaseString hasSuffix:@".app"])
            name = [name substringToIndex:name.length - 4];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSString *resolved = [ws fullPathForApplication:name];
#pragma clang diagnostic pop
        if (resolved) bundle = [NSBundle bundleWithPath:resolved];
    }

    if (!bundle) return NO;
    NSString *bid  = bundle.bundleIdentifier;
    NSString *path = bundle.bundlePath;
    if (!bid || !path) return NO;
    if (outPath)     *outPath     = path;
    if (outBundleID) *outBundleID = bid;
    return YES;
}

// Find the running NSRunningApplication by bundle identifier. Bundle ID
// is the canonical app identity — survives Tahoe-26 cryptex symlinks,
// path-case mismatches, and whatever literal string the user wrote in
// hotkey_bindings.json (we already resolved it to the on-disk bundle's
// CFBundleIdentifier at load time).
static NSRunningApplication *hotkey_find_running(NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]]) return nil;
    for (NSRunningApplication *a in
         [[NSWorkspace sharedWorkspace] runningApplications]) {
        if ([a.bundleIdentifier isEqualToString:bundleID]) return a;
    }
    return nil;
}

// Single-TCC-grant activate/hide path — no AppleEvents triggered.
//
// User mandate 2026-04-30 "시스템 폴더 하나허용으로 fix" — N target apps
// previously caused N separate "airgenome would like to control X"
// dialogs (kTCCServiceAppleEvents per target). Both primitives below
// route through APIs that do NOT send AppleEvents, so only the existing
// kTCCServiceAccessibility grant (already required for the CGEventTap)
// is needed.
//
// activate: NSRunningApplication.activateFromApplication:options: (macOS
// 14+) wraps the canonical private SkyLight call _SLPSSetFrontProcess-
// WithOptions(&psn, 0, kCPSUserGenerated) — same path yabai uses
// directly via dlsym. No AppleEvents path; just a CGS message to
// WindowServer. Confirmed via tcc-log inspection on Tahoe-26.
//
// hide: AX kAXHiddenAttribute=true on the application AXUIElement. Goes
// through Apple's AX framework (HIServices), which is bound to
// kTCCServiceAccessibility — the same grant that already authorizes
// airgenome's CGEventTap. NSRunningApplication.hide was REJECTED here
// because it sends kAEHide via the AppleEvents manager, prompting
// per-target. raw 178 stable DR: AX is a single grant covering all apps.
static void hotkey_ax_hide(pid_t pid) {
    AXUIElementRef appEl = AXUIElementCreateApplication(pid);
    if (!appEl) return;
    AXUIElementSetAttributeValue(appEl, kAXHiddenAttribute, kCFBooleanTrue);
    CFRelease(appEl);
}

// User report 2026-04-30 (round 2) "메뉴바엔 뜨는데 창은 안보여": SkyLight
// activation succeeds (menu bar swaps to target app) but no window surfaces.
// Two sub-cases conflated in the user-visible symptom:
//   (i)  zero-window state — Notes was Cmd+W'd previously, or never opened
//        a window in this session. SkyLight only changes the front PROCESS;
//        it does NOT trigger window creation. The system's normal "Dock
//        icon click" path sends an 'rapp' (kAEReopenApplication) AppleEvent
//        which the app's delegate handles in applicationShouldHandleReopen:-
//        hasVisibleWindows: by creating a default window. SkyLight skips
//        that codepath entirely.
//   (ii) all-minimized state — windows exist but every one is genie'd into
//        the Dock. Activation brings the menu bar but the Dock-tile windows
//        stay shrunk.
//
// Fix (post-SkyLight remediation, AX-only — no per-app TCC):
//   (i)  Query AXWindows. If the count is 0, dispatch NSWorkspace.openAppli-
//        cationAtURL:configuration: with activates=YES. For an already-
//        running app this routes through launchservicesd, which sends the
//        'rapp' on the workspace's behalf — the system-mediated path, NOT
//        a direct AppleEvent from airgenome, so it does NOT prompt the
//        per-target "would like to control X" TCC dialog (raw 178 single-
//        grant invariant preserved). Notes' delegate then opens a window.
//   (ii) For each minimized window, AXUIElementSetAttributeValue with
//        kAXMinimizedAttribute=false. AX is bound to the existing
//        kTCCServiceAccessibility grant (same as the CGEventTap), so this
//        also stays inside the single-TCC envelope.
static void hotkey_ensure_window_visible(NSRunningApplication *app) {
    pid_t pid = app.processIdentifier;
    AXUIElementRef appEl = AXUIElementCreateApplication(pid);
    if (!appEl) return;

    CFArrayRef windows = NULL;
    AXError e = AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute,
                                              (CFTypeRef *)&windows);
    CFIndex count = (e == kAXErrorSuccess && windows)
                    ? CFArrayGetCount(windows) : 0;

    if (count == 0) {
        if (windows) CFRelease(windows);
        CFRelease(appEl);
        NSURL *url = app.bundleURL;
        if (!url) return;
        NSWorkspaceOpenConfiguration *cfg =
            [NSWorkspaceOpenConfiguration configuration];
        cfg.activates = YES;
        [[NSWorkspace sharedWorkspace]
            openApplicationAtURL:url
                   configuration:cfg
               completionHandler:^(NSRunningApplication *r, NSError *err) {
            if (err) NSLog(@"[airgenome_hotkey] reopen failed: %@ (%@)",
                           url.path, err.localizedDescription);
            (void)r;
        }];
        NSLog(@"[airgenome_hotkey] %@ → reopen (no windows, AX count=0)",
              app.bundleIdentifier);
        return;
    }

    NSInteger deminimized = 0;
    for (CFIndex i = 0; i < count; i++) {
        AXUIElementRef w = (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
        CFTypeRef minimized = NULL;
        if (AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute, &minimized)
            != kAXErrorSuccess || !minimized) continue;
        BOOL isMin = CFEqual(minimized, kCFBooleanTrue);
        CFRelease(minimized);
        if (isMin) {
            AXUIElementSetAttributeValue(w, kAXMinimizedAttribute,
                                         kCFBooleanFalse);
            deminimized++;
        }
    }
    CFRelease(windows);
    CFRelease(appEl);
    if (deminimized > 0) {
        NSLog(@"[airgenome_hotkey] %@ → deminimized %ld/%ld windows",
              app.bundleIdentifier, (long)deminimized, (long)count);
    }
}

// User report 2026-04-30 "ctrl+r 메모 아예 안나오는 문제 였어": AppKit
// activation (activateFromApplication: / NSWorkspace.openApplicationAtURL:)
// silently drops on macOS 14+/Tahoe-26 when called from a background
// daemon — the OS "polite yield" policy decides Notes shouldn't be
// activated and produces NO visible state change (no menu bar swap, no
// raise, no error).
//
// Canonical fix (yabai/chunkwm/skhd pattern, ~10 years stable): post
// directly to WindowServer via SkyLight's _SLPSSetFrontProcessWithOptions
// with kCPSUserGenerated flag. This bypasses AppKit entirely; the flag
// marks the activation as user-initiated so WindowServer doesn't apply
// background-source rate-limiting. PSN comes from Carbon's GetProcess-
// ForPID, which is deprecated since 10.9 but still functional on
// Tahoe-26 (yabai uses the same family of Carbon process APIs).
//
// raw 91 honest C3: if GetProcessForPID fails (extremely unlikely for a
// process we just discovered via NSRunningApplication), fall back to
// NSWorkspace.openApplicationAtURL: — even a "polite" attempt is better
// than silent failure.
static void hotkey_activate_running(NSRunningApplication *app) {
    if (app.isHidden) {
        AXUIElementRef appEl =
            AXUIElementCreateApplication(app.processIdentifier);
        if (appEl) {
            AXUIElementSetAttributeValue(appEl, kAXHiddenAttribute,
                                         kCFBooleanFalse);
            CFRelease(appEl);
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    ProcessSerialNumber psn = { 0, 0 };
    OSStatus s = GetProcessForPID(app.processIdentifier, &psn);
#pragma clang diagnostic pop
    if (s == noErr) {
        CGError e = _SLPSSetFrontProcessWithOptions(&psn, 0,
                                                    kCPSUserGenerated);
        if (e == kCGErrorSuccess) {
            NSLog(@"[airgenome_hotkey] %@ → activate via SkyLight (pid=%d)",
                  app.bundleIdentifier, app.processIdentifier);
            hotkey_ensure_window_visible(app);
            return;
        }
        NSLog(@"[airgenome_hotkey] SkyLight activate err=%d, falling back",
              e);
    } else {
        NSLog(@"[airgenome_hotkey] GetProcessForPID(%d) err=%d, falling back",
              app.processIdentifier, (int)s);
    }
    // Fallback: NSWorkspace.openApplicationAtURL: with cfg.activates=YES.
    // LaunchServices path — less reliable from background but better than
    // nothing if SkyLight ever stops working on a future macOS. This path
    // ALSO triggers 'rapp' for already-running apps, so a successful
    // fallback inherently handles the no-window case (no extra
    // hotkey_ensure_window_visible call needed here).
    NSURL *url = app.bundleURL;
    if (!url) return;
    NSWorkspaceOpenConfiguration *cfg =
        [NSWorkspaceOpenConfiguration configuration];
    cfg.activates = YES;
    [[NSWorkspace sharedWorkspace]
        openApplicationAtURL:url
               configuration:cfg
           completionHandler:^(NSRunningApplication *r, NSError *e) {
        if (e) NSLog(@"[airgenome_hotkey] fallback activate failed: %@ (%@)",
                     url.path, e.localizedDescription);
        (void)r;
    }];
}

// activate-app: not-running → launch+activate / running → activate.
// Already-active is a no-op (no hide). User mandate 2026-04-30 rejected
// the earlier 3-state hide-on-repeat cycle. raw 91 honest C3: launch
// failure NSLog'd.
// activate-app: launch (if not running) → activate (if running but
// inactive) → unminimize-all (if active w/ minimized windows) → hide
// (if active w/ all windows visible). Toggle-on-active is built in
// per user mandate 2026-05-04 "활성화 + 토글기능도 자동으로 같이
// 갖는거야" — collapses what used to be two separate action types
// (activate-app + toggle-app) into one canonical behavior.
//
// State machine (4-state, evaluated in order):
//   (a) not running                       → launch (NSWorkspace open)
//   (b) running, inactive                 → activate (raise frontmost)
//   (c) active w/ minimized windows       → un-minimize all + re-raise
//   (d) active, all windows visible       → hide
//
// User mandate threading:
//   2026-04-30 "⌃R → Notes scratchpad: pressing again from inside Notes
//                should dismiss it" — gives state (d).
//   2026-05-01 "활성화 -> 비활성화 보단 일단 활성화 먼저 / 창이 여러개
//                있는경우 뒤에 숨겨진것도 다시 다 활성화 / 거기서 또
//                누르면 비활성화 토글" — gives state (c) two-press cycle.
//   2026-05-04 "activate-app 하나로 통일 / 토글기능도 자동으로 같이
//                갖는거야" — collapse to single action.
static void hotkey_activate_app(NSString *targetPath, NSString *bundleID) {
    NSRunningApplication *app = hotkey_find_running(bundleID);
    if (!app) {
        NSURL *url = [NSURL fileURLWithPath:targetPath];
        NSWorkspaceOpenConfiguration *cfg =
            [NSWorkspaceOpenConfiguration configuration];
        cfg.activates = YES;
        [[NSWorkspace sharedWorkspace]
            openApplicationAtURL:url
                   configuration:cfg
               completionHandler:^(NSRunningApplication *r, NSError *e) {
            if (e) NSLog(@"[airgenome_hotkey] toggle launch failed: %@ (%@)",
                         targetPath, e.localizedDescription);
            else   NSLog(@"[airgenome_hotkey] toggle launched: %@ pid=%d",
                         targetPath, r.processIdentifier);
        }];
        return;
    }
    if (app.isActive) {
        // 2-press cycle on the active state per user mandate 2026-05-01
        // "활성화 -> 비활성화 보단 일단 활성화 먼저 / 창이 여러개 있는경우
        // 뒤에 숨겨진것도 다시 다 활성화 / 거기서 또 누르면 비활성화 토글":
        //
        //   active + has minimized windows  → un-minimize all + re-raise
        //                                     the app (don't hide yet)
        //   active + all windows visible    → hide
        //
        // Detection is via kAXMinimizedAttribute on each window. Apps
        // hidden via Cmd+H surface as isActive=NO above, so we only
        // need to handle the minimization sub-state here.
        BOOL hadMinimized = NO;
        AXUIElementRef appEl = AXUIElementCreateApplication(
            app.processIdentifier);
        if (appEl) {
            CFTypeRef windowsRef = NULL;
            if (AXUIElementCopyAttributeValue(
                    appEl, kAXWindowsAttribute, &windowsRef)
                == kAXErrorSuccess && windowsRef) {
                CFArrayRef windows = (CFArrayRef)windowsRef;
                CFIndex n = CFArrayGetCount(windows);
                for (CFIndex i = 0; i < n; i++) {
                    AXUIElementRef w = (AXUIElementRef)
                        CFArrayGetValueAtIndex(windows, i);
                    CFTypeRef minRef = NULL;
                    if (AXUIElementCopyAttributeValue(
                            w, kAXMinimizedAttribute, &minRef)
                        == kAXErrorSuccess && minRef) {
                        if (CFBooleanGetValue((CFBooleanRef)minRef)) {
                            hadMinimized = YES;
                            AXUIElementSetAttributeValue(
                                w, kAXMinimizedAttribute,
                                kCFBooleanFalse);
                        }
                        CFRelease(minRef);
                    }
                }
                CFRelease(windows);
            }
            CFRelease(appEl);
        }
        if (hadMinimized) {
            // Re-activate so the just-restored windows actually surface
            // above whatever was layered in front of them.
            hotkey_activate_running(app);
            NSLog(@"[airgenome_hotkey] %@ → unminimize all + raise "
                  @"(active w/ minimized windows)", bundleID);
            return;
        }
        hotkey_ax_hide(app.processIdentifier);
        NSLog(@"[airgenome_hotkey] %@ → hide (was active, all visible)",
              bundleID);
        return;
    }
    hotkey_activate_running(app);
    NSLog(@"[airgenome_hotkey] %@ → activate (was inactive)", bundleID);
}

// Cycle through the frontmost app's windows in stable WID order. Picks
// the window whose CGWindowID is the smallest one strictly greater than
// the previously-raised WID for this pid; wraps to the smallest WID
// when no such window exists. Per-pid memory of "last raised" lets us
// keep cycling forward across n>=3 windows even though kAXWindowsAttribute
// keeps reordering by z-order behind us. Skips minimized windows so
// behavior matches user expectation of ⌘` (visible windows only).
//
// state reset on pid change: when frontmost app changes, last_pid no
// longer matches, so we start from current focused window's WID.
static void hotkey_cycle_app_windows(void) {
    static pid_t   s_last_pid = 0;
    static uint32_t s_last_wid = 0;

    NSRunningApplication *front =
        [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (!front) return;
    pid_t pid = front.processIdentifier;
    AXUIElementRef appEl = AXUIElementCreateApplication(pid);
    if (!appEl) return;

    CFTypeRef windowsRef = NULL;
    AXError e = AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute,
                                              &windowsRef);
    if (e != kAXErrorSuccess || !windowsRef) {
        if (windowsRef) CFRelease(windowsRef);
        CFRelease(appEl);
        return;
    }
    CFArrayRef windows = (CFArrayRef)windowsRef;
    CFIndex n = CFArrayGetCount(windows);
    if (n < 2) { CFRelease(windows); CFRelease(appEl); return; }

    // Build (wid, AXUIElementRef) list for non-minimized windows only.
    uint32_t        wids[64];
    AXUIElementRef  refs[64];
    CFIndex visible = 0;
    for (CFIndex i = 0; i < n && visible < 64; i++) {
        AXUIElementRef w = (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
        CFTypeRef minRef = NULL;
        BOOL isMin = NO;
        if (AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute, &minRef)
                == kAXErrorSuccess && minRef) {
            isMin = CFBooleanGetValue((CFBooleanRef)minRef);
            CFRelease(minRef);
        }
        if (isMin) continue;
        uint32_t wid = 0;
        if (_AXUIElementGetWindow(w, &wid) != kAXErrorSuccess || wid == 0)
            continue;
        wids[visible] = wid;
        refs[visible] = w;
        visible++;
    }
    if (visible < 2) { CFRelease(windows); CFRelease(appEl); return; }

    // Insertion sort (visible <= 64, almost always <10).
    for (CFIndex i = 1; i < visible; i++) {
        uint32_t kw = wids[i]; AXUIElementRef kr = refs[i]; CFIndex j = i;
        while (j > 0 && wids[j - 1] > kw) {
            wids[j] = wids[j - 1]; refs[j] = refs[j - 1]; j--;
        }
        wids[j] = kw; refs[j] = kr;
    }

    // Pick smallest wid > s_last_wid (if pid matches), else smallest.
    CFIndex chosen = 0;
    if (pid == s_last_pid && s_last_wid != 0) {
        chosen = -1;
        for (CFIndex i = 0; i < visible; i++) {
            if (wids[i] > s_last_wid) { chosen = i; break; }
        }
        if (chosen < 0) chosen = 0;  // wrap
    } else {
        // First press on this app: jump to the next window after the
        // currently-focused one so the very first ⌘` advances rather
        // than re-raising the already-focused window.
        uint32_t focusedWid = 0;
        CFTypeRef focusedRef = NULL;
        if (AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute,
                                          &focusedRef) == kAXErrorSuccess
            && focusedRef) {
            _AXUIElementGetWindow((AXUIElementRef)focusedRef, &focusedWid);
            CFRelease(focusedRef);
        }
        chosen = 0;
        if (focusedWid != 0) {
            for (CFIndex i = 0; i < visible; i++) {
                if (wids[i] > focusedWid) { chosen = i; break; }
            }
        }
    }

    [front activateWithOptions:0];
    AXUIElementSetAttributeValue(refs[chosen], kAXMainAttribute,
                                 kCFBooleanTrue);
    AXUIElementPerformAction(refs[chosen], kAXRaiseAction);
    s_last_pid = pid;
    s_last_wid = wids[chosen];
    NSLog(@"[airgenome_hotkey] cycle-windows pid=%d wid=%u (idx=%ld/%ld)",
          pid, wids[chosen], (long)chosen, (long)visible);

    CFRelease(windows);
    CFRelease(appEl);
}

// Built-in defaults — hardcoded in airgenome's tap, NOT routed through
// hotkey_bindings.json. User mandate 2026-05-04 round 2 "기본기능으로
// 구현해야됨 / hotkey 아님": treat these as always-on base features
// inside our own tap (the earlier same-day delete-and-defer-to-OS
// interpretation was wrong — fn+F11 was never the user's request, and
// macOS native ⌘` has the same n>=3 regression on Tahoe-26).
//
//   ⌃D            show-desktop   CoreDockSendNotification awake
//   ⌘Esc / ⌘`     cycle-windows  stable-WID AX raise
//
// Evaluated before the user-binding lookup so a stale matching entry in
// hotkey_bindings.json doesn't shadow the built-in. Returns YES to
// consume the event.
BOOL airgenome_hotkey_handle_default_keydown(CGEventRef event) {
    if (!event || CGEventGetType(event) != kCGEventKeyDown) return NO;
    CGEventFlags relevant = CGEventGetFlags(event)
        & (kCGEventFlagMaskControl | kCGEventFlagMaskCommand
           | kCGEventFlagMaskAlternate | kCGEventFlagMaskShift);
    int64_t kc = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    if (relevant == kCGEventFlagMaskControl && kc == kVK_ANSI_D) {
        CoreDockSendNotification(CFSTR("com.apple.showdesktop.awake"), NULL);
        NSLog(@"[airgenome_hotkey] ⌃D → show-desktop (built-in)");
        return YES;
    }
    if (relevant == kCGEventFlagMaskCommand
        && (kc == kVK_Escape || kc == kVK_ANSI_Grave)) {
        hotkey_cycle_app_windows();
        return YES;
    }
    return NO;
}

// ---------------------------------------------------------------------------
// Built-in: ⌥P (option+P) globally → toggle YouTube PiP in Safari, regardless
// of frontmost app.
// ---------------------------------------------------------------------------
//
// Use case: user is coding in Void (or any other app) while a YouTube tab is
// open in Safari. ⌥P toggles PiP without ⌘Tab-ing to Safari.
//
// Why ⌥P (and not bare 'p'):
//   bare 'p' globally would hijack every 'p' keystroke in any text input
//   (Void editor, terminal, search boxes). ⌥P maps to "π" glyph input on
//   default macOS layouts — almost never typed in practice. Single modifier
//   keeps the keystroke light vs ⌘⌥P / ⌃⌘P.
//
// Mechanism:
//   AppleScript iterates Safari's open documents (across all windows), finds
//   the first one whose URL contains "youtube.com", and injects the canonical
//   webkitSetPresentationMode toggle JS into it. The page-context JS installs
//   a capture-phase stopPropagation guard against YouTube's own
//   webkitpresentationmodechanged handler (which would otherwise revert PiP
//   back to inline immediately) — same pattern as MacRumors / vordenken's
//   AutoPiP content.js / Joe Seifi.
//
// No-op cases (handler still consumes ⌥P to keep behavior consistent):
//   - Safari not running                  → osascript reports "safari not running"
//   - Safari running but no YouTube tab   → osascript reports "no youtube tab"
//   - Safari has YouTube tab but no <video>→ JS no-op silently
//
// Required setup (one-time): Safari → Develop → "Allow JavaScript from Apple
// Events". Without it osascript returns rc=1 + AppleEvent permission prompt.

static void pip_run_osascript_async(void) {
    // page-context JS — capture-phase stopPropagation defeats YouTube's
    // webkitpresentationmodechanged listener that snaps PiP back to inline.
    static NSString *const kJS =
        @"var v=document.querySelector('video');"
        @"if(v&&v.webkitSupportsPresentationMode){"
        @"v.addEventListener('webkitpresentationmodechanged',"
        @"function(e){e.stopPropagation();},true);"
        @"var m=v.webkitPresentationMode;"
        @"v.webkitSetPresentationMode("
        @"m==='picture-in-picture'?'inline':'picture-in-picture');"
        @"}";
    NSString *escaped = [kJS stringByReplacingOccurrencesOfString:@"\""
                                                       withString:@"\\\""];
    // 'application "Safari" is running' guard avoids launching Safari just to
    // check; iterate documents across all windows; first youtube.com tab wins.
    NSString *script = [NSString stringWithFormat:
        @"if application \"Safari\" is running then\n"
        @"  tell application \"Safari\"\n"
        @"    repeat with d in documents\n"
        @"      try\n"
        @"        if URL of d contains \"youtube.com\" then\n"
        @"          do JavaScript \"%@\" in d\n"
        @"          return \"ok\"\n"
        @"        end if\n"
        @"      end try\n"
        @"    end repeat\n"
        @"    return \"no youtube tab\"\n"
        @"  end tell\n"
        @"end if\n"
        @"return \"safari not running\"",
        escaped];
    dispatch_async(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSTask *t = [NSTask new];
            t.launchPath = @"/usr/bin/osascript";
            t.arguments = @[@"-e", script];
            NSPipe *outPipe = [NSPipe pipe];
            t.standardOutput = outPipe;
            t.standardError = [NSPipe pipe];
            @try {
                [t launch];
                [t waitUntilExit];
                NSData *data =
                    [outPipe.fileHandleForReading readDataToEndOfFile];
                NSString *result =
                    [[[NSString alloc] initWithData:data
                                           encoding:NSUTF8StringEncoding]
                     stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (t.terminationStatus != 0) {
                    NSLog(@"[airgenome_pip] osascript rc=%d "
                          @"(enable Safari → Develop → "
                          @"Allow JavaScript from Apple Events)",
                          t.terminationStatus);
                } else {
                    NSLog(@"[airgenome_pip] osascript ok: %@", result);
                }
            } @catch (NSException *ex) {
                NSLog(@"[airgenome_pip] osascript launch failed: %@", ex);
            }
        }
    });
}

BOOL airgenome_hotkey_handle_pip_keydown(CGEventRef event) {
    if (!event || CGEventGetType(event) != kCGEventKeyDown) return NO;
    int64_t kc = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    if (kc != kVK_ANSI_P) return NO;

    // Require exactly ⌥ (Option) — no Cmd/Ctrl/Shift. Other combos pass
    // through so ⌘P (print), ⌃P, etc. retain their normal behavior.
    CGEventFlags relevant = CGEventGetFlags(event)
        & (kCGEventFlagMaskControl | kCGEventFlagMaskCommand
           | kCGEventFlagMaskAlternate | kCGEventFlagMaskShift);
    if (relevant != kCGEventFlagMaskAlternate) return NO;

    pip_run_osascript_async();
    NSLog(@"[airgenome_pip] ⌥P → Safari/YouTube PiP toggle (global)");
    return YES;
}

BOOL airgenome_hotkey_handle_keydown(CGEventRef event) {
    if (!event || CGEventGetType(event) != kCGEventKeyDown) return NO;
    if (!g_hotkey_bindings || g_hotkey_bindings.count == 0) return NO;
    CGEventFlags flags = CGEventGetFlags(event);
    CGEventFlags relevant = flags & (kCGEventFlagMaskControl
                                     | kCGEventFlagMaskCommand
                                     | kCGEventFlagMaskAlternate
                                     | kCGEventFlagMaskShift);
    int64_t kc = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    for (NSDictionary *b in g_hotkey_bindings) {
        CGEventFlags want =
            (CGEventFlags)[b[@"modifiers"] unsignedLongLongValue];
        int wantKc = [b[@"keycode"] intValue];
        if (relevant != want || kc != wantKc) continue;
        NSString *action = b[@"action"];
        if ([action isEqualToString:@"activate-app"]) {
            hotkey_activate_app(b[@"target"], b[@"bundle_id"]);
            return YES;  // CONSUME — global override per user mandate
        }
        NSLog(@"[airgenome_hotkey] unknown action '%@' for %@",
              action, b[@"spec"]);
        return NO;
    }
    return NO;
}
