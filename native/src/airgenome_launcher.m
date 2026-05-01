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
//     {"name": "email", "content": "me@example.com"}
//   ]
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
