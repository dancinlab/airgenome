// airgenome_notify.m — in-process notification queue drain.
//
// 외부 프로세스 (overload_check.sh 등) 가 ~/.airgenome/notify_queue.jsonl 에
// JSONL 한 줄씩 append 하면, airgenome.app 이 10s 주기로 drain 해
// NSUserNotification 으로 전달한다. 앱 bundle context 안에서 발사하므로
// macOS modern 알림 정책 (Notification Center 표시) 을 그대로 받는다.
//
// 라인 포맷: {"title":"…","subtitle":"…","info":"…"}
//   - title 필수, subtitle/info 선택.
//   - subtitle/info 누락 시 빈 문자열로 처리.
//
// race-safe drain:
//   1. queue path 존재 시 rename → queue.draining (atomic on same fs)
//   2. .draining 라인별 파싱 + 발사
//   3. unlink .draining
//   외부 writer 는 항상 queue path 에 O_APPEND 로 write — rename 직후
//   새 writer 가 새로 만든 queue 와 .draining 은 별 inode, race 차단.
//
// 단일 timer, 단일 함수. dispatch_source_t leak 방지 위해 g_notify_src 보존.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define AIRGENOME_NOTIFY_INTERVAL_S 10

static dispatch_source_t g_notify_src = NULL;
static dispatch_queue_t  g_notify_q   = NULL;

static NSString *airgenome_notify_queue_path(void) {
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@".airgenome/notify_queue.jsonl"];
}

static NSString *airgenome_notify_draining_path(void) {
    NSString *home = NSHomeDirectory();
    return [home stringByAppendingPathComponent:@".airgenome/notify_queue.jsonl.draining"];
}

static void airgenome_notify_post(NSString *title, NSString *subtitle, NSString *info) {
    if (title.length == 0) return;
    NSUserNotification *note = [[NSUserNotification alloc] init];
    note.title = title;
    if (subtitle.length) note.subtitle = subtitle;
    if (info.length)     note.informativeText = info;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
}

static void airgenome_notify_drain_once(void) {
    NSString *src = airgenome_notify_queue_path();
    NSString *dst = airgenome_notify_draining_path();
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:src]) return;

    // empty file → fast skip + cleanup
    NSDictionary *attrs = [fm attributesOfItemAtPath:src error:nil];
    if (attrs && [attrs[NSFileSize] unsignedLongLongValue] == 0) {
        [fm removeItemAtPath:src error:nil];
        return;
    }

    // atomic move into draining slot. 기존 .draining 잔존 시 (이전 cycle
    // crash) 그것까지 처리하기 위해 dst 가 있으면 src 내용을 append 한 뒤
    // src 제거 — 단순화 위해 그냥 dst 덮어쓰기.
    [fm removeItemAtPath:dst error:nil];
    NSError *moveErr = nil;
    if (![fm moveItemAtPath:src toPath:dst error:&moveErr]) {
        NSLog(@"[airgenome_notify] rename %@ → %@ failed: %@", src, dst, moveErr);
        return;
    }

    NSError *readErr = nil;
    NSString *blob = [NSString stringWithContentsOfFile:dst
                                               encoding:NSUTF8StringEncoding
                                                  error:&readErr];
    if (!blob) {
        NSLog(@"[airgenome_notify] read %@ failed: %@", dst, readErr);
        [fm removeItemAtPath:dst error:nil];
        return;
    }

    NSArray<NSString *> *lines = [blob componentsSeparatedByString:@"\n"];
    int delivered = 0, skipped = 0;
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0) continue;
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (!obj || ![obj isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[airgenome_notify] skip malformed line: %@", line);
            skipped++;
            continue;
        }
        NSDictionary *d = (NSDictionary *)obj;
        NSString *title    = [d[@"title"]    isKindOfClass:[NSString class]] ? d[@"title"]    : @"";
        NSString *subtitle = [d[@"subtitle"] isKindOfClass:[NSString class]] ? d[@"subtitle"] : @"";
        NSString *info     = [d[@"info"]     isKindOfClass:[NSString class]] ? d[@"info"]     : @"";
        if (title.length == 0) {
            skipped++;
            continue;
        }
        airgenome_notify_post(title, subtitle, info);
        delivered++;
    }

    [fm removeItemAtPath:dst error:nil];

    if (delivered || skipped) {
        NSLog(@"[airgenome_notify] drain delivered=%d skipped=%d", delivered, skipped);
    }
}

void airgenome_notify_init(void) {
    if (g_notify_src) return;
    g_notify_q = dispatch_queue_create("com.airgenome.notify", DISPATCH_QUEUE_SERIAL);
    g_notify_src = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, g_notify_q);
    if (!g_notify_src) return;
    uint64_t interval_ns = (uint64_t)AIRGENOME_NOTIFY_INTERVAL_S * NSEC_PER_SEC;
    uint64_t leeway_ns   = (uint64_t)1 * NSEC_PER_SEC;
    dispatch_source_set_timer(g_notify_src,
                              dispatch_time(DISPATCH_TIME_NOW, interval_ns),
                              interval_ns,
                              leeway_ns);
    dispatch_source_set_event_handler(g_notify_src, ^{
        @autoreleasepool {
            airgenome_notify_drain_once();
        }
    });
    dispatch_resume(g_notify_src);
    fprintf(stderr, "airgenome_notify: queue drain on (%ds tick, %s)\n",
            AIRGENOME_NOTIFY_INTERVAL_S,
            [airgenome_notify_queue_path() UTF8String]);
    fflush(stderr);
}

void airgenome_notify_shutdown(void) {
    if (g_notify_src) {
        dispatch_source_cancel(g_notify_src);
        g_notify_src = NULL;
    }
    g_notify_q = NULL;
}
