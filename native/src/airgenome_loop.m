// airgenome_loop.m — airgenome.app 내부 dispatch loop (raw 240 § B C4)
//
// 책임:
//   harvest / label / forecast 3 모듈을 in-process dispatch_source_t timer 로
//   주기 실행. 각 cycle 마다 posix_spawn 자식 (`hexa run modules/<x>.hexa`)
//   을 fork — 부모 (airgenome.app) 의 메모리 / TCC 권한 / dispatch queue 와
//   격리. 자식 crash → waitpid 회수 → 다른 모듈 timer 영향 0.
//
// 활성화 정책:
//   환경 변수 AIRG_TAP_LOOP=1 일 때만 init. default OFF.
//   AIRG_TAP_LOOP=0 또는 미설정 → 본 모듈 함수 호출 0, 자식 spawn 0.
//
// 7 안전망 (raw 240 R2 / B.5):
//   1. timer interval ≥ 60s — AIRGENOME_LOOP_MIN_INTERVAL_S 컴파일 시 상수
//   2. lockfile flock(LOCK_NB) — 동일 모듈 cycle overlap skip (재시도 0)
//   3. timeout SIGTERM → 3s grace → SIGKILL — 자식 무한 hang 차단
//   4. KeepAlive=false (plist 측 정책) — 본 .m 은 그 가정 하에 동작
//   5. StartInterval 미설정 (plist 측 정책) — launchd interval 미사용
//   6. 자식 stdout/stderr 명시적 redirect — 부모 stream 분리 (raw 240 R26)
//   7. 자식 fd close-on-exec — posix_spawn_file_actions + O_CLOEXEC (R22)
//
// 자기복제 / supervisor / watcher-of-watchers 패턴 부재:
//   본 모듈은 자식 spawn 책임만 — 자식이 부모를 재기동시키지 않음.
//   자식 crash 가 다른 자식 spawn 트리거 안 함 (lockfile 가 한 번에 하나).

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

// raw 240 R2 안전망 #1 — 컴파일 시 상수, 변경 시 반드시 본 .m 의 falsifier
// (F-RAW240-1 형태) 도 함께 갱신.
#define AIRGENOME_LOOP_MIN_INTERVAL_S 60

#define HEXA_BIN "/Users/ghost/core/hexa-lang/hexa"

// ----------------------------------------------------------------------
// lockfile — flock(LOCK_NB) overlap 차단 (R2 안전망 #2)
// ----------------------------------------------------------------------

// Returns fd >= 0 on success (caller must close to release lock),
//         -1 on overlap (이전 cycle 진행중 — skip),
//         -2 on system error.
static int loop_acquire_lockfile(const char *module_name) {
    char path[256];
    snprintf(path, sizeof(path), "/tmp/airgenome-loop-%s.lock", module_name);
    int fd = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0644);
    if (fd < 0) {
        NSLog(@"[airgenome_loop] %s: open lockfile failed errno=%d", module_name, errno);
        return -2;
    }
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void loop_release_lockfile(int fd) {
    if (fd >= 0) {
        flock(fd, LOCK_UN);
        close(fd);
    }
}

// ----------------------------------------------------------------------
// child watchdog — SIGTERM → 3s → SIGKILL (R2 안전망 #3)
// ----------------------------------------------------------------------

static void loop_arm_watchdog(pid_t pid, const char *module_name, int timeout_s) {
    dispatch_queue_t wd = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    char *name_copy = strdup(module_name);  // pid 콜백 후 release
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                  (int64_t)timeout_s * NSEC_PER_SEC),
                   wd, ^{
        if (kill(pid, 0) == 0) {
            NSLog(@"[airgenome_loop] %s pid=%d: timeout %ds → SIGTERM",
                  name_copy, pid, timeout_s);
            kill(pid, SIGTERM);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                          (int64_t)3 * NSEC_PER_SEC),
                           wd, ^{
                if (kill(pid, 0) == 0) {
                    NSLog(@"[airgenome_loop] %s pid=%d: SIGKILL after 3s grace",
                          name_copy, pid);
                    kill(pid, SIGKILL);
                }
                free(name_copy);
            });
        } else {
            free(name_copy);
        }
    });
}

// ----------------------------------------------------------------------
// posix_spawn child — `hexa run modules/<x>.hexa` (raw 240 R3 child 격리)
// ----------------------------------------------------------------------

// ~/.airgenome/ 자동 생성 (idempotent — mkdir EEXIST 무시).
static void loop_ensure_log_dir(void) {
    char path[256];
    snprintf(path, sizeof(path), "%s/.airgenome",
             getenv("HOME") ?: "/tmp");
    mkdir(path, 0755);
}

// Generic spawn — bin_path + args[] 받아 자식 fork + watchdog 적용.
// Returns child exit code on success, -1 on signal kill, -2 on lockfile
// system error, -3 on posix_spawn fail. lockfile overlap = -1.
static int loop_spawn_with_watchdog(const char *bin_path,
                                     char *const args[],
                                     const char *module_name,
                                     int timeout_s) {
    int lock_fd = loop_acquire_lockfile(module_name);
    if (lock_fd < 0) {
        if (lock_fd == -1) {
            NSLog(@"[airgenome_loop] %s: previous cycle still running — skip",
                  module_name);
        }
        return lock_fd;
    }

    loop_ensure_log_dir();
    char log_path[256];
    snprintf(log_path, sizeof(log_path),
             "%s/.airgenome/loop-%s.log",
             getenv("HOME") ?: "/tmp", module_name);

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    // 자식 stdout / stderr → log file (R26 사이드 이펙트 격리)
    posix_spawn_file_actions_addopen(&actions, 1, log_path,
                                      O_WRONLY | O_CREAT | O_APPEND, 0644);
    posix_spawn_file_actions_addopen(&actions, 2, log_path,
                                      O_WRONLY | O_CREAT | O_APPEND, 0644);

    pid_t pid = -1;
    int rc = posix_spawn(&pid, bin_path, &actions, NULL, args, environ);
    posix_spawn_file_actions_destroy(&actions);

    if (rc != 0) {
        NSLog(@"[airgenome_loop] %s: posix_spawn rc=%d", module_name, rc);
        loop_release_lockfile(lock_fd);
        return -3;
    }

    NSLog(@"[airgenome_loop] %s pid=%d: spawned (timeout=%ds)",
          module_name, pid, timeout_s);
    loop_arm_watchdog(pid, module_name, timeout_s);

    int status = 0;
    waitpid(pid, &status, 0);
    int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    int signaled = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
    NSLog(@"[airgenome_loop] %s pid=%d done: exit=%d signal=%d",
          module_name, pid, exit_code, signaled);

    loop_release_lockfile(lock_fd);
    return exit_code;
}

// ----------------------------------------------------------------------
// dispatch_source_t timer factory (R2 안전망 #1 강제)
// ----------------------------------------------------------------------

typedef struct {
    const char *module_name;
    const char *module_path;
    int interval_s;
    int timeout_s;
} airgenome_loop_module_t;

static dispatch_source_t loop_make_timer(const airgenome_loop_module_t *m,
                                          dispatch_queue_t q) {
    if (m->interval_s < AIRGENOME_LOOP_MIN_INTERVAL_S) {
        NSLog(@"[airgenome_loop] %s: REFUSE — interval %ds < %ds hard min",
              m->module_name, m->interval_s, AIRGENOME_LOOP_MIN_INTERVAL_S);
        return NULL;
    }
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                    0, 0, q);
    if (!src) return NULL;
    uint64_t interval_ns = (uint64_t)m->interval_s * NSEC_PER_SEC;
    uint64_t leeway_ns   = (uint64_t)(m->interval_s / 10) * NSEC_PER_SEC;
    dispatch_source_set_timer(src,
                              dispatch_time(DISPATCH_TIME_NOW, interval_ns),
                              interval_ns,
                              leeway_ns);
    const char *mod_path = m->module_path;
    const char *mod_name = m->module_name;
    int timeout_s = m->timeout_s;
    dispatch_source_set_event_handler(src, ^{
        char *args[] = {
            (char *)HEXA_BIN,
            "run",
            (char *)mod_path,
            NULL
        };
        loop_spawn_with_watchdog(HEXA_BIN, args, mod_name, timeout_s);
    });
    dispatch_resume(src);
    return src;
}

// ----------------------------------------------------------------------
// public init — main() 에서 환경 변수 gate 후 호출
// ----------------------------------------------------------------------

static dispatch_source_t g_harvest_src  = NULL;
static dispatch_source_t g_label_src    = NULL;
static dispatch_source_t g_forecast_src = NULL;
static dispatch_queue_t  g_loop_queue   = NULL;

void airgenome_loop_init(void) {
    static const airgenome_loop_module_t harvest = {
        .module_name = "harvest",
        .module_path = "/Users/ghost/core/airgenome/modules/harvest.hexa",
        .interval_s  = 60,
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t label = {
        .module_name = "label",
        .module_path = "/Users/ghost/core/airgenome/modules/label.hexa",
        .interval_s  = 300,
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t forecast = {
        .module_name = "forecast",
        .module_path = "/Users/ghost/core/airgenome/modules/forecast.hexa",
        .interval_s  = 3600,
        .timeout_s   = 120,
    };

    g_loop_queue   = dispatch_queue_create("com.airgenome.loop",
                                            DISPATCH_QUEUE_SERIAL);
    g_harvest_src  = loop_make_timer(&harvest,  g_loop_queue);
    g_label_src    = loop_make_timer(&label,    g_loop_queue);
    g_forecast_src = loop_make_timer(&forecast, g_loop_queue);

    NSLog(@"[airgenome_loop] init: harvest=%s label=%s forecast=%s",
          g_harvest_src  ? "ok" : "FAIL",
          g_label_src    ? "ok" : "FAIL",
          g_forecast_src ? "ok" : "FAIL");
}

// 단일 hexa 모듈 1회 실행 — bench / filter / one-shot dispatch.
// airgenome.app TCC (FDA, Accessibility, Input Monitoring, etc.) 가 자식
// hexa 프로세스에 상속됨 → modules/filters/data/safari_*.hexa 등 권한
// 필요 모듈 측정 / 실행 가능. 단일 binary 단일 TCC entry 정신 (raw 241).
//
// 호출: airgenome --mode=run-once=<absolute_module_path>
// timeout: 60s (대형 bench 는 인자로 override 검토)
int airgenome_loop_run_once(const char *module_path, int timeout_s) {
    if (!module_path || module_path[0] == '\0') {
        fprintf(stderr, "[airgenome_loop] run-once: empty module path\n");
        return 64;
    }
    fprintf(stderr, "[airgenome_loop] run-once: %s (timeout=%ds)\n",
            module_path, timeout_s);
    char *args[] = {
        (char *)HEXA_BIN,
        "run",
        (char *)module_path,
        NULL
    };
    int rc = loop_spawn_with_watchdog(HEXA_BIN, args, "run-once", timeout_s);
    fprintf(stderr, "[airgenome_loop] run-once exit=%d\n", rc);
    return rc;
}

// 종료 시 source cancel (R24 dispatch_source 종료 cleanup)
void airgenome_loop_shutdown(void) {
    if (g_harvest_src)  { dispatch_source_cancel(g_harvest_src);  g_harvest_src = NULL;  }
    if (g_label_src)    { dispatch_source_cancel(g_label_src);    g_label_src = NULL;    }
    if (g_forecast_src) { dispatch_source_cancel(g_forecast_src); g_forecast_src = NULL; }
}

// ----------------------------------------------------------------------
// self-test — Makefile `loop-selftest` 타깃이 단독 binary 로 컴파일.
// production binary 에는 #ifdef 으로 격리, 코드만 함수로 항상 컴파일됨
// (AIRGENOME_LOOP_SELFTEST_MAIN 미정의 시 standalone main 부재).
// ----------------------------------------------------------------------

#if AIRGENOME_LOOP_MIN_INTERVAL_S < 60
#error "AIRGENOME_LOOP_MIN_INTERVAL_S must be >= 60 (raw 240 R2 안전망 #1)"
#endif

static int g_st_pass = 0;
static int g_st_fail = 0;

#define ST_ASSERT(cond, name) do { \
    if (cond) { fprintf(stderr, "  PASS: %s\n", (name)); g_st_pass++; } \
    else      { fprintf(stderr, "  FAIL: %s\n", (name)); g_st_fail++; } \
} while (0)

int airgenome_loop_selftest(void) {
    fprintf(stderr, "airgenome_loop selftest (raw 240 § B.7 step 2):\n");

    // Test 1: lockfile 정상 acquire + release
    {
        unlink("/tmp/airgenome-loop-st1.lock");
        int fd = loop_acquire_lockfile("st1");
        ST_ASSERT(fd >= 0, "lockfile_acquire_clean_state");
        loop_release_lockfile(fd);
    }

    // Test 2: lockfile overlap (LOCK_NB 가 즉시 -1 반환)
    {
        int fd1 = loop_acquire_lockfile("st2");
        ST_ASSERT(fd1 >= 0, "lockfile_acquire_first");
        int fd2 = loop_acquire_lockfile("st2");
        ST_ASSERT(fd2 == -1, "lockfile_overlap_blocked");
        if (fd2 >= 0) loop_release_lockfile(fd2);
        loop_release_lockfile(fd1);
    }

    // Test 3: release 후 재취득
    {
        int fd1 = loop_acquire_lockfile("st3");
        loop_release_lockfile(fd1);
        int fd2 = loop_acquire_lockfile("st3");
        ST_ASSERT(fd2 >= 0, "lockfile_reacquire_after_release");
        loop_release_lockfile(fd2);
    }

    // Test 4: interval guard — 60s 미만 거부 (안전망 #1)
    {
        dispatch_queue_t q = dispatch_queue_create("st_q4",
                                                    DISPATCH_QUEUE_SERIAL);
        airgenome_loop_module_t bad = {
            .module_name = "st_bad",
            .module_path = "/tmp/never.hexa",
            .interval_s  = 30,
            .timeout_s   = 5,
        };
        dispatch_source_t s = loop_make_timer(&bad, q);
        ST_ASSERT(s == NULL, "interval_guard_30s_refused");
        if (s) dispatch_source_cancel(s);
    }

    // Test 5: interval guard — 60s 정확히 허용
    {
        dispatch_queue_t q = dispatch_queue_create("st_q5",
                                                    DISPATCH_QUEUE_SERIAL);
        airgenome_loop_module_t ok = {
            .module_name = "st_ok",
            .module_path = "/tmp/never.hexa",
            .interval_s  = 60,
            .timeout_s   = 5,
        };
        dispatch_source_t s = loop_make_timer(&ok, q);
        ST_ASSERT(s != NULL, "interval_guard_60s_accepted");
        // 첫 fire 전에 (60s) cancel — selftest 종료 시점이 60s 미만 보장
        if (s) dispatch_source_cancel(s);
    }

    // Test 6: spawn /bin/true — 빠른 정상 exit (R3 child 격리, R26 fd redirect)
    {
        char *args[] = { (char *)"/usr/bin/true", NULL };
        int rc = loop_spawn_with_watchdog("/usr/bin/true", args, "st_true", 5);
        ST_ASSERT(rc == 0, "spawn_fast_exit_0");
    }

    // Test 7: spawn /bin/sleep 10 with timeout 2 — watchdog SIGTERM kill (R2 #3)
    {
        time_t t0 = time(NULL);
        char *args[] = { (char *)"/bin/sleep", (char *)"10", NULL };
        int rc = loop_spawn_with_watchdog("/bin/sleep", args, "st_sleep", 2);
        time_t elapsed = time(NULL) - t0;
        // signaled child → exit_code = -1 (WIFEXITED false). watchdog 이
        // 2s 에 SIGTERM 전송 → /bin/sleep 즉시 종료 → elapsed ≈ 2s.
        // 만약 SIGTERM 무시되어도 5s 후 SIGKILL → elapsed ≤ 5s 안전 상한.
        ST_ASSERT(rc == -1 && elapsed <= 6, "spawn_watchdog_sigterm_kill");
        fprintf(stderr, "  (sleep killed in %lds, expected 2-5s)\n", (long)elapsed);
    }

    // Test 8: lockfile overlap during spawn — 동일 module 두번째 spawn = -1
    {
        int held = loop_acquire_lockfile("st_overlap");
        ST_ASSERT(held >= 0, "spawn_overlap_setup");
        char *args[] = { (char *)"/usr/bin/true", NULL };
        int rc = loop_spawn_with_watchdog("/usr/bin/true", args, "st_overlap", 5);
        ST_ASSERT(rc == -1, "spawn_overlap_skipped");
        loop_release_lockfile(held);
    }

    // Test 9: stderr redirect — child >&2 → log file 에 캡처 (R26)
    {
        char log_path[256];
        snprintf(log_path, sizeof(log_path), "%s/.airgenome/loop-st_log.log",
                 getenv("HOME") ?: "/tmp");
        unlink(log_path);
        char *args[] = {
            (char *)"/bin/sh",
            (char *)"-c",
            (char *)"echo HELLO_FROM_CHILD >&2",
            NULL
        };
        int rc = loop_spawn_with_watchdog("/bin/sh", args, "st_log", 5);
        ST_ASSERT(rc == 0, "spawn_stderr_redirect_exit_0");
        FILE *f = fopen(log_path, "r");
        ST_ASSERT(f != NULL, "spawn_stderr_redirect_log_exists");
        if (f) {
            char buf[256] = {0};
            size_t n = fread(buf, 1, sizeof(buf) - 1, f);
            buf[n] = '\0';
            ST_ASSERT(strstr(buf, "HELLO_FROM_CHILD") != NULL,
                      "spawn_stderr_redirect_content");
            fclose(f);
        }
        unlink(log_path);
    }

    // Cleanup leftover lockfiles
    unlink("/tmp/airgenome-loop-st1.lock");
    unlink("/tmp/airgenome-loop-st2.lock");
    unlink("/tmp/airgenome-loop-st3.lock");
    unlink("/tmp/airgenome-loop-st_bad.lock");
    unlink("/tmp/airgenome-loop-st_ok.lock");
    unlink("/tmp/airgenome-loop-st_true.lock");
    unlink("/tmp/airgenome-loop-st_sleep.lock");
    unlink("/tmp/airgenome-loop-st_overlap.lock");
    unlink("/tmp/airgenome-loop-st_log.lock");

    fprintf(stderr, "airgenome_loop selftest: %d pass / %d fail\n",
            g_st_pass, g_st_fail);
    return g_st_fail > 0 ? 1 : 0;
}

#ifdef AIRGENOME_LOOP_SELFTEST_MAIN
int main(int argc, char **argv) {
    (void)argc; (void)argv;
    @autoreleasepool {
        return airgenome_loop_selftest();
    }
}
#endif
