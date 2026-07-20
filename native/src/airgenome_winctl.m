// airgenome_winctl.m — focused-window arrangement hotkeys
//
// hive raw 209 sister axis (window-arrangement-hotkeys-mandate)
// Created: 2026-04-30
//
// Inherited foundational mandates (raw 209 composition):
//   raw 177 cli-single-tcc-entry-per-project — REUSE airgenome.app TCC
//                                              grant; same Accessibility row
//                                              already used by CGEventTap also
//                                              authorizes AXUIElement here
//   raw 178 cli-stable-designated-requirement — INHERIT existing cert-root DR
//   raw 179 cli-multi-user-safe-runtime-path — no fs writes; pure runtime
//   raw 180 cli-system-state-capture-restore — NO-OP (no system defaults
//                                              mutated; AX move/resize is
//                                              per-window in-process state)
//   raw 181 cli-uninstall-state-cleanup — NO-OP (no install state)
//
// Mapping (alt+N on focused window):
//   alt+1  Maximize       — frame = visibleFrame
//   alt+2  100/120 Center — size = visibleFrame * (100/120), centered
//                           (≈83.33% — matches "120% 디스플레이에서 100%만
//                            보이는 영역" semantics; user mandate 2026-04-30)
//   alt+3  Left Half      — left half of visibleFrame
//   alt+4  Right Half     — right half of visibleFrame
//   alt+5  Center Only    — preserve size, center origin
//   alt+6  Top Half       — top half of visibleFrame (상 최대 · user mandate
//                           2026-07-21)
//   alt+7  Bottom Half    — bottom half of visibleFrame (하 최대 · same mandate)
//   alt+0  Dock Reset     — NOT a window action. Resets macOS Dock's
//                           tilesize to a fixed value (recovery from
//                           accidental drag-resize). Default 48px; override
//                           via AIRG_TAP_WINCTL_DOCK_TILE env (clamped 16..128).
//                           Writes com.apple.dock tilesize via CFPreferences,
//                           then SIGHUP-equivalent restart via killall Dock
//                           (Dock auto-respawns; no admin auth needed since
//                           com.apple.dock prefs live in user domain).
//                           (Moved 6→0 per 2026-07-21 mandate to free 6/7 for
//                            top/bottom half.)
//
// Coordinate system note: AX uses GLOBAL screen coords with origin at the
// TOP-LEFT of the PRIMARY screen, while NSScreen.visibleFrame is bottom-left
// origin in a coordinate space spanning all screens. We convert at the
// boundary in compute_target_rect_ax.
//
// Multi-display: raw 168 minimum-viable picks the screen the focused window
// currently sits on (best overlap by area). Future raw can refine for partial
// overlaps and Mission Control space transitions.
//
// Build: linked into airgenome binary alongside _tap.m and _launcher.m
//        (raw 177 single TCC entry — one bundle id, one TCC row).

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

extern BOOL airgenome_winctl_handle_keydown(CGEventRef event);
// Dock tilesize reset — exposed so tap.m's startup can run the same logic
// once on first-install (without duplicating the prefs+killall sequence).
extern void airgenome_winctl_reset_dock_tilesize(void);

// Sentinel action id for the Dock-tilesize reset (system action, not a window
// rect transform). Kept well clear of the 1..7 window-action range so the
// winctl_target_rect geometry never sees it.
#define WINCTL_ACTION_DOCK_RESET 100

// Hotkey table: keycode → action id (1..7 window actions + dock-reset sentinel).
// kVK_ANSI_1..5 = 0x12,0x13,0x14,0x15,0x17 (5 is 0x17 not 0x16); 6 = 0x16;
// 7 = 0x1A; 0 = 0x1D (top-row digit row is non-contiguous on the macOS keymap).
static int winctl_keycode_to_action(int64_t kc) {
    switch (kc) {
        case kVK_ANSI_1: return 1;
        case kVK_ANSI_2: return 2;
        case kVK_ANSI_3: return 3;
        case kVK_ANSI_4: return 4;
        case kVK_ANSI_5: return 5;
        case kVK_ANSI_6: return 6;   // Top half (상 최대)
        case kVK_ANSI_7: return 7;   // Bottom half (하 최대)
        case kVK_ANSI_0: return WINCTL_ACTION_DOCK_RESET;  // Dock reset (moved 6→0)
        default:         return 0;
    }
}

// Reset macOS Dock tilesize to a fixed value, then restart Dock to apply.
// Recovers from accidental drag-resize that left the Dock comically large.
// Env override: AIRG_TAP_WINCTL_DOCK_TILE (int, clamped 16..128). Default 48
// (matches macOS "Medium" preset midpoint — common reset target).
//
// Mechanism: CFPreferencesSetAppValue writes ~/Library/Preferences/
// com.apple.dock.plist; CFPreferencesAppSynchronize flushes; killall Dock
// causes launchd to immediately respawn it with new prefs. raw 91 honest
// C3: every step NSLog'd; failures non-fatal (next reset retry will work).
void airgenome_winctl_reset_dock_tilesize(void) {
    int tile = 48;
    const char *env = getenv("AIRG_TAP_WINCTL_DOCK_TILE");
    if (env && *env) {
        int v = atoi(env);
        if (v >= 16 && v <= 128) tile = v;
        else NSLog(@"[airgenome_winctl] AIRG_TAP_WINCTL_DOCK_TILE=%s out of "
                   @"range [16..128], using default 48", env);
    }
    CFNumberRef num = CFNumberCreate(kCFAllocatorDefault,
                                     kCFNumberIntType, &tile);
    CFPreferencesSetAppValue(CFSTR("tilesize"), num, CFSTR("com.apple.dock"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
    if (num) CFRelease(num);
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/killall";
    task.arguments = @[@"Dock"];
    @try {
        [task launch];
    } @catch (NSException *e) {
        NSLog(@"[airgenome_winctl] killall Dock launch failed: %@", e.reason);
        return;
    }
    NSLog(@"[airgenome_winctl] dock tilesize reset → %d (Dock respawning)",
          tile);
}

// Pick the NSScreen that the AX window rect (top-left global coords) overlaps
// most. Falls back to mainScreen if no overlap (off-screen window edge case).
static NSScreen *winctl_screen_for_ax_rect(CGRect axRect) {
    NSArray<NSScreen *> *screens = [NSScreen screens];
    if (screens.count == 0) return [NSScreen mainScreen];
    // Convert AX rect (top-left primary origin) to NS coords (bottom-left,
    // primary screen frame). Primary is screens[0] in AppKit semantics.
    CGFloat primaryHeight = [screens[0] frame].size.height;
    NSRect winNS = NSMakeRect(axRect.origin.x,
                              primaryHeight - axRect.origin.y - axRect.size.height,
                              axRect.size.width,
                              axRect.size.height);
    NSScreen *best = nil;
    CGFloat bestArea = -1;
    for (NSScreen *s in screens) {
        NSRect inter = NSIntersectionRect(winNS, [s frame]);
        CGFloat a = inter.size.width * inter.size.height;
        if (a > bestArea) { bestArea = a; best = s; }
    }
    return best ? best : [NSScreen mainScreen];
}

// Convert NSScreen.visibleFrame (bottom-left, all-screens space) into AX-space
// (top-left, primary-screen origin) — this is what AXValue position/size want.
static CGRect winctl_visible_frame_ax(NSScreen *screen) {
    NSArray<NSScreen *> *screens = [NSScreen screens];
    CGFloat primaryHeight = screens.count > 0 ? [screens[0] frame].size.height
                                              : [screen frame].size.height;
    NSRect vf = [screen visibleFrame];
    return CGRectMake(vf.origin.x,
                      primaryHeight - vf.origin.y - vf.size.height,
                      vf.size.width,
                      vf.size.height);
}

// Compute target AX rect for action 1..5, given the visibleFrame of the
// screen the window lives on (already in AX coords).
//
// C-PORT (forge-secp256k1-SPLIT): this is the only Cocoa-free math island in
// the native/src/*.m sources. Its pure rect transform is mirrored 1:1 by the
// hexa-native kernel ../kernel/winctl_geometry.hexa, which is the SSOT spec for
// the geometry. This in-process C copy is RUNEQ-locked to that kernel —
// value-exact over the runeq corpus (7 window actions × real screens × windows
// + identity path); see ../kernel/runeq_winctl.sh and the C-PORT domain verdict
// .verdicts/c-port/winctl-geometry-runeq.txt. The menubar tap runs this per
// keystroke in-process (no shell-out), so the kernel stays the spec and any
// edit to the math here MUST keep runeq_winctl.sh green.
static CGRect winctl_target_rect(int action, CGRect vf, CGRect curWin) {
    switch (action) {
        case 1: // Maximize
            return vf;
        case 2: { // 100/120 center (≈83.33%) — user mandate 2026-04-30
            const CGFloat scale = 100.0 / 120.0;
            CGFloat w = vf.size.width  * scale;
            CGFloat h = vf.size.height * scale;
            return CGRectMake(vf.origin.x + (vf.size.width  - w) / 2,
                              vf.origin.y + (vf.size.height - h) / 2,
                              w, h);
        }
        case 3: // Left half
            return CGRectMake(vf.origin.x, vf.origin.y,
                              vf.size.width / 2, vf.size.height);
        case 4: // Right half
            return CGRectMake(vf.origin.x + vf.size.width / 2, vf.origin.y,
                              vf.size.width / 2, vf.size.height);
        case 5: { // Center only — preserve current size
            CGFloat w = curWin.size.width;
            CGFloat h = curWin.size.height;
            // Clamp size to visibleFrame so a giant window still fits.
            if (w > vf.size.width)  w = vf.size.width;
            if (h > vf.size.height) h = vf.size.height;
            return CGRectMake(vf.origin.x + (vf.size.width  - w) / 2,
                              vf.origin.y + (vf.size.height - h) / 2,
                              w, h);
        }
        case 6: // Top half (상 최대) — AX coords: top edge is min y.
            return CGRectMake(vf.origin.x, vf.origin.y,
                              vf.size.width, vf.size.height / 2);
        case 7: // Bottom half (하 최대)
            return CGRectMake(vf.origin.x, vf.origin.y + vf.size.height / 2,
                              vf.size.width, vf.size.height / 2);
        // Dock reset (alt+0) is a system action handled in handle_keydown —
        // it never reaches winctl_target_rect.
        default:
            return curWin;
    }
}

// Get focused window via system-wide AXUIElement. Returns CFTypeRef the caller
// must CFRelease. NULL on any failure (no focused app, no focused window, AX
// permission denied, etc.). raw 91 honest C3: NSLog the failure mode.
static AXUIElementRef winctl_copy_focused_window(void) {
    AXUIElementRef sysWide = AXUIElementCreateSystemWide();
    if (!sysWide) return NULL;
    CFTypeRef appRef = NULL;
    AXError err = AXUIElementCopyAttributeValue(
        sysWide, kAXFocusedApplicationAttribute, &appRef);
    CFRelease(sysWide);
    if (err != kAXErrorSuccess || !appRef) {
        NSLog(@"[airgenome_winctl] no focused app (AX err=%d)", err);
        return NULL;
    }
    CFTypeRef winRef = NULL;
    err = AXUIElementCopyAttributeValue(
        (AXUIElementRef)appRef, kAXFocusedWindowAttribute, &winRef);
    CFRelease(appRef);
    if (err != kAXErrorSuccess || !winRef) {
        NSLog(@"[airgenome_winctl] no focused window (AX err=%d)", err);
        return NULL;
    }
    return (AXUIElementRef)winRef;
}

// Read current position+size of an AX window into a CGRect (AX coords).
static BOOL winctl_read_window_rect(AXUIElementRef win, CGRect *out) {
    if (!win || !out) return NO;
    CFTypeRef posRef = NULL;
    CFTypeRef sizRef = NULL;
    if (AXUIElementCopyAttributeValue(win, kAXPositionAttribute, &posRef) != kAXErrorSuccess
        || !posRef) return NO;
    if (AXUIElementCopyAttributeValue(win, kAXSizeAttribute, &sizRef) != kAXErrorSuccess
        || !sizRef) {
        CFRelease(posRef);
        return NO;
    }
    CGPoint p = CGPointZero;
    CGSize  s = CGSizeZero;
    AXValueGetValue((AXValueRef)posRef, kAXValueCGPointType, &p);
    AXValueGetValue((AXValueRef)sizRef, kAXValueCGSizeType,  &s);
    CFRelease(posRef);
    CFRelease(sizRef);
    *out = CGRectMake(p.x, p.y, s.width, s.height);
    return YES;
}

// AXEnhancedUserInterface lives on the APPLICATION element (not the window).
// Chromium/Electron apps (Chrome, VS Code, Slack) turn this ON when they detect
// an AX client; while it is ON they debounce/ignore programmatic position+size
// writes, so alt+N snap silently no-ops for Chrome even though it works for
// Terminal/Safari/Finder. Canonical fix (Rectangle · yabai · Hammerspoon):
// disable it, apply the frame, restore it. Do NOT touch AXManualAccessibility
// (that enables Chromium's content AX tree → heavy CPU/mem cost).
static const CFStringRef kWinctlAXEnhancedUserInterface =
    CFSTR("AXEnhancedUserInterface");

// Apply target rect to the AX window as size → position → size. First size lets
// the app enforce min/increment constraints, position performs the cross-
// monitor move, final size corrects clamping against the destination display.
// More reliable for Chromium than position→size→position while still fixing the
// Terminal/iTerm re-clamp. AXEnhancedUserInterface is disabled around the writes
// (only when it was already true and the disable succeeds) and restored after.
static void winctl_apply_rect(AXUIElementRef win, CGRect r) {
    if (!win) return;

    // AXEnhancedUserInterface is an application-element attribute. Derive the
    // pid from `win` (not from focused-app, which could change mid-op).
    AXUIElementRef app = NULL;
    pid_t pid = 0;
    if (AXUIElementGetPid(win, &pid) == kAXErrorSuccess && pid > 0)
        app = AXUIElementCreateApplication(pid);

    CFTypeRef originalEnhanced = NULL;
    Boolean restoreEnhanced = false;
    if (app
        && AXUIElementCopyAttributeValue(app, kWinctlAXEnhancedUserInterface,
                                         &originalEnhanced) == kAXErrorSuccess
        && originalEnhanced
        && CFGetTypeID(originalEnhanced) == CFBooleanGetTypeID()
        && CFBooleanGetValue((CFBooleanRef)originalEnhanced)) {
        // Restore only if the disable actually took (VoiceOver can veto it).
        restoreEnhanced =
            AXUIElementSetAttributeValue(app, kWinctlAXEnhancedUserInterface,
                                         kCFBooleanFalse) == kAXErrorSuccess;
    }

    CGPoint p = CGPointMake(r.origin.x, r.origin.y);
    CGSize  s = CGSizeMake(r.size.width, r.size.height);
    AXValueRef sizVal1 = AXValueCreate(kAXValueCGSizeType,  &s);
    if (sizVal1) {
        AXUIElementSetAttributeValue(win, kAXSizeAttribute, sizVal1);
        CFRelease(sizVal1);
    }
    AXValueRef posVal = AXValueCreate(kAXValueCGPointType, &p);
    if (posVal) {
        AXUIElementSetAttributeValue(win, kAXPositionAttribute, posVal);
        CFRelease(posVal);
    }
    AXValueRef sizVal2 = AXValueCreate(kAXValueCGSizeType,  &s);
    if (sizVal2) {
        AXUIElementSetAttributeValue(win, kAXSizeAttribute, sizVal2);
        CFRelease(sizVal2);
    }

    if (restoreEnhanced)
        AXUIElementSetAttributeValue(app, kWinctlAXEnhancedUserInterface,
                                     kCFBooleanTrue);
    if (originalEnhanced) CFRelease(originalEnhanced);
    if (app) CFRelease(app);
}

BOOL airgenome_winctl_handle_keydown(CGEventRef event) {
    if (!event) return NO;
    if (CGEventGetType(event) != kCGEventKeyDown) return NO;
    CGEventFlags flags = CGEventGetFlags(event);
    CGEventFlags relevant = flags & (kCGEventFlagMaskControl
                                     | kCGEventFlagMaskCommand
                                     | kCGEventFlagMaskAlternate
                                     | kCGEventFlagMaskShift);
    // Match: ALT only (no other modifiers — user said "alt+N" exactly).
    // Allowing extra modifiers would conflict with shift+alt+N text input
    // and cmd+alt+N system-reserved chords.
    if (relevant != kCGEventFlagMaskAlternate) return NO;
    int64_t kc = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    int action = winctl_keycode_to_action(kc);
    if (action == 0) return NO;

    // alt+0: system-level Dock tilesize reset, NOT a window manipulation.
    // Bypass the focused-window pipeline entirely (works even with no
    // focused app, e.g. on Desktop / Mission Control).
    if (action == WINCTL_ACTION_DOCK_RESET) {
        airgenome_winctl_reset_dock_tilesize();
        return YES;
    }

    AXUIElementRef win = winctl_copy_focused_window();
    if (!win) return NO;  // no focused window — fall through (don't consume)
    CGRect cur;
    if (!winctl_read_window_rect(win, &cur)) {
        CFRelease(win);
        return NO;
    }
    NSScreen *screen = winctl_screen_for_ax_rect(cur);
    CGRect vf = winctl_visible_frame_ax(screen);
    CGRect target = winctl_target_rect(action, vf, cur);
    winctl_apply_rect(win, target);
    CFRelease(win);
    NSLog(@"[airgenome_winctl] action=%d → (%.0f,%.0f %.0fx%.0f)",
          action, target.origin.x, target.origin.y,
          target.size.width, target.size.height);
    return YES;  // consume event so the underlying app does not see alt+N
}
