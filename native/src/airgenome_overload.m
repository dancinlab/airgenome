// airgenome_overload.m — in-process macOS load watcher + claude-priority gate.
//
// 60s 주기:
//   1. getloadavg(3) load1 > LOAD_THRESHOLD → "macOS overload" notify (쿨다운)
//      + 가장 무거운 non-claude / non-system PID 들을 Darwin background tier 로
//        강등 → claude code CLI 가 P-core / 정상 우선순위 독식.
//   2. /bin/ps 로 CPU > CPU_THRESHOLD PID 추적, sliding window → "runaway PID"
//      notify + 해당 PID background tier 강등.
//   3. 매 tick: claude code CLI PID 들을 taskpolicy -B (not-background) 로 유지
//      — 다른 모듈(idle-dup gate 등)의 taskpolicy_bg 강등을 무효화하는 상시 약-부스트.
//
// "claude code CLI" 판정:
//   - wrapping mode 의 실 바이너리:  …/.local/bin/claude.real
//   - launcher / native 바이너리:    basename == "claude"
//   - 셸 래퍼 / node·bun 기동:        argv 에 .local/bin/claude · /claude/cli.js 등
//
// 메커니즘은 `taskpolicy -b / -B` 만 사용 — `renice` 상향(저우선)은 root 아닌
// 사용자가 되돌릴 수 없는 일방통행이라 회피. taskpolicy background state 는
// 같은 uid 프로세스에 대해 root 없이 켜고/끌 수 있어 load 회복 시 원복 가능.
// 절대 kill 미수행 — 14+ active claude 세션 보호. 알림 + 우선순위 조정만.
//
// 단일 launchd 진입점 정책 (com.airgenome.tap) 준수 — 별도 plist 미생성.
// dispatch_source_t timer 가 app 수명 내내 살아있음.
//
// State: in-memory. App 재시작 시 reset — runaway 카운터 새 사이클부터 재시작
// (재시작 직후 burst 알림 방지). 강등한 PID 들은 watcher off / app 종료 시 원복.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

// "idle 걸리기 전 조기 경보" 컨셉. 임계 조정 2026-05-10:
//   load1 > 80    : 일상 heavy 작업 (multi-claude + IDE + Safari) 위로
//   cpu  > 80%    : runaway 명확 (50% 는 정상 build/encoding 도 잡음)
//   runaway 10min : 5min 은 normal long task (ffmpeg, swift-build) 도 catch
//   cooldown 10min: 같은 load1 알림 매 tick 재발화 방지
#define AIRGENOME_OVERLOAD_INTERVAL_S        60
#define AIRGENOME_OVERLOAD_LOAD_THRESHOLD    80.0
#define AIRGENOME_OVERLOAD_CPU_THRESHOLD     80.0
#define AIRGENOME_OVERLOAD_RUNAWAY_AGE_S     600
#define AIRGENOME_OVERLOAD_ALERT_COOLDOWN_S  600
// load1 임계 초과 시 background tier 로 강등할 후보: CPU% 가 이 값 이상인
// non-claude / non-system PID 중 상위 N개. claude 가 자원 독식하도록 공격적.
// (load 가 회복되면 전부 default 로 원복 — #define 으로 조정 가능)
#define AIRGENOME_OVERLOAD_DEPRIO_CPU_FLOOR  15.0
#define AIRGENOME_OVERLOAD_DEPRIO_TOP_N      12
// ps -A 파싱 상한 (정상 Mac proc 수 << 1024). claude idle 세션도 0% 라 끝까지 봐야 함.
#define AIRGENOME_OVERLOAD_PS_MAX            1024

static dispatch_source_t g_overload_src = NULL;
static dispatch_queue_t  g_overload_q   = NULL;
// 0 = suspended (dispatch source not resumed), 1 = running.
// Toggle 시 suspend/resume balance 위해 명시 추적. dispatch_source_create 직후
// 상태는 suspended — 첫 enable 시 resume.
static int               g_overload_running = 0;

// pid (NSNumber) → @{ @"first_seen": NSNumber<time_t>, @"notified": NSNumber<bool> }
static NSMutableDictionary *g_runaway_state = nil;
// load1 알림 쿨다운 — 같은 조건 매 60s 재발화 방지.
static time_t g_last_load_alert_ts = 0;
// 우리가 background tier 로 강등한 PID 들 (NSNumber). load 회복 / watcher off 시 원복.
static NSMutableSet *g_deprioritized = nil;
// 직전 tick 의 claude PID set (NSNumber) — CLAUDE-BOOST 로그 dedup 용.
static NSMutableSet *g_claude_boosted = nil;

static NSString *airgenome_overload_log_path(void) {
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@".airgenome/overload_check.log"];
}

static void airgenome_overload_log(NSString *line) {
    NSString *path = airgenome_overload_log_path();
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    NSString *out = [NSString stringWithFormat:@"%@ %@\n",
                     [fmt stringFromDate:[NSDate date]], line];
    NSData *data = [out dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [data writeToFile:path atomically:NO];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:data];
        [fh closeFile];
    }
}

static void airgenome_overload_post(NSString *title, NSString *info) {
    NSUserNotification *note = [[NSUserNotification alloc] init];
    note.title = title;
    note.informativeText = info;
    // 좌측 앱 아이콘 = bundle 의 CFBundleIconFile → IconServices 캐시.
    // contentImage (우측 썸네일) 는 미사용 — 좌측 아이콘만으로 충분.
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
}

static double airgenome_overload_load1(void) {
    double avg[3] = {0, 0, 0};
    if (getloadavg(avg, 3) < 1) return 0.0;
    return avg[0];
}

static NSString *airgenome_overload_str(const char *c) {
    if (!c) return @"";
    NSString *s = [NSString stringWithUTF8String:c];
    if (s) return s;
    s = [NSString stringWithCString:c encoding:NSISOLatin1StringEncoding];
    return s ?: @"";
}

// 전체 프로세스 스냅샷, CPU 사용량 내림차순 (`ps -r`). 각 원소:
//   @{ @"pid":NSNumber, @"cpu":NSNumber<double>, @"comm":NSString, @"args":NSString }
// `comm=` 는 실행 파일 전체 경로 (드물게 공백 포함 경로면 첫 토큰까지만 — 허용).
static NSArray *airgenome_overload_ps_all(void) {
    FILE *fp = popen("/bin/ps -Ao pid=,%cpu=,comm=,args= -r 2>/dev/null", "r");
    if (!fp) return @[];
    NSMutableArray *out = [NSMutableArray array];
    char line[8192];
    while (fgets(line, sizeof(line), fp)) {
        long pid = 0;
        double cpu = 0.0;
        char comm[2048] = {0};
        char rest[6000] = {0};
        int n = sscanf(line, "%ld %lf %2047s %5999[^\n]", &pid, &cpu, comm, rest);
        if (n < 3 || pid <= 0) continue;
        char *cp = comm; while (*cp == ' ' || *cp == '\t') cp++;
        char *rp = rest; while (*rp == ' ' || *rp == '\t') rp++;
        [out addObject:@{
            @"pid":  @(pid),
            @"cpu":  @(cpu),
            @"comm": airgenome_overload_str(cp),
            @"args": airgenome_overload_str(n >= 4 ? rp : cp),
        }];
        if (out.count >= AIRGENOME_OVERLOAD_PS_MAX) break;
    }
    pclose(fp);
    return out;
}

// "이건 claude code CLI 다" — 부스트 대상 판정. over-match 안전 (false positive →
// taskpolicy -B 한 번 / 강등 후보에서 제외, 둘 다 무해).
static BOOL airgenome_overload_is_claude(NSString *comm, NSString *args) {
    if ([comm hasSuffix:@"/claude.real"] || [comm isEqualToString:@"claude.real"]) return YES;
    if ([comm hasSuffix:@"/claude"]      || [comm isEqualToString:@"claude"])      return YES;
    if (args.length) {
        if ([args rangeOfString:@"/claude.real"].location != NSNotFound)        return YES;
        if ([args rangeOfString:@".local/bin/claude"].location != NSNotFound)   return YES;
        if ([args rangeOfString:@"/claude/cli.js"].location != NSNotFound)      return YES;
        if ([args rangeOfString:@"/.npm-global/bin/claude"].location != NSNotFound) return YES;
        if ([args hasSuffix:@"/claude"] || [args rangeOfString:@"/claude "].location != NSNotFound) return YES;
    }
    return NO;
}

// 절대 손대지 않을 프로세스 — UI/시스템 핵심, airgenome 자신, 터미널, claude.app.
static BOOL airgenome_overload_is_protected(long pid, NSString *comm, NSString *args) {
    if (pid == (long)getpid()) return YES;
    if (pid <= 1) return YES;                       // kernel_task / launchd
    static NSArray *names = nil;
    if (!names) names = @[
        @"WindowServer", @"kernel_task", @"launchd", @"loginwindow",
        @"coreservicesd", @"opendirectoryd", @"hidd", @"distnoted", @"cfprefsd",
        @"runningboardd", @"powerd", @"WindowManager", @"SystemUIServer",
        @"/mds", @"mds_stores", @"Spotlight",
        @"Dock.app", @"Finder.app", @"iTerm", @"Terminal.app", @"Warp.app",
        @"airgenome", @"Airgenome", @"/hexa", @"hexa.real",
        @"Claude.app",                              // the desktop app — leave default
    ];
    for (NSString *n in names) {
        if ([comm rangeOfString:n].location != NSNotFound) return YES;
    }
    if (args.length &&
        ([args rangeOfString:@"airgenome"].location != NSNotFound ||
         [args rangeOfString:@"Airgenome"].location != NSNotFound)) return YES;
    return NO;
}

// 같은 uid 프로세스에 Darwin background state 적용/해제. root 불필요. 우리 소유가
// 아닌 (root 등) PID 에는 EPERM 으로 조용히 실패 — /dev/null 로 버림.
static void airgenome_overload_taskpolicy(const char *flag /* "-b" | "-B" */, long pid) {
    char cmd[160];
    snprintf(cmd, sizeof(cmd), "/usr/bin/taskpolicy %s -p %ld >/dev/null 2>&1", flag, pid);
    (void)system(cmd);
}

static void airgenome_overload_deprioritize(NSNumber *pid, NSString *comm, double cpu) {
    BOOL fresh = ![g_deprioritized containsObject:pid];
    airgenome_overload_taskpolicy("-b", [pid longValue]);
    [g_deprioritized addObject:pid];
    if (fresh) {
        airgenome_overload_log([NSString stringWithFormat:
            @"DEPRIO pid=%@ comm=%@ cpu=%.1f%% → background (taskpolicy -b, claude 우선)",
            pid, comm, cpu]);
    }
}

static void airgenome_overload_restore_all(NSString *why) {
    if (g_deprioritized.count == 0) return;
    NSArray *pids = [g_deprioritized allObjects];
    for (NSNumber *pid in pids) airgenome_overload_taskpolicy("-B", [pid longValue]);
    airgenome_overload_log([NSString stringWithFormat:
        @"RESTORE %lu pid(s) → default (%@)", (unsigned long)pids.count, why]);
    [g_deprioritized removeAllObjects];
}

// 상시 약-부스트: root 없이 음수 nice 불가 → 할 수 있는 건 claude 가 절대
// background tier 에 갇히지 않도록 보장하는 것 (idle-dup gate 등의 taskpolicy_bg
// 무효화). 임계 시의 강-부스트(경쟁 프로세스 강등)는 tick 의 별도 분기.
static void airgenome_overload_claude_boost(NSArray *procs) {
    NSMutableSet *now = [NSMutableSet set];
    for (NSDictionary *p in procs) {
        if (!airgenome_overload_is_claude(p[@"comm"], p[@"args"])) continue;
        NSNumber *pid = p[@"pid"];
        [now addObject:pid];
        airgenome_overload_taskpolicy("-B", [pid longValue]);
    }
    if (g_claude_boosted == nil) g_claude_boosted = [NSMutableSet set];
    if (![now isEqualToSet:g_claude_boosted]) {
        if (now.count) {
            airgenome_overload_log([NSString stringWithFormat:
                @"CLAUDE-BOOST %lu pid(s) → not-background: %@",
                (unsigned long)now.count, [[now allObjects] componentsJoinedByString:@","]]);
        } else {
            airgenome_overload_log(@"CLAUDE-BOOST 0 pid(s) — claude CLI 미감지");
        }
        [g_claude_boosted setSet:now];
    }
}

static void airgenome_overload_tick(void) {
    double load1 = airgenome_overload_load1();
    NSArray *procs = airgenome_overload_ps_all();   // CPU desc
    airgenome_overload_log([NSString stringWithFormat:@"tick load1=%.2f procs=%lu",
                            load1, (unsigned long)procs.count]);

    // (A) 항상: claude CLI hygiene — not-background 유지.
    airgenome_overload_claude_boost(procs);

    time_t now_ts = time(NULL);

    // (B) load1 임계 — 알림(쿨다운) + 강-부스트(경쟁 프로세스 background 강등).
    if (load1 > AIRGENOME_OVERLOAD_LOAD_THRESHOLD) {
        if (now_ts - g_last_load_alert_ts >= AIRGENOME_OVERLOAD_ALERT_COOLDOWN_S) {
            NSString *info = [NSString stringWithFormat:
                @"load1=%.2f (>%.0f) — idle 위험 조기 경보",
                load1, AIRGENOME_OVERLOAD_LOAD_THRESHOLD];
            airgenome_overload_post(@"macOS overload", info);
            airgenome_overload_log([NSString stringWithFormat:
                @"ALERT load1=%.2f notification fired", load1]);
            g_last_load_alert_ts = now_ts;
        } else {
            airgenome_overload_log([NSString stringWithFormat:
                @"SUPPRESS load1=%.2f (cooldown %lds remaining)",
                load1, (long)(AIRGENOME_OVERLOAD_ALERT_COOLDOWN_S - (now_ts - g_last_load_alert_ts))]);
        }
        int picked = 0;
        for (NSDictionary *p in procs) {
            double cpu = [p[@"cpu"] doubleValue];
            if (cpu < AIRGENOME_OVERLOAD_DEPRIO_CPU_FLOOR) break;   // procs 는 CPU desc
            long pid = [p[@"pid"] longValue];
            NSString *comm = p[@"comm"], *cargs = p[@"args"];
            if (airgenome_overload_is_claude(comm, cargs)) continue;
            if (airgenome_overload_is_protected(pid, comm, cargs)) continue;
            airgenome_overload_deprioritize(p[@"pid"], comm, cpu);
            if (++picked >= AIRGENOME_OVERLOAD_DEPRIO_TOP_N) break;
        }
    } else if (g_deprioritized.count) {
        airgenome_overload_restore_all(@"load recovered");
    }

    // (C) runaway PID (단일 PID 장시간 高-CPU) — 알림 + 해당 PID background 강등.
    NSMutableSet *seen_now = [NSMutableSet set];
    time_t now = time(NULL);
    for (NSDictionary *proc in procs) {
        double cpu = [proc[@"cpu"] doubleValue];
        if (cpu <= AIRGENOME_OVERLOAD_CPU_THRESHOLD) continue;
        NSNumber *pid_n = proc[@"pid"];
        NSString *comm = proc[@"comm"], *cargs = proc[@"args"];
        [seen_now addObject:pid_n];

        NSDictionary *prev = g_runaway_state[pid_n];
        time_t first_seen = prev ? [prev[@"first_seen"] longLongValue] : now;
        BOOL notified = prev ? [prev[@"notified"] boolValue] : NO;
        time_t age = now - first_seen;

        if (age >= AIRGENOME_OVERLOAD_RUNAWAY_AGE_S && !notified) {
            airgenome_overload_post(@"macOS runaway PID",
                [NSString stringWithFormat:@"PID %@ (%@) cpu=%.1f%% for %lds",
                 pid_n, comm, cpu, (long)age]);
            airgenome_overload_log([NSString stringWithFormat:
                @"ALERT runaway pid=%@ cpu=%.1f comm=%@ age=%lds", pid_n, cpu, comm, (long)age]);
            notified = YES;
            if (!airgenome_overload_is_claude(comm, cargs) &&
                !airgenome_overload_is_protected([pid_n longValue], comm, cargs)) {
                airgenome_overload_deprioritize(pid_n, comm, cpu);
            }
        }

        g_runaway_state[pid_n] = @{
            @"first_seen": @((long long)first_seen),
            @"notified":   @(notified),
        };
    }
    // drop PIDs not seen this tick (recovered or died)
    for (NSNumber *k in [g_runaway_state allKeys]) {
        if (![seen_now containsObject:k]) [g_runaway_state removeObjectForKey:k];
    }

    // 죽은 PID 는 g_deprioritized 에서도 정리 (load 회복 전에 끝난 build 등).
    if (g_deprioritized.count) {
        NSMutableSet *live = [NSMutableSet set];
        for (NSDictionary *p in procs) [live addObject:p[@"pid"]];
        for (NSNumber *pid in [g_deprioritized allObjects]) {
            if (![live containsObject:pid]) [g_deprioritized removeObject:pid];
        }
    }
}

// Build the timer source in suspended state. enable() resumes it; disable()
// suspends. shutdown() cancels it.
static void airgenome_overload_build_source_locked(void) {
    if (g_overload_src) return;
    g_runaway_state  = [NSMutableDictionary dictionary];
    g_deprioritized  = [NSMutableSet set];
    g_claude_boosted = [NSMutableSet set];
    g_overload_q = dispatch_queue_create("com.airgenome.overload", DISPATCH_QUEUE_SERIAL);
    g_overload_src = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, g_overload_q);
    if (!g_overload_src) return;
    uint64_t interval_ns = (uint64_t)AIRGENOME_OVERLOAD_INTERVAL_S * NSEC_PER_SEC;
    uint64_t leeway_ns   = (uint64_t)5 * NSEC_PER_SEC;
    dispatch_source_set_timer(g_overload_src,
                              dispatch_time(DISPATCH_TIME_NOW, interval_ns),
                              interval_ns,
                              leeway_ns);
    dispatch_source_set_event_handler(g_overload_src, ^{
        @autoreleasepool {
            airgenome_overload_tick();
        }
    });
    // Source starts suspended — caller resumes via airgenome_overload_set_enabled.
}

// Toggle target — menubar 또는 외부 호출자 (CLI 등). idempotent.
//   on=1 → resume (이미 running 이면 no-op)
//   on=0 → suspend (이미 stopped 면 no-op) + 강등했던 PID 전부 원복
void airgenome_overload_set_enabled(int on) {
    if (!g_overload_src) airgenome_overload_build_source_locked();
    if (!g_overload_src) return;
    if (on && !g_overload_running) {
        dispatch_resume(g_overload_src);
        g_overload_running = 1;
        fprintf(stderr,
                "airgenome_overload: ON (%ds tick — load>%.0f → top-%d non-claude PID "
                "→ background; claude CLI → not-background; cpu>%.0f%%×%ds runaway alert)\n",
                AIRGENOME_OVERLOAD_INTERVAL_S,
                AIRGENOME_OVERLOAD_LOAD_THRESHOLD,
                AIRGENOME_OVERLOAD_DEPRIO_TOP_N,
                AIRGENOME_OVERLOAD_CPU_THRESHOLD,
                AIRGENOME_OVERLOAD_RUNAWAY_AGE_S);
        fflush(stderr);
    } else if (!on && g_overload_running) {
        // 강등 원복은 tick 과 같은 큐에서 직렬화 — 진행 중 tick 과의 race 방지.
        if (g_overload_q) {
            dispatch_sync(g_overload_q, ^{ airgenome_overload_restore_all(@"watcher off"); });
        }
        dispatch_suspend(g_overload_src);
        g_overload_running = 0;
        fprintf(stderr, "airgenome_overload: off\n");
        fflush(stderr);
    }
}

int airgenome_overload_is_enabled(void) {
    return g_overload_running;
}

// Convenience: build source + enable. Used by app startup when persisted
// state says overload=on (or default ON on first run).
void airgenome_overload_init(void) {
    airgenome_overload_set_enabled(1);
}

void airgenome_overload_shutdown(void) {
    if (g_overload_src) {
        // 종료 전에 강등 PID 원복 — 안 그러면 app 재시작 후 추적 불가 (in-memory).
        // queue 가 있으면 tick 과 직렬화 (queue 자체는 source suspend 와 무관하게 동작).
        if (g_overload_q) {
            dispatch_sync(g_overload_q, ^{ airgenome_overload_restore_all(@"shutdown"); });
        } else {
            airgenome_overload_restore_all(@"shutdown");
        }
        // dispatch_source_cancel 은 suspended source 에서도 안전. 단,
        // suspended 상태로 release 시 crash — 먼저 resume 후 cancel.
        if (!g_overload_running) {
            dispatch_resume(g_overload_src);
            g_overload_running = 1;
        }
        dispatch_source_cancel(g_overload_src);
        g_overload_src = NULL;
        g_overload_running = 0;
    }
    g_overload_q     = NULL;
    g_runaway_state  = nil;
    g_deprioritized  = nil;
    g_claude_boosted = nil;
}

// Manual test fire — `airgenome overload-check test` 가 호출 가능. 단,
// CLI 진입점이 별도 프로세스라 NSUserNotification 미배달 가능. 큐 경로
// (~/.airgenome/notify_queue.jsonl) 가 더 안전 — overload_check.sh 에서 처리.
void airgenome_overload_fire_test(void) {
    airgenome_overload_post(@"macOS overload (test)", @"airgenome overload-check test fire");
    airgenome_overload_log(@"TEST notification fired");
}
