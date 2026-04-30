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

// Hotkey table: keycode → action id 1..5.
// kVK_ANSI_1..5 = 0x12, 0x13, 0x14, 0x15, 0x17 (note: 5 is 0x17 not 0x16).
static int winctl_keycode_to_action(int64_t kc) {
    switch (kc) {
        case kVK_ANSI_1: return 1;
        case kVK_ANSI_2: return 2;
        case kVK_ANSI_3: return 3;
        case kVK_ANSI_4: return 4;
        case kVK_ANSI_5: return 5;
        default:         return 0;
    }
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

// Apply target rect to the AX window (set position then size — order matters
// when window goes to a different monitor, since size could be clamped to
// the OLD monitor before position moves it).
static void winctl_apply_rect(AXUIElementRef win, CGRect r) {
    CGPoint p = CGPointMake(r.origin.x, r.origin.y);
    CGSize  s = CGSizeMake(r.size.width, r.size.height);
    AXValueRef posVal = AXValueCreate(kAXValueCGPointType, &p);
    AXValueRef sizVal = AXValueCreate(kAXValueCGSizeType,  &s);
    if (posVal) {
        AXUIElementSetAttributeValue(win, kAXPositionAttribute, posVal);
        CFRelease(posVal);
    }
    if (sizVal) {
        AXUIElementSetAttributeValue(win, kAXSizeAttribute, sizVal);
        CFRelease(sizVal);
    }
    // Second position pass: some apps (Terminal, iTerm) honor size first then
    // re-clamp position — repeating position keeps origin authoritative.
    posVal = AXValueCreate(kAXValueCGPointType, &p);
    if (posVal) {
        AXUIElementSetAttributeValue(win, kAXPositionAttribute, posVal);
        CFRelease(posVal);
    }
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
