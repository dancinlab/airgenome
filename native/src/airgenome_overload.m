// airgenome_overload.m — in-process macOS load watcher.
//
// 60s 주기:
//   1. getloadavg(3) load1 > 50 → "macOS overload" notify
//   2. /bin/ps 로 CPU > 50% PID 추적, sliding 5min window → "macOS runaway PID"
//
// 절대 kill 미수행 — 14+ active claude 세션 보호. 알림 + 로그만.
//
// 단일 launchd 진입점 정책 (com.airgenome.tap) 준수 — 별도 plist 미생성.
// dispatch_source_t timer 가 app 수명 내내 살아있음.
//
// 알림 발사: NSUserNotificationCenter (app bundle context).
//
// State: in-memory NSMutableDictionary<pid, [first_seen, notified]>. App 재시작
// 시 reset — runaway PID 가 5min 지나도 새 사이클부터 다시 카운트. 이는 의도적
// (재시작 직후 burst 알림 방지).

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define AIRGENOME_OVERLOAD_INTERVAL_S    60
#define AIRGENOME_OVERLOAD_LOAD_THRESHOLD 50.0
#define AIRGENOME_OVERLOAD_CPU_THRESHOLD  50.0
#define AIRGENOME_OVERLOAD_RUNAWAY_AGE_S  300

static dispatch_source_t g_overload_src = NULL;
static dispatch_queue_t  g_overload_q   = NULL;
// 0 = suspended (dispatch source not resumed), 1 = running.
// Toggle 시 suspend/resume balance 위해 명시 추적. dispatch_source_create 직후
// 상태는 suspended — 첫 enable 시 resume.
static int               g_overload_running = 0;

// pid (NSNumber) → @{ @"first_seen": NSNumber<time_t>, @"notified": NSNumber<bool> }
static NSMutableDictionary *g_runaway_state = nil;

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
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
}

static double airgenome_overload_load1(void) {
    double avg[3] = {0, 0, 0};
    if (getloadavg(avg, 3) < 1) return 0.0;
    return avg[0];
}

// Returns array of @{ @"pid":NSNumber, @"cpu":NSNumber<double>, @"comm":NSString }
// for processes with CPU% > AIRGENOME_OVERLOAD_CPU_THRESHOLD. Top 5 only.
static NSArray *airgenome_overload_runaway_snapshot(void) {
    FILE *fp = popen("/bin/ps -Ao pid=,%cpu=,comm= 2>/dev/null", "r");
    if (!fp) return @[];
    NSMutableArray *out = [NSMutableArray array];
    char line[4096];
    while (fgets(line, sizeof(line), fp)) {
        long pid = 0;
        double cpu = 0.0;
        char comm[1024] = {0};
        if (sscanf(line, "%ld %lf %1023[^\n]", &pid, &cpu, comm) < 3) continue;
        if (cpu <= AIRGENOME_OVERLOAD_CPU_THRESHOLD) continue;
        // strip leading whitespace from comm
        char *cp = comm;
        while (*cp == ' ' || *cp == '\t') cp++;
        [out addObject:@{
            @"pid":  @(pid),
            @"cpu":  @(cpu),
            @"comm": [NSString stringWithUTF8String:cp],
        }];
        if (out.count >= 5) break;
    }
    pclose(fp);
    return out;
}

static void airgenome_overload_tick(void) {
    double load1 = airgenome_overload_load1();
    airgenome_overload_log([NSString stringWithFormat:@"tick load1=%.2f", load1]);

    if (load1 > AIRGENOME_OVERLOAD_LOAD_THRESHOLD) {
        NSString *info = [NSString stringWithFormat:@"load1=%.2f (>50)", load1];
        airgenome_overload_post(@"macOS overload", info);
        airgenome_overload_log([NSString stringWithFormat:@"ALERT load1=%.2f notification fired", load1]);
    }

    NSArray *runaway = airgenome_overload_runaway_snapshot();
    time_t now = time(NULL);
    NSMutableSet *seen_now = [NSMutableSet set];

    for (NSDictionary *proc in runaway) {
        NSNumber *pid_n = proc[@"pid"];
        double cpu = [proc[@"cpu"] doubleValue];
        NSString *comm = proc[@"comm"];
        [seen_now addObject:pid_n];

        NSDictionary *prev = g_runaway_state[pid_n];
        time_t first_seen = prev ? [prev[@"first_seen"] longLongValue] : now;
        BOOL notified = prev ? [prev[@"notified"] boolValue] : NO;
        time_t age = now - first_seen;

        if (age >= AIRGENOME_OVERLOAD_RUNAWAY_AGE_S && !notified) {
            NSString *info = [NSString stringWithFormat:@"PID %@ (%@) cpu=%.1f%% for %lds",
                              pid_n, comm, cpu, (long)age];
            airgenome_overload_post(@"macOS runaway PID", info);
            airgenome_overload_log([NSString stringWithFormat:
                @"ALERT runaway pid=%@ cpu=%.1f comm=%@ age=%lds", pid_n, cpu, comm, (long)age]);
            notified = YES;
        }

        g_runaway_state[pid_n] = @{
            @"first_seen": @((long long)first_seen),
            @"notified":   @(notified),
        };
    }

    // drop PIDs not seen this tick (recovered or died)
    NSArray *all_keys = [g_runaway_state allKeys];
    for (NSNumber *k in all_keys) {
        if (![seen_now containsObject:k]) {
            [g_runaway_state removeObjectForKey:k];
        }
    }
}

// Build the timer source in suspended state. enable() resumes it; disable()
// suspends. shutdown() cancels it.
static void airgenome_overload_build_source_locked(void) {
    if (g_overload_src) return;
    g_runaway_state = [NSMutableDictionary dictionary];
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
//   on=0 → suspend (이미 stopped 면 no-op)
void airgenome_overload_set_enabled(int on) {
    if (!g_overload_src) airgenome_overload_build_source_locked();
    if (!g_overload_src) return;
    if (on && !g_overload_running) {
        dispatch_resume(g_overload_src);
        g_overload_running = 1;
        fprintf(stderr,
                "airgenome_overload: ON (%ds tick, load>%.0f / cpu>%.0f%% × %ds)\n",
                AIRGENOME_OVERLOAD_INTERVAL_S,
                AIRGENOME_OVERLOAD_LOAD_THRESHOLD,
                AIRGENOME_OVERLOAD_CPU_THRESHOLD,
                AIRGENOME_OVERLOAD_RUNAWAY_AGE_S);
        fflush(stderr);
    } else if (!on && g_overload_running) {
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
    g_overload_q = NULL;
    g_runaway_state = nil;
}

// Manual test fire — `airgenome overload-check test` 가 호출 가능. 단,
// CLI 진입점이 별도 프로세스라 NSUserNotification 미배달 가능. 큐 경로
// (~/.airgenome/notify_queue.jsonl) 가 더 안전 — overload_check.sh 에서 처리.
void airgenome_overload_fire_test(void) {
    airgenome_overload_post(@"macOS overload (test)", @"airgenome overload-check test fire");
    airgenome_overload_log(@"TEST notification fired");
}
