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

// Launch action — invoke NSWorkspace to open the chosen app bundle.
BOOL airgenome_launcher_launch_app(NSURL *appBundleURL);

// State capture/restore (raw 180 axis).
// Capture original system-default tristate at startup; restore on exit.
void airgenome_launcher_capture_state(void);
void airgenome_launcher_restore_state(void);

// MARK: - Stub implementations (scaffold only, raw 168 minimum-viable)

// Default hotkey: ctrl+s (kVK_ANSI_S = 0x01, kCGEventFlagMaskControl).
// Future: read from ~/Library/Application Support/airgenome/launcher.jsonl
// for user-configurable override (raw 49 additive sister axis hotkey-binder).
#define AIRG_LAUNCHER_HOTKEY_KEYCODE 0x01
#define AIRG_LAUNCHER_HOTKEY_FLAGS   kCGEventFlagMaskControl

BOOL airgenome_launcher_handle_keydown(CGEventRef event) {
    if (!event) return NO;
    if (CGEventGetType(event) != kCGEventKeyDown) return NO;
    CGEventFlags flags = CGEventGetFlags(event);
    int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    // Match ctrl+s exactly: control flag set, keycode = S.
    // Mask out lock/numlock/caps so we ignore irrelevant modifier state.
    CGEventFlags relevant = flags & (kCGEventFlagMaskControl
                                     | kCGEventFlagMaskCommand
                                     | kCGEventFlagMaskAlternate
                                     | kCGEventFlagMaskShift);
    if (relevant == AIRG_LAUNCHER_HOTKEY_FLAGS
        && keycode == AIRG_LAUNCHER_HOTKEY_KEYCODE) {
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
static NSArray<NSURL *> *g_launcher_current_results = nil;
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
        return;
    }
    NSUInteger n = g_launcher_current_results.count;
    if (n == 0) {
        [g_launcher_status_label setStringValue:@"No matches"];
        return;
    }
    NSURL *first = g_launcher_current_results.firstObject;
    NSString *name = [[first lastPathComponent] stringByDeletingPathExtension];
    [g_launcher_status_label setStringValue:
        [NSString stringWithFormat:@"↵ %@  (%lu match%@)",
         name, (unsigned long)n, n == 1 ? @"" : @"es"]];
}

// Tiny delegate that bridges NSTextField text-change + Enter-key events
// to the launcher's search/launch functions. Single shared instance.
@interface AirgenomeLauncherDelegate : NSObject <NSTextFieldDelegate, NSWindowDelegate>
@end

@implementation AirgenomeLauncherDelegate
- (void)controlTextDidChange:(NSNotification *)note {
    NSTextField *tf = (NSTextField *)note.object;
    NSString *q = [tf stringValue];
    g_launcher_current_results = airgenome_launcher_search_apps(q);
    airgenome_launcher_refresh_status(q);
}
- (void)launcherEnterAction:(id)sender {
    (void)sender;
    if (g_launcher_current_results.count > 0) {
        airgenome_launcher_launch_app(g_launcher_current_results.firstObject);
    } else {
        airgenome_launcher_hide_overlay();
    }
}
// NSTextFieldDelegate: handle special keys (Esc dismiss, optional arrows for
// future result cycling). Returns YES if command consumed, NO to fall through.
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView
    doCommandBySelector:(SEL)cmd {
    (void)control; (void)textView;
    if (cmd == @selector(cancelOperation:)) {
        // Esc → dismiss launcher overlay.
        airgenome_launcher_hide_overlay();
        return YES;
    }
    return NO;
}
// NSWindowDelegate: auto-dismiss when user clicks outside (loses key window).
// Standard launcher UX: panel disappears on focus loss.
- (void)windowDidResignKey:(NSNotification *)note {
    (void)note;
    airgenome_launcher_hide_overlay();
}
@end

static AirgenomeLauncherDelegate *g_launcher_delegate = nil;

void airgenome_launcher_show_overlay(void) {
    // Idempotent: if already shown, just bring to front + clear search.
    if (g_launcher_panel && [g_launcher_panel isVisible]) {
        [g_launcher_search_field setStringValue:@""];
        [g_launcher_panel makeKeyAndOrderFront:nil];
        return;
    }
    // Lazy-create on first show; reused thereafter.
    if (!g_launcher_panel) {
        NSRect frame = NSMakeRect(0, 0, 600, 90);
        g_launcher_panel = [[NSPanel alloc]
            initWithContentRect:frame
                      styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [g_launcher_panel setLevel:NSFloatingWindowLevel];
        [g_launcher_panel setOpaque:NO];
        [g_launcher_panel setBackgroundColor:[[NSColor windowBackgroundColor] colorWithAlphaComponent:0.95]];
        [g_launcher_panel setHasShadow:YES];
        [g_launcher_panel setMovableByWindowBackground:YES];
        // Search input field at center of panel.
        NSRect fieldFrame = NSMakeRect(20, 45, 560, 30);
        g_launcher_search_field = [[NSTextField alloc] initWithFrame:fieldFrame];
        [g_launcher_search_field setBezelStyle:NSTextFieldRoundedBezel];
        [g_launcher_search_field setFont:[NSFont systemFontOfSize:18]];
        [g_launcher_search_field setPlaceholderString:@"Type app name..."];
        // Wire delegate for text-change + Enter-key handling.
        if (!g_launcher_delegate) {
            g_launcher_delegate = [[AirgenomeLauncherDelegate alloc] init];
        }
        [g_launcher_search_field setDelegate:g_launcher_delegate];
        [g_launcher_search_field setTarget:g_launcher_delegate];
        [g_launcher_search_field setAction:@selector(launcherEnterAction:)];
        [g_launcher_panel setDelegate:g_launcher_delegate];
        [[g_launcher_panel contentView] addSubview:g_launcher_search_field];
        // Status label below search field — visual feedback on Enter target.
        NSRect statusFrame = NSMakeRect(20, 12, 560, 22);
        g_launcher_status_label = [[NSTextField alloc] initWithFrame:statusFrame];
        [g_launcher_status_label setBezeled:NO];
        [g_launcher_status_label setDrawsBackground:NO];
        [g_launcher_status_label setEditable:NO];
        [g_launcher_status_label setSelectable:NO];
        [g_launcher_status_label setFont:[NSFont systemFontOfSize:13]];
        [g_launcher_status_label setTextColor:[NSColor secondaryLabelColor]];
        [g_launcher_status_label setStringValue:@""];
        [[g_launcher_panel contentView] addSubview:g_launcher_status_label];
    }
    [g_launcher_search_field setStringValue:@""];
    // Center on screen of currently-active mouse cursor.
    NSScreen *screen = [NSScreen mainScreen];
    NSRect screenFrame = [screen visibleFrame];
    NSRect panelFrame = [g_launcher_panel frame];
    NSPoint origin = NSMakePoint(
        screenFrame.origin.x + (screenFrame.size.width  - panelFrame.size.width)  / 2,
        screenFrame.origin.y + (screenFrame.size.height - panelFrame.size.height) * 0.66
    );
    [g_launcher_panel setFrameOrigin:origin];
    // Populate app cache once per show; cleared on hide_overlay.
    g_launcher_app_cache = airgenome_launcher_enumerate_apps();
    [g_launcher_panel makeKeyAndOrderFront:nil];
    [g_launcher_panel makeFirstResponder:g_launcher_search_field];
}

void airgenome_launcher_hide_overlay(void) {
    if (g_launcher_panel) {
        [g_launcher_panel orderOut:nil];
    }
    // Drop cache on hide; freshens app list on next show (apps may install/
    // uninstall between sessions). raw 65 idempotent: re-call OK.
    g_launcher_app_cache = nil;
    g_launcher_current_results = nil;
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

BOOL airgenome_launcher_launch_app(NSURL *appBundleURL) {
    if (!appBundleURL) return NO;
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
        } else if (app) {
            NSLog(@"[airgenome_launcher] launched: %@ (pid=%d)",
                  appBundleURL.path, app.processIdentifier);
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
