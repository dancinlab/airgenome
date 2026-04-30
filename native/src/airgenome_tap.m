// airgenome_tap.m -- unified CGEventTap + AX shim for airgenome.
//
// Consolidates the previous two single-purpose shims into a single binary
// so macOS Accessibility / TCC only needs ONE permission grant for the
// whole airgenome input stack:
//
//   (a) Mouse button 4 / 5  -> Cmd+[ / Cmd+]
//       (Finder/Safari/Xcode back/forward)
//   (b) Mouse-wheel scroll inversion -- mouse only, trackpad untouched
//       (kCGScrollWheelEventIsContinuous == 1 -> trackpad -> passthrough)
//   (c) Drag-to-edge 8-zone window snap (top/bottom/left/right halves +
//       four corner quarters), plus macOS Sequoia/Tahoe native tiling
//       lockout while the daemon is alive.
//
// Build:  clang -O2 -Wall -Wextra -ObjC
//                -framework ApplicationServices -framework Carbon
//                -framework Cocoa -framework AppKit -framework IOKit
//                -o build/airgenome native/src/airgenome_tap.m
//
// raw 213 (cli-osascript-shell-out-os-escalation-ban-mandate, 2026-04-30):
//   Wake (sleep prevention) and Wake-when-lid-closed are implemented via
//   IOKit IOPMAssertionCreateWithName held IN-PROCESS — NO osascript admin
//   shell-out, NO LaunchAgent indirection, NO pmset shell-out, NO admin auth
//   dialog. Native Apple primitive (IOKit/IOPMLib.h):
//     Wake             = kIOPMAssertionTypePreventUserIdleDisplaySleep
//                        (display + system idle + screen-saver auto-lock)
//     Wake-lid-closed  = kIOPMAssertionTypePreventSystemSleep (lid-close survive)
//   raw 91 honest C3: kIOPMAssertionTypePreventSystemSleep is documented Apple
//   side as effective only on AC power; on battery + lid close some Apple
//   Silicon Macs sleep regardless (hardware-level enforcement). Apps like
//   Amphetamine use private APIs; we use ONLY public API per raw 9 hexa-only.
//
// Run:    build/airgenome                              (foreground test)
//         launchctl bootstrap gui/$UID
//             ~/Library/LaunchAgents/com.airgenome.tap.plist
//
// Permission: System Settings -> Privacy & Security -> Accessibility ->
//             enable build/airgenome (one-time grant; covers all features).
//
// Sentinel (raw#80):
//   __AIRGENOME_TAP_RESULT__ <PASS|FAIL> reason=<slug>     (stderr)
//
// Feature toggles (env vars, read once at startup):
//   AIRG_TAP_MOUSE_BUTTONS=1       button4/5 -> Cmd+[/]            (default 1)
//   AIRG_TAP_MOUSE_SCROLL=1        mouse-wheel inversion           (default 1)
//   AIRG_TAP_MAGNET=1              8-zone window snap              (default 1)
//   AIRG_TAP_DISABLE_NATIVE=1      flip Sequoia/Tahoe tiling off   (default 1)
//   AIRG_TAP_EDGE_PX=20            edge-half threshold pixels
//   AIRG_TAP_CORNER_PX=40          corner-quarter threshold pixels
//   AIRG_TAP_DRAG_MIN_PX=8         click-vs-drag distance threshold
//
// Lineage:
//   - mouse_remap (~/core/mouse_remap, archive)
//   - window_magnet (~/core/window_magnet, archive)
// Both are kept on disk per raw#21 (deprecated-symlink-ban) but no longer
// have their own LaunchAgents -- this single binary supersedes them.

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>

// ---------------------------------------------------------------------------
// Configuration (env-overridable at startup)
// ---------------------------------------------------------------------------

// Stable macOS constants -- raw#15 no-hardcode opt-out: @const named below.
static const int  BUTTON_BACK     = 3;   // mouse4 -- historically "back"
static const int  BUTTON_FORWARD  = 4;   // mouse5 -- historically "forward"
static const CGKeyCode KEY_BRACKET_L = kVK_ANSI_LeftBracket;
static const CGKeyCode KEY_BRACKET_R = kVK_ANSI_RightBracket;

// Feature flags
static int g_buttons_on  = 1;
static int g_scroll_on   = 1;
static int g_magnet_on   = 1;
static int g_disable_native = 1;
static int g_launcher_on = 1;   // ctrl+s app launcher overlay; hive raw 209
                                 // (default ON 2026-04-30 — user expectation
                                 // is "installed = working"; menubar can OFF)
static int g_winctl_on   = 1;   // alt+1..5 window arrange; raw 209 sister axis
static int g_debug       = 0;   // set via AIRG_TAP_DEBUG=1, logs every event

// hive raw 209 reference impl - declared in airgenome_launcher.m, linked
// into the same binary (raw 177 single TCC entry per project).
extern BOOL airgenome_launcher_handle_keydown(CGEventRef event);
// hive raw 209 sister axis - declared in airgenome_winctl.m, same binary.
extern BOOL airgenome_winctl_handle_keydown(CGEventRef event);
extern void airgenome_winctl_reset_dock_tilesize(void);

// Magnet thresholds (pixels). Generous defaults for multi-monitor and
// 4K/5K layouts -- a 20px reach feels invisible at high pixel densities.
// User-overridable via AIRG_TAP_{EDGE,CORNER}_PX env vars.
static int EDGE_THRESHOLD_PX    = 80;
static int CORNER_THRESHOLD_PX  = 160;
static int DRAG_MIN_DISTANCE_PX = 8;

// Top-edge guard: while dragging, clamp the cursor's reported y coordinate
// to be >= SPACES_GUARD_PX so macOS Mission Control's "drag-to-top reveals
// Spaces strip" hover-detector never sees y == 0. Mouse-up events are NOT
// clamped, so our snap classifier still sees the user's true intent and
// snaps to the top half. Empirically 8px is enough to prevent the trigger
// while remaining invisible during normal drags.
static int SPACES_GUARD_PX      = 8;

// Menu-bar status item icon -- SF Symbol "dna" (macOS 13+, double helix).
// Forced to white via contentTintColor so it stays bright on dark menu
// bars; users with a light menu bar can override the tint by editing
// install_status_item(). A short text fallback ("ag") is used if the
// symbol is unavailable on older macOS.
static NSString * const STATUS_BAR_SYMBOL   = @"dna";
static NSString * const STATUS_BAR_FALLBACK = @"ag";

// Native-tiling defaults keys (com.apple.WindowManager domain).
static const char *KEY_EDGE_DRAG     = "EnableTilingByEdgeDrag";
static const char *KEY_TOP_EDGE_DRAG = "EnableTopTilingByEdgeDrag";
static const char *KEY_OPTION_ACCEL  = "EnableTilingOptionAccelerator";

// ---------------------------------------------------------------------------
// Runtime state
// ---------------------------------------------------------------------------

static CFMachPortRef    g_tap            = NULL;

// Drag detection state for the magnet feature.
static int              g_dragging       = 0;
static CGPoint          g_drag_start_pt  = {0, 0};
static AXUIElementRef   g_drag_window    = NULL;
// Title-bar-drag whitelist (the ONLY gate). At LeftMouseDown we capture
// the focused window's frame.origin into g_drag_window_origin_at_start.
// During the drag we re-read the window's origin on every dragged event;
// once it has moved by >= TITLE_BAR_DRAG_THRESHOLD_PX we flip
// g_window_actually_moved to 1 and only THEN do we run the magnet
// pipeline (zone classification, preview, top-edge y-clamp, snap on up).
//
// Rationale: title-bar drags move the window; URL-bar / Finder-icon /
// text / image / attachment drag-to-copy gestures all share the property
// that the source window does NOT move. So a window-position delta is the
// single sufficient whitelist for "this is a real window drag".
static CGPoint          g_drag_window_origin_at_start = {0, 0};
static int              g_window_actually_moved       = 0;
static int              TITLE_BAR_DRAG_THRESHOLD_PX   = 3;

// Native-tiling restore state. -1 = "key was unset originally" so on
// restore we delete the override rather than forcing a value the user
// never had.
static int  g_native_modified   = 0;
static int  g_orig_edge_drag    = -1;
static int  g_orig_top_drag     = -1;
static int  g_orig_option_accel = -1;

// Menu-bar status item -- strong reference keeps the item alive for the
// lifetime of the process. Released in main() after [NSApp run] returns.
static NSStatusItem *g_status_item = nil;

// Menu items + target reference -- runtime-toggleable per-feature checkmarks
// (Mouse / Magnet / Wake / Lid-Closed-Awake). Strong refs keep them alive.
@class AirgenomeMenuTarget;
static NSMenuItem         *g_item_mouse  = nil;
static NSMenuItem         *g_item_magnet = nil;
static NSMenuItem         *g_item_wake   = nil;
static NSMenuItem         *g_item_lid    = nil;
static NSMenuItem         *g_item_winctl = nil;
static NSMenuItem         *g_item_launcher = nil;
static AirgenomeMenuTarget *g_menu_target = nil;

// Snap-preview overlay -- a borderless transparent window with a white
// outline + faint fill, shown over the screen rect that the window will
// snap into if the drag releases right now. Strong reference keeps it
// alive across drag cycles; orderOut hides without deallocating.
static NSWindow *g_preview_window = nil;

// Singleton lock -- prevents two airgenome processes from racing both
// installing a menu-bar status item, which would result in two visible
// icons in the menu bar. flock() releases automatically on process death,
// so even SIGKILL leaves no stale lock behind.
static int g_singleton_fd = -1;
#define SINGLETON_LOCK_PATH "/tmp/com.airgenome.tap.lock"

// raw 213 (2026-04-30) — IOPMAssertion held in-process. Lifetime tied to the
// airgenome.app process; on shutdown the kernel auto-releases assertions
// belonging to a dying process so a SIGKILL never leaves a stale Wake state.
// Persisted in menubar.state (wake=on/off, lid_closed=on/off) so RunAtLoad
// rehydrates from disk and the assertion is recreated on next launch.
static IOPMAssertionID g_wake_assertion = kIOPMNullAssertionID;
static IOPMAssertionID g_lid_assertion  = kIOPMNullAssertionID;
static int g_wake_on        = 0;   // mirrors menubar.state wake=on/off
static int g_lid_closed_on  = 0;   // mirrors menubar.state lid_closed=on/off

// ---------------------------------------------------------------------------
// Singleton lock -- exclusive flock() on /tmp lockfile.
// ---------------------------------------------------------------------------

static int acquire_singleton_lock(void) {
    g_singleton_fd = open(SINGLETON_LOCK_PATH, O_CREAT | O_RDWR, 0644);
    if (g_singleton_fd < 0) {
        return 0;
    }
    if (flock(g_singleton_fd, LOCK_EX | LOCK_NB) < 0) {
        close(g_singleton_fd);
        g_singleton_fd = -1;
        return 0;
    }
    // Write our pid for diagnostic purposes.
    char buf[32];
    int n = snprintf(buf, sizeof buf, "%d\n", (int)getpid());
    if (n > 0) {
        ftruncate(g_singleton_fd, 0);
        lseek(g_singleton_fd, 0, SEEK_SET);
        write(g_singleton_fd, buf, (size_t)n);
    }
    return 1;
}

// ---------------------------------------------------------------------------
// raw#66 ai-native error trailer + raw#80 sentinel
// ---------------------------------------------------------------------------

static void emit_sentinel(const char *verdict, const char *reason) {
    fprintf(stderr, "__AIRGENOME_TAP_RESULT__ %s reason=%s\n", verdict, reason);
    fflush(stderr);
}

static void emit_ai_native_error(const char *reason, const char *fix) {
    fprintf(stderr, "airgenome_tap: fatal\n"
                    "reason: %s\n"
                    "fix: %s\n", reason, fix);
    fflush(stderr);
}

static int env_int(const char *name, int def) {
    const char *v = getenv(name);
    if (!v || !*v) return def;
    char *end = NULL;
    long n = strtol(v, &end, 10);
    if (end == v) return def;
    return (int)n;
}

static int env_flag(const char *name, int def) {
    const char *v = getenv(name);
    if (!v || !*v) return def;
    return (v[0] != '0');
}

// ---------------------------------------------------------------------------
// macOS native tiling defaults: read / write / restore
// ---------------------------------------------------------------------------

// Returns 0/1 for explicit values, -1 if the key is unset or unreadable.
static int read_default_tristate(const char *key) {
    char cmd[256];
    snprintf(cmd, sizeof cmd,
             "defaults read com.apple.WindowManager %s 2>/dev/null", key);
    FILE *f = popen(cmd, "r");
    if (!f) return -1;
    char buf[64] = {0};
    int got = (fgets(buf, sizeof buf, f) != NULL);
    int rc  = pclose(f);
    if (!got || rc != 0) return -1;
    buf[strcspn(buf, "\n")] = 0;
    if (strcmp(buf, "0") == 0) return 0;
    if (strcmp(buf, "1") == 0) return 1;
    return -1;
}

static void write_default_bool(const char *key, int val) {
    char cmd[256];
    snprintf(cmd, sizeof cmd,
             "defaults write com.apple.WindowManager %s -bool %s",
             key, val ? "true" : "false");
    int rc = system(cmd);
    (void)rc;
}

static void delete_default(const char *key) {
    char cmd[256];
    snprintf(cmd, sizeof cmd,
             "defaults delete com.apple.WindowManager %s 2>/dev/null", key);
    int rc = system(cmd);
    (void)rc;
}

static void kick_window_manager(void) {
    // Hot-reload defaults: WindowManager is auto-respawned by launchd.
    int rc = system("killall WindowManager 2>/dev/null");
    (void)rc;
}

static void native_tiling_capture_and_disable(void) {
    if (!g_disable_native || !g_magnet_on) return;
    g_orig_edge_drag    = read_default_tristate(KEY_EDGE_DRAG);
    g_orig_top_drag     = read_default_tristate(KEY_TOP_EDGE_DRAG);
    g_orig_option_accel = read_default_tristate(KEY_OPTION_ACCEL);
    write_default_bool(KEY_EDGE_DRAG,     0);
    write_default_bool(KEY_TOP_EDGE_DRAG, 0);
    write_default_bool(KEY_OPTION_ACCEL,  0);
    kick_window_manager();
    g_native_modified = 1;
    fprintf(stderr,
        "native-tiling: captured (edge=%d top=%d accel=%d) -> all-disabled\n",
        g_orig_edge_drag, g_orig_top_drag, g_orig_option_accel);
    fflush(stderr);
}

static void native_tiling_restore(void) {
    if (!g_native_modified) return;
    if (g_orig_edge_drag    < 0) delete_default(KEY_EDGE_DRAG);
    else                         write_default_bool(KEY_EDGE_DRAG,     g_orig_edge_drag);
    if (g_orig_top_drag     < 0) delete_default(KEY_TOP_EDGE_DRAG);
    else                         write_default_bool(KEY_TOP_EDGE_DRAG, g_orig_top_drag);
    if (g_orig_option_accel < 0) delete_default(KEY_OPTION_ACCEL);
    else                         write_default_bool(KEY_OPTION_ACCEL, g_orig_option_accel);
    kick_window_manager();
    g_native_modified = 0;
    fprintf(stderr, "native-tiling: restored\n");
    fflush(stderr);
}

// ---------------------------------------------------------------------------
// AX API helpers
// ---------------------------------------------------------------------------

static AXUIElementRef get_focused_window(void) {
    AXUIElementRef sys = AXUIElementCreateSystemWide();
    if (!sys) {
        fprintf(stderr, "ax: system-wide create failed\n");
        fflush(stderr);
        return NULL;
    }
    AXUIElementRef appRef = NULL;
    AXError err = AXUIElementCopyAttributeValue(
        sys, kAXFocusedApplicationAttribute, (CFTypeRef *)&appRef);
    CFRelease(sys);
    if (err != kAXErrorSuccess || !appRef) {
        fprintf(stderr, "ax: focused-app err=%d (no AX permission? try restart)\n",
                (int)err);
        fflush(stderr);
        return NULL;
    }
    AXUIElementRef winRef = NULL;
    err = AXUIElementCopyAttributeValue(
        appRef, kAXFocusedWindowAttribute, (CFTypeRef *)&winRef);
    CFRelease(appRef);
    if (err != kAXErrorSuccess) {
        fprintf(stderr, "ax: focused-window err=%d (app has no focused window)\n",
                (int)err);
        fflush(stderr);
        return NULL;
    }
    return winRef;
}

// Read the AX position (top-left, screen coords) of the given window.
// Returns {0,0} on failure -- callers must treat that as "could not read"
// rather than "window is at origin", and gracefully degrade. In practice
// the only consequence of a read failure during a drag is a false-negative
// magnet (we miss a real title-bar drag), which is acceptable.
static CGPoint get_window_origin(AXUIElementRef win) {
    CGPoint p = {0, 0};
    if (!win) return p;
    AXValueRef v = NULL;
    AXError err = AXUIElementCopyAttributeValue(
        win, kAXPositionAttribute, (CFTypeRef *)&v);
    if (err != kAXErrorSuccess || !v) {
        fprintf(stderr, "ax: get window origin failed err=%d\n", (int)err);
        fflush(stderr);
        if (v) CFRelease(v);
        return p;
    }
    AXValueGetValue(v, kAXValueCGPointType, &p);
    CFRelease(v);
    return p;
}

static int window_set_frame(AXUIElementRef win, CGRect frame) {
    if (!win) return 0;
    CGPoint p = frame.origin;
    CGSize  s = frame.size;
    AXValueRef pv = AXValueCreate(kAXValueCGPointType, &p);
    AXValueRef sv = AXValueCreate(kAXValueCGSizeType,  &s);
    int ok = 1;
    AXError err_p = AXUIElementSetAttributeValue(win, kAXPositionAttribute, pv);
    AXError err_s = AXUIElementSetAttributeValue(win, kAXSizeAttribute,     sv);
    if (err_p != kAXErrorSuccess) {
        fprintf(stderr, "ax: set-position err=%d (window may be non-resizable)\n",
                (int)err_p);
        ok = 0;
    }
    if (err_s != kAXErrorSuccess) {
        fprintf(stderr, "ax: set-size err=%d (window may be non-resizable)\n",
                (int)err_s);
        ok = 0;
    }
    if (pv) CFRelease(pv);
    if (sv) CFRelease(sv);
    return ok;
}

// ---------------------------------------------------------------------------
// NSScreen helpers
//
// AX coords:    origin = top-left of primary display, +y down.
// NSScreen NS:  origin = bottom-left of primary display, +y up.
// We translate NS rects into AX rects so visibleFrame queries stay in AX.
// ---------------------------------------------------------------------------

static CGRect ns_to_ax_rect(NSRect ns_rect) {
    NSArray<NSScreen *> *screens = [NSScreen screens];
    if ([screens count] == 0) {
        return CGRectMake(ns_rect.origin.x, ns_rect.origin.y,
                          ns_rect.size.width, ns_rect.size.height);
    }
    NSRect primary = [[screens objectAtIndex:0] frame];
    CGFloat ax_y = primary.size.height
                 - (ns_rect.origin.y + ns_rect.size.height);
    return CGRectMake(ns_rect.origin.x, ax_y,
                      ns_rect.size.width, ns_rect.size.height);
}

// Inverse of ns_to_ax_rect -- AX rect (top-left origin) -> NSWindow rect
// (bottom-left origin of primary screen). Used to position the snap
// preview overlay correctly across multi-monitor layouts.
static NSRect ax_to_ns_rect(CGRect ax_rect) {
    NSArray<NSScreen *> *screens = [NSScreen screens];
    if ([screens count] == 0) {
        return NSMakeRect(ax_rect.origin.x, ax_rect.origin.y,
                          ax_rect.size.width, ax_rect.size.height);
    }
    NSRect primary = [[screens objectAtIndex:0] frame];
    CGFloat ns_y = primary.size.height
                 - (ax_rect.origin.y + ax_rect.size.height);
    return NSMakeRect(ax_rect.origin.x, ns_y,
                      ax_rect.size.width, ax_rect.size.height);
}

static CGRect screen_visible_frame_at(CGPoint mouse_ax) {
    NSArray<NSScreen *> *screens = [NSScreen screens];
    for (NSScreen *sc in screens) {
        CGRect ax_frame = ns_to_ax_rect([sc frame]);
        if (CGRectContainsPoint(ax_frame, mouse_ax)) {
            return ns_to_ax_rect([sc visibleFrame]);
        }
    }
    if ([screens count] > 0) {
        return ns_to_ax_rect([[screens objectAtIndex:0] visibleFrame]);
    }
    return CGRectMake(0, 0, 1280, 720);
}

// ---------------------------------------------------------------------------
// Snap-preview overlay (white outline rectangle drawn over target zone)
//
// Calls into NSWindow are dispatched to the main queue because the event
// tap callback runs on the CG event-tap thread; UI mutation must happen
// on the main thread.
// ---------------------------------------------------------------------------

static void show_snap_preview(CGRect frame_ax) {
    NSRect ns_frame = ax_to_ns_rect(frame_ax);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_preview_window) {
            NSWindow *w = [[NSWindow alloc]
                initWithContentRect:NSMakeRect(0, 0, 100, 100)
                          styleMask:NSWindowStyleMaskBorderless
                            backing:NSBackingStoreBuffered
                              defer:NO];
            w.opaque               = NO;
            w.hasShadow            = NO;
            w.backgroundColor      = [NSColor clearColor];
            w.ignoresMouseEvents   = YES;
            w.level                = NSScreenSaverWindowLevel - 1;
            w.collectionBehavior   = NSWindowCollectionBehaviorCanJoinAllSpaces
                                   | NSWindowCollectionBehaviorTransient
                                   | NSWindowCollectionBehaviorIgnoresCycle;
            w.releasedWhenClosed   = NO;
            NSView *content = w.contentView;
            content.wantsLayer = YES;
            content.layer.borderColor      = [NSColor whiteColor].CGColor;
            content.layer.borderWidth      = 4.0;
            content.layer.cornerRadius     = 14.0;
            content.layer.backgroundColor  = [NSColor colorWithWhite:1.0 alpha:0.08].CGColor;
            g_preview_window = w;
        }
        [g_preview_window setFrame:ns_frame display:YES];
        if (!g_preview_window.isVisible) {
            [g_preview_window orderFrontRegardless];
        }
    });
}

static void hide_snap_preview(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_preview_window && g_preview_window.isVisible) {
            [g_preview_window orderOut:nil];
        }
    });
}

// ---------------------------------------------------------------------------
// 8-zone classification + frame projection
// ---------------------------------------------------------------------------

typedef enum {
    ZONE_NONE = 0,
    ZONE_TOP, ZONE_BOTTOM, ZONE_LEFT, ZONE_RIGHT,
    ZONE_TL,  ZONE_TR,     ZONE_BL,   ZONE_BR
} Zone;

static Zone classify_zone(CGPoint m, CGRect vf) {
    CGFloat lx = vf.origin.x;
    CGFloat ty = vf.origin.y;
    CGFloat rx = vf.origin.x + vf.size.width;
    CGFloat by = vf.origin.y + vf.size.height;

    int near_left   = (m.x - lx) <= CORNER_THRESHOLD_PX;
    int near_right  = (rx - m.x) <= CORNER_THRESHOLD_PX;
    int near_top    = (m.y - ty) <= CORNER_THRESHOLD_PX;
    int near_bottom = (by - m.y) <= CORNER_THRESHOLD_PX;

    int edge_left   = (m.x - lx) <= EDGE_THRESHOLD_PX;
    int edge_right  = (rx - m.x) <= EDGE_THRESHOLD_PX;
    int edge_top    = (m.y - ty) <= EDGE_THRESHOLD_PX;
    int edge_bottom = (by - m.y) <= EDGE_THRESHOLD_PX;

    if (near_top    && near_left)  return ZONE_TL;
    if (near_top    && near_right) return ZONE_TR;
    if (near_bottom && near_left)  return ZONE_BL;
    if (near_bottom && near_right) return ZONE_BR;

    if (edge_top)    return ZONE_TOP;
    if (edge_bottom) return ZONE_BOTTOM;
    if (edge_left)   return ZONE_LEFT;
    if (edge_right)  return ZONE_RIGHT;
    return ZONE_NONE;
}

static CGRect zone_to_frame(Zone z, CGRect vf) {
    CGFloat hx = vf.size.width  / 2.0;
    CGFloat hy = vf.size.height / 2.0;
    switch (z) {
        case ZONE_TOP:
            return CGRectMake(vf.origin.x, vf.origin.y, vf.size.width, hy);
        case ZONE_BOTTOM:
            return CGRectMake(vf.origin.x, vf.origin.y + hy,
                              vf.size.width, hy);
        case ZONE_LEFT:
            return CGRectMake(vf.origin.x, vf.origin.y, hx, vf.size.height);
        case ZONE_RIGHT:
            return CGRectMake(vf.origin.x + hx, vf.origin.y,
                              hx, vf.size.height);
        case ZONE_TL:
            return CGRectMake(vf.origin.x, vf.origin.y, hx, hy);
        case ZONE_TR:
            return CGRectMake(vf.origin.x + hx, vf.origin.y, hx, hy);
        case ZONE_BL:
            return CGRectMake(vf.origin.x, vf.origin.y + hy, hx, hy);
        case ZONE_BR:
            return CGRectMake(vf.origin.x + hx, vf.origin.y + hy, hx, hy);
        default:
            return CGRectNull;
    }
}

static const char *zone_name(Zone z) {
    switch (z) {
        case ZONE_TOP:    return "top";
        case ZONE_BOTTOM: return "bottom";
        case ZONE_LEFT:   return "left";
        case ZONE_RIGHT:  return "right";
        case ZONE_TL:     return "tl";
        case ZONE_TR:     return "tr";
        case ZONE_BL:     return "bl";
        case ZONE_BR:     return "br";
        default:          return "none";
    }
}

// ---------------------------------------------------------------------------
// Mouse button feature: button 4 / 5 -> Cmd+[ / Cmd+]
// ---------------------------------------------------------------------------

static void post_cmd_key(CGKeyCode key) {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!src) return;
    CGEventRef down = CGEventCreateKeyboardEvent(src, key, true);
    CGEventRef up   = CGEventCreateKeyboardEvent(src, key, false);
    CGEventSetFlags(down, kCGEventFlagMaskCommand);
    CGEventSetFlags(up,   kCGEventFlagMaskCommand);
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    CFRelease(down);
    CFRelease(up);
    CFRelease(src);
}

// Returns 1 if event was consumed (suppress passthrough), 0 if untouched.
static int handle_mouse_button(CGEventRef event) {
    int64_t btn = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    if (btn == BUTTON_BACK)    { post_cmd_key(KEY_BRACKET_L); return 1; }
    if (btn == BUTTON_FORWARD) { post_cmd_key(KEY_BRACKET_R); return 1; }
    return 0;
}

// ---------------------------------------------------------------------------
// Scroll wheel feature: invert mouse-wheel direction; trackpad untouched.
// ---------------------------------------------------------------------------

static void handle_scroll_wheel(CGEventRef event) {
    int64_t is_continuous = CGEventGetIntegerValueField(
        event, kCGScrollWheelEventIsContinuous);
    if (is_continuous != 0) return;   // trackpad -> passthrough

    int64_t d1  = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t d2  = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    int64_t pd1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    int64_t pd2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
    int64_t fd1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
    int64_t fd2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);

    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1,        -d1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2,        -d2);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1,   -pd1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2,   -pd2);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -fd1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -fd2);
}

// ---------------------------------------------------------------------------
// Magnet feature: drag detection + 8-zone snap on mouse-up
// ---------------------------------------------------------------------------

static void magnet_on_left_down(CGEventRef event) {
    g_drag_start_pt = CGEventGetLocation(event);
    g_dragging = 0;
    g_window_actually_moved = 0;
    if (g_drag_window) {
        CFRelease(g_drag_window);
        g_drag_window = NULL;
    }
    // Stale preview from a previous cycle, if any.
    hide_snap_preview();
    // Capture the focused window EARLY (do not wait for drag-min-distance)
    // so we can compare frame.origin on every dragged event from t=0. This
    // is the basis of the title-bar-drag whitelist: a real window drag
    // moves the window; any other drag-and-drop source leaves it stationary.
    g_drag_window = get_focused_window();
    g_drag_window_origin_at_start = get_window_origin(g_drag_window);
    if (g_debug) {
        fprintf(stderr,
            "magnet: down pt=(%.0f,%.0f) win=%s origin=(%.0f,%.0f)\n",
            g_drag_start_pt.x, g_drag_start_pt.y,
            g_drag_window ? "yes" : "no",
            g_drag_window_origin_at_start.x,
            g_drag_window_origin_at_start.y);
        fflush(stderr);
    }
}

static void magnet_on_left_dragged(CGEventRef event) {
    CGPoint p = CGEventGetLocation(event);

    // Drag-detect (only run while not yet dragging). Note: g_dragging
    // here means "cursor has moved beyond the click slop"; it is NOT the
    // magnet-eligible signal. The magnet-eligible signal is
    // g_window_actually_moved, set below.
    if (!g_dragging) {
        CGFloat dx = p.x - g_drag_start_pt.x;
        CGFloat dy = p.y - g_drag_start_pt.y;
        CGFloat thr = (CGFloat)DRAG_MIN_DISTANCE_PX;
        if (dx * dx + dy * dy >= thr * thr) {
            g_dragging = 1;
        }
    }

    // Title-bar-drag whitelist: while g_dragging is set but we have not
    // yet confirmed a real window move, re-read the focused window's
    // origin and compare to the start. Once the delta crosses
    // TITLE_BAR_DRAG_THRESHOLD_PX we latch g_window_actually_moved and
    // never re-test (the window may briefly be re-positioned by user
    // intent during the drag and we want to keep the magnet engaged).
    if (g_dragging && !g_window_actually_moved && g_drag_window) {
        CGPoint cur = get_window_origin(g_drag_window);
        CGFloat ox = cur.x - g_drag_window_origin_at_start.x;
        CGFloat oy = cur.y - g_drag_window_origin_at_start.y;
        CGFloat thr = (CGFloat)TITLE_BAR_DRAG_THRESHOLD_PX;
        if (ox * ox + oy * oy >= thr * thr) {
            g_window_actually_moved = 1;
            if (g_debug) {
                fprintf(stderr,
                    "magnet: window moved (%.1f,%.1f) -> engaging\n", ox, oy);
                fflush(stderr);
            }
        }
    }

    // Until the window has actually moved, this is either a click+release,
    // a sub-threshold tremor, or a drag-to-copy gesture. In all cases we
    // suppress the entire magnet pipeline -- no preview, no zone classify,
    // no spaces-guard y-clamp -- so the system's drag-and-drop session
    // (URL drag, file icon drag, text selection, image, attachment) flows
    // through untouched.
    if (!g_window_actually_moved) return;

    // Live snap-preview: classify against the REAL cursor (not the
    // y-clamped event we are about to forward to the rest of macOS) so
    // the user sees feedback even when their cursor is in the very
    // edge sliver that the SPACES_GUARD_PX clamp covers.
    CGRect vf = screen_visible_frame_at(p);
    Zone   z  = classify_zone(p, vf);
    if (z != ZONE_NONE) {
        show_snap_preview(zone_to_frame(z, vf));
    } else {
        hide_snap_preview();
    }

    // Top-edge guard: rewrite the event's y so the rest of macOS (the
    // window-drag manager and the Mission Control hover detector) never
    // sees y < SPACES_GUARD_PX. The MouseUp handler still classifies on
    // the real cursor location so the user can target the very top of
    // the screen without Spaces strip popping in.
    if (p.y < SPACES_GUARD_PX) {
        CGPoint clamped = p;
        clamped.y = SPACES_GUARD_PX;
        CGEventSetLocation(event, clamped);
    }
}

static void magnet_on_left_up(CGEventRef event) {
    // Always tear the preview down on release, regardless of whether the
    // snap actually fired (zone == NONE leaves no snap but we still want
    // the overlay gone).
    hide_snap_preview();

    // Title-bar-drag whitelist: only run the snap path when we observed
    // the focused window actually move during this drag. Drag-to-copy
    // gestures (URL bar, file icon, text/image/attachment) never moved a
    // window and so cleanly bypass the snap.
    if (g_window_actually_moved) {
        CGPoint mouse_ax = CGEventGetLocation(event);
        CGRect vf = screen_visible_frame_at(mouse_ax);
        Zone z = classify_zone(mouse_ax, vf);
        // Always log every drag-end so we can see where the cursor landed
        // even when the zone classifier rejects (e.g. cursor not near edge).
        fprintf(stderr,
            "drag-end: pt=(%.0f,%.0f) vf=(%.0f,%.0f %.0fx%.0f) zone=%s win=%s\n",
            mouse_ax.x, mouse_ax.y,
            vf.origin.x, vf.origin.y, vf.size.width, vf.size.height,
            zone_name(z),
            g_drag_window ? "yes" : "no");
        fflush(stderr);
        if (g_drag_window && z != ZONE_NONE) {
            CGRect frame = zone_to_frame(z, vf);
            if (window_set_frame(g_drag_window, frame)) {
                fprintf(stderr,
                    "snap: zone=%s frame=%.0f,%.0f %.0fx%.0f\n",
                    zone_name(z),
                    frame.origin.x, frame.origin.y,
                    frame.size.width, frame.size.height);
                fflush(stderr);
            }
        }
    }

    if (g_drag_window) {
        CFRelease(g_drag_window);
        g_drag_window = NULL;
    }
    g_dragging = 0;
    g_window_actually_moved = 0;
}

// ---------------------------------------------------------------------------
// Event tap callback (dispatch by event type to feature handlers)
// ---------------------------------------------------------------------------

static CGEventRef tap_callback(CGEventTapProxy proxy,
                               CGEventType    type,
                               CGEventRef     event,
                               void          *refcon) {
    (void)proxy; (void)refcon;

    if (type == kCGEventTapDisabledByTimeout
     || type == kCGEventTapDisabledByUserInput) {
        fprintf(stderr, "tap: disabled (type=%u) -> re-enabling\n",
                (unsigned)type);
        fflush(stderr);
        if (g_tap) CGEventTapEnable(g_tap, true);
        return event;
    }

    // Per-event trace: noisy but invaluable when diagnosing a tap that
    // appears armed but never seems to fire. Off by default.
    if (g_debug) {
        fprintf(stderr, "ev: type=%u\n", (unsigned)type);
        fflush(stderr);
    }

    // (a0) hive raw 209 launcher hotkey hook - check before mouse handlers
    // since launcher consumes ctrl+s key down events. Per-event opt-in via
    // AIRG_TAP_LAUNCHER env flag (raw 177 per-feature opt-in pattern).
    if (g_launcher_on && type == kCGEventKeyDown) {
        if (airgenome_launcher_handle_keydown(event)) return NULL;
    }

    // (a1) hive raw 209 sister axis: alt+1..5 window arrangement on focused
    // window via AX. Per-event opt-in via AIRG_TAP_WINCTL env flag.
    if (g_winctl_on && type == kCGEventKeyDown) {
        if (airgenome_winctl_handle_keydown(event)) return NULL;
    }

    // (a) Mouse button: button 4 / 5 -> Cmd+[ / Cmd+]
    if (g_buttons_on && type == kCGEventOtherMouseDown) {
        if (handle_mouse_button(event)) return NULL;   // consumed
        return event;
    }

    // (b) Scroll wheel inversion (mouse only)
    if (g_scroll_on && type == kCGEventScrollWheel) {
        handle_scroll_wheel(event);
        return event;
    }

    // (c) Magnet: drag detection + snap-on-release
    if (g_magnet_on) {
        if (type == kCGEventLeftMouseDown)    { magnet_on_left_down(event);    return event; }
        if (type == kCGEventLeftMouseDragged) { magnet_on_left_dragged(event); return event; }
        if (type == kCGEventLeftMouseUp)      { magnet_on_left_up(event);      return event; }
    }

    return event;
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// Forward declarations — IOPMAssertion lifecycle defined further down with
// the menubar-state code (raw 213 in-process IOKit primitives).
static void wake_assertion_release(void);
static void lid_assertion_release(void);

// Graceful shutdown: release IOPMAssertions, restore native tiling defaults,
// emit sentinel, stop the event tap, then ask NSApp to terminate. Called from
// a dispatch source (signal-safe scheduling) rather than directly from a UNIX
// signal handler so we can call into AppKit safely.
static void on_shutdown(const char *reason) {
    // raw 213: release in-process IOPMAssertions on shutdown. The kernel
    // also auto-releases on process death (so SIGKILL is safe), but explicit
    // release on graceful exit makes the lifecycle observable.
    wake_assertion_release();
    lid_assertion_release();
    native_tiling_restore();
    emit_sentinel("PASS", reason);
    if (g_tap) {
        CGEventTapEnable(g_tap, false);
        g_tap = NULL;
    }
    if (NSApp) {
        [NSApp terminate:nil];
    } else {
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

// Wire SIGINT/SIGTERM/SIGHUP to dispatch_source_t handlers running on the
// main queue. signal()-installed handlers cannot safely call AppKit APIs;
// dispatch sources handle the signal asynchronously on the main thread.
static void install_signal_handlers(void) {
    int signals[] = { SIGINT, SIGTERM, SIGHUP };
    const char *names[] = { "sigint", "sigterm", "sighup" };
    for (int i = 0; i < 3; i++) {
        signal(signals[i], SIG_IGN);   // disarm default; dispatch_source takes over
        dispatch_source_t src = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_SIGNAL, signals[i], 0,
            dispatch_get_main_queue());
        const char *reason_slug = names[i];
        dispatch_source_set_event_handler(src, ^{
            on_shutdown(reason_slug);
        });
        dispatch_resume(src);
    }
}

// ---------------------------------------------------------------------------
// Persistent menubar state (raw 168 minimum-viable, raw 179 ~/Library path,
// raw 213 native-IOKit IOPMAssertion replaces shell-out)
// ---------------------------------------------------------------------------
// Format (KV-pair, line-oriented, raw 92 ai-native-canonical):
//   mouse=on
//   magnet=on
//   wake=on          (raw 213: in-process IOPMAssertionTypeNoIdleSleep)
//   lid_closed=on    (raw 213: in-process IOPMAssertionTypePreventSystemSleep)
// Wake/Lid live state = the IOPMAssertionID's validity (kIOPMNullAssertionID
// when off). The state file is the persistence-across-launch surface.

static NSString *menubar_state_dir(void) {
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@"Library/Application Support/airgenome"];
}

static NSString *menubar_state_path(void) {
    return [menubar_state_dir() stringByAppendingPathComponent:@"menubar.state"];
}

// raw 180 capture/restore: screencapture shadow-disable on startup.
// Disables the ~50px drop shadow that macOS adds to ⌘⇧4-space window
// screenshots. Captures the ORIGINAL pref value to system_state.plist on
// first run only (later toggle-during-uptime won't be misrecorded as
// original). Idempotent: re-call with already-true pref is a fast skip.
//
// No SystemUIServer kill needed — screencapture reads the pref live on
// each invocation (verified macOS 11+). Avoiding the kill prevents the
// menubar-icons flicker that would otherwise happen every airgenome boot.
static void apply_screenshot_shadow_disable(void) {
    NSString *statePath = [menubar_state_dir()
        stringByAppendingPathComponent:@"system_state.plist"];
    NSMutableDictionary *st = [NSMutableDictionary
        dictionaryWithContentsOfFile:statePath];
    if (!st) st = [NSMutableDictionary dictionary];
    if (!st[@"screencapture_shadow_disable_original"]) {
        CFPropertyListRef cur = CFPreferencesCopyAppValue(
            CFSTR("disable-shadow"), CFSTR("com.apple.screencapture"));
        if (cur && CFGetTypeID(cur) == CFBooleanGetTypeID()) {
            st[@"screencapture_shadow_disable_original"] =
                CFBooleanGetValue((CFBooleanRef)cur) ? @"true" : @"false";
        } else {
            st[@"screencapture_shadow_disable_original"] = @"absent";
        }
        if (cur) CFRelease(cur);
        [[NSFileManager defaultManager] createDirectoryAtPath:menubar_state_dir()
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
        [st writeToFile:statePath atomically:YES];
    }
    CFPropertyListRef cur = CFPreferencesCopyAppValue(
        CFSTR("disable-shadow"), CFSTR("com.apple.screencapture"));
    BOOL already = (cur && CFGetTypeID(cur) == CFBooleanGetTypeID()
                    && CFBooleanGetValue((CFBooleanRef)cur));
    if (cur) CFRelease(cur);
    if (already) {
        fprintf(stderr, "screencapture: shadow already disabled (skip)\n");
        fflush(stderr);
        return;
    }
    CFPreferencesSetAppValue(CFSTR("disable-shadow"), kCFBooleanTrue,
                             CFSTR("com.apple.screencapture"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.screencapture"));
    fprintf(stderr, "screencapture: shadow disabled (window screenshots)\n");
    fflush(stderr);
}

// raw 180 capture/restore: dock tilesize reset on FIRST install only.
// Unlike screenshot-shadow (always-true preference), tilesize is something
// the user may legitimately customize after install — so this runs once,
// gated by a sentinel in system_state.plist, then NEVER again on subsequent
// boots. Manual ⌥6 still works any time.
//
// Capture original tilesize before write so a future restore subcommand
// can reverse the install-time mutation (raw 181 uninstall symmetry).
static void apply_dock_tilesize_reset_once(void) {
    NSString *statePath = [menubar_state_dir()
        stringByAppendingPathComponent:@"system_state.plist"];
    NSMutableDictionary *st = [NSMutableDictionary
        dictionaryWithContentsOfFile:statePath];
    if (!st) st = [NSMutableDictionary dictionary];
    if (st[@"dock_tilesize_reset_done"]) {
        // Already applied once; respect any subsequent user dock resizing.
        return;
    }
    CFPropertyListRef cur = CFPreferencesCopyAppValue(
        CFSTR("tilesize"), CFSTR("com.apple.dock"));
    if (cur && CFGetTypeID(cur) == CFNumberGetTypeID()) {
        int origVal = 0;
        CFNumberGetValue((CFNumberRef)cur, kCFNumberIntType, &origVal);
        st[@"dock_tilesize_original"] = @(origVal);
    } else {
        st[@"dock_tilesize_original"] = @"absent";
    }
    if (cur) CFRelease(cur);
    airgenome_winctl_reset_dock_tilesize();   // shared logic in winctl.m
    st[@"dock_tilesize_reset_done"] = @YES;
    [[NSFileManager defaultManager] createDirectoryAtPath:menubar_state_dir()
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    [st writeToFile:statePath atomically:YES];
    fprintf(stderr, "dock: tilesize reset (one-time on first install)\n");
    fflush(stderr);
}

// Legacy LaunchAgent path — cleaned up at first launch of the new binary so
// the legacy caffeinate process is not left running alongside the in-process
// IOPMAssertion (raw 91 honest C3: avoid double-effect during migration).
static NSString *legacy_wake_plist_path(void) {
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@"Library/LaunchAgents/com.airgenome.wake.plist"];
}

static void load_menubar_state(void) {
    NSString *path = menubar_state_path();
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:&err];
    if (!content) return;   // first-run default = env flags untouched
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSArray *kv = [line componentsSeparatedByString:@"="];
        if (kv.count != 2) continue;
        NSString *k = [kv[0] stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];
        NSString *v = [kv[1] stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];
        int on = ([v isEqualToString:@"on"] ? 1 : 0);
        if ([k isEqualToString:@"mouse"]) {
            g_buttons_on = on;
            g_scroll_on  = on;
        } else if ([k isEqualToString:@"magnet"]) {
            g_magnet_on = on;
        } else if ([k isEqualToString:@"wake"]) {
            g_wake_on = on;
        } else if ([k isEqualToString:@"lid_closed"]) {
            g_lid_closed_on = on;
        } else if ([k isEqualToString:@"winctl"]) {
            g_winctl_on = on;
        } else if ([k isEqualToString:@"launcher"]) {
            g_launcher_on = on;
        }
    }
}

static void save_menubar_state(void) {
    NSString *dir = menubar_state_dir();
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    int mouse_on = (g_buttons_on || g_scroll_on) ? 1 : 0;
    NSString *content = [NSString stringWithFormat:
        @"mouse=%s\nmagnet=%s\nwake=%s\nlid_closed=%s\nwinctl=%s\nlauncher=%s\n",
        mouse_on        ? "on" : "off",
        g_magnet_on     ? "on" : "off",
        g_wake_on       ? "on" : "off",
        g_lid_closed_on ? "on" : "off",
        g_winctl_on     ? "on" : "off",
        g_launcher_on   ? "on" : "off"];
    [content writeToFile:menubar_state_path()
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:NULL];
}

// raw 213: native IOPMAssertion replaces launchctl + caffeinate indirection
// AND osascript-with-administrator-privileges admin shell-out for pmset.
// Both assertions are held in-process; lifetime = airgenome.app PID; kernel
// auto-releases on process death so SIGKILL leaves no stale assertion.

static int wake_assertion_create(void) {
    if (g_wake_assertion != kIOPMNullAssertionID) return 1;
    // 2026-04-30 04:50 — upgraded from kIOPMAssertionTypeNoIdleSleep to
    // kIOPMAssertionTypePreventUserIdleDisplaySleep (superset). User report:
    // "wake 잠금 안된다 / 화면 자동잠금 안빠지도록". NoIdleSleep only
    // blocks system idle sleep — display still goes dark per `displaysleep`
    // setting (10 min default), and screen-saver-triggered auto-lock fires
    // when display sleeps. NoDisplaySleepAssertion blocks BOTH display sleep
    // AND keeps user-idle timer pinned, which prevents screen saver +
    // auto-lock from kicking in. Same effect as `caffeinate -d`.
    IOReturn rc = IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventUserIdleDisplaySleep,
        kIOPMAssertionLevelOn,
        CFSTR("airgenome.wake"),
        &g_wake_assertion);
    if (rc != kIOReturnSuccess) {
        g_wake_assertion = kIOPMNullAssertionID;
        fprintf(stderr,
            "wake: IOPMAssertionCreateWithName(NoDisplaySleep) failed rc=0x%x\n",
            (unsigned)rc);
        fflush(stderr);
        return 0;
    }
    return 1;
}

static void wake_assertion_release(void) {
    if (g_wake_assertion == kIOPMNullAssertionID) return;
    IOPMAssertionRelease(g_wake_assertion);
    g_wake_assertion = kIOPMNullAssertionID;
}

static int lid_assertion_create(void) {
    if (g_lid_assertion != kIOPMNullAssertionID) return 1;
    IOReturn rc = IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventSystemSleep,
        kIOPMAssertionLevelOn,
        CFSTR("airgenome.lid-closed-awake"),
        &g_lid_assertion);
    if (rc != kIOReturnSuccess) {
        g_lid_assertion = kIOPMNullAssertionID;
        fprintf(stderr,
            "lid: IOPMAssertionCreateWithName(PreventSystemSleep) failed rc=0x%x\n"
            "     (raw 91 C3: on Apple Silicon battery + lid close, hardware-level\n"
            "     sleep enforcement may apply regardless — Apple-documented limitation)\n",
            (unsigned)rc);
        fflush(stderr);
        return 0;
    }
    return 1;
}

static void lid_assertion_release(void) {
    if (g_lid_assertion == kIOPMNullAssertionID) return;
    IOPMAssertionRelease(g_lid_assertion);
    g_lid_assertion = kIOPMNullAssertionID;
}

static int query_wake_state(void) {
    // Live state = assertion-id validity; persisted state = g_wake_on flag.
    return (g_wake_assertion != kIOPMNullAssertionID) ? 1 : 0;
}

static int query_lid_closed_awake_state(void) {
    return (g_lid_assertion != kIOPMNullAssertionID) ? 1 : 0;
}

// One-time legacy LaunchAgent cleanup on first launch of the raw 213 binary.
// The previous implementation wrote ~/Library/LaunchAgents/com.airgenome.wake.plist
// and ran `caffeinate -dimsu` in a separate process. The new in-process
// IOPMAssertion supersedes it, so we bootout + rm the legacy plist to avoid
// double-effect (two parallel sleep-prevention sources).
static void cleanup_legacy_wake_launchagent(void) {
    NSString *plist = legacy_wake_plist_path();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:plist]) return;

    // SMAppService / direct libxpc would be the canonical native-API
    // replacement here, but the launchctl bootout call is read-only sandbox
    // safe (no admin escalation) and operates on a user-domain LaunchAgent.
    // raw 213 Tier-A bans osascript admin shell-out; this path is not admin.
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/launchctl";
    task.arguments  = @[@"bootout",
                        [NSString stringWithFormat:@"gui/%u", (unsigned)getuid()],
                        plist];
    NSPipe *out = [NSPipe pipe];
    task.standardOutput = out;
    task.standardError  = out;
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        // ignore — LaunchAgent may not be loaded; rm proceeds regardless.
    }

    NSError *err = nil;
    [fm removeItemAtPath:plist error:&err];
    fprintf(stderr,
        "wake: legacy LaunchAgent cleaned up (raw 213 migration: %s)\n",
        err ? "plist remove failed" : "bootout + plist removed");
    fflush(stderr);
}

// ---------------------------------------------------------------------------
// Menu target -- 4 toggle actions
// ---------------------------------------------------------------------------

static void update_menu_states(void);

@interface AirgenomeMenuTarget : NSObject
- (void)toggleMouse:(id)sender;
- (void)toggleMagnet:(id)sender;
- (void)toggleWake:(id)sender;
- (void)toggleLidClosed:(id)sender;
@end

@implementation AirgenomeMenuTarget

- (void)toggleMouse:(id)sender {
    (void)sender;
    int on = (g_buttons_on || g_scroll_on) ? 0 : 1;
    g_buttons_on = on;
    g_scroll_on  = on;
    save_menubar_state();
    update_menu_states();
    fprintf(stderr, "menubar: mouse -> %s\n", on ? "ON" : "off");
    fflush(stderr);
}

- (void)toggleMagnet:(id)sender {
    (void)sender;
    if (!g_magnet_on) {
        // OFF -> ON: AX permission required for window manipulation.
        if (!AXIsProcessTrusted()) {
            fprintf(stderr,
                "menubar: magnet toggle refused (AX permission missing)\n"
                "  fix: System Settings -> Privacy & Security -> Accessibility -> enable airgenome\n");
            fflush(stderr);
            return;
        }
        g_magnet_on = 1;
        if (g_disable_native) native_tiling_capture_and_disable();
    } else {
        // ON -> OFF
        g_magnet_on = 0;
        native_tiling_restore();
    }
    save_menubar_state();
    update_menu_states();
    fprintf(stderr, "menubar: magnet -> %s\n", g_magnet_on ? "ON" : "off");
    fflush(stderr);
}

// raw 209: launcher overlay (ctrl+s) — pure key-event consumption + AppKit
// NSPanel; needs Accessibility for CGEventTap (already gated upstream by
// the tap activation itself). No additional permission required at toggle
// time. Default ON; toggle persists via menubar.state.
- (void)toggleLauncher:(id)sender {
    (void)sender;
    g_launcher_on = !g_launcher_on;
    save_menubar_state();
    update_menu_states();
    fprintf(stderr, "menubar: launcher -> %s\n", g_launcher_on ? "ON" : "off");
    fflush(stderr);
}

// raw 209 sister axis: alt+1..5 focused-window arrangement. Same AX
// permission gate as magnet (kAXPositionAttribute / kAXSizeAttribute writes
// require the same Accessibility grant). raw 91 honest C3: refuse with a
// pointer to System Settings instead of silently no-op'ing the toggle.
- (void)toggleWinctl:(id)sender {
    (void)sender;
    if (!g_winctl_on) {
        if (!AXIsProcessTrusted()) {
            fprintf(stderr,
                "menubar: winctl toggle refused (AX permission missing)\n"
                "  fix: System Settings -> Privacy & Security -> Accessibility -> enable airgenome\n");
            fflush(stderr);
            return;
        }
        g_winctl_on = 1;
    } else {
        g_winctl_on = 0;
    }
    save_menubar_state();
    update_menu_states();
    fprintf(stderr, "menubar: winctl -> %s\n", g_winctl_on ? "ON" : "off");
    fflush(stderr);
}

- (void)toggleWake:(id)sender {
    (void)sender;
    // raw 213: in-process IOPMAssertion (kIOPMAssertionTypeNoIdleSleep).
    // No osascript, no LaunchAgent indirection, no admin auth dialog.
    if (query_wake_state()) {
        wake_assertion_release();
        g_wake_on = 0;
        fprintf(stderr, "menubar: wake -> off (IOPMAssertion released)\n");
    } else {
        if (wake_assertion_create()) {
            g_wake_on = 1;
            fprintf(stderr, "menubar: wake -> ON (IOPMAssertion held)\n");
        } else {
            fprintf(stderr, "menubar: wake -> FAILED (IOKit returned non-success)\n");
        }
    }
    fflush(stderr);
    save_menubar_state();
    update_menu_states();
}

// Returns 1 if the system is currently powered by AC, 0 if on battery, -1 if
// undetermined (e.g., desktop Mac with no battery — treat as AC).
static int query_on_ac_power(void) {
    CFTypeRef ps_info = IOPSCopyPowerSourcesInfo();
    if (!ps_info) return -1;
    CFArrayRef sources = IOPSCopyPowerSourcesList(ps_info);
    if (!sources) { CFRelease(ps_info); return -1; }
    int on_ac = -1;
    CFIndex n = CFArrayGetCount(sources);
    for (CFIndex i = 0; i < n; i++) {
        CFTypeRef src = CFArrayGetValueAtIndex(sources, i);
        CFDictionaryRef desc = IOPSGetPowerSourceDescription(ps_info, src);
        if (!desc) continue;
        CFStringRef state = (CFStringRef)CFDictionaryGetValue(desc, CFSTR(kIOPSPowerSourceStateKey));
        if (state && CFStringCompare(state, CFSTR(kIOPSACPowerValue), 0) == kCFCompareEqualTo) {
            on_ac = 1; break;
        } else if (state && CFStringCompare(state, CFSTR(kIOPSBatteryPowerValue), 0) == kCFCompareEqualTo) {
            on_ac = 0;
        }
    }
    CFRelease(sources);
    CFRelease(ps_info);
    return on_ac;
}

- (void)toggleLidClosed:(id)sender {
    (void)sender;
    // raw 213: in-process IOPMAssertion (kIOPMAssertionTypePreventSystemSleep).
    // Replaces `osascript -e 'do shell script "pmset -a disablesleep N"
    // with administrator privileges'` admin shell-out — no admin dialog,
    // instant toggle. raw 91 C3: on Apple Silicon battery + lid close, hardware
    // sleep enforcement may still apply regardless of this assertion.
    if (query_lid_closed_awake_state()) {
        lid_assertion_release();
        g_lid_closed_on = 0;
        fprintf(stderr, "menubar: lid-closed-awake -> off (IOPMAssertion released)\n");
    } else {
        if (lid_assertion_create()) {
            g_lid_closed_on = 1;
            // raw 91 honest C3 hint: kIOPMAssertionTypePreventSystemSleep is
            // documented effective only on AC power. Warn user when they
            // toggle ON while currently on battery — assertion is held but
            // hardware-level lid-close sleep enforcement may bypass it.
            int on_ac = query_on_ac_power();
            if (on_ac == 0) {
                fprintf(stderr,
                    "menubar: lid-closed-awake -> ON (IOPMAssertion held)  "
                    "WARNING: currently on battery; "
                    "kIOPMAssertionTypePreventSystemSleep is effective only on "
                    "AC power per Apple docs (raw 91 C3 + raw 213 known limit)\n");
                NSAlert *alert = [[NSAlert alloc] init];
                alert.alertStyle = NSAlertStyleWarning;
                alert.messageText = @"Wake when lid closed — battery limit";
                alert.informativeText =
                    @"This setting is held in process via IOPMAssertion "
                    @"(kIOPMAssertionTypePreventSystemSleep).\n\n"
                    @"Apple documents this assertion as effective only on AC "
                    @"power. On battery + lid close, the system may still "
                    @"sleep due to hardware-level enforcement on Apple "
                    @"Silicon.\n\nFor reliable lid-closed wake on battery, "
                    @"connect AC power.";
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            } else {
                fprintf(stderr, "menubar: lid-closed-awake -> ON (IOPMAssertion held, on AC)\n");
            }
        } else {
            fprintf(stderr, "menubar: lid-closed-awake -> FAILED (IOKit returned non-success)\n");
        }
    }
    fflush(stderr);
    save_menubar_state();
    update_menu_states();
}

@end

static void update_menu_states(void) {
    int mouse_on = (g_buttons_on || g_scroll_on) ? 1 : 0;
    if (g_item_mouse)  g_item_mouse.state  = mouse_on    ? NSControlStateValueOn : NSControlStateValueOff;
    if (g_item_magnet) g_item_magnet.state = g_magnet_on ? NSControlStateValueOn : NSControlStateValueOff;
    if (g_item_wake)   g_item_wake.state   = query_wake_state()             ? NSControlStateValueOn : NSControlStateValueOff;
    if (g_item_lid)    g_item_lid.state    = query_lid_closed_awake_state() ? NSControlStateValueOn : NSControlStateValueOff;
    if (g_item_winctl)   g_item_winctl.state   = g_winctl_on   ? NSControlStateValueOn : NSControlStateValueOff;
    if (g_item_launcher) g_item_launcher.state = g_launcher_on ? NSControlStateValueOn : NSControlStateValueOff;
}

// ---------------------------------------------------------------------------
// Menu-bar status item
// ---------------------------------------------------------------------------

static void install_status_item(void) {
    NSStatusItem *item = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSVariableStatusItemLength];

    NSImage *icon = nil;
    if (@available(macOS 11.0, *)) {
        icon = [NSImage imageWithSystemSymbolName:STATUS_BAR_SYMBOL
                         accessibilityDescription:@"airgenome"];
    }

    // Always set a text title as the primary visual (visible regardless of
    // image-rendering quirks on different macOS appearances). When the SF
    // Symbol loads, also attach the image as a template (auto-tints to the
    // current menu-bar foreground colour, so it stays visible in both
    // light and dark menu bars).
    item.button.title = STATUS_BAR_FALLBACK;
    item.button.imagePosition = NSImageLeading;
    if (icon) {
        [icon setTemplate:YES];
        item.button.image = icon;
        fprintf(stderr,
            "menubar: status item created (icon=dna template, title=%s)\n",
            [STATUS_BAR_FALLBACK UTF8String]);
    } else {
        fprintf(stderr,
            "menubar: status item created (icon=nil, title-only=%s)\n",
            [STATUS_BAR_FALLBACK UTF8String]);
    }
    fflush(stderr);
    item.button.toolTip = @"airgenome -- mouse + scroll + 8-zone magnet";

    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *header = [[NSMenuItem alloc]
        initWithTitle:@"airgenome" action:nil keyEquivalent:@""];
    [header setEnabled:NO];
    [menu addItem:header];
    [menu addItem:[NSMenuItem separatorItem]];

    g_menu_target = [[AirgenomeMenuTarget alloc] init];

    g_item_wake = [[NSMenuItem alloc]
        initWithTitle:@"Wake (sleep prevention)"
               action:@selector(toggleWake:)
        keyEquivalent:@""];
    g_item_wake.target = g_menu_target;
    [menu addItem:g_item_wake];

    g_item_lid = [[NSMenuItem alloc]
        initWithTitle:@"Wake when lid closed"
               action:@selector(toggleLidClosed:)
        keyEquivalent:@""];
    g_item_lid.target = g_menu_target;
    [menu addItem:g_item_lid];

    g_item_magnet = [[NSMenuItem alloc]
        initWithTitle:@"Magnet (8-zone snap)"
               action:@selector(toggleMagnet:)
        keyEquivalent:@""];
    g_item_magnet.target = g_menu_target;
    [menu addItem:g_item_magnet];

    g_item_winctl = [[NSMenuItem alloc]
        initWithTitle:@"Window arrange (⌥1..6)"
               action:@selector(toggleWinctl:)
        keyEquivalent:@""];
    g_item_winctl.target = g_menu_target;
    [menu addItem:g_item_winctl];

    g_item_launcher = [[NSMenuItem alloc]
        initWithTitle:@"App launcher (⌃S)"
               action:@selector(toggleLauncher:)
        keyEquivalent:@""];
    g_item_launcher.target = g_menu_target;
    [menu addItem:g_item_launcher];

    g_item_mouse = [[NSMenuItem alloc]
        initWithTitle:@"Mouse (buttons + scroll)"
               action:@selector(toggleMouse:)
        keyEquivalent:@""];
    g_item_mouse.target = g_menu_target;
    [menu addItem:g_item_mouse];

    update_menu_states();   // sync checkmarks to current real state

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit airgenome"
                    action:@selector(terminate:)
             keyEquivalent:@"q"];

    item.menu = menu;
    g_status_item = item;   // strong reference to keep alive
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    @autoreleasepool {
        // Refuse to start if another airgenome.tap process is already alive.
        // flock() ensures the menu-bar status item is never duplicated, even
        // when launchd's KeepAlive tries to respawn during a slow shutdown.
        if (!acquire_singleton_lock()) {
            emit_ai_native_error(
                "singleton-lock-held: another airgenome.tap process is already running",
                "1) launchctl print gui/$(id -u)/com.airgenome.tap | grep pid  "
                "2) check pid is alive (ps -p <pid>); if zombie, rm /tmp/com.airgenome.tap.lock  "
                "3) re-run (no reboot needed)");
            emit_sentinel("FAIL", "singleton-lock-held");
            return 75;   // EX_TEMPFAIL
        }

        g_buttons_on        = env_flag("AIRG_TAP_MOUSE_BUTTONS",  g_buttons_on);
        g_scroll_on         = env_flag("AIRG_TAP_MOUSE_SCROLL",   g_scroll_on);
        g_magnet_on         = env_flag("AIRG_TAP_MAGNET",         g_magnet_on);
        g_disable_native    = env_flag("AIRG_TAP_DISABLE_NATIVE", g_disable_native);
        g_launcher_on       = env_flag("AIRG_TAP_LAUNCHER",       g_launcher_on);
        g_winctl_on         = env_flag("AIRG_TAP_WINCTL",         g_winctl_on);
        g_debug             = env_flag("AIRG_TAP_DEBUG",          g_debug);
        // Persisted menubar state overrides env defaults (raw 168 minimum-viable).
        load_menubar_state();
        // raw 180 capture/restore: disable screenshot drop-shadow on startup.
        // Idempotent; captures original pref value on first run.
        apply_screenshot_shadow_disable();
        // raw 180 capture/restore: dock tilesize reset — one-time only,
        // gated by system_state.plist sentinel (won't override user
        // resizing on subsequent boots).
        apply_dock_tilesize_reset_once();
        // raw 213: one-time legacy LaunchAgent cleanup (com.airgenome.wake
        // running caffeinate -dimsu) so the new in-process IOPMAssertion is
        // not running alongside the legacy caffeinate process.
        cleanup_legacy_wake_launchagent();
        // Rehydrate IOPMAssertions from persisted state. If wake=on / lid=on
        // were set in a previous session, recreate the assertions now so the
        // user's intent survives reboot / RunAtLoad.
        if (g_wake_on)       { wake_assertion_create(); }
        if (g_lid_closed_on) { lid_assertion_create();  }
        EDGE_THRESHOLD_PX   = env_int("AIRG_TAP_EDGE_PX",     EDGE_THRESHOLD_PX);
        CORNER_THRESHOLD_PX = env_int("AIRG_TAP_CORNER_PX",   CORNER_THRESHOLD_PX);
        DRAG_MIN_DISTANCE_PX= env_int("AIRG_TAP_DRAG_MIN_PX", DRAG_MIN_DISTANCE_PX);
        SPACES_GUARD_PX     = env_int("AIRG_TAP_SPACES_GUARD_PX", SPACES_GUARD_PX);

        if (!g_buttons_on && !g_scroll_on && !g_magnet_on) {
            emit_ai_native_error(
                "all-features-disabled: every AIRG_TAP_* flag is 0",
                "set at least one of AIRG_TAP_MOUSE_BUTTONS=1, "
                "AIRG_TAP_MOUSE_SCROLL=1, AIRG_TAP_MAGNET=1");
            emit_sentinel("FAIL", "all-features-disabled");
            return 64;
        }

        // AX permission check up front -- both CGEventTap and AX window
        // manipulation need it. Bailing here keeps native-tiling defaults
        // untouched on first-run-without-permission.
        if (g_magnet_on && !AXIsProcessTrusted()) {
            emit_ai_native_error(
                "ax-permission-missing: process not in Accessibility allowlist",
                "1) System Settings -> Privacy & Security -> Accessibility  "
                "2) add+enable build/airgenome binary  "
                "3) re-run (no reboot needed)");
            emit_sentinel("FAIL", "ax-permission-missing");
            return 78;
        }

        native_tiling_capture_and_disable();

        // Always subscribe to the union of all feature event types so the
        // menubar can flip g_*_on flags at runtime without re-creating the
        // CGEventTap. The callback gates per-event handling on the flags
        // (see tap_callback above), so an "off" feature is a cheap noop.
        // hive raw 209: kCGEventKeyDown required for launcher hotkey hook
        // (handle_keydown in tap_callback line ~804). Was missing in iter 14
        // tap.m integration — silent-dead-code bug found 2026-04-30 04:38.
        CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDown)
                         | CGEventMaskBit(kCGEventScrollWheel)
                         | CGEventMaskBit(kCGEventLeftMouseDown)
                         | CGEventMaskBit(kCGEventLeftMouseDragged)
                         | CGEventMaskBit(kCGEventLeftMouseUp)
                         | CGEventMaskBit(kCGEventKeyDown);

        // Mouse button feature needs to suppress the original button event
        // (return NULL from callback), so the tap must be in default mode
        // rather than listen-only. Magnet does not modify events but lives
        // in the same tap.
        g_tap = CGEventTapCreate(kCGSessionEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionDefault,
                                 mask,
                                 tap_callback,
                                 NULL);
        if (!g_tap) {
            native_tiling_restore();
            emit_ai_native_error(
                "cgeventtap-create-failed: missing Accessibility permission",
                "1) System Settings -> Privacy & Security -> Accessibility  "
                "2) add+enable build/airgenome binary  "
                "3) re-run (no reboot needed)");
            emit_sentinel("FAIL", "accessibility-permission-missing");
            return 78;
        }

        CFRunLoopSourceRef src =
            CFMachPortCreateRunLoopSource(NULL, g_tap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src,
                           kCFRunLoopCommonModes);
        CGEventTapEnable(g_tap, true);

        fprintf(stderr,
            "airgenome_tap: armed  buttons=%s scroll=%s magnet=%s  "
            "native-tiling=%s\n",
            g_buttons_on ? "on" : "off",
            g_scroll_on  ? "on" : "off",
            g_magnet_on  ? "on" : "off",
            (g_disable_native && g_magnet_on) ? "disabled" : "untouched");
        fprintf(stderr,
            "             magnet thresholds: edge=%dpx corner=%dpx drag-min=%dpx\n",
            EDGE_THRESHOLD_PX, CORNER_THRESHOLD_PX, DRAG_MIN_DISTANCE_PX);
        fflush(stderr);

        // NSApp accessory mode: shows in the macOS menu bar (NSStatusItem)
        // but does not appear in the Dock. install_signal_handlers must
        // run AFTER NSApp is initialized so the dispatch sources fire on
        // a live main queue.
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        install_status_item();
        install_signal_handlers();

        [NSApp run];

        if (src) CFRelease(src);
        if (g_tap) CFRelease(g_tap);
        native_tiling_restore();
    }
    return 0;
}
