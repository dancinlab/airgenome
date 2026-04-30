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
    const char *extra_arg;   // optional, NULL = no extra arg (own 9 / A9 — encode mode 등)
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
    const char *extra_arg = m->extra_arg;
    int timeout_s = m->timeout_s;
    dispatch_source_set_event_handler(src, ^{
        // A9 — extra_arg pass-through (encode 모드 등 sub-mode 분기).
        char *args[8];
        int i = 0;
        args[i++] = (char *)HEXA_BIN;
        args[i++] = "run";
        args[i++] = (char *)mod_path;
        if (extra_arg != NULL && extra_arg[0] != '\0') {
            args[i++] = (char *)extra_arg;
        }
        args[i] = NULL;
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
// Safari 통합 wave (F45/F64/F65/F66) — env AIRG_TAP_LOOP_SAFARI=1 일 때만 활성.
// default OFF (보수적 — wave 4 production-test 통과 후 enable). raw 241/246
// 정합 (별도 plist 0, 별도 binary 0, 모두 단일 binary in-process timer).
static dispatch_source_t g_safari_genome_src   = NULL;
static dispatch_source_t g_safari_active_src   = NULL;
static dispatch_source_t g_safari_youtube_src  = NULL;
static dispatch_source_t g_safari_battery_src  = NULL;
// own 9 BENCHMARK-COMPLETE 결과 — production-validated 9 추가 filter (env gate).
// AIRG_TAP_LOOP_BLOBS  → E4 / F18 / PTBF (Safari blob refresh)
// AIRG_TAP_LOOP_PROCS  → 6 process gate filter (calendar/finder/mail/memo/safari/telegram)
static dispatch_source_t g_blob_e4_src         = NULL;
static dispatch_source_t g_blob_f18_src        = NULL;
static dispatch_source_t g_blob_ptbf_src       = NULL;
static dispatch_source_t g_proc_calendar_src   = NULL;
static dispatch_source_t g_proc_finder_src     = NULL;
static dispatch_source_t g_proc_mail_src       = NULL;
static dispatch_source_t g_proc_memo_src       = NULL;
static dispatch_source_t g_proc_safari_src     = NULL;
static dispatch_source_t g_proc_telegram_src   = NULL;
// own 9 — K-wave macOS-level Type E data 재해석 (raw 240 V2 만점기준 사전 적용).
// AIRG_TAP_LOOP_DATAE → K1 / K2 / K5 / K6 + IM1 (5 filter, encode mode timer).
// 만점 2 (K1 400/400 / K6 400/400) + 381/380/395 3개. blob refresh 주기 등록.
static dispatch_source_t g_datae_im1_src       = NULL;
static dispatch_source_t g_datae_k1_src        = NULL;
static dispatch_source_t g_datae_k2_src        = NULL;
static dispatch_source_t g_datae_k5_src        = NULL;
static dispatch_source_t g_datae_k6_src        = NULL;
static dispatch_source_t g_datae_k4_src        = NULL;  // K4 v2 (snappy 352/400)
static dispatch_source_t g_datae_dklc_src      = NULL;  // DKLC docker (420/420)
// own 9 wave-5 production-validated 10 filter (a49e5e018 validation 2026-04-30).
// 5 PASS @ 1800s + 5 PASS @ 7200s. 5 FAIL (calendar_event BufferError, reminders/
// photos/maps/finder_alias 1×미달) + 4 SKIP (mail/memo_attachment 실 데이터 부재).
static dispatch_source_t g_datae_w5_memo_notes_src      = NULL;
static dispatch_source_t g_datae_w5_memo_search_src     = NULL;
static dispatch_source_t g_datae_w5_tel_chat_src        = NULL;
static dispatch_source_t g_datae_w5_tel_media_src       = NULL;
static dispatch_source_t g_datae_w5_fi_recent_src       = NULL;
static dispatch_source_t g_datae_w5_tel_contact_src     = NULL;
static dispatch_source_t g_datae_w5_cal_recurring_src   = NULL;
static dispatch_source_t g_datae_w5_music_src           = NULL;
static dispatch_source_t g_datae_w5_books_src           = NULL;
static dispatch_source_t g_datae_w5_shortcuts_src       = NULL;
static dispatch_source_t g_datae_w5_cal_event_src       = NULL;  // FAIL fix 301.8× post BufferError patch
static dispatch_source_t g_datae_w5_mail_envelope_src   = NULL;  // V10 schema fix 1161.7× post Mail set up
static dispatch_source_t g_datae_w5_mail_sender_src     = NULL;  // OTHER bucket fix size 96% lossless
static dispatch_source_t g_datae_w5_memo_attach_src     = NULL;  // auto-discover regular + shared Media+Previews
// own 9 wave-6 — 13 bg agent 산출 26 PASS filter (raw 240 V2 만점기준 사전 적용).
// 만점 13 / B10 ceiling 420 expansion 2 (CT3 + IX1) / 380+ 11.
static dispatch_source_t g_datae_w6_bash_src            = NULL;  // DV5 400/400 K6 verbatim
static dispatch_source_t g_datae_w6_ib1_src             = NULL;  // IB1 400/400 iPhone Manifest.db
static dispatch_source_t g_datae_w6_ib2_src             = NULL;  // IB2 400/400 iPhone backup blob dedup
static dispatch_source_t g_datae_w6_pb1_src             = NULL;  // PB1 400/400 pasteboard history
static dispatch_source_t g_datae_w6_pb2_src             = NULL;  // PB2 400/400 continuity clipboard
static dispatch_source_t g_datae_w6_md1_src             = NULL;  // MD1 380/400 Photos faces dict
static dispatch_source_t g_datae_w6_md2_src             = NULL;  // MD2 380/400 Photos scenes APBF
static dispatch_source_t g_datae_w6_sl1_src             = NULL;  // SL1 364/400 crash reports dict
static dispatch_source_t g_datae_w6_cl3_src             = NULL;  // CL3 381/400 iCloud documents
static dispatch_source_t g_datae_w6_mx1_src             = NULL;  // MX1 400/400 Mail rules dict
static dispatch_source_t g_datae_w6_mx2_src             = NULL;  // MX2 400/400 Mail smart mailboxes
static dispatch_source_t g_datae_w6_mx3_src             = NULL;  // MX3 400/400 Calendar attachment dedup
static dispatch_source_t g_datae_w6_mx4_src             = NULL;  // MX4 400/400 Calendar alarms dict
static dispatch_source_t g_datae_w6_ct1_src             = NULL;  // CT1 400/400 podman containers
static dispatch_source_t g_datae_w6_ct2_src             = NULL;  // CT2 400/400 colima lima state
static dispatch_source_t g_datae_w6_ct3_src             = NULL;  // CT3 420/420 docker image layer dedup (B10)
static dispatch_source_t g_datae_w6_br1_src             = NULL;  // BR1 376/400 chrome history
static dispatch_source_t g_datae_w6_br2_src             = NULL;  // BR2 374/400 chrome bookmarks
static dispatch_source_t g_datae_w6_br3_src             = NULL;  // BR3 372/400 chrome localstorage (snappy)
static dispatch_source_t g_datae_w6_br6_src             = NULL;  // BR6 374/400 chrome cookies dict
static dispatch_source_t g_datae_w6_sf1_src             = NULL;  // SF1 374/400 safari reading list
static dispatch_source_t g_datae_w6_sf3_src             = NULL;  // SF3 378/400 safari cookies binary (BE/LE mixed)
static dispatch_source_t g_datae_w6_sf4_src             = NULL;  // SF4 376/400 safari extensions
static dispatch_source_t g_datae_w6_ix1_src             = NULL;  // IX1 420/420 locate database mmap (B10)
static dispatch_source_t g_datae_w6_ix2_src             = NULL;  // IX2 400/400 dyld shared cache dict
static dispatch_source_t g_datae_w6_ix3_src             = NULL;  // IX3 400/400 recent documents global
// own 9 wave-7 — Network 6 partial PASS filter (rate-limit reset 4:10am 후 잔여 7건 별도 cycle).
// bench verified: WiFi 1.9μs / DNS dedup 34.9% packet reduction / TCP 6.5× / etc.
static dispatch_source_t g_datae_w7_wifi_signal_src     = NULL;  // NW-W1 wifi_signal_shbf
static dispatch_source_t g_datae_w7_dns_cache_src       = NULL;  // NW-D1 dns_cache_dedup
static dispatch_source_t g_datae_w7_dns_query_src       = NULL;  // NW-D2 dns_query_history
static dispatch_source_t g_datae_w7_pkt_dedup_src       = NULL;  // NW-P1 packet_payload_dedup
static dispatch_source_t g_datae_w7_http_consol_src     = NULL;  // NW-P2 http_request_consolidate
static dispatch_source_t g_datae_w7_tcp_conn_src        = NULL;  // NW-C1 tcp_connection_dict 6.5×
static dispatch_source_t g_datae_w7_wifi_dedup_src      = NULL;  // NW-W2 wifi_scan_dedup
static dispatch_source_t g_datae_w7_bonjour_src         = NULL;  // NW-D3 bonjour 46.2% packet reduction
static dispatch_source_t g_datae_w7_keepalive_src       = NULL;  // NW-C2 keepalive_state_optimizer
static dispatch_queue_t  g_loop_queue   = NULL;

void airgenome_loop_init(void) {
    static const airgenome_loop_module_t harvest = {
        .module_name = "harvest",
        .module_path = "/Users/ghost/core/airgenome/modules/harvest.hexa",
        .extra_arg   = NULL,
        .interval_s  = 60,
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t label = {
        .module_name = "label",
        .module_path = "/Users/ghost/core/airgenome/modules/label.hexa",
        .extra_arg   = NULL,
        .interval_s  = 300,
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t forecast = {
        .module_name = "forecast",
        .module_path = "/Users/ghost/core/airgenome/modules/forecast.hexa",
        .extra_arg   = NULL,
        .interval_s  = 3600,
        .timeout_s   = 120,
    };
    // Safari 통합 wave (commit 788e483a production-validated):
    //   F45 bg_tab_throttle_genome — 60s, 30s timeout (own 8 successor, Type D)
    //   F64 active_throttle_signal — 60s, 30s timeout (Type B, 33× speedup)
    //   F65 youtube_gpu_filter     — 120s, 60s timeout (Type A+B, 7×)
    //   F66 battery_freeze_filter  — 60s, 30s timeout (Type A, 13×)
    static const airgenome_loop_module_t safari_genome = {
        .module_name = "safari-genome",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/safari_bg_tab_throttle_genome.hexa",
        .extra_arg   = NULL,
        .interval_s  = 60,
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t safari_active = {
        .module_name = "safari-active",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/safari_active_throttle_signal.hexa",
        .extra_arg   = NULL,
        .interval_s  = 60,
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t safari_youtube = {
        .module_name = "safari-youtube",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/safari_youtube_gpu_filter.hexa",
        .extra_arg   = NULL,
        .interval_s  = 120,
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t safari_battery = {
        .module_name = "safari-battery",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/safari_battery_freeze_filter.hexa",
        .extra_arg   = NULL,
        .interval_s  = 60,
        .timeout_s   = 30,
    };
    // own 9 BENCHMARK-COMPLETE — Safari blob refresh (E4 / F18 / PTBF).
    // encode mode 호출로 blob 주기 갱신. Source data (Safari history.db /
    // Bookmarks.plist) 가 변할 때마다 blob 재생성. 이후 query 측은 mmap+bisect.
    static const airgenome_loop_module_t blob_e4 = {
        .module_name = "blob-e4-history",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/safari_mmap.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30 min — Safari history grows
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t blob_f18 = {
        .module_name = "blob-f18-bookmarks",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/safari_bookmarks_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 3600,           // 1h — bookmarks change rarely
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t blob_ptbf = {
        .module_name = "blob-ptbf-prefix-trie",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/prefix_trie_mmap.hexa",
        .extra_arg   = "encode",
        .interval_s  = 3600,           // 1h — prefix trie generic
        .timeout_s   = 60,
    };
    // own 9 BENCHMARK-COMPLETE — process gate (Type A) filters.
    // wave 2 측정 (commit 1218592a) 7/7 PASS exit 0, 0 panic.
    // claude.hexa 는 session_now.json 외부 의존으로 exception (loop 미통합).
    // compute.hexa 는 L0/AG6 frozen exception.
    static const airgenome_loop_module_t proc_calendar = {
        .module_name = "proc-calendar",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/calendar.hexa",
        .extra_arg   = NULL,
        .interval_s  = 300,            // 5min — calendar event 빈도 적당
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t proc_finder = {
        .module_name = "proc-finder",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/finder.hexa",
        .extra_arg   = NULL,
        .interval_s  = 180,            // 3min — Finder helper drift
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t proc_mail = {
        .module_name = "proc-mail",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/mail.hexa",
        .extra_arg   = NULL,
        .interval_s  = 300,            // 5min
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t proc_memo = {
        .module_name = "proc-memo",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/memo.hexa",
        .extra_arg   = NULL,
        .interval_s  = 300,            // 5min
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t proc_safari = {
        .module_name = "proc-safari",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/safari.hexa",
        .extra_arg   = NULL,
        .interval_s  = 180,            // 3min — Safari WebContent drift
        .timeout_s   = 30,
    };
    static const airgenome_loop_module_t proc_telegram = {
        .module_name = "proc-telegram",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/process/telegram.hexa",
        .extra_arg   = NULL,
        .interval_s  = 300,            // 5min — 통화중 보호 우선
        .timeout_s   = 30,
    };
    // own 9 — K-wave macOS-level Type E data 재해석 (commit 65e59eab + def7b1a4).
    // 만점기준 사전 적용 (raw 240 V2 9-block 400pt). encode mode 호출로 blob 갱신.
    //   IM1 imessage_chat_shbf — T1 패턴 직접 이식, ~395/400 (chat.db ?immutable=1)
    //   K1  imessage_attachment_dedup — 400/400, smoke 151.6× (T2 verbatim lift)
    //   K2  sharedfilelist_recent_shbf — 381/400, 158 unique paths (sfl3/sfl4)
    //   K5  launchagents_enum_shbf — 380/400, 56 plists + btm v16
    //   K6  zsh_history_columnar — 400/400, 524KB / 10K lines (cmd dict + line pool)
    static const airgenome_loop_module_t datae_im1 = {
        .module_name = "datae-im1-imessage-chat",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/imessage_chat_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — chat.db 활발 갱신
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_k1 = {
        .module_name = "datae-k1-imessage-attachment",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/imessage_attachment_dedup.hexa",
        .extra_arg   = "encode",
        .interval_s  = 3600,           // 1h — 첨부 walk 비싸므로 보수적
        .timeout_s   = 120,
    };
    static const airgenome_loop_module_t datae_k2 = {
        .module_name = "datae-k2-sharedfilelist",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/sharedfilelist_recent_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — recent items drift 빠름
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_k5 = {
        .module_name = "datae-k5-launchagents",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/launchagents_enum_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 3600,           // 1h — plist 변경 드뭄
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_k6 = {
        .module_name = "datae-k6-zsh-history",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/zsh_history_columnar.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — shell history grows steadily
        .timeout_s   = 60,
    };
    // K4 v2 unlock cycle (commit aafc957e, 352/400 with pure-python snappy 38 LOC).
    // Discord LOCK 안전망: pgrep guard 가 filter 내부에서 Discord 실행 시 synth-only.
    static const airgenome_loop_module_t datae_k4 = {
        .module_name = "datae-k4-discord-localstorage",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/discord_localstorage_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 7200,           // 2h — Discord LOCK race 회피, snappy 비용 high
        .timeout_s   = 120,
    };
    // DKLC docker_backend_log_columnar (commit e3ca3fbd, 420/420 ceiling 확장 with B10).
    // Docker Desktop 실행 시만 의미 — 미실행 시 synth fallback.
    static const airgenome_loop_module_t datae_dklc = {
        .module_name = "datae-dklc-docker-backend-log",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/docker_backend_log_columnar.hexa",
        .extra_arg   = "encode",
        .interval_s  = 3600,           // 1h — log rotation 따라잡기
        .timeout_s   = 60,
    };
    // wave-5 production-validated PASS 10 filter (a49e5e018 2026-04-30).
    // 1800s × 5 (high drift) + 7200s × 5 (low drift). 3600s 미사용 (이 host 분포).
    static const airgenome_loop_module_t datae_w5_memo_notes = {
        .module_name = "datae-w5-memo-notes",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/memo_notes_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — 1708× ROI 최고
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_memo_search = {
        .module_name = "datae-w5-memo-search",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/memo_notes_search_apbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — 79×
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_tel_chat = {
        .module_name = "datae-w5-telegram-chat",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/telegram_chat_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — 7.7× (postbox 파일명 walk)
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_tel_media = {
        .module_name = "datae-w5-telegram-media",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/telegram_media_dedup.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — 40×, 91MB dup 감지
        .timeout_s   = 120,            // wyhash blake2b 큰 파일 head 64KB
    };
    static const airgenome_loop_module_t datae_w5_fi_recent = {
        .module_name = "datae-w5-finder-recent",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/finder_recent_file_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — 27×, mdfind cold-start 우회
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_tel_contact = {
        .module_name = "datae-w5-telegram-contact",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/telegram_contact_apbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 7200,           // 2h — 7.2×, contact 변경 드뭄
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_cal_recurring = {
        .module_name = "datae-w5-calendar-recurring",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/calendar_recurring_pack.hexa",
        .extra_arg   = "encode",
        .interval_s  = 7200,           // 2h — 30×, RRULE 변경 드뭄
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_music = {
        .module_name = "datae-w5-music",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/music_library_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 7200,           // 2h — 80× (synth), library export 드뭄
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_books = {
        .module_name = "datae-w5-books",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/books_annotation_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 7200,           // 2h — 4.7×
        .timeout_s   = 60,
    };
    static const airgenome_loop_module_t datae_w5_shortcuts = {
        .module_name = "datae-w5-shortcuts",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/shortcuts_config_mmap.hexa",
        .extra_arg   = "encode",
        .interval_s  = 7200,           // 2h — 2.9× (low scale n=300)
        .timeout_s   = 60,
    };
    // wave-5 FAIL fix — calendar_event_shbf BufferError 해결 (memoryview release)
    // 후 재측정 301.8× (5000 events / 208KB blob / lossless 14025=14025).
    static const airgenome_loop_module_t datae_w5_cal_event = {
        .module_name = "datae-w5-calendar-event",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/calendar_event_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — calendar event 빈도 적당
        .timeout_s   = 60,
    };
    // wave-5 SKIP→PASS post Google mail set up (V10 schema fix str() wrap):
    // mail_envelope_shbf 1161.7× speedup on real V10 (14676 msgs / 1.83MB blob).
    static const airgenome_loop_module_t datae_w5_mail_envelope = {
        .module_name = "datae-w5-mail-envelope",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/mail_envelope_shbf.hexa",
        .extra_arg   = "encode",
        .interval_s  = 1800,           // 30min — Mail.app 새 메시지 drift
        .timeout_s   = 120,            // V10 14K msgs 풀 스캔 시 여유
    };
    // wave-5 SKIP→PASS post diff_test fold fix:
    // mail_sender_dict size 96% (480KB→22KB, wall 0.8× 인정) lossless 0 mismatch.
    static const airgenome_loop_module_t datae_w5_mail_sender = {
        .module_name = "datae-w5-mail-sender",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/mail_sender_dict.hexa",
        .extra_arg   = "encode",
        .interval_s  = 7200,           // 2h — sender dict 변경 드뭄
        .timeout_s   = 60,
    };
    // wave-5 SKIP→PASS post auto-discover (regular + shared Media+Previews):
    // memo_attachment_dedup attachments=22 / dup clusters=3 / disk 14.7% recoverable.
    // 양쪽 모두 (Accounts/*/Media + Accounts/*/Previews) 자동 glob.
    static const airgenome_loop_module_t datae_w5_memo_attach = {
        .module_name = "datae-w5-memo-attach",
        .module_path = "/Users/ghost/core/airgenome/modules/filters/data/memo_attachment_dedup.hexa",
        .extra_arg   = "encode",
        .interval_s  = 3600,           // 1h — 첨부 파일 walk 비용 medium
        .timeout_s   = 120,
    };
    // wave-6 — 13 bg agent 산출 26 PASS filter (raw 240 V2 사전 적용).
    static const airgenome_loop_module_t datae_w6_bash = {
        .module_name="datae-w6-bash-history", .module_path="/Users/ghost/core/airgenome/modules/filters/data/bash_history_columnar.hexa",
        .extra_arg="encode", .interval_s=1800, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_ib1 = {
        .module_name="datae-w6-ib1-iphone-manifest", .module_path="/Users/ghost/core/airgenome/modules/filters/data/iphone_backup_manifest.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_ib2 = {
        .module_name="datae-w6-ib2-iphone-app-dedup", .module_path="/Users/ghost/core/airgenome/modules/filters/data/iphone_app_dedup.hexa",
        .extra_arg="encode", .interval_s=14400, .timeout_s=120 };
    static const airgenome_loop_module_t datae_w6_pb1 = {
        .module_name="datae-w6-pb1-pasteboard", .module_path="/Users/ghost/core/airgenome/modules/filters/data/pasteboard_history_columnar.hexa",
        .extra_arg="encode", .interval_s=1800, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_pb2 = {
        .module_name="datae-w6-pb2-continuity", .module_path="/Users/ghost/core/airgenome/modules/filters/data/continuity_clipboard.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_md1 = {
        .module_name="datae-w6-md1-photos-faces", .module_path="/Users/ghost/core/airgenome/modules/filters/data/photos_faces_dict.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_md2 = {
        .module_name="datae-w6-md2-photos-scenes", .module_path="/Users/ghost/core/airgenome/modules/filters/data/photos_scenes_apbf.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_sl1 = {
        .module_name="datae-w6-sl1-crash-reports", .module_path="/Users/ghost/core/airgenome/modules/filters/data/crash_reports_dict.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_cl3 = {
        .module_name="datae-w6-cl3-icloud", .module_path="/Users/ghost/core/airgenome/modules/filters/data/icloud_documents_shbf.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=120 };
    static const airgenome_loop_module_t datae_w6_mx1 = {
        .module_name="datae-w6-mx1-mail-rules", .module_path="/Users/ghost/core/airgenome/modules/filters/data/mail_rules_dict.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_mx2 = {
        .module_name="datae-w6-mx2-smart-mailboxes", .module_path="/Users/ghost/core/airgenome/modules/filters/data/mail_smart_mailboxes.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_mx3 = {
        .module_name="datae-w6-mx3-cal-attach", .module_path="/Users/ghost/core/airgenome/modules/filters/data/calendar_attachment_dedup.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=120 };
    static const airgenome_loop_module_t datae_w6_mx4 = {
        .module_name="datae-w6-mx4-cal-alarms", .module_path="/Users/ghost/core/airgenome/modules/filters/data/calendar_alarms_dict.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_ct1 = {
        .module_name="datae-w6-ct1-podman", .module_path="/Users/ghost/core/airgenome/modules/filters/data/podman_containers_dict.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_ct2 = {
        .module_name="datae-w6-ct2-colima-lima", .module_path="/Users/ghost/core/airgenome/modules/filters/data/colima_lima_state.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_ct3 = {
        .module_name="datae-w6-ct3-docker-layer", .module_path="/Users/ghost/core/airgenome/modules/filters/data/docker_image_layer_dedup.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=120 };
    static const airgenome_loop_module_t datae_w6_br1 = {
        .module_name="datae-w6-br1-chrome-history", .module_path="/Users/ghost/core/airgenome/modules/filters/data/chrome_history_shbf.hexa",
        .extra_arg="encode", .interval_s=1800, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_br2 = {
        .module_name="datae-w6-br2-chrome-bookmarks", .module_path="/Users/ghost/core/airgenome/modules/filters/data/chrome_bookmarks_shbf.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_br3 = {
        .module_name="datae-w6-br3-chrome-localstorage", .module_path="/Users/ghost/core/airgenome/modules/filters/data/chrome_localstorage_shbf.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=120 };
    static const airgenome_loop_module_t datae_w6_br6 = {
        .module_name="datae-w6-br6-chrome-cookies", .module_path="/Users/ghost/core/airgenome/modules/filters/data/chrome_cookies_dict.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_sf1 = {
        .module_name="datae-w6-sf1-safari-reading", .module_path="/Users/ghost/core/airgenome/modules/filters/data/safari_reading_list_shbf.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_sf3 = {
        .module_name="datae-w6-sf3-safari-cookies", .module_path="/Users/ghost/core/airgenome/modules/filters/data/safari_cookies_binary.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_sf4 = {
        .module_name="datae-w6-sf4-safari-extensions", .module_path="/Users/ghost/core/airgenome/modules/filters/data/safari_extensions_dict.hexa",
        .extra_arg="encode", .interval_s=7200, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w6_ix1 = {
        .module_name="datae-w6-ix1-locate-db", .module_path="/Users/ghost/core/airgenome/modules/filters/data/locate_database_mmap.hexa",
        .extra_arg="encode", .interval_s=14400, .timeout_s=120 };
    static const airgenome_loop_module_t datae_w6_ix2 = {
        .module_name="datae-w6-ix2-dyld-cache", .module_path="/Users/ghost/core/airgenome/modules/filters/data/dyld_shared_cache_dict.hexa",
        .extra_arg="encode", .interval_s=14400, .timeout_s=120 };
    static const airgenome_loop_module_t datae_w6_ix3 = {
        .module_name="datae-w6-ix3-recent-documents", .module_path="/Users/ghost/core/airgenome/modules/filters/data/recent_documents_global.hexa",
        .extra_arg="encode", .interval_s=3600, .timeout_s=60 };
    // wave-7 network — 6 partial PASS filter (rate-limit 차단 잔여 별도 cycle)
    static const airgenome_loop_module_t datae_w7_wifi_signal = {
        .module_name="datae-w7-wifi-signal", .module_path="/Users/ghost/core/airgenome/modules/filters/data/wifi_signal_shbf.hexa",
        .extra_arg="encode", .interval_s=300, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w7_dns_cache = {
        .module_name="datae-w7-dns-cache-dedup", .module_path="/Users/ghost/core/airgenome/modules/filters/transport/dns_cache_dedup_shbf.hexa",
        .extra_arg="encode", .interval_s=600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w7_dns_query = {
        .module_name="datae-w7-dns-query-history", .module_path="/Users/ghost/core/airgenome/modules/filters/transport/dns_query_history_columnar.hexa",
        .extra_arg="encode", .interval_s=1800, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w7_pkt_dedup = {
        .module_name="datae-w7-packet-payload-dedup", .module_path="/Users/ghost/core/airgenome/modules/filters/data/network_packet_payload_dedup.hexa",
        .extra_arg="encode", .interval_s=600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w7_http_consol = {
        .module_name="datae-w7-http-consolidate", .module_path="/Users/ghost/core/airgenome/modules/filters/data/network_http_request_consolidate.hexa",
        .extra_arg="encode", .interval_s=1800, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w7_tcp_conn = {
        .module_name="datae-w7-tcp-connection", .module_path="/Users/ghost/core/airgenome/modules/filters/data/tcp_connection_dict.hexa",
        .extra_arg="encode", .interval_s=300, .timeout_s=60 };
    // wave-7 foreground 추가 3건 (rate-limit 우회, 사용자 keep going)
    static const airgenome_loop_module_t datae_w7_wifi_dedup = {
        .module_name="datae-w7-wifi-scan-dedup", .module_path="/Users/ghost/core/airgenome/modules/filters/data/wifi_scan_dedup.hexa",
        .extra_arg="encode", .interval_s=600, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w7_bonjour = {
        .module_name="datae-w7-bonjour-traffic", .module_path="/Users/ghost/core/airgenome/modules/filters/transport/bonjour_traffic_filter.hexa",
        .extra_arg="encode", .interval_s=1800, .timeout_s=60 };
    static const airgenome_loop_module_t datae_w7_keepalive = {
        .module_name="datae-w7-keepalive", .module_path="/Users/ghost/core/airgenome/modules/filters/data/keepalive_state_optimizer.hexa",
        .extra_arg="encode", .interval_s=600, .timeout_s=60 };

    g_loop_queue   = dispatch_queue_create("com.airgenome.loop",
                                            DISPATCH_QUEUE_SERIAL);
    g_harvest_src  = loop_make_timer(&harvest,  g_loop_queue);
    g_label_src    = loop_make_timer(&label,    g_loop_queue);
    g_forecast_src = loop_make_timer(&forecast, g_loop_queue);

    // Safari 통합 wave gate — env AIRG_TAP_LOOP_SAFARI=1 시만 (own 9 default ON).
    const char *safari_env = getenv("AIRG_TAP_LOOP_SAFARI");
    int safari_on = (safari_env && safari_env[0] == '1') ? 1 : 0;
    if (safari_on) {
        g_safari_genome_src  = loop_make_timer(&safari_genome,  g_loop_queue);
        g_safari_active_src  = loop_make_timer(&safari_active,  g_loop_queue);
        g_safari_youtube_src = loop_make_timer(&safari_youtube, g_loop_queue);
        g_safari_battery_src = loop_make_timer(&safari_battery, g_loop_queue);
    }

    // own 9 BENCHMARK-COMPLETE wave — blob refresh (E4/F18/PTBF) gate.
    const char *blobs_env = getenv("AIRG_TAP_LOOP_BLOBS");
    int blobs_on = (blobs_env && blobs_env[0] == '1') ? 1 : 0;
    if (blobs_on) {
        g_blob_e4_src   = loop_make_timer(&blob_e4,   g_loop_queue);
        g_blob_f18_src  = loop_make_timer(&blob_f18,  g_loop_queue);
        g_blob_ptbf_src = loop_make_timer(&blob_ptbf, g_loop_queue);
    }

    // own 9 BENCHMARK-COMPLETE wave — process gate (6 filter) gate.
    const char *procs_env = getenv("AIRG_TAP_LOOP_PROCS");
    int procs_on = (procs_env && procs_env[0] == '1') ? 1 : 0;
    if (procs_on) {
        g_proc_calendar_src = loop_make_timer(&proc_calendar, g_loop_queue);
        g_proc_finder_src   = loop_make_timer(&proc_finder,   g_loop_queue);
        g_proc_mail_src     = loop_make_timer(&proc_mail,     g_loop_queue);
        g_proc_memo_src     = loop_make_timer(&proc_memo,     g_loop_queue);
        g_proc_safari_src   = loop_make_timer(&proc_safari,   g_loop_queue);
        g_proc_telegram_src = loop_make_timer(&proc_telegram, g_loop_queue);
    }

    // own 9 — K-wave macOS-level Type E (raw 240 V2 만점기준 사전 적용 5 filter).
    const char *datae_env = getenv("AIRG_TAP_LOOP_DATAE");
    int datae_on = (datae_env && datae_env[0] == '1') ? 1 : 0;
    if (datae_on) {
        g_datae_im1_src  = loop_make_timer(&datae_im1,  g_loop_queue);
        g_datae_k1_src   = loop_make_timer(&datae_k1,   g_loop_queue);
        g_datae_k2_src   = loop_make_timer(&datae_k2,   g_loop_queue);
        g_datae_k5_src   = loop_make_timer(&datae_k5,   g_loop_queue);
        g_datae_k6_src   = loop_make_timer(&datae_k6,   g_loop_queue);
        g_datae_k4_src   = loop_make_timer(&datae_k4,   g_loop_queue);
        g_datae_dklc_src = loop_make_timer(&datae_dklc, g_loop_queue);
        // wave-5 PASS 10
        g_datae_w5_memo_notes_src    = loop_make_timer(&datae_w5_memo_notes,    g_loop_queue);
        g_datae_w5_memo_search_src   = loop_make_timer(&datae_w5_memo_search,   g_loop_queue);
        g_datae_w5_tel_chat_src      = loop_make_timer(&datae_w5_tel_chat,      g_loop_queue);
        g_datae_w5_tel_media_src     = loop_make_timer(&datae_w5_tel_media,     g_loop_queue);
        g_datae_w5_fi_recent_src     = loop_make_timer(&datae_w5_fi_recent,     g_loop_queue);
        g_datae_w5_tel_contact_src   = loop_make_timer(&datae_w5_tel_contact,   g_loop_queue);
        g_datae_w5_cal_recurring_src = loop_make_timer(&datae_w5_cal_recurring, g_loop_queue);
        g_datae_w5_music_src         = loop_make_timer(&datae_w5_music,         g_loop_queue);
        g_datae_w5_books_src         = loop_make_timer(&datae_w5_books,         g_loop_queue);
        g_datae_w5_shortcuts_src     = loop_make_timer(&datae_w5_shortcuts,     g_loop_queue);
        g_datae_w5_cal_event_src     = loop_make_timer(&datae_w5_cal_event,     g_loop_queue);
        g_datae_w5_mail_envelope_src = loop_make_timer(&datae_w5_mail_envelope, g_loop_queue);
        g_datae_w5_mail_sender_src   = loop_make_timer(&datae_w5_mail_sender,   g_loop_queue);
        g_datae_w5_memo_attach_src   = loop_make_timer(&datae_w5_memo_attach,   g_loop_queue);
        // wave-6 26 PASS filter
        g_datae_w6_bash_src = loop_make_timer(&datae_w6_bash, g_loop_queue);
        g_datae_w6_ib1_src  = loop_make_timer(&datae_w6_ib1,  g_loop_queue);
        g_datae_w6_ib2_src  = loop_make_timer(&datae_w6_ib2,  g_loop_queue);
        g_datae_w6_pb1_src  = loop_make_timer(&datae_w6_pb1,  g_loop_queue);
        g_datae_w6_pb2_src  = loop_make_timer(&datae_w6_pb2,  g_loop_queue);
        g_datae_w6_md1_src  = loop_make_timer(&datae_w6_md1,  g_loop_queue);
        g_datae_w6_md2_src  = loop_make_timer(&datae_w6_md2,  g_loop_queue);
        g_datae_w6_sl1_src  = loop_make_timer(&datae_w6_sl1,  g_loop_queue);
        g_datae_w6_cl3_src  = loop_make_timer(&datae_w6_cl3,  g_loop_queue);
        g_datae_w6_mx1_src  = loop_make_timer(&datae_w6_mx1,  g_loop_queue);
        g_datae_w6_mx2_src  = loop_make_timer(&datae_w6_mx2,  g_loop_queue);
        g_datae_w6_mx3_src  = loop_make_timer(&datae_w6_mx3,  g_loop_queue);
        g_datae_w6_mx4_src  = loop_make_timer(&datae_w6_mx4,  g_loop_queue);
        g_datae_w6_ct1_src  = loop_make_timer(&datae_w6_ct1,  g_loop_queue);
        g_datae_w6_ct2_src  = loop_make_timer(&datae_w6_ct2,  g_loop_queue);
        g_datae_w6_ct3_src  = loop_make_timer(&datae_w6_ct3,  g_loop_queue);
        g_datae_w6_br1_src  = loop_make_timer(&datae_w6_br1,  g_loop_queue);
        g_datae_w6_br2_src  = loop_make_timer(&datae_w6_br2,  g_loop_queue);
        g_datae_w6_br3_src  = loop_make_timer(&datae_w6_br3,  g_loop_queue);
        g_datae_w6_br6_src  = loop_make_timer(&datae_w6_br6,  g_loop_queue);
        g_datae_w6_sf1_src  = loop_make_timer(&datae_w6_sf1,  g_loop_queue);
        g_datae_w6_sf3_src  = loop_make_timer(&datae_w6_sf3,  g_loop_queue);
        g_datae_w6_sf4_src  = loop_make_timer(&datae_w6_sf4,  g_loop_queue);
        g_datae_w6_ix1_src  = loop_make_timer(&datae_w6_ix1,  g_loop_queue);
        g_datae_w6_ix2_src  = loop_make_timer(&datae_w6_ix2,  g_loop_queue);
        g_datae_w6_ix3_src  = loop_make_timer(&datae_w6_ix3,  g_loop_queue);
        // wave-7 network 6 partial
        g_datae_w7_wifi_signal_src = loop_make_timer(&datae_w7_wifi_signal, g_loop_queue);
        g_datae_w7_dns_cache_src   = loop_make_timer(&datae_w7_dns_cache,   g_loop_queue);
        g_datae_w7_dns_query_src   = loop_make_timer(&datae_w7_dns_query,   g_loop_queue);
        g_datae_w7_pkt_dedup_src   = loop_make_timer(&datae_w7_pkt_dedup,   g_loop_queue);
        g_datae_w7_http_consol_src = loop_make_timer(&datae_w7_http_consol, g_loop_queue);
        g_datae_w7_tcp_conn_src    = loop_make_timer(&datae_w7_tcp_conn,    g_loop_queue);
        g_datae_w7_wifi_dedup_src  = loop_make_timer(&datae_w7_wifi_dedup,  g_loop_queue);
        g_datae_w7_bonjour_src     = loop_make_timer(&datae_w7_bonjour,     g_loop_queue);
        g_datae_w7_keepalive_src   = loop_make_timer(&datae_w7_keepalive,   g_loop_queue);
    }

    NSLog(@"[airgenome_loop] init: harvest=%s label=%s forecast=%s safari=%s blobs=%s procs=%s datae=%s",
          g_harvest_src  ? "ok" : "FAIL",
          g_label_src    ? "ok" : "FAIL",
          g_forecast_src ? "ok" : "FAIL",
          safari_on ? "on" : "off",
          blobs_on  ? "on" : "off",
          procs_on  ? "on" : "off",
          datae_on  ? "on" : "off");
    if (safari_on) {
        NSLog(@"[airgenome_loop] safari wave: genome=%s active=%s youtube=%s battery=%s",
              g_safari_genome_src  ? "ok" : "FAIL",
              g_safari_active_src  ? "ok" : "FAIL",
              g_safari_youtube_src ? "ok" : "FAIL",
              g_safari_battery_src ? "ok" : "FAIL");
    }
    if (blobs_on) {
        NSLog(@"[airgenome_loop] blob wave: e4=%s f18=%s ptbf=%s",
              g_blob_e4_src   ? "ok" : "FAIL",
              g_blob_f18_src  ? "ok" : "FAIL",
              g_blob_ptbf_src ? "ok" : "FAIL");
    }
    if (procs_on) {
        NSLog(@"[airgenome_loop] procs wave: cal=%s finder=%s mail=%s memo=%s safari=%s tel=%s",
              g_proc_calendar_src ? "ok" : "FAIL",
              g_proc_finder_src   ? "ok" : "FAIL",
              g_proc_mail_src     ? "ok" : "FAIL",
              g_proc_memo_src     ? "ok" : "FAIL",
              g_proc_safari_src   ? "ok" : "FAIL",
              g_proc_telegram_src ? "ok" : "FAIL");
    }
    if (datae_on) {
        NSLog(@"[airgenome_loop] datae wave: im1=%s k1=%s k2=%s k5=%s k6=%s k4=%s dklc=%s",
              g_datae_im1_src  ? "ok" : "FAIL",
              g_datae_k1_src   ? "ok" : "FAIL",
              g_datae_k2_src   ? "ok" : "FAIL",
              g_datae_k5_src   ? "ok" : "FAIL",
              g_datae_k6_src   ? "ok" : "FAIL",
              g_datae_k4_src   ? "ok" : "FAIL",
              g_datae_dklc_src ? "ok" : "FAIL");
        NSLog(@"[airgenome_loop] datae w5: memo_notes=%s memo_search=%s tel_chat=%s tel_media=%s fi_recent=%s tel_contact=%s cal_recur=%s music=%s books=%s shortcuts=%s cal_event=%s",
              g_datae_w5_memo_notes_src    ? "ok" : "FAIL",
              g_datae_w5_memo_search_src   ? "ok" : "FAIL",
              g_datae_w5_tel_chat_src      ? "ok" : "FAIL",
              g_datae_w5_tel_media_src     ? "ok" : "FAIL",
              g_datae_w5_fi_recent_src     ? "ok" : "FAIL",
              g_datae_w5_tel_contact_src   ? "ok" : "FAIL",
              g_datae_w5_cal_recurring_src ? "ok" : "FAIL",
              g_datae_w5_music_src         ? "ok" : "FAIL",
              g_datae_w5_books_src         ? "ok" : "FAIL",
              g_datae_w5_shortcuts_src     ? "ok" : "FAIL",
              g_datae_w5_cal_event_src     ? "ok" : "FAIL");
        NSLog(@"[airgenome_loop] datae mail-fix: envelope=%s sender=%s memo_attach=%s",
              g_datae_w5_mail_envelope_src ? "ok" : "FAIL",
              g_datae_w5_mail_sender_src   ? "ok" : "FAIL",
              g_datae_w5_memo_attach_src   ? "ok" : "FAIL");
        NSLog(@"[airgenome_loop] datae w6-A: bash=%s ib1=%s ib2=%s pb1=%s pb2=%s md1=%s md2=%s sl1=%s cl3=%s",
              g_datae_w6_bash_src ? "ok" : "FAIL",
              g_datae_w6_ib1_src  ? "ok" : "FAIL",
              g_datae_w6_ib2_src  ? "ok" : "FAIL",
              g_datae_w6_pb1_src  ? "ok" : "FAIL",
              g_datae_w6_pb2_src  ? "ok" : "FAIL",
              g_datae_w6_md1_src  ? "ok" : "FAIL",
              g_datae_w6_md2_src  ? "ok" : "FAIL",
              g_datae_w6_sl1_src  ? "ok" : "FAIL",
              g_datae_w6_cl3_src  ? "ok" : "FAIL");
        NSLog(@"[airgenome_loop] datae w6-B: mx1=%s mx2=%s mx3=%s mx4=%s ct1=%s ct2=%s ct3=%s",
              g_datae_w6_mx1_src ? "ok" : "FAIL",
              g_datae_w6_mx2_src ? "ok" : "FAIL",
              g_datae_w6_mx3_src ? "ok" : "FAIL",
              g_datae_w6_mx4_src ? "ok" : "FAIL",
              g_datae_w6_ct1_src ? "ok" : "FAIL",
              g_datae_w6_ct2_src ? "ok" : "FAIL",
              g_datae_w6_ct3_src ? "ok" : "FAIL");
        NSLog(@"[airgenome_loop] datae w6-C: br1=%s br2=%s br3=%s br6=%s sf1=%s sf3=%s sf4=%s ix1=%s ix2=%s ix3=%s",
              g_datae_w6_br1_src ? "ok" : "FAIL",
              g_datae_w6_br2_src ? "ok" : "FAIL",
              g_datae_w6_br3_src ? "ok" : "FAIL",
              g_datae_w6_br6_src ? "ok" : "FAIL",
              g_datae_w6_sf1_src ? "ok" : "FAIL",
              g_datae_w6_sf3_src ? "ok" : "FAIL",
              g_datae_w6_sf4_src ? "ok" : "FAIL",
              g_datae_w6_ix1_src ? "ok" : "FAIL",
              g_datae_w6_ix2_src ? "ok" : "FAIL",
              g_datae_w6_ix3_src ? "ok" : "FAIL");
        NSLog(@"[airgenome_loop] datae w7-net: wifi=%s dns_cache=%s dns_query=%s pkt_dedup=%s http_consol=%s tcp_conn=%s",
              g_datae_w7_wifi_signal_src ? "ok" : "FAIL",
              g_datae_w7_dns_cache_src   ? "ok" : "FAIL",
              g_datae_w7_dns_query_src   ? "ok" : "FAIL",
              g_datae_w7_pkt_dedup_src   ? "ok" : "FAIL",
              g_datae_w7_http_consol_src ? "ok" : "FAIL",
              g_datae_w7_tcp_conn_src    ? "ok" : "FAIL");
        NSLog(@"[airgenome_loop] datae w7-fg: wifi_dedup=%s bonjour=%s keepalive=%s",
              g_datae_w7_wifi_dedup_src ? "ok" : "FAIL",
              g_datae_w7_bonjour_src    ? "ok" : "FAIL",
              g_datae_w7_keepalive_src  ? "ok" : "FAIL");
    }
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
    if (g_safari_genome_src)  { dispatch_source_cancel(g_safari_genome_src);  g_safari_genome_src  = NULL; }
    if (g_safari_active_src)  { dispatch_source_cancel(g_safari_active_src);  g_safari_active_src  = NULL; }
    if (g_safari_youtube_src) { dispatch_source_cancel(g_safari_youtube_src); g_safari_youtube_src = NULL; }
    if (g_safari_battery_src) { dispatch_source_cancel(g_safari_battery_src); g_safari_battery_src = NULL; }
    if (g_blob_e4_src)        { dispatch_source_cancel(g_blob_e4_src);        g_blob_e4_src        = NULL; }
    if (g_blob_f18_src)       { dispatch_source_cancel(g_blob_f18_src);       g_blob_f18_src       = NULL; }
    if (g_blob_ptbf_src)      { dispatch_source_cancel(g_blob_ptbf_src);      g_blob_ptbf_src      = NULL; }
    if (g_proc_calendar_src)  { dispatch_source_cancel(g_proc_calendar_src);  g_proc_calendar_src  = NULL; }
    if (g_proc_finder_src)    { dispatch_source_cancel(g_proc_finder_src);    g_proc_finder_src    = NULL; }
    if (g_proc_mail_src)      { dispatch_source_cancel(g_proc_mail_src);      g_proc_mail_src      = NULL; }
    if (g_proc_memo_src)      { dispatch_source_cancel(g_proc_memo_src);      g_proc_memo_src      = NULL; }
    if (g_proc_safari_src)    { dispatch_source_cancel(g_proc_safari_src);    g_proc_safari_src    = NULL; }
    if (g_proc_telegram_src)  { dispatch_source_cancel(g_proc_telegram_src);  g_proc_telegram_src  = NULL; }
    if (g_datae_im1_src)      { dispatch_source_cancel(g_datae_im1_src);      g_datae_im1_src      = NULL; }
    if (g_datae_k1_src)       { dispatch_source_cancel(g_datae_k1_src);       g_datae_k1_src       = NULL; }
    if (g_datae_k2_src)       { dispatch_source_cancel(g_datae_k2_src);       g_datae_k2_src       = NULL; }
    if (g_datae_k5_src)       { dispatch_source_cancel(g_datae_k5_src);       g_datae_k5_src       = NULL; }
    if (g_datae_k6_src)       { dispatch_source_cancel(g_datae_k6_src);       g_datae_k6_src       = NULL; }
    if (g_datae_k4_src)       { dispatch_source_cancel(g_datae_k4_src);       g_datae_k4_src       = NULL; }
    if (g_datae_dklc_src)     { dispatch_source_cancel(g_datae_dklc_src);     g_datae_dklc_src     = NULL; }
    if (g_datae_w5_memo_notes_src)    { dispatch_source_cancel(g_datae_w5_memo_notes_src);    g_datae_w5_memo_notes_src    = NULL; }
    if (g_datae_w5_memo_search_src)   { dispatch_source_cancel(g_datae_w5_memo_search_src);   g_datae_w5_memo_search_src   = NULL; }
    if (g_datae_w5_tel_chat_src)      { dispatch_source_cancel(g_datae_w5_tel_chat_src);      g_datae_w5_tel_chat_src      = NULL; }
    if (g_datae_w5_tel_media_src)     { dispatch_source_cancel(g_datae_w5_tel_media_src);     g_datae_w5_tel_media_src     = NULL; }
    if (g_datae_w5_fi_recent_src)     { dispatch_source_cancel(g_datae_w5_fi_recent_src);     g_datae_w5_fi_recent_src     = NULL; }
    if (g_datae_w5_tel_contact_src)   { dispatch_source_cancel(g_datae_w5_tel_contact_src);   g_datae_w5_tel_contact_src   = NULL; }
    if (g_datae_w5_cal_recurring_src) { dispatch_source_cancel(g_datae_w5_cal_recurring_src); g_datae_w5_cal_recurring_src = NULL; }
    if (g_datae_w5_music_src)         { dispatch_source_cancel(g_datae_w5_music_src);         g_datae_w5_music_src         = NULL; }
    if (g_datae_w5_books_src)         { dispatch_source_cancel(g_datae_w5_books_src);         g_datae_w5_books_src         = NULL; }
    if (g_datae_w5_shortcuts_src)     { dispatch_source_cancel(g_datae_w5_shortcuts_src);     g_datae_w5_shortcuts_src     = NULL; }
    if (g_datae_w5_cal_event_src)     { dispatch_source_cancel(g_datae_w5_cal_event_src);     g_datae_w5_cal_event_src     = NULL; }
    if (g_datae_w5_mail_envelope_src) { dispatch_source_cancel(g_datae_w5_mail_envelope_src); g_datae_w5_mail_envelope_src = NULL; }
    if (g_datae_w5_mail_sender_src)   { dispatch_source_cancel(g_datae_w5_mail_sender_src);   g_datae_w5_mail_sender_src   = NULL; }
    if (g_datae_w5_memo_attach_src)   { dispatch_source_cancel(g_datae_w5_memo_attach_src);   g_datae_w5_memo_attach_src   = NULL; }
    if (g_datae_w6_bash_src) { dispatch_source_cancel(g_datae_w6_bash_src); g_datae_w6_bash_src = NULL; }
    if (g_datae_w6_ib1_src)  { dispatch_source_cancel(g_datae_w6_ib1_src);  g_datae_w6_ib1_src  = NULL; }
    if (g_datae_w6_ib2_src)  { dispatch_source_cancel(g_datae_w6_ib2_src);  g_datae_w6_ib2_src  = NULL; }
    if (g_datae_w6_pb1_src)  { dispatch_source_cancel(g_datae_w6_pb1_src);  g_datae_w6_pb1_src  = NULL; }
    if (g_datae_w6_pb2_src)  { dispatch_source_cancel(g_datae_w6_pb2_src);  g_datae_w6_pb2_src  = NULL; }
    if (g_datae_w6_md1_src)  { dispatch_source_cancel(g_datae_w6_md1_src);  g_datae_w6_md1_src  = NULL; }
    if (g_datae_w6_md2_src)  { dispatch_source_cancel(g_datae_w6_md2_src);  g_datae_w6_md2_src  = NULL; }
    if (g_datae_w6_sl1_src)  { dispatch_source_cancel(g_datae_w6_sl1_src);  g_datae_w6_sl1_src  = NULL; }
    if (g_datae_w6_cl3_src)  { dispatch_source_cancel(g_datae_w6_cl3_src);  g_datae_w6_cl3_src  = NULL; }
    if (g_datae_w6_mx1_src)  { dispatch_source_cancel(g_datae_w6_mx1_src);  g_datae_w6_mx1_src  = NULL; }
    if (g_datae_w6_mx2_src)  { dispatch_source_cancel(g_datae_w6_mx2_src);  g_datae_w6_mx2_src  = NULL; }
    if (g_datae_w6_mx3_src)  { dispatch_source_cancel(g_datae_w6_mx3_src);  g_datae_w6_mx3_src  = NULL; }
    if (g_datae_w6_mx4_src)  { dispatch_source_cancel(g_datae_w6_mx4_src);  g_datae_w6_mx4_src  = NULL; }
    if (g_datae_w6_ct1_src)  { dispatch_source_cancel(g_datae_w6_ct1_src);  g_datae_w6_ct1_src  = NULL; }
    if (g_datae_w6_ct2_src)  { dispatch_source_cancel(g_datae_w6_ct2_src);  g_datae_w6_ct2_src  = NULL; }
    if (g_datae_w6_ct3_src)  { dispatch_source_cancel(g_datae_w6_ct3_src);  g_datae_w6_ct3_src  = NULL; }
    if (g_datae_w6_br1_src)  { dispatch_source_cancel(g_datae_w6_br1_src);  g_datae_w6_br1_src  = NULL; }
    if (g_datae_w6_br2_src)  { dispatch_source_cancel(g_datae_w6_br2_src);  g_datae_w6_br2_src  = NULL; }
    if (g_datae_w6_br3_src)  { dispatch_source_cancel(g_datae_w6_br3_src);  g_datae_w6_br3_src  = NULL; }
    if (g_datae_w6_br6_src)  { dispatch_source_cancel(g_datae_w6_br6_src);  g_datae_w6_br6_src  = NULL; }
    if (g_datae_w6_sf1_src)  { dispatch_source_cancel(g_datae_w6_sf1_src);  g_datae_w6_sf1_src  = NULL; }
    if (g_datae_w6_sf3_src)  { dispatch_source_cancel(g_datae_w6_sf3_src);  g_datae_w6_sf3_src  = NULL; }
    if (g_datae_w6_sf4_src)  { dispatch_source_cancel(g_datae_w6_sf4_src);  g_datae_w6_sf4_src  = NULL; }
    if (g_datae_w6_ix1_src)  { dispatch_source_cancel(g_datae_w6_ix1_src);  g_datae_w6_ix1_src  = NULL; }
    if (g_datae_w6_ix2_src)  { dispatch_source_cancel(g_datae_w6_ix2_src);  g_datae_w6_ix2_src  = NULL; }
    if (g_datae_w6_ix3_src)  { dispatch_source_cancel(g_datae_w6_ix3_src);  g_datae_w6_ix3_src  = NULL; }
    if (g_datae_w7_wifi_signal_src) { dispatch_source_cancel(g_datae_w7_wifi_signal_src); g_datae_w7_wifi_signal_src = NULL; }
    if (g_datae_w7_dns_cache_src)   { dispatch_source_cancel(g_datae_w7_dns_cache_src);   g_datae_w7_dns_cache_src   = NULL; }
    if (g_datae_w7_dns_query_src)   { dispatch_source_cancel(g_datae_w7_dns_query_src);   g_datae_w7_dns_query_src   = NULL; }
    if (g_datae_w7_pkt_dedup_src)   { dispatch_source_cancel(g_datae_w7_pkt_dedup_src);   g_datae_w7_pkt_dedup_src   = NULL; }
    if (g_datae_w7_http_consol_src) { dispatch_source_cancel(g_datae_w7_http_consol_src); g_datae_w7_http_consol_src = NULL; }
    if (g_datae_w7_tcp_conn_src)    { dispatch_source_cancel(g_datae_w7_tcp_conn_src);    g_datae_w7_tcp_conn_src    = NULL; }
    if (g_datae_w7_wifi_dedup_src)  { dispatch_source_cancel(g_datae_w7_wifi_dedup_src);  g_datae_w7_wifi_dedup_src  = NULL; }
    if (g_datae_w7_bonjour_src)     { dispatch_source_cancel(g_datae_w7_bonjour_src);     g_datae_w7_bonjour_src     = NULL; }
    if (g_datae_w7_keepalive_src)   { dispatch_source_cancel(g_datae_w7_keepalive_src);   g_datae_w7_keepalive_src   = NULL; }
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
