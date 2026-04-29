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
    int kc = airgenome_launcher_letter_to_keycode([keyPart characterAtIndex:0]);
    if (kc < 0) return;
    g_launcher_hotkey_flags = flags;
    g_launcher_hotkey_keycode = kc;
    NSLog(@"[airgenome_launcher] hotkey override: %@ (flags=0x%llx keycode=0x%02x)",
          spec, (unsigned long long)flags, kc);
}

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
        NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:sel.path];
        if (icon) [icon setSize:NSMakeSize(24, 24)];
        [g_launcher_status_icon setImage:icon];
    }
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
    g_launcher_selection_index = 0;  // reset on new query
    airgenome_launcher_refresh_status(q);
}
- (void)launcherEnterAction:(id)sender {
    (void)sender;
    NSUInteger n = g_launcher_current_results.count;
    if (n > 0) {
        NSUInteger idx = g_launcher_selection_index < n
            ? g_launcher_selection_index : 0;
        airgenome_launcher_launch_app(g_launcher_current_results[idx]);
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
    NSUInteger n = g_launcher_current_results.count;
    if (n > 0 && cmd == @selector(moveDown:)) {
        // Down arrow → next result (wrap around).
        g_launcher_selection_index = (g_launcher_selection_index + 1) % n;
        airgenome_launcher_refresh_status([g_launcher_search_field stringValue]);
        return YES;
    }
    if (n > 0 && cmd == @selector(moveUp:)) {
        // Up arrow → previous result (wrap around).
        g_launcher_selection_index =
            g_launcher_selection_index == 0 ? n - 1 : g_launcher_selection_index - 1;
        airgenome_launcher_refresh_status([g_launcher_search_field stringValue]);
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
        // Status row: icon (left) + label (right).
        NSRect iconFrame = NSMakeRect(20, 10, 24, 24);
        g_launcher_status_icon = [[NSImageView alloc] initWithFrame:iconFrame];
        [g_launcher_status_icon setImageScaling:NSImageScaleProportionallyDown];
        [[g_launcher_panel contentView] addSubview:g_launcher_status_icon];
        NSRect statusFrame = NSMakeRect(50, 12, 530, 22);
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
    // Populate app cache + recent set once per show; cleared on hide_overlay.
    g_launcher_app_cache = airgenome_launcher_enumerate_apps();
    airgenome_launcher_refresh_recent_set();
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

// Recent-launch path set, populated from launcher.jsonl on show_overlay.
// Each ".path" value from successful launches inside last 50 rows; matching
// apps get a +200 boost in match_score (raw 168 minimum-viable: substring
// match on JSONL, no full JSON parser).
static NSSet<NSString *> *g_launcher_recent_set = nil;

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
