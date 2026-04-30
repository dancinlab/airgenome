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
//       {"hotkey": "ctrl+q", "action": "toggle-app",
//        "target": "/Applications/Void.app"},
//       {"hotkey": "ctrl+d", "action": "show-desktop"}
//     ]
//   }
//
// Action types (raw 168 minimum-viable):
//   activate-app: 2-state activate-only on the target app (user mandate
//                  2026-04-30 "이미 실행되있으면 활성화" / hide-on-repeat
//                  REJECTED):
//                  (a) not running       → launch via NSWorkspace + activate
//                  (b) running, inactive → activate (bring to front)
//                  (c) running, active   → no-op (already focused)
//                  Earlier `toggle-app` 3-state cycle was renamed and the
//                  hide-when-active branch removed per direct user spec.
//   show-desktop: post synthetic F11 keydown/up to delegate to macOS
//                  Mission Control "Show Desktop" hotkey, which is itself
//                  a toggle (press = hide windows, press again = restore).
//                  Repeated ⌃D therefore toggles desktop visibility. Requires
//                  user to have F11 bound to Show Desktop (default on
//                  macOS). raw 91 honest C3: if user unbound F11 in Desktop
//                  & Dock settings, this action becomes a no-op silently
//                  — no fallback in this raw 168 minimum-viable iteration.
//
// Hotkey conflict policy: CGEventTap consumes matched events (return NULL
// from tap callback), so user-bound combos OVERRIDE the focused app's
// binding (e.g., ctrl+w globally launches Safari even when Chrome would
// have closed its tab on ctrl+w). User mandate 2026-04-30 "글로벌".

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

// Public API — extern'd by airgenome_tap.m and main() startup.
extern BOOL airgenome_hotkey_handle_keydown(CGEventRef event);
extern void airgenome_hotkey_load_bindings(void);

// Loaded bindings. Each entry is an NSDictionary with keys:
//   keycode    NSNumber (int kVK_*)
//   modifiers  NSNumber (CGEventFlags packed)
//   target     NSString (bundle path; absent for non-app actions)
//   action     NSString ("activate-app" | "show-desktop")
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
    else if ([keyPart isEqualToString:@"escape"]) kc = 0x35;
    else if ([keyPart isEqualToString:@"esc"])    kc = 0x35;
    else if (keyPart.length == 1) {
        kc = hotkey_letter_to_keycode([keyPart characterAtIndex:0]);
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
        // Backwards-compat alias: legacy "toggle-app" configs map to
        // activate-app since that's the post-mandate semantics.
        if ([action isEqualToString:@"toggle-app"]) action = @"activate-app";
        if (![spec isKindOfClass:[NSString class]]) continue;
        if ([action isEqualToString:@"activate-app"]
            && ![target isKindOfClass:[NSString class]]) {
            NSLog(@"[airgenome_hotkey] activate-app missing target: %@", spec);
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
        if ([target isKindOfClass:[NSString class]]) entry[@"target"] = target;
        [g_hotkey_bindings addObject:entry];
        NSLog(@"[airgenome_hotkey] loaded: %@ → %@%@",
              spec, action,
              target ? [@" " stringByAppendingString:target] : @"");
    }
    NSLog(@"[airgenome_hotkey] %lu bindings loaded",
          (unsigned long)g_hotkey_bindings.count);
}

// Find the running NSRunningApplication for a bundle path. Match by
// standardized bundleURL path (resolves trailing slash, ./.., symlinks).
// Returns nil if the app isn't currently running.
static NSRunningApplication *hotkey_find_running(NSString *targetPath) {
    NSURL *targetURL = [NSURL fileURLWithPath:targetPath];
    NSString *target = [[targetURL URLByStandardizingPath] path];
    for (NSRunningApplication *a in
         [[NSWorkspace sharedWorkspace] runningApplications]) {
        NSURL *bundle = a.bundleURL;
        if (!bundle) continue;
        NSString *p = [[bundle URLByStandardizingPath] path];
        if ([p isEqualToString:target]) return a;
    }
    return nil;
}

// activate-app: not-running → launch+activate / running → activate.
// Already-active is a no-op (no hide). User mandate 2026-04-30 rejected
// the earlier 3-state hide-on-repeat cycle. raw 91 honest C3: launch
// failure NSLog'd.
static void hotkey_activate_app(NSString *targetPath) {
    NSRunningApplication *app = hotkey_find_running(targetPath);
    if (!app) {
        NSURL *url = [NSURL fileURLWithPath:targetPath];
        NSWorkspaceOpenConfiguration *cfg =
            [NSWorkspaceOpenConfiguration configuration];
        cfg.activates = YES;
        [[NSWorkspace sharedWorkspace]
            openApplicationAtURL:url
                   configuration:cfg
               completionHandler:^(NSRunningApplication *r, NSError *e) {
            if (e) NSLog(@"[airgenome_hotkey] launch failed: %@ (%@)",
                         targetPath, e.localizedDescription);
            else   NSLog(@"[airgenome_hotkey] launched: %@ pid=%d",
                         targetPath, r.processIdentifier);
        }];
        return;
    }
    if (app.isActive) {
        NSLog(@"[airgenome_hotkey] %@ → already active (no-op)", targetPath);
        return;
    }
    if (app.isHidden) [app unhide];
    if (@available(macOS 14.0, *)) {
        [app activateFromApplication:[NSRunningApplication currentApplication]
                             options:0];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
#pragma clang diagnostic pop
    }
    NSLog(@"[airgenome_hotkey] %@ → activate (was inactive)", targetPath);
}

// Show Desktop: invoke macOS Mission Control's native Show Desktop via the
// private CoreDock notification "com.apple.showdesktop.awake". This is
// the EXACT same internal trigger the system uses when the user presses
// fn+F11 — same animation (windows slide off-screen), same toggle
// behaviour (second invocation slides them back). Identified by string-
// scanning the Mission Control binary; documented across third-party
// macOS automation tools (yabai issue #147 catalogues four such
// notifications: expose.awake / showdesktop.awake / expose.front.awake /
// launchpad.toggle).
//
// Why not synthesize fn+F11 via CGEventPost: tested against kCGHIDEventTap
// and kCGSessionEventTap, with both NULL source and CGEventSourceState-
// CombinedSessionState. First press triggers Show Desktop; second press
// (toggle-back) is silently dropped by the macOS hotkey dispatcher —
// the dispatcher debounces or filters synthesized fn-modifier events at
// the toggle boundary. CoreDockSendNotification bypasses the keystroke
// path entirely and posts directly to the Dock process's notification
// listener, which is what owns Show Desktop's toggle state.
//
// raw 213 compliance: Tier-C exempt — private API call into Apple's own
// Dock framework via dlopen-free extern. NO admin privileges, NO shell-
// out. Stable across 10.7 → Sequoia (15) per yabai/Hammerspoon community
// usage. Tahoe-26 verified at install time (this file's deploy target).
extern void CoreDockSendNotification(CFStringRef notification,
                                     void *unused);

static void hotkey_show_desktop(void) {
    CoreDockSendNotification(CFSTR("com.apple.showdesktop.awake"), NULL);
    NSLog(@"[airgenome_hotkey] show-desktop (CoreDockSendNotification)");
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
            hotkey_activate_app(b[@"target"]);
            return YES;  // CONSUME — global override per user mandate
        }
        if ([action isEqualToString:@"show-desktop"]) {
            hotkey_show_desktop();
            return YES;
        }
        NSLog(@"[airgenome_hotkey] unknown action '%@' for %@",
              action, b[@"spec"]);
        return NO;
    }
    return NO;
}
