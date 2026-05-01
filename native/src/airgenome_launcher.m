// airgenome_launcher.m — fuzzy app-name launcher extension scaffold
//
// hive raw 209 reference impl (cli-app-name-fuzzy-launcher-mandate)
// Status: scaffold (raw 168 minimum-viable; full impl by 2026-05-30 per
//         raw 209 proof-obligation closure)
// Created: 2026-04-29 (UTC)
//
// Inherited foundational mandates (hive raw 209 composition):
//   raw 177 cli-single-tcc-entry-per-project — REUSE airgenome.app TCC
//                                              grant; NO new bundle row
//   raw 178 cli-stable-designated-requirement — INHERIT existing cert-root
//                                                DR via setup_signing_cert.sh
//   raw 179 cli-multi-user-safe-runtime-path — runtime paths via
//                                              NSHomeDirectory + /Applications
//   raw 180 cli-system-state-capture-restore — signal handlers + restore
//                                              subcommand for SIGKILL recovery
//   raw 181 cli-uninstall-state-cleanup — Makefile install/uninstall pair
//                                          symmetry, idempotent removal
//
// Out of scope (raw 49 additive sister axes — separate hive raws):
//   - @-prefix snippet expander (text template emit)
//   - user-defined hotkey-action binder (custom shortcut → app/action)
//
// Build:  clang -O2 -Wall -Wextra -ObjC
//                -framework ApplicationServices -framework Carbon
//                -framework Cocoa -framework AppKit
//                -o build/airgenome_launcher native/src/airgenome_launcher.m
//
// Integration: this scaffold defines stub functions to be invoked from
//              airgenome_tap.m's CGEventTap callback when AIRG_TAP_LAUNCHER
//              env flag is set (per-feature opt-in pattern, raw 177 axis).

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

// MARK: - Forward declarations (raw 168 minimum-viable scaffold)

// Hotkey detection — to be invoked from airgenome_tap.m's CGEventCallback
// when the configured launcher hotkey (default ctrl+s) fires.
//
// Returns YES if event was consumed by launcher (suppress upstream),
// NO if event should propagate (not a launcher hotkey).
BOOL airgenome_launcher_handle_keydown(CGEventRef event);

// Popup overlay control — show/hide the NSPanel search overlay.
// Idempotent: calling show twice while already shown is a no-op.
void airgenome_launcher_show_overlay(void);
void airgenome_launcher_hide_overlay(void);

// Fuzzy app-name search backend.
// Returns array of matching NSURL app bundle URLs, ranked by relevance.
NSArray<NSURL *> *airgenome_launcher_search_apps(NSString *query);

// Internal helper - enumerate installed app bundles. Forward-declared because
// show_overlay references it (cache population) before its definition.
static NSArray<NSURL *> *airgenome_launcher_enumerate_apps(void);

// Internal helper - read launcher.jsonl history into recent-launch path set.
// Forward-declared because show_overlay primes the set before its definition.
static void airgenome_launcher_refresh_recent_set(void);

// Internal helper - app icon cache lookup. Forward-declared because
// refresh_status uses it before its definition.
static NSImage *airgenome_launcher_cached_icon(NSString *path);
// Forward declaration for icon cache dictionary so hide_overlay can clear it
// before its definition lower in the file.
static NSMutableDictionary<NSString *, NSImage *> *g_launcher_icon_cache;

// Inline-completion + history + snippet (raw 168 mandate 2026-05-01).
//   - Typed prefix lives in the real NSTextField (white text). The gray
//     completion is a SEPARATE borderless NSTextField (the "ghost") drawn
//     immediately to the right of the typed text — visually a placeholder
//     hint, not part of the field's storage. User mandate
//     "회색이란건 placeholder 영역" (2026-05-01) — keeping the suffix out
//     of the real field's text means backspace, IME composition, and
//     selection all behave naturally.
//   - Tab commits the ghost suffix into the real field; Enter
//     launches/copies; ↑/↓ navigate the last 5 typed queries.
//   - Query starting with '@' switches to snippet mode: completion ranks
//     against snippet names from snippets.json (name-sorted), and Enter
//     copies the snippet's "content" to the pasteboard.
static void airgenome_launcher_update_ghost(NSString *typed);
static void airgenome_launcher_apply_history(void);
static NSArray<NSDictionary *> *airgenome_launcher_load_snippets(void);
static NSArray<NSDictionary *> *airgenome_launcher_search_snippets(NSString *q);
// Forward-declared so the snippet search (defined above its callee) can
// reuse the same fuzzy ranker used for app names.
static NSInteger airgenome_launcher_match_score(NSString *appName, NSString *query);

// Settings manager — separate titled NSPanel with two NSTabViewItems
// ("앱 단축키" and "스니펫 관리"). Opened by selecting the synthetic
// "airgenome settings" entry in the launcher's search results — the
// launcher hides itself first, then the manager activates airgenome.
void airgenome_settings_show_manager(void);

// Defined in airgenome_hotkey.m. Reloads hotkey_bindings.json from disk
// into the live binding table. Called after the manager writes hotkey
// changes so the daemon picks them up without a launchd respawn.
extern void airgenome_hotkey_load_bindings(void);

// Launch action — invoke NSWorkspace to open the chosen app bundle.
BOOL airgenome_launcher_launch_app(NSURL *appBundleURL);

// State capture/restore (raw 180 axis).
// Capture original system-default tristate at startup; restore on exit.
void airgenome_launcher_capture_state(void);
void airgenome_launcher_restore_state(void);

// MARK: - Stub implementations (scaffold only, raw 168 minimum-viable)

// Default hotkey: ctrl+s. Override via env AIRG_TAP_LAUNCHER_HOTKEY.
// Format: "modifier+letter" where modifier ∈ {ctrl,cmd,alt,shift} and letter
// is a-z (lowercase). Examples: "cmd+space", "alt+l", "ctrl+s" (default).
// Parse once at first hotkey check; cached for session lifetime.
static int g_launcher_hotkey_keycode = 0x01;            // S
static CGEventFlags g_launcher_hotkey_flags = kCGEventFlagMaskControl;
static int g_launcher_hotkey_parsed = 0;

// Map a-z lowercase letter to macOS keycode (kVK_ANSI_*). Subset only;
// non-letter keys (space/tab/enter) deferred to future polish.
static int airgenome_launcher_letter_to_keycode(char c) {
    static const int map[26] = {
        0x00, 0x0B, 0x08, 0x02, 0x0E, 0x03, 0x05, 0x04,  // a b c d e f g h
        0x22, 0x26, 0x28, 0x25, 0x2E, 0x2D, 0x1F, 0x23,  // i j k l m n o p
        0x0C, 0x0F, 0x01, 0x11, 0x20, 0x09, 0x0D, 0x07,  // q r s t u v w x
        0x10, 0x06                                        // y z
    };
    if (c < 'a' || c > 'z') return -1;
    return map[c - 'a'];
}

static void airgenome_launcher_parse_hotkey_env(void) {
    if (g_launcher_hotkey_parsed) return;
    g_launcher_hotkey_parsed = 1;
    const char *env = getenv("AIRG_TAP_LAUNCHER_HOTKEY");
    if (!env || !*env) return;  // keep defaults
    NSString *spec = [[NSString stringWithUTF8String:env] lowercaseString];
    CGEventFlags flags = 0;
    if ([spec rangeOfString:@"ctrl"].location  != NSNotFound) flags |= kCGEventFlagMaskControl;
    if ([spec rangeOfString:@"cmd"].location   != NSNotFound) flags |= kCGEventFlagMaskCommand;
    if ([spec rangeOfString:@"alt"].location   != NSNotFound) flags |= kCGEventFlagMaskAlternate;
    if ([spec rangeOfString:@"opt"].location   != NSNotFound) flags |= kCGEventFlagMaskAlternate;
    if ([spec rangeOfString:@"shift"].location != NSNotFound) flags |= kCGEventFlagMaskShift;
    // Last char of spec is the letter (after final '+').
    NSRange last = [spec rangeOfString:@"+" options:NSBackwardsSearch];
    NSString *keyPart = last.location == NSNotFound
        ? spec
        : [spec substringFromIndex:last.location + 1];
    if (keyPart.length == 0 || flags == 0) return;
    // Named-key aliases (multi-char). Match these BEFORE letter fallback,
    // otherwise "cmd+space" would be parsed as 'cmd' + letter 's'.
    int kc = -1;
    if      ([keyPart isEqualToString:@"space"])  kc = 0x31;  // kVK_Space
    else if ([keyPart isEqualToString:@"tab"])    kc = 0x30;  // kVK_Tab
    else if ([keyPart isEqualToString:@"return"]) kc = 0x24;  // kVK_Return
    else if ([keyPart isEqualToString:@"enter"])  kc = 0x24;  // alias
    else if ([keyPart isEqualToString:@"escape"]) kc = 0x35;  // kVK_Escape
    else if ([keyPart isEqualToString:@"esc"])    kc = 0x35;  // alias
    else if (keyPart.length == 1) {
        kc = airgenome_launcher_letter_to_keycode(
            [keyPart characterAtIndex:0]);
    }
    if (kc < 0) return;
    g_launcher_hotkey_flags = flags;
    g_launcher_hotkey_keycode = kc;
    NSLog(@"[airgenome_launcher] hotkey override: %@ (flags=0x%llx keycode=0x%02x)",
          spec, (unsigned long long)flags, kc);
}

// Borderless NSPanel returns NO from canBecomeKeyWindow by default in some
// configurations — overriding here is the deterministic guarantee per
// Apple's own borderless-window sample code. raw 168 min-viable subclass:
// 4 lines, single override responsibility. 2026-04-30 04:55.
//
// Canonical Spotlight-overlay pattern (philz.blog + cindori + fazm.ai
// 2026-04-30): the NonactivatingPanel style-mask flag MUST be set in the
// designated initializer's styleMask argument and NEVER changed afterward —
// NSPanel calls -_setPreventsActivation: only during setup to propagate
// kCGSPreventsActivationTagBit to the WindowServer. Mutating styleMask
// post-init desynchronises the framework view and the WindowServer tag,
// which manifests as "panel appears key visually but cannot receive
// keyboard input" / "lingering / second-press fails". This subclass +
// init-time styleMask in show_overlay enforce that mandate.
@interface AirgenomeLauncherPanel : NSPanel
@end
@implementation AirgenomeLauncherPanel
- (BOOL)canBecomeKeyWindow  { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

// NSTextFieldCell defaults render single-line text with the baseline near
// the bottom of the cell — visibly off-center inside a tall row. User
// mandate 2026-04-30 "돋보기, 입력란 세로 가운데 정렬". This subclass
// shifts the title rect so the text bounds (font ascent + descent) land at
// the cell's vertical midpoint, both for static draw AND while editing
// (NSText field-editor paths).
@interface AirgenomeVCenterTextFieldCell : NSTextFieldCell
@end
@implementation AirgenomeVCenterTextFieldCell
- (NSRect)titleRectForBounds:(NSRect)theRect {
    NSRect r = [super titleRectForBounds:theRect];
    NSFont *f = self.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]];
    CGFloat textHeight = f.ascender - f.descender + f.leading;
    CGFloat offset = (theRect.size.height - textHeight) / 2.0;
    if (offset < 0) offset = 0;
    r.origin.y    = theRect.origin.y + offset;
    r.size.height = textHeight;
    return r;
}
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)v {
    [super drawInteriorWithFrame:[self titleRectForBounds:cellFrame] inView:v];
}
- (void)editWithFrame:(NSRect)aRect
               inView:(NSView *)v
               editor:(NSText *)t
             delegate:(id)d
                event:(NSEvent *)e {
    [super editWithFrame:[self titleRectForBounds:aRect]
                  inView:v editor:t delegate:d event:e];
}
- (void)selectWithFrame:(NSRect)aRect
                 inView:(NSView *)v
                 editor:(NSText *)t
               delegate:(id)d
                  start:(NSInteger)selStart
                 length:(NSInteger)selLength {
    [super selectWithFrame:[self titleRectForBounds:aRect]
                    inView:v editor:t delegate:d
                     start:selStart length:selLength];
}
@end

// NSTextField that auto-allocates the v-centered cell on init. NSControl
// queries +cellClass when initWithFrame: builds the default cell, so any
// instance of this class gets centered text without manual cell-swap.
@interface AirgenomeLauncherTextField : NSTextField
@end
@implementation AirgenomeLauncherTextField
+ (Class)cellClass { return [AirgenomeVCenterTextFieldCell class]; }
@end

BOOL airgenome_launcher_handle_keydown(CGEventRef event) {
    if (!event) return NO;
    if (CGEventGetType(event) != kCGEventKeyDown) return NO;
    airgenome_launcher_parse_hotkey_env();
    CGEventFlags flags = CGEventGetFlags(event);
    int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    // Mask out lock/numlock/caps so we ignore irrelevant modifier state.
    CGEventFlags relevant = flags & (kCGEventFlagMaskControl
                                     | kCGEventFlagMaskCommand
                                     | kCGEventFlagMaskAlternate
                                     | kCGEventFlagMaskShift);
    if (relevant == g_launcher_hotkey_flags
        && keycode == g_launcher_hotkey_keycode) {
        airgenome_launcher_show_overlay();
        return YES;
    }
    return NO;
}

// File-scope panel state. Single instance (idempotent show/hide).
// Strong references retained between show/hide cycles for fast reopen.
static NSPanel *g_launcher_panel = nil;
static NSTextField *g_launcher_search_field = nil;
static NSTextField *g_launcher_status_label = nil;
static NSImageView *g_launcher_status_icon = nil;
static NSArray<NSURL *> *g_launcher_current_results = nil;
static NSUInteger g_launcher_selection_index = 0;

// Inline-completion + history + snippet state (raw 168 mandate 2026-05-01).
//   g_launcher_ghost_field        — borderless NSTextField pinned beside the
//                                   real search field. Holds the gray
//                                   completion suffix. Non-editable, non-
//                                   selectable, hidden when no suffix.
//   g_launcher_typed              — mirrors the search field's stringValue
//                                   (snapshot taken on every textDidChange
//                                   and on programmatic mutations) so
//                                   handlers reading state from key paths
//                                   that pre-empt the field editor still
//                                   see the right value.
//   g_launcher_history            — last-5 typed queries (newest first,
//                                   dedup-on-reuse). Persists across hide/
//                                   show within the daemon process.
//   g_launcher_history_position   — −1 means "user input / empty"; ≥0 indexes
//                                   into g_launcher_history. ↑ increases
//                                   (older), ↓ decreases (newer / −1).
//   g_launcher_snippet_*          — snippet mode state, see snippet block
//                                   below for storage format.
static NSTextField *g_launcher_ghost_field = nil;
static NSString *g_launcher_typed = @"";
static NSMutableArray<NSString *> *g_launcher_history = nil;
static NSInteger g_launcher_history_position = -1;
static NSArray<NSDictionary *> *g_launcher_snippet_cache = nil;
static NSArray<NSDictionary *> *g_launcher_snippet_results = nil;
static BOOL g_launcher_snippet_mode = NO;

// Outside-click dismiss monitor. Canonical Spotlight pattern (fazm.ai +
// cindori): NSEvent +addGlobalMonitorForEvents fires the dismiss callback
// for left/right mouse-down events occurring OUTSIDE airgenome's process,
// which is exactly the surface we want for "click anywhere else to close".
// Installed in show_overlay, removed in hide_overlay. Strong reference
// retained on the global so we can pair add/remove symmetrically.
static id g_launcher_click_monitor = nil;

// Lazy-install minimal main menu so Cmd+A/C/V/X/Z dispatch via the standard
// responder chain to NSTextField's field editor. Without a main menu, macOS
// eats Cmd shortcuts before they reach the panel. User report 2026-04-30:
// "복사,전체선택등등 단축키 전혀안됨". raw 168 min-viable: only Edit menu
// + 5 standard items. raw 65 idempotent: noop after first install.
static void airgenome_launcher_install_main_menu(void) {
    if ([NSApp mainMenu] != nil) return;

    NSMenu *mainMenu = [[NSMenu alloc] init];

    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editItem setSubmenu:editMenu];
    [editMenu addItemWithTitle:@"Cut"
                        action:@selector(cut:)        keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copy:)       keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste"
                        action:@selector(paste:)      keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All"
                        action:@selector(selectAll:)  keyEquivalent:@"a"];
    [editMenu addItemWithTitle:@"Undo"
                        action:@selector(undo:)       keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo"
                        action:@selector(redo:)       keyEquivalent:@"Z"];
    [redo setKeyEquivalentModifierMask:
        NSEventModifierFlagCommand | NSEventModifierFlagShift];

    [NSApp setMainMenu:mainMenu];
}

// Focus-restore bookkeeping (g_launcher_prev_app / g_launcher_launching)
// REMOVED 2026-04-30 (canonical NonactivatingPanel migration). The previous
// approach captured the frontmost NSRunningApplication on show and called
// -activateFromApplication: on hide; layered hacks (NSApp activate /
// NSApp hide / unhide) caused (a) "second ⌃S 한번에 안됨" race and
// (b) panel-lingering instability after style-mask was added post-init.
// The canonical NonactivatingPanel pattern (philz.blog) makes airgenome
// NEVER become the active app, so there is nothing to restore — focus
// stays on the user's prior app for the entire show/hide cycle. Dead-code
// removal per raw 91 honest C3 (don't leave dead state behind).

// Saved input source for restore on hide. User report 2026-04-30 04:59:
// "검색해도 안됨 / 초기 언어는 무조건 영어 고정 / 한영키 상태면 영어로".
// All app names are ASCII so Hangul IME composing chars never match; we
// force ABC layout on show, restore previous source on hide so the user's
// app context (Hangul IME for chat etc.) stays untouched.
static TISInputSourceRef g_launcher_prev_input_source = NULL;

// Switch keyboard layout to ABC (US English). Saves current source so
// hide_overlay can restore. raw 65 idempotent: re-call OK; safe-noop if TIS
// fails (rare — typically only first user with no English layouts installed).
//
// History: an earlier iteration dispatched the TIS switch async on the main
// queue to dodge a race with NSApp.activate / makeKeyAndOrderFront ("ctrl+s
// 창이 다시 안뜸" 2026-04-30 09:20). With the canonical NonactivatingPanel
// migration the activation race no longer exists — and async actually
// reintroduced a different bug: if the user starts typing before the
// async block fires, TISSelectInputSource lands mid-edit and disrupts the
// field editor. Sync now, called BEFORE makeKeyAndOrderFront, finishes the
// IME swap before any keyboard event can reach the panel.
static void airgenome_launcher_force_english(void) {
    if (g_launcher_prev_input_source) {
        CFRelease(g_launcher_prev_input_source);
        g_launcher_prev_input_source = NULL;
    }
    g_launcher_prev_input_source = TISCopyCurrentKeyboardInputSource();
    NSDictionary *filter = @{
        (__bridge NSString *)kTISPropertyInputSourceID:
            @"com.apple.keylayout.ABC"
    };
    CFArrayRef sources = TISCreateInputSourceList(
        (__bridge CFDictionaryRef)filter, false);
    if (sources && CFArrayGetCount(sources) > 0) {
        TISInputSourceRef abc =
            (TISInputSourceRef)CFArrayGetValueAtIndex(sources, 0);
        TISSelectInputSource(abc);
    }
    if (sources) CFRelease(sources);
}

// Restore the input source captured by force_english. raw 65 idempotent.
static void airgenome_launcher_restore_input(void) {
    if (!g_launcher_prev_input_source) return;
    TISSelectInputSource(g_launcher_prev_input_source);
    CFRelease(g_launcher_prev_input_source);
    g_launcher_prev_input_source = NULL;
}
// App enumeration cache - populated on each show_overlay, invalidated on hide.
// Avoids filesystem traversal on every keystroke (raw 168 minimum-viable
// performance optimization). Typical /Applications enumeration is fast (~ms),
// but on slow disks or NFS mounts the per-keystroke cost would compound.
static NSArray<NSURL *> *g_launcher_app_cache = nil;

// Update the status label to show selection feedback. Called from
// controlTextDidChange whenever results change. Empty query → idle hint.
static void airgenome_launcher_refresh_status(NSString *query) {
    if (!g_launcher_status_label) return;
    if (query.length == 0) {
        [g_launcher_status_label setStringValue:@""];
        if (g_launcher_status_icon) [g_launcher_status_icon setImage:nil];
        return;
    }
    NSUInteger n = g_launcher_current_results.count;
    if (n == 0) {
        [g_launcher_status_label setStringValue:@"No matches"];
        if (g_launcher_status_icon) [g_launcher_status_icon setImage:nil];
        return;
    }
    if (g_launcher_selection_index >= n) g_launcher_selection_index = 0;
    NSURL *sel = g_launcher_current_results[g_launcher_selection_index];
    NSString *name = [[sel lastPathComponent] stringByDeletingPathExtension];
    [g_launcher_status_label setStringValue:
        [NSString stringWithFormat:@"↵ %@  (%lu/%lu — ↑↓ cycle)",
         name,
         (unsigned long)(g_launcher_selection_index + 1),
         (unsigned long)n]];
    // App icon preview: NSWorkspace iconForFile gives bundle icon (cached
    // by AppKit). raw 168 minimum-viable: synchronous on main thread, OK
    // for ≤24×24 size (iconForFile is fast for installed apps).
    if (g_launcher_status_icon) {
        [g_launcher_status_icon setImage:airgenome_launcher_cached_icon(sel.path)];
    }
}

// Update the trailing ghost field that shows the gray completion suffix.
// The real search field's stringValue stays exactly equal to what the user
// typed — the ghost is a sibling subview pinned to the right of the typed
// text. Two layout invariants make this work without a fudge factor:
//   1. Both fields use the same NSTextField subclass and font, so their
//      cell horizontal padding is identical and cancels out when we set
//      ghost.origin.x = main.origin.x + measured-typed-width.
//   2. Both fields have drawsBackground=NO so neither paints over the
//      other; the ghost draws strictly to the right of the field-editor
//      cursor (which sits at the end of typed text).
// Hidden when there is no suffix to show — keeps the right-side empty
// area clean instead of rendering an invisible zero-length label.
static void airgenome_launcher_update_ghost(NSString *typed) {
    if (!g_launcher_ghost_field || !g_launcher_search_field) return;
    NSString *suffix = nil;
    if (typed.length > 0) {
        NSString *bestName = nil;
        if (g_launcher_snippet_mode) {
            if (g_launcher_snippet_results.count > 0) {
                NSString *n = g_launcher_snippet_results[0][@"name"];
                if (n) bestName = [@"@" stringByAppendingString:n];
            }
        } else if (g_launcher_current_results.count > 0) {
            NSURL *url = g_launcher_current_results[0];
            bestName = [[url lastPathComponent]
                stringByDeletingPathExtension];
        }
        if (bestName
            && bestName.length > typed.length
            && [[bestName lowercaseString]
                hasPrefix:[typed lowercaseString]]) {
            // Suffix takes the matched name's own casing; the user's
            // casing for the typed prefix stays untouched in the real
            // field.
            suffix = [bestName substringFromIndex:typed.length];
        }
    }
    [g_launcher_ghost_field setStringValue:suffix ?: @""];
    NSFont *f = [NSFont systemFontOfSize:20];
    CGFloat typedWidth = 0;
    if (typed.length > 0) {
        typedWidth = ceil([typed sizeWithAttributes:
            @{ NSFontAttributeName: f }].width);
    }
    NSRect mainFrame = g_launcher_search_field.frame;
    CGFloat ghostX = mainFrame.origin.x + typedWidth;
    CGFloat ghostW = NSMaxX(mainFrame) - ghostX;
    if (ghostW < 0) ghostW = 0;
    [g_launcher_ghost_field setFrame:NSMakeRect(
        ghostX, mainFrame.origin.y, ghostW, mainFrame.size.height)];
    [g_launcher_ghost_field setHidden:(suffix.length == 0)];
}

// Apply the currently-selected history slot to the field. Position −1 means
// the bottom-of-stack empty input. Re-detects snippet mode from the recalled
// query so a recalled "@foo" still searches snippets.
static void airgenome_launcher_apply_history(void) {
    NSString *q = @"";
    if (g_launcher_history_position >= 0
        && g_launcher_history.count > 0) {
        NSInteger idx = g_launcher_history_position;
        if (idx >= (NSInteger)g_launcher_history.count) {
            idx = (NSInteger)g_launcher_history.count - 1;
        }
        q = g_launcher_history[idx];
    }
    g_launcher_typed = [q copy];
    g_launcher_selection_index = 0;
    if ([q hasPrefix:@"@"]) {
        g_launcher_snippet_mode = YES;
        g_launcher_snippet_results =
            airgenome_launcher_search_snippets([q substringFromIndex:1]);
        g_launcher_current_results = @[];
    } else {
        g_launcher_snippet_mode = NO;
        g_launcher_snippet_results = @[];
        g_launcher_current_results = airgenome_launcher_search_apps(q);
    }
    [g_launcher_search_field setStringValue:q];
    NSText *editor = [g_launcher_search_field currentEditor];
    if (editor) [editor setSelectedRange:NSMakeRange(q.length, 0)];
    airgenome_launcher_update_ghost(q);
    airgenome_launcher_refresh_status(q);
}

// Snippet storage: ~/Library/Application Support/airgenome/snippets.json.
// Format (per 2026-05-01 mandate "json 먼저 / 이름순 보관"):
//   [
//     {"name": "addr",  "content": "Seoul, ROK"},
//     {"name": "email", "content": "me@example.com"},
//     {"name": "sig",   "content": "감사합니다.\n--\nme@example.com"}
//   ]
// Multi-line content uses standard JSON "\n" escapes — the NSString flows
// straight through NSPasteboard so the pasted text preserves line breaks.
// Registration UI is intentionally deferred — the user edits this file by
// hand. Loaded on each show_overlay so edits take effect without restart.
// Sorted case-insensitively by name for deterministic ordering when the
// user types "@" with no further chars.
static NSArray<NSDictionary *> *airgenome_launcher_load_snippets(void) {
    NSString *dir = [NSHomeDirectory()
        stringByAppendingPathComponent:
            @"Library/Application Support/airgenome"];
    NSString *path = [dir stringByAppendingPathComponent:@"snippets.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return @[];
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data
                                             options:0
                                               error:&err];
    if (err || ![obj isKindOfClass:[NSArray class]]) {
        if (err) {
            NSLog(@"[airgenome_launcher] snippets.json parse error: %@",
                  err.localizedDescription);
        }
        return @[];
    }
    NSMutableArray *valid = [NSMutableArray array];
    for (id row in (NSArray *)obj) {
        if (![row isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = row;
        NSString *name = d[@"name"];
        NSString *content = d[@"content"];
        if (![name isKindOfClass:[NSString class]]) continue;
        if (![content isKindOfClass:[NSString class]]) continue;
        if (name.length == 0) continue;
        [valid addObject:@{ @"name": name, @"content": content }];
    }
    [valid sortUsingComparator:^NSComparisonResult(
        NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] caseInsensitiveCompare:b[@"name"]];
    }];
    return valid;
}

// Match snippets against `q` (the part after '@'). Empty `q` returns all
// snippets in stored (name-sorted) order so typing just '@' shows the first
// snippet's name as the inline-completion suffix.
static NSArray<NSDictionary *> *airgenome_launcher_search_snippets(NSString *q) {
    NSArray<NSDictionary *> *all = g_launcher_snippet_cache
        ? g_launcher_snippet_cache
        : airgenome_launcher_load_snippets();
    if (q == nil || q.length == 0) return all;
    NSMutableArray *scored = [NSMutableArray array];
    for (NSDictionary *snip in all) {
        NSString *name = snip[@"name"] ?: @"";
        NSInteger s = airgenome_launcher_match_score(name, q);
        if (s > 0) [scored addObject:@{ @"snip": snip, @"score": @(s) }];
    }
    [scored sortUsingComparator:^NSComparisonResult(
        NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    for (NSDictionary *d in scored) [result addObject:d[@"snip"]];
    return result;
}

// MARK: - Settings manager (앱 단축키 + 스니펫 관리, two NSTabViewItems).
//
// The launcher exposes a synthetic "airgenome settings" search result that
// opens this panel on Enter. Two tabs share a common Save/Cancel pair at
// the panel bottom. Save writes BOTH hotkey_bindings.json and
// snippets.json (each sorted for deterministic ordering), then asks
// airgenome_hotkey_load_bindings() to repopulate the daemon's live binding
// table so changes take effect without a launchd respawn. The launcher's
// snippet cache is rebuilt on its next show_overlay, no restart required.

static NSPanel *g_settings_panel = nil;

// Snippet tab.
static NSTableView *g_snippet_table = nil;
static NSTextField *g_snippet_name_field = nil;
static NSTextView *g_snippet_content_view = nil;
static NSMutableArray<NSMutableDictionary *> *g_snippet_edit_list = nil;
static NSInteger g_snippet_selected_row = -1;

// Hotkey tab. Per 2026-05-01 user mandate "직접입력이 아닌 드랍다운 2개",
// the hotkey value is built from a modifier popup × key popup combo
// rather than a free-form NSTextField — eliminates typo classes (mixed
// case, stray whitespace, unrecognized modifier names) at input time.
static NSTableView *g_hotkey_table = nil;
static NSPopUpButton *g_hotkey_mod_popup = nil;
static NSPopUpButton *g_hotkey_key_popup = nil;
static NSPopUpButton *g_hotkey_action_popup = nil;
static NSTextField *g_hotkey_target_field = nil;
static NSMutableArray<NSMutableDictionary *> *g_hotkey_edit_list = nil;
static NSInteger g_hotkey_selected_row = -1;

// Canonical-ordered modifier strings the popups offer. Listed in the
// order ctrl → cmd → alt → shift so multi-modifier combos compose
// deterministically (the daemon's parser is order-insensitive but the
// JSON-on-disk should be stable for diffing). The set covers the combos
// users actually bind in practice; exotic combos (e.g. fn+) are out of
// scope for this UI.
static NSArray<NSString *> *airgenome_hotkey_modifier_choices(void) {
    return @[
        @"ctrl", @"cmd", @"alt", @"shift",
        @"ctrl+shift", @"ctrl+cmd", @"ctrl+alt",
        @"cmd+shift", @"cmd+alt",
        @"alt+shift",
        @"ctrl+cmd+shift", @"ctrl+cmd+alt"
    ];
}

// Letter / digit / named keys the parser in airgenome_hotkey.m supports.
// Letters first, then digits, then named keys — matches the visual order
// users scan a popup top-to-bottom (alphabetical → numeric → special).
static NSArray<NSString *> *airgenome_hotkey_key_choices(void) {
    NSMutableArray *out = [NSMutableArray array];
    for (char c = 'a'; c <= 'z'; c++) {
        [out addObject:[NSString stringWithFormat:@"%c", c]];
    }
    for (char c = '0'; c <= '9'; c++) {
        [out addObject:[NSString stringWithFormat:@"%c", c]];
    }
    [out addObjectsFromArray:@[
        @"space", @"tab", @"return", @"escape"
    ]];
    return out;
}

// Load snippets.json into MUTABLE copies so the manager can edit values
// in place without re-fetching the dict through immutable accessors.
static NSMutableArray<NSMutableDictionary *> *
airgenome_snippets_load_mutable(void) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in airgenome_launcher_load_snippets()) {
        [out addObject:[d mutableCopy]];
    }
    return out;
}

// Persist snippet edit list to snippets.json. Drops empty-name entries
// (the launcher's load_snippets validation rejects them anyway, so
// persisting them would leave invisible rows on disk). Sorts by name
// case-insensitively to match load-time ordering, pretty-printed JSON
// for hand-editability.
static BOOL airgenome_snippets_save_to_disk(
    NSMutableArray<NSMutableDictionary *> *list) {
    [list sortUsingComparator:^NSComparisonResult(
        NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] caseInsensitiveCompare:b[@"name"]];
    }];
    NSMutableArray *valid = [NSMutableArray array];
    for (NSDictionary *m in list) {
        NSString *name = m[@"name"];
        if (![name isKindOfClass:[NSString class]] || name.length == 0) continue;
        [valid addObject:@{
            @"name":    name,
            @"content": m[@"content"] ?: @""
        }];
    }
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Application Support/airgenome"];
    [[NSFileManager defaultManager]
        createDirectoryAtPath:dir
        withIntermediateDirectories:YES
                   attributes:nil
                        error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"snippets.json"];
    NSError *err = nil;
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:valid
                   options:NSJSONWritingPrettyPrinted
                     error:&err];
    if (err || !data) {
        NSLog(@"[airgenome_snippets] JSON encode failed: %@",
              err.localizedDescription);
        return NO;
    }
    BOOL ok = [data writeToFile:path atomically:YES];
    if (!ok) NSLog(@"[airgenome_snippets] write failed: %@", path);
    return ok;
}

// Hotkey load: parses hotkey_bindings.json into mutable dicts so the
// manager can edit values in place. Missing fields default to safe values.
static NSMutableArray<NSMutableDictionary *> *
airgenome_hotkey_load_mutable(void) {
    NSMutableArray *out = [NSMutableArray array];
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Application Support/airgenome/hotkey_bindings.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return out;
    NSError *err = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data
                                                options:0 error:&err];
    if (err || ![parsed isKindOfClass:[NSDictionary class]]) return out;
    NSArray *bindings = ((NSDictionary *)parsed)[@"bindings"];
    if (![bindings isKindOfClass:[NSArray class]]) return out;
    for (id b in bindings) {
        if (![b isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *bd = b;
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        m[@"hotkey"] = bd[@"hotkey"] ?: @"";
        m[@"action"] = bd[@"action"] ?: @"activate-app";
        m[@"target"] = bd[@"target"] ?: @"";
        [out addObject:m];
    }
    return out;
}

// Hotkey save: alphabetical-by-hotkey, drops invalid rows (empty hotkey,
// or app-action without a target). Wraps the array in {"bindings": [...]}
// to match the existing schema airgenome_hotkey_load_bindings expects.
static BOOL airgenome_hotkey_save_to_disk(
    NSMutableArray<NSMutableDictionary *> *list) {
    [list sortUsingComparator:^NSComparisonResult(
        NSDictionary *a, NSDictionary *b) {
        return [a[@"hotkey"] caseInsensitiveCompare:b[@"hotkey"]];
    }];
    NSMutableArray *valid = [NSMutableArray array];
    for (NSDictionary *m in list) {
        NSString *hk     = m[@"hotkey"];
        NSString *action = m[@"action"];
        NSString *target = m[@"target"];
        if (![hk isKindOfClass:[NSString class]] || hk.length == 0) continue;
        if (![action isKindOfClass:[NSString class]]
            || action.length == 0) continue;
        BOOL needsTarget = [action isEqualToString:@"activate-app"]
                        || [action isEqualToString:@"toggle-app"];
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        out[@"hotkey"] = hk;
        out[@"action"] = action;
        if (needsTarget) {
            if (![target isKindOfClass:[NSString class]]
                || target.length == 0) continue;
            out[@"target"] = target;
        }
        [valid addObject:out];
    }
    NSDictionary *root = @{ @"bindings": valid };
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Application Support/airgenome"];
    [[NSFileManager defaultManager]
        createDirectoryAtPath:dir
        withIntermediateDirectories:YES
                   attributes:nil
                        error:nil];
    NSString *path = [dir stringByAppendingPathComponent:
        @"hotkey_bindings.json"];
    NSError *err = nil;
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:root
                   options:NSJSONWritingPrettyPrinted
                     error:&err];
    if (err || !data) {
        NSLog(@"[airgenome_hotkey] JSON encode failed: %@",
              err.localizedDescription);
        return NO;
    }
    BOOL ok = [data writeToFile:path atomically:YES];
    if (!ok) NSLog(@"[airgenome_hotkey] write failed: %@", path);
    return ok;
}

// One-line preview of a (possibly multiline) content string for the table
// row. First line + " …" suffix when there are additional lines, so the
// table makes it visually obvious which entries hold multiline payloads.
static NSString *airgenome_snippets_preview(NSString *content) {
    if (!content) return @"";
    NSRange nl = [content rangeOfString:@"\n"];
    if (nl.location == NSNotFound) return content;
    return [[content substringToIndex:nl.location]
        stringByAppendingString:@" …"];
}

@interface AirgenomeSettingsDelegate : NSObject
    <NSTableViewDataSource, NSTableViewDelegate>
- (void)snipAddClicked:(id)sender;
- (void)snipDeleteClicked:(id)sender;
- (void)hkAddClicked:(id)sender;
- (void)hkDeleteClicked:(id)sender;
- (void)hkBrowseClicked:(id)sender;
- (void)saveClicked:(id)sender;
- (void)cancelClicked:(id)sender;
@end

@implementation AirgenomeSettingsDelegate

// Push edit-field text back into the selected row's working dict. Called
// before any action that re-renders or persists, so typed-but-unsaved
// changes don't silently get dropped on row-switch / save / cancel.
- (void)flushSnippetFields {
    NSInteger row = g_snippet_selected_row;
    if (row < 0 || row >= (NSInteger)g_snippet_edit_list.count) return;
    NSMutableDictionary *snip = g_snippet_edit_list[row];
    snip[@"name"] = [g_snippet_name_field stringValue] ?: @"";
    snip[@"content"] = [g_snippet_content_view string] ?: @"";
}

- (void)flushHotkeyFields {
    NSInteger row = g_hotkey_selected_row;
    if (row < 0 || row >= (NSInteger)g_hotkey_edit_list.count) return;
    NSMutableDictionary *hk = g_hotkey_edit_list[row];
    NSString *mod = g_hotkey_mod_popup.titleOfSelectedItem ?: @"ctrl";
    NSString *key = g_hotkey_key_popup.titleOfSelectedItem ?: @"a";
    hk[@"hotkey"] = [NSString stringWithFormat:@"%@+%@", mod, key];
    hk[@"action"] = g_hotkey_action_popup.titleOfSelectedItem
                  ?: @"activate-app";
    hk[@"target"] = [g_hotkey_target_field stringValue] ?: @"";
}

// Both tables share this delegate object — dispatch by tableView identity.
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    if (tv == g_snippet_table) return g_snippet_edit_list.count;
    if (tv == g_hotkey_table)  return g_hotkey_edit_list.count;
    return 0;
}

- (id)tableView:(NSTableView *)tv
    objectValueForTableColumn:(NSTableColumn *)col
                          row:(NSInteger)row {
    if (tv == g_snippet_table) {
        if (row < 0 || row >= (NSInteger)g_snippet_edit_list.count) return nil;
        NSDictionary *s = g_snippet_edit_list[row];
        if ([col.identifier isEqualToString:@"name"]) return s[@"name"];
        if ([col.identifier isEqualToString:@"content"])
            return airgenome_snippets_preview(s[@"content"]);
    } else if (tv == g_hotkey_table) {
        if (row < 0 || row >= (NSInteger)g_hotkey_edit_list.count) return nil;
        NSDictionary *h = g_hotkey_edit_list[row];
        if ([col.identifier isEqualToString:@"hotkey"]) return h[@"hotkey"];
        if ([col.identifier isEqualToString:@"action"]) return h[@"action"];
        if ([col.identifier isEqualToString:@"target"]) {
            // Show last path component (e.g. "Safari.app") rather than the
            // full path — the full path lives in the edit field below.
            NSString *t = h[@"target"] ?: @"";
            NSString *last = [t lastPathComponent];
            return last.length > 0 ? last : t;
        }
    }
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)note {
    NSTableView *tv = note.object;
    if (tv == g_snippet_table) {
        [self flushSnippetFields];
        NSInteger row = tv.selectedRow;
        g_snippet_selected_row = row;
        if (row >= 0 && row < (NSInteger)g_snippet_edit_list.count) {
            NSDictionary *s = g_snippet_edit_list[row];
            [g_snippet_name_field setStringValue:s[@"name"] ?: @""];
            [g_snippet_content_view setString:s[@"content"] ?: @""];
        } else {
            [g_snippet_name_field setStringValue:@""];
            [g_snippet_content_view setString:@""];
        }
    } else if (tv == g_hotkey_table) {
        [self flushHotkeyFields];
        NSInteger row = tv.selectedRow;
        g_hotkey_selected_row = row;
        if (row >= 0 && row < (NSInteger)g_hotkey_edit_list.count) {
            NSDictionary *h = g_hotkey_edit_list[row];
            // Parse "ctrl+shift+q" → mod="ctrl+shift", key="q". The
            // daemon's parser (airgenome_hotkey.m) is order-insensitive,
            // but we canonicalize here so the popup selection matches one
            // of the predefined combo entries no matter how the JSON was
            // hand-edited (e.g. "shift+ctrl+q" → "ctrl+shift").
            NSString *spec = [(h[@"hotkey"] ?: @"") lowercaseString];
            NSMutableArray<NSString *> *parts = [NSMutableArray array];
            if ([spec rangeOfString:@"ctrl"].location  != NSNotFound)
                [parts addObject:@"ctrl"];
            if ([spec rangeOfString:@"cmd"].location   != NSNotFound)
                [parts addObject:@"cmd"];
            if ([spec rangeOfString:@"alt"].location   != NSNotFound)
                [parts addObject:@"alt"];
            if ([spec rangeOfString:@"opt"].location   != NSNotFound
                && [spec rangeOfString:@"alt"].location == NSNotFound)
                [parts addObject:@"alt"];
            if ([spec rangeOfString:@"shift"].location != NSNotFound)
                [parts addObject:@"shift"];
            NSString *mod = [parts componentsJoinedByString:@"+"];
            NSRange last = [spec rangeOfString:@"+"
                                       options:NSBackwardsSearch];
            NSString *key = (last.location == NSNotFound)
                ? spec
                : [spec substringFromIndex:last.location + 1];
            // Fall back to the first popup item when the parsed value
            // doesn't appear in the offered set (corrupt / unsupported
            // stored value), so the user can fix it via the popup.
            [g_hotkey_mod_popup selectItemWithTitle:mod];
            if (g_hotkey_mod_popup.indexOfSelectedItem < 0)
                [g_hotkey_mod_popup selectItemAtIndex:0];
            [g_hotkey_key_popup selectItemWithTitle:key];
            if (g_hotkey_key_popup.indexOfSelectedItem < 0)
                [g_hotkey_key_popup selectItemAtIndex:0];
            NSString *action = h[@"action"] ?: @"activate-app";
            [g_hotkey_action_popup selectItemWithTitle:action];
            if (g_hotkey_action_popup.indexOfSelectedItem < 0)
                [g_hotkey_action_popup selectItemAtIndex:0];
            [g_hotkey_target_field setStringValue:h[@"target"] ?: @""];
        } else {
            [g_hotkey_mod_popup selectItemAtIndex:0];
            [g_hotkey_key_popup selectItemAtIndex:0];
            [g_hotkey_action_popup selectItemAtIndex:0];
            [g_hotkey_target_field setStringValue:@""];
        }
    }
}

- (void)snipAddClicked:(id)sender {
    (void)sender;
    [self flushSnippetFields];
    NSMutableDictionary *fresh = [NSMutableDictionary
        dictionaryWithDictionary:@{ @"name": @"new", @"content": @"" }];
    [g_snippet_edit_list addObject:fresh];
    [g_snippet_table reloadData];
    NSInteger row = g_snippet_edit_list.count - 1;
    [g_snippet_table selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                 byExtendingSelection:NO];
    [g_snippet_table scrollRowToVisible:row];
    [g_settings_panel makeFirstResponder:g_snippet_name_field];
    [g_snippet_name_field selectText:nil];
}

- (void)snipDeleteClicked:(id)sender {
    (void)sender;
    NSInteger row = g_snippet_table.selectedRow;
    if (row < 0 || row >= (NSInteger)g_snippet_edit_list.count) return;
    [g_snippet_edit_list removeObjectAtIndex:row];
    g_snippet_selected_row = -1;
    [g_snippet_table reloadData];
    [g_snippet_name_field setStringValue:@""];
    [g_snippet_content_view setString:@""];
}

- (void)hkAddClicked:(id)sender {
    (void)sender;
    [self flushHotkeyFields];
    // Default to "ctrl+a" — first option of each popup; the user picks
    // a real combo + target before saving.
    NSMutableDictionary *fresh = [NSMutableDictionary
        dictionaryWithDictionary:@{
            @"hotkey": @"ctrl+a",
            @"action": @"activate-app",
            @"target": @""
        }];
    [g_hotkey_edit_list addObject:fresh];
    [g_hotkey_table reloadData];
    NSInteger row = g_hotkey_edit_list.count - 1;
    [g_hotkey_table selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                 byExtendingSelection:NO];
    [g_hotkey_table scrollRowToVisible:row];
    [g_settings_panel makeFirstResponder:g_hotkey_target_field];
}

- (void)hkDeleteClicked:(id)sender {
    (void)sender;
    NSInteger row = g_hotkey_table.selectedRow;
    if (row < 0 || row >= (NSInteger)g_hotkey_edit_list.count) return;
    [g_hotkey_edit_list removeObjectAtIndex:row];
    g_hotkey_selected_row = -1;
    [g_hotkey_table reloadData];
    [g_hotkey_mod_popup selectItemAtIndex:0];
    [g_hotkey_key_popup selectItemAtIndex:0];
    [g_hotkey_action_popup selectItemAtIndex:0];
    [g_hotkey_target_field setStringValue:@""];
}

- (void)hkBrowseClicked:(id)sender {
    (void)sender;
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseFiles:YES];
    [op setCanChooseDirectories:NO];
    [op setAllowsMultipleSelection:NO];
    // setAllowedFileTypes:@[@"app"] is deprecated in macOS 12+; the
    // -setAllowedContentTypes: replacement requires UniformTypeIdentifiers
    // and a UTType.application reference. Silence the deprecation but
    // keep the legacy call — modern macOS still respects it, and adding
    // the UT framework dependency for one filter is overkill.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [op setAllowedFileTypes:@[ @"app" ]];
#pragma clang diagnostic pop
    [op setDirectoryURL:[NSURL fileURLWithPath:@"/Applications"]];
    if ([op runModal] == NSModalResponseOK) {
        NSURL *url = op.URLs.firstObject;
        if (url) [g_hotkey_target_field setStringValue:url.path];
    }
}

- (void)saveClicked:(id)sender {
    (void)sender;
    [self flushSnippetFields];
    [self flushHotkeyFields];
    BOOL snipOK = airgenome_snippets_save_to_disk(g_snippet_edit_list);
    BOOL hkOK   = airgenome_hotkey_save_to_disk(g_hotkey_edit_list);
    if (!snipOK || !hkOK) {
        NSAlert *a = [[NSAlert alloc] init];
        a.messageText = @"airgenome settings 저장 실패";
        a.informativeText = [NSString stringWithFormat:
            @"snippets:%@ / hotkeys:%@",
            snipOK ? @"OK" : @"FAIL",
            hkOK   ? @"OK" : @"FAIL"];
        [a runModal];
        return;
    }
    // Live-reload the daemon's hotkey table so just-saved bindings take
    // effect on the very next keystroke (no launchd respawn needed).
    airgenome_hotkey_load_bindings();
    [g_settings_panel orderOut:nil];
}

- (void)cancelClicked:(id)sender {
    (void)sender;
    [g_settings_panel orderOut:nil];
}

@end

static AirgenomeSettingsDelegate *g_settings_delegate = nil;

// Build the 앱 단축키 tab content view: table on top, +/- buttons, three
// edit rows (Hotkey / Action popup / Target with Browse…).
static NSView *airgenome_settings_build_hotkey_tab(NSRect frame) {
    NSView *root = [[NSView alloc] initWithFrame:frame];
    [root setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    const CGFloat W = frame.size.width, H = frame.size.height;
    const CGFloat pad = 12.0;
    const CGFloat tableH = 200.0, btnH = 24.0, fieldH = 22.0;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:
        NSMakeRect(pad, H - pad - tableH, W - 2 * pad, tableH)];
    [scroll setHasVerticalScroller:YES];
    [scroll setBorderType:NSBezelBorder];
    [scroll setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    g_hotkey_table = [[NSTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *hkCol = [[NSTableColumn alloc] initWithIdentifier:@"hotkey"];
    hkCol.title = @"Hotkey"; hkCol.width = 120;
    [g_hotkey_table addTableColumn:hkCol];
    NSTableColumn *acCol = [[NSTableColumn alloc] initWithIdentifier:@"action"];
    acCol.title = @"Action"; acCol.width = 120;
    [g_hotkey_table addTableColumn:acCol];
    NSTableColumn *tgCol = [[NSTableColumn alloc] initWithIdentifier:@"target"];
    tgCol.title = @"Target"; tgCol.width = 240;
    [g_hotkey_table addTableColumn:tgCol];
    g_hotkey_table.delegate = g_settings_delegate;
    g_hotkey_table.dataSource = g_settings_delegate;
    [scroll setDocumentView:g_hotkey_table];
    [root addSubview:scroll];

    CGFloat btnY = H - pad - tableH - 8 - btnH;
    NSButton *addBtn = [NSButton buttonWithTitle:@"+ New"
                                           target:g_settings_delegate
                                           action:@selector(hkAddClicked:)];
    [addBtn setFrame:NSMakeRect(pad, btnY, 80, btnH)];
    [addBtn setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:addBtn];
    NSButton *delBtn = [NSButton buttonWithTitle:@"Delete"
                                           target:g_settings_delegate
                                           action:@selector(hkDeleteClicked:)];
    [delBtn setFrame:NSMakeRect(pad + 90, btnY, 80, btnH)];
    [delBtn setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:delBtn];

    CGFloat hkY = btnY - 12 - fieldH;
    NSTextField *hkLabel = [NSTextField labelWithString:@"Hotkey:"];
    [hkLabel setFrame:NSMakeRect(pad, hkY + 2, 60, fieldH)];
    [hkLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:hkLabel];
    // Modifier popup × Key popup. Compact widths chosen so the "+" label
    // sits centered between them and the row stays inside even a
    // narrowed panel.
    const CGFloat modW = 160, plusW = 14, keyW = 110;
    g_hotkey_mod_popup = [[NSPopUpButton alloc] initWithFrame:
        NSMakeRect(pad + 70, hkY - 2, modW, fieldH + 6) pullsDown:NO];
    [g_hotkey_mod_popup addItemsWithTitles:
        airgenome_hotkey_modifier_choices()];
    [g_hotkey_mod_popup setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:g_hotkey_mod_popup];
    NSTextField *plusLabel = [NSTextField labelWithString:@"+"];
    [plusLabel setAlignment:NSTextAlignmentCenter];
    [plusLabel setFrame:NSMakeRect(pad + 70 + modW + 2, hkY + 2,
                                    plusW, fieldH)];
    [plusLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:plusLabel];
    g_hotkey_key_popup = [[NSPopUpButton alloc] initWithFrame:
        NSMakeRect(pad + 70 + modW + 2 + plusW + 2, hkY - 2,
                   keyW, fieldH + 6) pullsDown:NO];
    [g_hotkey_key_popup addItemsWithTitles:
        airgenome_hotkey_key_choices()];
    [g_hotkey_key_popup setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:g_hotkey_key_popup];

    CGFloat acY = hkY - 8 - fieldH;
    NSTextField *acLabel = [NSTextField labelWithString:@"Action:"];
    [acLabel setFrame:NSMakeRect(pad, acY + 2, 60, fieldH)];
    [acLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:acLabel];
    g_hotkey_action_popup = [[NSPopUpButton alloc] initWithFrame:
        NSMakeRect(pad + 70, acY - 2, 180, fieldH + 6) pullsDown:NO];
    [g_hotkey_action_popup addItemWithTitle:@"activate-app"];
    [g_hotkey_action_popup addItemWithTitle:@"toggle-app"];
    [g_hotkey_action_popup addItemWithTitle:@"show-desktop"];
    [g_hotkey_action_popup setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:g_hotkey_action_popup];

    CGFloat tgY = acY - 8 - fieldH;
    NSTextField *tgLabel = [NSTextField labelWithString:@"Target:"];
    [tgLabel setFrame:NSMakeRect(pad, tgY + 2, 60, fieldH)];
    [tgLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:tgLabel];
    NSButton *browseBtn = [NSButton buttonWithTitle:@"Browse…"
                                              target:g_settings_delegate
                                              action:@selector(hkBrowseClicked:)];
    const CGFloat browseW = 88;
    [browseBtn setFrame:NSMakeRect(W - pad - browseW, tgY - 2,
                                    browseW, fieldH + 6)];
    [browseBtn setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [root addSubview:browseBtn];
    g_hotkey_target_field = [[NSTextField alloc] initWithFrame:
        NSMakeRect(pad + 70, tgY,
                   W - 2 * pad - 70 - browseW - 8, fieldH)];
    [[g_hotkey_target_field cell] setPlaceholderString:
        @"/Applications/Safari.app  (omit for show-desktop)"];
    [g_hotkey_target_field setAutoresizingMask:
        NSViewWidthSizable | NSViewMinYMargin];
    [root addSubview:g_hotkey_target_field];

    return root;
}

// Build the 스니펫 관리 tab content view: table + name field + multiline
// content textview.
static NSView *airgenome_settings_build_snippet_tab(NSRect frame) {
    NSView *root = [[NSView alloc] initWithFrame:frame];
    [root setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    const CGFloat W = frame.size.width, H = frame.size.height;
    const CGFloat pad = 12.0;
    const CGFloat tableH = 180.0, btnH = 24.0;
    const CGFloat fieldH = 22.0, labelH = 18.0;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:
        NSMakeRect(pad, H - pad - tableH, W - 2 * pad, tableH)];
    [scroll setHasVerticalScroller:YES];
    [scroll setBorderType:NSBezelBorder];
    [scroll setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    g_snippet_table = [[NSTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *nCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nCol.title = @"Name"; nCol.width = 120;
    [g_snippet_table addTableColumn:nCol];
    NSTableColumn *cCol = [[NSTableColumn alloc] initWithIdentifier:@"content"];
    cCol.title = @"Content (1-line preview)"; cCol.width = 340;
    [g_snippet_table addTableColumn:cCol];
    g_snippet_table.delegate = g_settings_delegate;
    g_snippet_table.dataSource = g_settings_delegate;
    [scroll setDocumentView:g_snippet_table];
    [root addSubview:scroll];

    CGFloat btnY = H - pad - tableH - 8 - btnH;
    NSButton *addBtn = [NSButton buttonWithTitle:@"+ New"
                                           target:g_settings_delegate
                                           action:@selector(snipAddClicked:)];
    [addBtn setFrame:NSMakeRect(pad, btnY, 80, btnH)];
    [addBtn setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:addBtn];
    NSButton *delBtn = [NSButton buttonWithTitle:@"Delete"
                                           target:g_settings_delegate
                                           action:@selector(snipDeleteClicked:)];
    [delBtn setFrame:NSMakeRect(pad + 90, btnY, 80, btnH)];
    [delBtn setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:delBtn];

    CGFloat nameY = btnY - 12 - fieldH;
    NSTextField *nameLabel = [NSTextField labelWithString:@"Name:"];
    [nameLabel setFrame:NSMakeRect(pad, nameY + 2, 60, fieldH)];
    [nameLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:nameLabel];
    g_snippet_name_field = [[NSTextField alloc] initWithFrame:
        NSMakeRect(pad + 70, nameY, W - 2 * pad - 70, fieldH)];
    [g_snippet_name_field setAutoresizingMask:
        NSViewWidthSizable | NSViewMinYMargin];
    [root addSubview:g_snippet_name_field];

    CGFloat contentLabelY = nameY - 8 - labelH;
    NSTextField *contentLabel = [NSTextField labelWithString:@"Content:"];
    [contentLabel setFrame:NSMakeRect(pad, contentLabelY, 80, labelH)];
    [contentLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:contentLabel];

    CGFloat contentY = pad;
    CGFloat contentH = contentLabelY - 4 - contentY;
    if (contentH < 80) contentH = 80;
    NSScrollView *contentScroll = [[NSScrollView alloc] initWithFrame:
        NSMakeRect(pad, contentY, W - 2 * pad, contentH)];
    [contentScroll setHasVerticalScroller:YES];
    [contentScroll setBorderType:NSBezelBorder];
    [contentScroll setAutoresizingMask:
        NSViewWidthSizable | NSViewHeightSizable];
    g_snippet_content_view = [[NSTextView alloc]
        initWithFrame:contentScroll.bounds];
    [g_snippet_content_view setRichText:NO];
    [g_snippet_content_view setAllowsUndo:YES];
    [g_snippet_content_view setFont:
        [NSFont userFixedPitchFontOfSize:12]];
    [g_snippet_content_view setMinSize:NSMakeSize(0, 0)];
    [g_snippet_content_view setMaxSize:
        NSMakeSize(FLT_MAX, FLT_MAX)];
    [g_snippet_content_view setVerticallyResizable:YES];
    [g_snippet_content_view setHorizontallyResizable:NO];
    [g_snippet_content_view setAutoresizingMask:NSViewWidthSizable];
    [g_snippet_content_view.textContainer setWidthTracksTextView:YES];
    [contentScroll setDocumentView:g_snippet_content_view];
    [root addSubview:contentScroll];

    return root;
}

void airgenome_settings_show_manager(void) {
    g_snippet_edit_list = airgenome_snippets_load_mutable();
    g_snippet_selected_row = -1;
    g_hotkey_edit_list = airgenome_hotkey_load_mutable();
    g_hotkey_selected_row = -1;

    if (!g_settings_panel) {
        const CGFloat W = 620.0, H = 540.0;
        const CGFloat pad = 16.0, actionH = 28.0;
        g_settings_panel = [[NSPanel alloc]
            initWithContentRect:NSMakeRect(0, 0, W, H)
                      styleMask:NSWindowStyleMaskTitled
                              | NSWindowStyleMaskClosable
                              | NSWindowStyleMaskResizable
                        backing:NSBackingStoreBuffered
                          defer:NO];
        g_settings_panel.title = @"airgenome settings";
        [g_settings_panel setReleasedWhenClosed:NO];
        [g_settings_panel setLevel:NSFloatingWindowLevel];
        [g_settings_panel setHidesOnDeactivate:NO];

        if (!g_settings_delegate) {
            g_settings_delegate =
                [[AirgenomeSettingsDelegate alloc] init];
        }
        NSView *cv = g_settings_panel.contentView;

        NSButton *saveBtn = [NSButton buttonWithTitle:@"Save"
                                                target:g_settings_delegate
                                                action:@selector(saveClicked:)];
        [saveBtn setFrame:NSMakeRect(W - pad - 80, pad, 80, actionH)];
        [saveBtn setKeyEquivalent:@"\r"];
        [saveBtn setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
        [cv addSubview:saveBtn];
        NSButton *cancelBtn = [NSButton buttonWithTitle:@"Cancel"
                                                  target:g_settings_delegate
                                                  action:@selector(cancelClicked:)];
        [cancelBtn setFrame:NSMakeRect(W - pad - 170, pad, 80, actionH)];
        [cancelBtn setKeyEquivalent:@"\033"];
        [cancelBtn setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
        [cv addSubview:cancelBtn];

        CGFloat tabY = pad + actionH + 12;
        CGFloat tabH = H - pad - tabY;
        NSTabView *tabView = [[NSTabView alloc] initWithFrame:
            NSMakeRect(pad, tabY, W - 2 * pad, tabH)];
        [tabView setAutoresizingMask:
            NSViewWidthSizable | NSViewHeightSizable];

        // 앱 단축키 listed first per user mandate ordering
        // ("앱단축키 , 스니펫 관리").
        NSRect tabFrame = NSMakeRect(0, 0, W - 2 * pad - 8, tabH - 30);
        NSTabViewItem *hkItem = [[NSTabViewItem alloc]
            initWithIdentifier:@"hk"];
        hkItem.label = @"앱 단축키";
        hkItem.view = airgenome_settings_build_hotkey_tab(tabFrame);
        [tabView addTabViewItem:hkItem];

        NSTabViewItem *snipItem = [[NSTabViewItem alloc]
            initWithIdentifier:@"snip"];
        snipItem.label = @"스니펫 관리";
        snipItem.view = airgenome_settings_build_snippet_tab(tabFrame);
        [tabView addTabViewItem:snipItem];

        [cv addSubview:tabView];
    }
    [g_hotkey_table reloadData];
    [g_snippet_table reloadData];
    [g_hotkey_mod_popup selectItemAtIndex:0];
    [g_hotkey_key_popup selectItemAtIndex:0];
    [g_hotkey_action_popup selectItemAtIndex:0];
    [g_hotkey_target_field setStringValue:@""];
    [g_snippet_name_field setStringValue:@""];
    [g_snippet_content_view setString:@""];
    [g_settings_panel center];
    [NSApp activateIgnoringOtherApps:YES];
    [g_settings_panel makeKeyAndOrderFront:nil];
    [g_settings_panel makeFirstResponder:g_hotkey_table];
}

// Tiny delegate that bridges NSTextField text-change + Enter-key events
// to the launcher's search/launch functions. Single shared instance.
@interface AirgenomeLauncherDelegate : NSObject <NSTextFieldDelegate, NSWindowDelegate>
@end

@implementation AirgenomeLauncherDelegate
- (void)controlTextDidChange:(NSNotification *)note {
    NSTextField *tf = (NSTextField *)note.object;
    NSString *q = [tf stringValue];
    NSLog(@"[airgenome_launcher] DBG textDidChange q='%@'", q);
    g_launcher_typed = [q copy];
    g_launcher_history_position = -1;  // user typed → reset history nav
    g_launcher_selection_index = 0;
    if ([q hasPrefix:@"@"]) {
        g_launcher_snippet_mode = YES;
        g_launcher_snippet_results =
            airgenome_launcher_search_snippets([q substringFromIndex:1]);
        g_launcher_current_results = @[];
    } else {
        g_launcher_snippet_mode = NO;
        g_launcher_snippet_results = @[];
        g_launcher_current_results = airgenome_launcher_search_apps(q);
    }
    airgenome_launcher_update_ghost(q);
    airgenome_launcher_refresh_status(q);
}
- (void)launcherEnterAction:(id)sender {
    (void)sender;
    // Append typed query to in-memory history (LIFO, dedup, cap 5). Both
    // app launches and snippet copies feed history — the user's "previous
    // input" recall (↑/↓) covers either mode.
    if (g_launcher_typed.length > 0) {
        if (!g_launcher_history) g_launcher_history = [NSMutableArray array];
        [g_launcher_history removeObject:g_launcher_typed];
        [g_launcher_history insertObject:[g_launcher_typed copy] atIndex:0];
        while (g_launcher_history.count > 5) {
            [g_launcher_history removeLastObject];
        }
    }
    if (g_launcher_snippet_mode) {
        if (g_launcher_snippet_results.count > 0) {
            NSDictionary *top = g_launcher_snippet_results[0];
            NSString *content = top[@"content"] ?: @"";
            NSPasteboard *pb = [NSPasteboard generalPasteboard];
            [pb clearContents];
            [pb setString:content forType:NSPasteboardTypeString];
            NSLog(@"[airgenome_launcher] snippet copied: @%@ (%lu chars)",
                  top[@"name"] ?: @"?", (unsigned long)content.length);
        }
        airgenome_launcher_hide_overlay();
        return;
    }
    NSUInteger n = g_launcher_current_results.count;
    if (n > 0) {
        NSUInteger idx = g_launcher_selection_index < n
            ? g_launcher_selection_index : 0;
        airgenome_launcher_launch_app(g_launcher_current_results[idx]);
    } else {
        airgenome_launcher_hide_overlay();
    }
}
// NSTextFieldDelegate: Esc dismiss, Tab commit completion, ↑/↓ history.
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView
    doCommandBySelector:(SEL)cmd {
    (void)control; (void)textView;
    if (cmd == @selector(cancelOperation:)) {
        airgenome_launcher_hide_overlay();
        return YES;
    }
    if (cmd == @selector(insertTab:) || cmd == @selector(insertBacktab:)) {
        // Tab: commit the ghost suffix into the real field so the gray
        // hint becomes typed input. Read the suffix from the ghost field
        // directly — it is the source of truth for "what would be
        // completed" — instead of recomputing the top match (the cache
        // could have changed between textDidChange and this keystroke).
        NSString *suffix = g_launcher_ghost_field
            ? [g_launcher_ghost_field stringValue] : @"";
        if (suffix.length > 0) {
            NSString *combined =
                [g_launcher_typed stringByAppendingString:suffix];
            g_launcher_typed = [combined copy];
            [g_launcher_search_field setStringValue:combined];
            NSText *editor = [g_launcher_search_field currentEditor];
            if (editor) {
                [editor setSelectedRange:NSMakeRange(combined.length, 0)];
            }
            // Re-search with the now-completed query so the ghost goes
            // empty (typed == name → no further suffix to show).
            if (g_launcher_snippet_mode) {
                g_launcher_snippet_results =
                    airgenome_launcher_search_snippets(
                        [combined substringFromIndex:1]);
            } else {
                g_launcher_current_results =
                    airgenome_launcher_search_apps(combined);
            }
            airgenome_launcher_update_ghost(combined);
        }
        return YES;
    }
    // No special-casing for deleteBackward / deleteForward: with the ghost
    // suffix living outside the field's storage, the default delete behavior
    // already does the right thing (one user-visible character per press),
    // and the next textDidChange recomputes the ghost from the new typed
    // prefix.
    if (cmd == @selector(moveUp:)) {
        // ↑: older (previous) keyword in history. Stops at the oldest entry
        // (no wrap — wrapping makes it ambiguous which end of the buffer
        // the user is at after a long hold).
        if (g_launcher_history.count > 0
            && g_launcher_history_position
                < (NSInteger)g_launcher_history.count - 1) {
            g_launcher_history_position++;
            airgenome_launcher_apply_history();
        }
        return YES;
    }
    if (cmd == @selector(moveDown:)) {
        // ↓: newer keyword. Past the most-recent entry the position lands
        // at −1 = empty input (per user mandate "가장 아래쪽은 빈칸").
        if (g_launcher_history_position >= 0) {
            g_launcher_history_position--;
            airgenome_launcher_apply_history();
        }
        return YES;
    }
    return NO;
}
// NSWindowDelegate: REMOVED windowDidResignKey auto-hide 2026-04-30 04:58.
// Was firing during the activation race (panel gains key briefly, then a
// system-internal focus event resigns it before the user can interact).
// User report "아예 안뜸" — panel created and immediately hidden via this
// handler. Dismiss surfaces remaining: Esc / Enter (post-launch) / ctrl+s
// toggle (in show_overlay) / outside click (handled by panel itself when
// it loses focus on user click in another app — this is OS-level, not us).
@end

static AirgenomeLauncherDelegate *g_launcher_delegate = nil;

void airgenome_launcher_show_overlay(void) {
    // Toggle behavior: ctrl+s while visible → hide (Spotlight pattern).
    // User request 2026-04-30 04:57 "다시 ctrl+s 눌렀을때 닫아져야되".
    if (g_launcher_panel && [g_launcher_panel isVisible]) {
        airgenome_launcher_hide_overlay();
        return;
    }

    // No NSApp activation here — the panel is a NonactivatingPanel, so
    // makeKeyAndOrderFront below brings the overlay to the front WITHOUT
    // making airgenome the active app. The user's prior app stays
    // frontmost, which is exactly the focus-restore semantics we want
    // and avoids the hide/unhide-race second-press bug entirely.

    // Lazy main menu install — required for Cmd+A/C/V/X/Z dispatch.
    airgenome_launcher_install_main_menu();

    // Force ABC keyboard layout — app names are ASCII; Hangul IME would
    // compose unmatchable chars. Saves prev source for restore on hide.
    airgenome_launcher_force_english();
    // Lazy-create on first show; reused thereafter.
    //
    // Visual redesign 2026-04-30 (user mandate "완전 블랙에 좌우 둥글게
    // 앞쪽에 검색 아이콘"): pure-black stadium (cornerRadius = height/2)
    // with magnifyingglass SF symbol left-anchored, top-row search input,
    // bottom-row status icon+label. Drop-shadow handled by NSPanel itself.
    if (!g_launcher_panel) {
        // Single-row stadium (user reference 2026-04-30 "이렇게 안정적이여
        // 야함") — height collapsed from 90 → 56 so the capsule is one
        // tight input row, no empty black space below. Status row REMOVED
        // from view (data path still tracks selection for ↑↓ cycling); a
        // future raw can re-introduce it as a separate floating panel
        // below the capsule when results exist.
        const CGFloat W = 600.0;
        const CGFloat H = 56.0;
        NSRect frame = NSMakeRect(0, 0, W, H);
        // CANONICAL Spotlight-overlay panel recipe (philz.blog +
        // cindori.com + fazm.ai, validated 2026-04-30). All
        // NonactivatingPanel-related properties are set HERE in the
        // designated init or immediately after — and never mutated again,
        // per philz.blog "set at init, never change" caveat. Mutating
        // styleMask post-init desyncs the kCGSPreventsActivationTagBit
        // WindowServer tag and produces the "lingering / can't dismiss /
        // second-press fails" symptom cluster we just escaped.
        //
        // Property-by-property reasoning:
        //   styleMask: Borderless | NonactivatingPanel
        //     - Borderless: pure-black stadium, no titlebar chrome.
        //     - NonactivatingPanel: panel becomes key WITHOUT activating
        //       airgenome — prior app stays frontmost the whole time, so
        //       no NSApp.activate / NSApp.hide bookkeeping is needed.
        //   level = NSFloatingWindowLevel: above normal windows.
        //   collectionBehavior:
        //     - CanJoinAllSpaces: ⌃S works in any Space without forcing
        //       a Space switch (Spotlight/Alfred parity).
        //     - FullScreenAuxiliary: visible on top of fullscreen apps.
        //     - Stationary: don't slide with Mission Control.
        //   isFloatingPanel = YES: explicit auxiliary marker (cindori).
        //   becomesKeyOnlyIfNeeded = YES: panel only takes keyboard focus
        //     when a control inside it (the search field) needs input —
        //     preserves the prior app's keyboard ownership otherwise.
        //   hidesOnDeactivate = NO: airgenome never activates anyway, but
        //     setting this NO is the canonical pairing that prevents
        //     spurious orderOut on app-level events.
        //   isReleasedWhenClosed = NO: keep panel alive across hide/show
        //     cycles so we don't leak NSPanel allocations on every ⌃S.
        g_launcher_panel = [[AirgenomeLauncherPanel alloc]
            initWithContentRect:frame
                      styleMask:NSWindowStyleMaskBorderless
                              | NSWindowStyleMaskNonactivatingPanel
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [g_launcher_panel setLevel:NSFloatingWindowLevel];
        [g_launcher_panel setCollectionBehavior:
            NSWindowCollectionBehaviorCanJoinAllSpaces
          | NSWindowCollectionBehaviorFullScreenAuxiliary
          | NSWindowCollectionBehaviorStationary];
        [g_launcher_panel setFloatingPanel:YES];
        // becomesKeyOnlyIfNeeded MUST be NO for a search-overlay: typing is
        // the primary interaction, so the panel needs to be unconditionally
        // key the moment it's shown. The agent set this YES per generic
        // "auxiliary panel" guidance, but YES blocked makeKeyAndOrderFront
        // from actually making the panel key — keystrokes silently leaked
        // into the prior app, and the user's eventual click there was
        // caught by the global mouse monitor as an "outside click",
        // dismissing the panel mid-typing. User report 2026-04-30
        // "검색창에서 타이핑시 닫히는경우등 버그".
        [g_launcher_panel setBecomesKeyOnlyIfNeeded:NO];
        [g_launcher_panel setHidesOnDeactivate:NO];
        [g_launcher_panel setReleasedWhenClosed:NO];
        [g_launcher_panel setOpaque:NO];
        [g_launcher_panel setBackgroundColor:[NSColor clearColor]];
        [g_launcher_panel setHasShadow:YES];
        [g_launcher_panel setMovableByWindowBackground:YES];

        // Pure-black stadium contentView: cornerRadius = H/2 → left/right
        // edges become semicircles, top/bottom become flat (pill shape).
        NSView *cv = [g_launcher_panel contentView];
        [cv setWantsLayer:YES];
        cv.layer.backgroundColor = [[NSColor blackColor] CGColor];
        cv.layer.cornerRadius   = H / 2.0;
        cv.layer.masksToBounds  = YES;

        if (!g_launcher_delegate) {
            g_launcher_delegate = [[AirgenomeLauncherDelegate alloc] init];
        }
        [g_launcher_panel setDelegate:g_launcher_delegate];

        // Search icon (front-left), vertically centered.
        const CGFloat iconSz   = 20.0;
        const CGFloat iconPadX = 24.0;             // safe inside stadium curve
        NSRect iconFrame = NSMakeRect(iconPadX, (H - iconSz) / 2,
                                      iconSz, iconSz);
        NSImageView *searchIcon = [[NSImageView alloc] initWithFrame:iconFrame];
        if (@available(macOS 11.0, *)) {
            NSImage *mg = [NSImage imageWithSystemSymbolName:@"magnifyingglass"
                                    accessibilityDescription:@"search"];
            if (mg) {
                searchIcon.image = mg;
                // User mandate 2026-04-30 "돋보기 굵고 투명도 50%":
                // Bold SF symbol weight + 50%-alpha white tint.
                searchIcon.symbolConfiguration = [NSImageSymbolConfiguration
                    configurationWithPointSize:iconSz
                                        weight:NSFontWeightBold];
                searchIcon.contentTintColor =
                    [NSColor colorWithWhite:1.0 alpha:0.5];
            }
        }
        [searchIcon setImageScaling:NSImageScaleProportionallyDown];
        [cv addSubview:searchIcon];

        // Search input — borderless, transparent, white text, dim placeholder.
        const CGFloat fieldX = iconPadX + iconSz + 10.0;
        const CGFloat fieldH = 30.0;
        NSRect fieldFrame = NSMakeRect(fieldX, (H - fieldH) / 2,
                                       W - fieldX - iconPadX, fieldH);
        g_launcher_search_field =
            [[AirgenomeLauncherTextField alloc] initWithFrame:fieldFrame];
        [g_launcher_search_field setBezeled:NO];
        [g_launcher_search_field setBordered:NO];
        [g_launcher_search_field setDrawsBackground:NO];
        [g_launcher_search_field setFocusRingType:NSFocusRingTypeNone];
        [g_launcher_search_field setFont:[NSFont systemFontOfSize:20
                                               weight:NSFontWeightRegular]];
        [g_launcher_search_field setTextColor:[NSColor whiteColor]];
        g_launcher_search_field.placeholderAttributedString =
            [[NSAttributedString alloc] initWithString:@"Search"
                attributes:@{
                    NSForegroundColorAttributeName:
                        [NSColor colorWithWhite:1.0 alpha:0.4],
                    NSFontAttributeName:
                        [NSFont systemFontOfSize:20]
                }];
        [g_launcher_search_field setDelegate:g_launcher_delegate];
        [g_launcher_search_field setTarget:g_launcher_delegate];
        [g_launcher_search_field setAction:@selector(launcherEnterAction:)];
        // NSTextFieldCell defaults sendsActionOnEndEditing=YES → action
        // (launcherEnterAction:) fires whenever the field commits or loses
        // first-responder, not just on Return. With launcherEnterAction
        // calling hide_overlay when results.count==0, ANY momentary focus
        // dip during typing dismissed the panel. Restrict to explicit
        // Return-key sends only.
        [[g_launcher_search_field cell] setSendsActionOnEndEditing:NO];
        [cv addSubview:g_launcher_search_field];

        // Ghost field — sibling subview that renders only the gray
        // completion suffix to the right of the typed text. Same font and
        // cell class as the real field so vertical centering and
        // horizontal padding line up exactly. Non-editable + non-
        // selectable + ignoresMouseDown = the user can't tab into it,
        // click it, or otherwise steal first-responder from the real
        // field.
        g_launcher_ghost_field =
            [[AirgenomeLauncherTextField alloc] initWithFrame:fieldFrame];
        [g_launcher_ghost_field setBezeled:NO];
        [g_launcher_ghost_field setBordered:NO];
        [g_launcher_ghost_field setDrawsBackground:NO];
        [g_launcher_ghost_field setEditable:NO];
        [g_launcher_ghost_field setSelectable:NO];
        [g_launcher_ghost_field setFocusRingType:NSFocusRingTypeNone];
        [g_launcher_ghost_field setFont:[NSFont systemFontOfSize:20
                                              weight:NSFontWeightRegular]];
        [g_launcher_ghost_field setTextColor:
            [NSColor colorWithWhite:1.0 alpha:0.4]];
        [g_launcher_ghost_field setStringValue:@""];
        [g_launcher_ghost_field setHidden:YES];
        [cv addSubview:g_launcher_ghost_field
             positioned:NSWindowBelow
             relativeTo:g_launcher_search_field];

        // Status icon + label intentionally NOT created here. refresh_status
        // is guarded by `if (!g_launcher_status_label) return` so the data
        // path stays inert without UI. Selection cycling via ↑↓ still works
        // (g_launcher_selection_index updates), and Enter launches whichever
        // result is at index 0 / current selection.
    }
    [g_launcher_search_field setStringValue:@""];
    if (g_launcher_ghost_field) {
        [g_launcher_ghost_field setStringValue:@""];
        [g_launcher_ghost_field setHidden:YES];
    }
    // Reset inline-completion + history + snippet state for the fresh
    // session. History array intentionally NOT cleared — it persists across
    // hide/show cycles within the daemon process so ↑ recalls past queries.
    g_launcher_typed = @"";
    g_launcher_history_position = -1;
    g_launcher_snippet_mode = NO;
    g_launcher_snippet_results = nil;
    g_launcher_snippet_cache = airgenome_launcher_load_snippets();
    // Center on screen of currently-active mouse cursor.
    NSScreen *screen = [NSScreen mainScreen];
    NSRect screenFrame = [screen visibleFrame];
    NSRect panelFrame = [g_launcher_panel frame];
    NSPoint origin = NSMakePoint(
        screenFrame.origin.x + (screenFrame.size.width  - panelFrame.size.width)  / 2,
        screenFrame.origin.y + (screenFrame.size.height - panelFrame.size.height) * 0.66
    );
    [g_launcher_panel setFrameOrigin:origin];
    // Populate app cache + recent set once per show; cleared on hide_overlay.
    g_launcher_app_cache = airgenome_launcher_enumerate_apps();
    airgenome_launcher_refresh_recent_set();
    [g_launcher_panel makeKeyAndOrderFront:nil];
    [g_launcher_panel makeFirstResponder:g_launcher_search_field];

    // Canonical outside-click dismiss (fazm.ai + cindori). Global monitor
    // fires for mouse-down events in OTHER processes — we don't see clicks
    // inside our own panel here, so clicking the search field is unaffected.
    // Pair with the orderOut + monitor-removal in hide_overlay (raw 65
    // idempotent: removing nil monitor is a no-op via guard below).
    if (!g_launcher_click_monitor) {
        g_launcher_click_monitor = [NSEvent
            addGlobalMonitorForEventsMatchingMask:
                NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown
            handler:^(NSEvent * _Nonnull e) {
                NSLog(@"[airgenome_launcher] DBG global mouse-down "
                      @"type=%lu loc=(%.0f,%.0f) — dismiss",
                      (unsigned long)e.type, e.locationInWindow.x,
                      e.locationInWindow.y);
                airgenome_launcher_hide_overlay();
            }];
    }
}

void airgenome_launcher_hide_overlay(void) {
    NSArray<NSString *> *frames = [NSThread callStackSymbols];
    NSLog(@"[airgenome_launcher] DBG hide_overlay caller=%@",
          frames.count >= 2 ? frames[1] : @"<top>");
    // Sentinel for mechanical symptom attribution (raw 91 honest C3 +
    // emit-driven debug discipline). Future "panel closed for mystery
    // reason" reports: grep airgenome.err for __AIRGENOME_LAUNCHER_DISMISS__
    // — its presence proves a clean dismiss path (esc/enter/outside-click/
    // toggle), its ABSENCE between a textDidChange and a launchd respawn
    // proves a crash. Lets us separate "user dismissed" from "process died"
    // without reading stack frames in DiagnosticReports/*.ips.
    fprintf(stderr, "__AIRGENOME_LAUNCHER_DISMISS__ ts=%.3f caller=%s\n",
            [[NSDate date] timeIntervalSince1970],
            frames.count >= 2 ? [frames[1] UTF8String] : "<top>");
    fflush(stderr);
    // Remove outside-click monitor BEFORE orderOut — symmetry with the
    // install in show_overlay. raw 65 idempotent: nil-guarded.
    if (g_launcher_click_monitor) {
        [NSEvent removeMonitor:g_launcher_click_monitor];
        g_launcher_click_monitor = nil;
    }
    if (g_launcher_panel) {
        [g_launcher_panel orderOut:nil];
    }
    // Restore the input source captured by force_english on show.
    airgenome_launcher_restore_input();
    // Drop cache on hide; freshens app list on next show (apps may install/
    // uninstall between sessions). raw 65 idempotent: re-call OK.
    g_launcher_app_cache = nil;
    g_launcher_current_results = nil;
    [g_launcher_icon_cache removeAllObjects];
    // Canonical NonactivatingPanel: airgenome was never frontmost while
    // the overlay was visible, so there's nothing to deactivate / restore.
    // orderOut alone hands keyboard focus straight back to the user's
    // prior app. No NSApp.hide / NSApp.activate / NSRunningApplication
    // bookkeeping is needed (and prior attempts at it produced the
    // "second-press fails" + "panel lingers" bugs we just retired).
}

// Enumerate installed .app bundles from canonical macOS locations.
// raw 179 multi-user-safe path: uses NSHomeDirectory (per-user) +
// /Applications + /System/Applications (system-wide). No /Users/<specific>/.
static NSArray<NSURL *> *airgenome_launcher_enumerate_apps(void) {
    NSMutableArray<NSURL *> *all = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *roots = @[
        @"/Applications",
        @"/System/Applications",
        [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"]
    ];
    for (NSString *root in roots) {
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:root isDirectory:&isDir] || !isDir) continue;
        NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *name in entries) {
            if (![name hasSuffix:@".app"]) continue;
            NSString *full = [root stringByAppendingPathComponent:name];
            [all addObject:[NSURL fileURLWithPath:full]];
        }
    }
    return all;
}

// Fuzzy-match score: 0 = no match, higher = better.
// Tiered ranking: exact-prefix > word-prefix > substring > char-subseq.
static NSInteger airgenome_launcher_match_score(NSString *appName, NSString *query) {
    if (query.length == 0) return 0;
    NSString *appLower = [appName lowercaseString];
    NSString *qLower   = [query lowercaseString];
    if ([appLower hasPrefix:qLower]) return 1000 - (NSInteger)appLower.length;
    NSRange r = [appLower rangeOfString:qLower];
    if (r.location != NSNotFound) {
        // Word-boundary match (preceded by space/-/.) ranks higher.
        if (r.location > 0) {
            unichar prev = [appLower characterAtIndex:r.location - 1];
            if (prev == ' ' || prev == '-' || prev == '.' || prev == '_') {
                return 700 - (NSInteger)r.location;
            }
        }
        return 500 - (NSInteger)r.location;
    }
    // Char-subsequence: query chars appear in order anywhere in name.
    NSUInteger qi = 0;
    for (NSUInteger i = 0; i < appLower.length && qi < qLower.length; i++) {
        if ([appLower characterAtIndex:i] == [qLower characterAtIndex:qi]) qi++;
    }
    if (qi == qLower.length) return 100 - (NSInteger)appLower.length;
    return 0;
}

// Recent-launch path set, populated from launcher.jsonl on show_overlay.
// Each ".path" value from successful launches inside last 50 rows; matching
// apps get a +200 boost in match_score (raw 168 minimum-viable: substring
// match on JSONL, no full JSON parser).
static NSSet<NSString *> *g_launcher_recent_set = nil;

// App icon cache: path → NSImage. Avoids redundant iconForFile fetch when
// user cycles through results (↑↓). Cleared on hide_overlay (raw 65 idempotent).
// (Forward-declared near top of file.)
static NSMutableDictionary<NSString *, NSImage *> *g_launcher_icon_cache = nil;

// Fetch icon with caching. Sets size to 24x24 once.
static NSImage *airgenome_launcher_cached_icon(NSString *path) {
    if (!g_launcher_icon_cache) {
        g_launcher_icon_cache = [NSMutableDictionary dictionary];
    }
    NSImage *cached = g_launcher_icon_cache[path];
    if (cached) return cached;
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    if (icon) {
        [icon setSize:NSMakeSize(24, 24)];
        g_launcher_icon_cache[path] = icon;
    }
    return icon;
}

static void airgenome_launcher_refresh_recent_set(void) {
    NSString *path = [[NSHomeDirectory()
        stringByAppendingPathComponent:@"Library/Application Support/airgenome"]
        stringByAppendingPathComponent:@"launcher.jsonl"];
    NSString *raw = [NSString stringWithContentsOfFile:path
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    if (!raw) { g_launcher_recent_set = nil; return; }
    NSArray<NSString *> *lines = [raw componentsSeparatedByString:@"\n"];
    // Last 50 lines, parse "path":"..." substring with success:true.
    NSMutableSet<NSString *> *set = [NSMutableSet set];
    NSInteger start = (NSInteger)lines.count - 50;
    if (start < 0) start = 0;
    for (NSInteger i = start; i < (NSInteger)lines.count; i++) {
        NSString *line = lines[i];
        if ([line rangeOfString:@"\"success\":true"].location == NSNotFound) continue;
        NSRange pStart = [line rangeOfString:@"\"path\":\""];
        if (pStart.location == NSNotFound) continue;
        NSUInteger valStart = pStart.location + pStart.length;
        NSRange tail = NSMakeRange(valStart, line.length - valStart);
        NSRange pEnd = [line rangeOfString:@"\"" options:0 range:tail];
        if (pEnd.location == NSNotFound) continue;
        NSString *p = [line substringWithRange:NSMakeRange(valStart, pEnd.location - valStart)];
        [set addObject:p];
    }
    g_launcher_recent_set = set;
}

// Synthetic search-result URL representing the "airgenome settings"
// virtual entry. The path doesn't exist on disk; launch_app intercepts
// any URL whose last path component equals this constant and routes to
// airgenome_settings_show_manager() instead of NSWorkspace.openApp.
//
// Why use an NSURL at all (instead of a typed Result struct)? The
// launcher's UI plumbing — search results array, ghost-suffix lookup,
// history entries — is all keyed off NSURL; a synthetic URL slots into
// the existing pipeline with one tiny intercept point in launch_app.
NSString * const kAirgenomeSettingsSentinel = @"airgenome settings.app";

static NSURL *airgenome_settings_sentinel_url(void) {
    return [NSURL fileURLWithPath:
        [@"/" stringByAppendingPathComponent:kAirgenomeSettingsSentinel]];
}

BOOL airgenome_launcher_is_settings_sentinel(NSURL *url) {
    if (!url) return NO;
    return [[url lastPathComponent]
        isEqualToString:kAirgenomeSettingsSentinel];
}

NSArray<NSURL *> *airgenome_launcher_search_apps(NSString *query) {
    if (!query || query.length == 0) return @[];
    // Use cached enumeration when available (populated on show_overlay).
    NSArray<NSURL *> *all = g_launcher_app_cache
        ? g_launcher_app_cache
        : airgenome_launcher_enumerate_apps();
    NSMutableArray *scored = [NSMutableArray array];
    for (NSURL *url in all) {
        NSString *name = [[url lastPathComponent] stringByDeletingPathExtension];
        NSInteger s = airgenome_launcher_match_score(name, query);
        if (s > 0) {
            // Recent-launch boost: +200 if app launched within last 50 rows.
            if (g_launcher_recent_set
                && [g_launcher_recent_set containsObject:url.path]) {
                s += 200;
            }
            [scored addObject:@{ @"url": url, @"score": @(s) }];
        }
    }
    // Synthetic "airgenome settings" entry — included whenever match_score
    // says the query matches its display name. +50 boost over the same
    // raw score keeps the settings entry above bare "airgenome.app" when
    // both prefix-match the user's query, so typing "air" surfaces the
    // settings panel as the top suggestion (and the ghost-suffix
    // completes "genome settings").
    NSInteger settingsScore = airgenome_launcher_match_score(
        @"airgenome settings", query);
    if (settingsScore > 0) {
        [scored addObject:@{
            @"url":   airgenome_settings_sentinel_url(),
            @"score": @(settingsScore + 50)
        }];
    }
    [scored sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];
    NSMutableArray<NSURL *> *result = [NSMutableArray array];
    for (NSDictionary *d in scored) [result addObject:d[@"url"]];
    return result;
}

// raw 77 audit ledger: append one JSONL row per launch.
// Path: ~/Library/Application Support/airgenome/launcher.jsonl (raw 179
// multi-user-safe NSHomeDirectory). raw 65 idempotent: append-only, no edit.
// raw 91 honest C3: best-effort write; failures NSLog'd but do not block launch.
static void airgenome_launcher_append_history(NSURL *appURL, BOOL success) {
    NSString *dir = [NSHomeDirectory()
        stringByAppendingPathComponent:@"Library/Application Support/airgenome"];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES
                   attributes:nil error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"launcher.jsonl"];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    df.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSString *name = [[appURL lastPathComponent] stringByDeletingPathExtension];
    NSString *row = [NSString stringWithFormat:
        @"{\"ts\":\"%@\",\"event\":\"launcher-launch\",\"app\":\"%@\","
        @"\"path\":\"%@\",\"success\":%@,\"raw\":\"raw 209\"}\n",
        [df stringFromDate:[NSDate date]],
        name, appURL.path, success ? @"true" : @"false"];
    NSData *data = [row dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [data writeToFile:path atomically:YES];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:data];
    [fh closeFile];
}

BOOL airgenome_launcher_launch_app(NSURL *appBundleURL) {
    if (!appBundleURL) return NO;
    // Synthetic "airgenome settings" entry → open the in-process tabbed
    // manager instead of asking NSWorkspace to launch a non-existent
    // /airgenome settings.app bundle. Hide the launcher first so its
    // non-activating panel surrenders the keyboard surface before
    // [NSApp activateIgnoringOtherApps:] hands focus to the manager.
    if (airgenome_launcher_is_settings_sentinel(appBundleURL)) {
        airgenome_launcher_hide_overlay();
        airgenome_settings_show_manager();
        return YES;
    }
    // No focus-restore bookkeeping — canonical NonactivatingPanel means
    // airgenome was never frontmost, so the just-launched app (configured
    // below with cfg.activates=YES) takes focus directly via NSWorkspace
    // without us needing to suppress an out-of-band restore step.
    // Modern macOS 10.15+ API: openApplicationAtURL:configuration:completionHandler:
    // Returns immediately; activation happens async. We hide the launcher overlay
    // synchronously (UX: user sees overlay close + app launch in one motion).
    NSWorkspaceOpenConfiguration *cfg = [NSWorkspaceOpenConfiguration configuration];
    cfg.activates = YES;
    cfg.addsToRecentItems = YES;
    [[NSWorkspace sharedWorkspace]
        openApplicationAtURL:appBundleURL
               configuration:cfg
           completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[airgenome_launcher] launch failed: %@ (%@)",
                  appBundleURL.path, error.localizedDescription);
            airgenome_launcher_append_history(appBundleURL, NO);
        } else if (app) {
            NSLog(@"[airgenome_launcher] launched: %@ (pid=%d)",
                  appBundleURL.path, app.processIdentifier);
            airgenome_launcher_append_history(appBundleURL, YES);
        }
    }];
    airgenome_launcher_hide_overlay();
    return YES;
}

// raw 180 capture/restore axis - launcher current scope NO-OP (honest C3).
//
// Audit of mutations the launcher actually performs:
//   - CGEventTap hook: managed by airgenome_tap.m (raw 177 single TCC entry);
//                      launcher reuses the existing tap, does NOT install its own.
//   - NSPanel popup:   in-process AppKit state; no system default written.
//   - NSWorkspace.openApplication: launch action; no system default written.
//   - Hotkey detection: pure event-flag inspection in handle_keydown;
//                       no NSGlobalDomain or com.apple.* default mutated.
//
// Since the launcher writes ZERO system state today, capture/restore are
// documented no-ops. Future raw 49 additive sister axis (user-defined
// hotkey-action binder) MAY mutate state - at that time these functions
// MUST be filled in per raw 180 contract (capture original tristate at
// startup; paired restore on signal AND restore-* subcommand for SIGKILL).
//
// This keeps the function symbols stable for raw 180 audit linting while
// honestly disclosing that the contract reduces to no-op for the current
// launcher scope. Calling this from `airgenome launcher restore` subcommand
// is safe and idempotent.

void airgenome_launcher_capture_state(void) {
    // No-op: launcher scope today writes no system state. See header audit.
}

void airgenome_launcher_restore_state(void) {
    // No-op: nothing to restore. See header audit. Idempotent re-invocation OK.
}
