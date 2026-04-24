// bin/menubar_launcher.m — airgenome menubar V5 (ObjC-native, 2026-04-24).
//
// 배경 (2026-04-24 convergence 기록 참조):
// hexa_v2 로 컴파일된 menubar 코드는 NSApp 수동 초기화 + custom event pump
// 을 쓸 경우 Sequoia 15.6.1 + adhoc 서명 조합에서 LaunchServices check-in 이
// 완료되지 않아 NSStatusItem 이 system menubar 에 register 되지 않음.
// 또한 launcher main context 에서 hexa FFI msg_send 가 objc_msgSend 를
// 올바로 호출하지 못해 0 반환/SIGSEGV.
//
// 본 launcher 는 완전 ObjC-native 경로:
//   1. NSApplicationMain 스타일 — sharedApplication + [NSApp run] 으로
//      정상 LaunchServices check-in + Aqua WindowServer bind.
//   2. NSStatusItem 을 ObjC 에서 생성 + retain (self.item 강참조).
//   3. NSTimer 가 tick 당 airgenome state 디렉토리의 JSON 을 읽어 title/menu
//      를 rebuild — hexa FFI 경유 없음.
//
// hexa 쪽 menubar_setup/menubar_tick 은 dead code 로 bin/menubar.hexa 에
// 남아있음 (향후 FFI init 수정되면 재활성화).

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <fcntl.h>
#import <sys/time.h>
#import <sys/stat.h>

// hexa autogen main — globals/string-literal 초기화만 필요 (u_main 호출은
// build_menubar.sh 에서 perl 로 제거됨). 사용하지 않아도 무방하지만 hexa C
// 심볼 (menubar_setup 등) 참조 시 링크 유지를 위해 호출.
extern int hexa_autogen_main(int argc, char **argv);

static NSString *AG_STATE_DIR(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"core/airgenome/state"];
}
static NSString *AG_PATH(NSString *rel) {
    return [AG_STATE_DIR() stringByAppendingPathComponent:rel];
}

static NSDictionary *readJSON(NSString *path) {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

// bar glyph — 0..100 → unicode block
static NSString *barGlyph(int pct) {
    if (pct < 13) return @"▁"; if (pct < 25) return @"▂";
    if (pct < 38) return @"▃"; if (pct < 50) return @"▄";
    if (pct < 63) return @"▅"; if (pct < 75) return @"▆";
    if (pct < 88) return @"▇"; return @"█";
}

static NSColor *pctColor(int pct) {
    if (pct < 50) return [NSColor systemGreenColor];
    if (pct < 80) return [NSColor systemYellowColor];
    return [NSColor systemRedColor];
}

@interface AirGenomeDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSTimer *tickTimer;
@property (nonatomic, strong) NSStatusItem *item;
@end

@implementation AirGenomeDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.item = [[NSStatusBar systemStatusBar]
                  statusItemWithLength:NSVariableStatusItemLength];
    [self rebuildUI];

    self.tickTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                      target:self
                                                    selector:@selector(onTick:)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)onTick:(NSTimer *)t {
    [self touchHeartbeat];
    [self rebuildUI];
}

- (void)touchHeartbeat {
    NSString *hb = AG_PATH(@"menubar_heartbeat");
    int fd = open([hb fileSystemRepresentation], O_CREAT | O_WRONLY, 0644);
    if (fd >= 0) close(fd);
    utimes([hb fileSystemRepresentation], NULL);
}

// 상태 스냅샷 수집 — state/ 디렉토리 JSON 직접 파싱.
- (NSMutableDictionary *)snapshot {
    NSMutableDictionary *s = [NSMutableDictionary dictionary];

    // Ω fixpoint
    NSDictionary *omega = readJSON(AG_PATH(@"ag_dsl_omega_fixpoint.json"));
    if (omega) {
        s[@"omega_psi"] = omega[@"lhs"] ?: @"";
        s[@"omega_eps"] = omega[@"rhs"] ?: @"";
        s[@"omega_diff"] = omega[@"alignment"] ?: @"";
        s[@"omega_verdict"] = omega[@"verdict"] ?: @"";
    }

    // throttle state (forge/predictive_throttle_state.json)
    NSString *thrPath = [NSHomeDirectory() stringByAppendingPathComponent:
                         @"core/airgenome/forge/predictive_throttle_state.json"];
    NSDictionary *thr = readJSON(thrPath);
    if (thr) {
        s[@"throttle_level"] = thr[@"level"] ?: @"?";
        s[@"pred_cpu"] = thr[@"pred_cpu"] ?: @(0);
        s[@"pred_ram"] = thr[@"pred_ram"] ?: @(0);
    }

    // infra_state (nexus)
    NSString *infraPath = [NSHomeDirectory() stringByAppendingPathComponent:
                           @"core/nexus/infra_state.json"];
    NSDictionary *infra = readJSON(infraPath);
    if (infra && [infra[@"hosts"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *hosts = infra[@"hosts"];
        NSDictionary *mac = hosts[@"mac"];
        if ([mac isKindOfClass:[NSDictionary class]]) {
            s[@"mac_cpu"] = mac[@"cpu_pct"] ?: @(0);
            s[@"mac_ram"] = mac[@"ram_pct"] ?: @(0);
        }
        NSDictionary *ubu1 = hosts[@"ubu1"];
        if ([ubu1 isKindOfClass:[NSDictionary class]]) {
            double load = [(ubu1[@"load"] ?: @"0") doubleValue];
            s[@"ubu1_load"] = @(load);
            s[@"ubu1_pct"] = @((int)(load * 12.5));  // 8-thread approx
        }
        NSDictionary *ubu2 = hosts[@"ubu2"];
        if ([ubu2 isKindOfClass:[NSDictionary class]]) {
            double load = [(ubu2[@"load"] ?: @"0") doubleValue];
            s[@"ubu2_load"] = @(load);
            s[@"ubu2_pct"] = @((int)(load / 12.0 * 100));
        }
        NSDictionary *htz = hosts[@"htz"];
        if ([htz isKindOfClass:[NSDictionary class]]) {
            double load = [(htz[@"load"] ?: @"0") doubleValue];
            s[@"htz_load"] = @(load);
            s[@"htz_pct"] = @((int)(load / 32.0 * 100));
        }
    }

    // file age for stale indication
    struct stat st;
    if (stat([infraPath fileSystemRepresentation], &st) == 0) {
        s[@"infra_age"] = @((int)(time(NULL) - st.st_mtime));
    }

    return s;
}

- (NSAttributedString *)composeTitle:(NSDictionary *)s {
    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] initWithString:@""];
    int mac = [s[@"mac_cpu"] intValue];
    int ubu1 = [s[@"ubu1_pct"] intValue];
    int ubu2 = [s[@"ubu2_pct"] intValue];
    int htz = [s[@"htz_pct"] intValue];

    NSArray *bars = @[@[barGlyph(mac), pctColor(mac)],
                      @[barGlyph(ubu1), pctColor(ubu1)],
                      @[barGlyph(ubu2), pctColor(ubu2)],
                      @[barGlyph(htz), pctColor(htz)]];
    int i = 0;
    for (NSArray *pair in bars) {
        NSMutableAttributedString *seg = [[NSMutableAttributedString alloc]
            initWithString:pair[0]
                attributes:@{NSForegroundColorAttributeName: pair[1]}];
        [out appendAttributedString:seg];
        if (i == 0) [out appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        i++;
    }
    return out;
}

- (NSMenu *)buildMenu:(NSDictionary *)s {
    NSMenu *m = [[NSMenu alloc] initWithTitle:@""];

    NSString *thrLine = [NSString stringWithFormat:@"Throttle:  %@   pred cpu=%@%%  ram=%@%%",
                         s[@"throttle_level"] ?: @"?",
                         s[@"pred_cpu"] ?: @(0), s[@"pred_ram"] ?: @(0)];
    [[m addItemWithTitle:thrLine action:nil keyEquivalent:@""] setEnabled:NO];

    [m addItem:[NSMenuItem separatorItem]];

    NSString *macLine = [NSString stringWithFormat:@"mac:  %@  cpu=%@%%  ram=%@%%",
                          barGlyph([s[@"mac_cpu"] intValue]),
                          s[@"mac_cpu"] ?: @(0), s[@"mac_ram"] ?: @(0)];
    [[m addItemWithTitle:macLine action:nil keyEquivalent:@""] setEnabled:NO];

    NSString *u1Line = [NSString stringWithFormat:@"ubu1: %@  load=%@  (≈%@%%)",
                         barGlyph([s[@"ubu1_pct"] intValue]),
                         s[@"ubu1_load"] ?: @(0), s[@"ubu1_pct"] ?: @(0)];
    [[m addItemWithTitle:u1Line action:nil keyEquivalent:@""] setEnabled:NO];

    NSString *u2Line = [NSString stringWithFormat:@"ubu2: %@  load=%@  (≈%@%%)",
                         barGlyph([s[@"ubu2_pct"] intValue]),
                         s[@"ubu2_load"] ?: @(0), s[@"ubu2_pct"] ?: @(0)];
    [[m addItemWithTitle:u2Line action:nil keyEquivalent:@""] setEnabled:NO];

    NSString *htzLine = [NSString stringWithFormat:@"htz:  %@  load=%@  (≈%@%%)",
                          barGlyph([s[@"htz_pct"] intValue]),
                          s[@"htz_load"] ?: @(0), s[@"htz_pct"] ?: @(0)];
    [[m addItemWithTitle:htzLine action:nil keyEquivalent:@""] setEnabled:NO];

    [m addItem:[NSMenuItem separatorItem]];

    // Ω fixpoint — observer UI 핵심 (Phase 1 관찰자 승격)
    NSString *verdict = s[@"omega_verdict"] ?: @"";
    NSString *omegaIcon = [verdict isEqualToString:@"ok"] ? @"Ω✓" : @"Ω⚠";
    if ([verdict length] == 0) omegaIcon = @"Ω?";
    NSString *omegaLine = [NSString stringWithFormat:@"%@  Ψ=%@  ε=%@  |Δ|=%@  (%@)",
                           omegaIcon,
                           s[@"omega_psi"] ?: @"-",
                           s[@"omega_eps"] ?: @"-",
                           s[@"omega_diff"] ?: @"-",
                           verdict.length ? verdict : @"no data"];
    [[m addItemWithTitle:omegaLine action:nil keyEquivalent:@""] setEnabled:NO];

    [m addItem:[NSMenuItem separatorItem]];

    NSMenuItem *reveal = [m addItemWithTitle:@"Reveal state dir"
                                      action:@selector(revealStateDir:)
                               keyEquivalent:@""];
    reveal.target = self;
    NSMenuItem *refresh = [m addItemWithTitle:@"Refresh now"
                                       action:@selector(refreshNow:)
                                keyEquivalent:@""];
    refresh.target = self;
    [m addItem:[NSMenuItem separatorItem]];
    [m addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];

    return m;
}

- (void)rebuildUI {
    NSDictionary *s = [self snapshot];
    if (self.item.button) {
        self.item.button.attributedTitle = [self composeTitle:s];
    }
    self.item.menu = [self buildMenu:s];
}

- (void)revealStateDir:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:AG_STATE_DIR()]];
}

- (void)refreshNow:(id)sender {
    [self onTick:nil];
}

@end

int main(int argc, const char *argv[]) {
    // hexa runtime 초기화 — globals + FFI symbol dlsym table 준비.
    hexa_autogen_main(argc, (char **)argv);

    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        AirGenomeDelegate *d = [[AirGenomeDelegate alloc] init];
        [app setDelegate:d];
        [app run];
    }
    return 0;
}
