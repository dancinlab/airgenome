// airgenome_helper.mm — Phase 1 stage2 — hexa loader 의 native helper
//
// hexa loader 의 native_helper_bridge.hexa 와 file-based RPC 로 통신.
// 기능: mmap_file, dlopen, dlsym, call_function, ping.
//
// build: clang++ -ObjC++ -framework Foundation -framework AppKit \
//          airgenome_helper.mm -o airgenome_helper
//
// 통신 protocol v1:
//   request file (/tmp/airgenome_bridge_req):
//     "v1\t<op>\t<payload>\n"
//   response file (/tmp/airgenome_bridge_resp):
//     "v1\tok\t<result>\n"   or   "v1\terror\t<msg>\n"

#import <Foundation/Foundation.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <dlfcn.h>
#import <unistd.h>
#import <string.h>
#import <errno.h>

static NSString * const kReqPath  = @"/tmp/airgenome_bridge_req";
static NSString * const kRespPath = @"/tmp/airgenome_bridge_resp";

// ─── op handlers ───

static NSString *handle_ping(NSString *payload) {
    (void)payload;
    return @"pong";
}

static NSString *handle_mmap_file(NSString *payload) {
    // payload = "<path>\t<prot>"  (prot = R / RX / RW)
    NSArray<NSString *> *parts = [payload componentsSeparatedByString:@"\t"];
    if (parts.count < 2) return @"error\tbad_payload";
    NSString *path = parts[0];
    NSString *prot = parts[1];

    int prot_flags = PROT_READ;
    if ([prot containsString:@"W"]) prot_flags |= PROT_WRITE;
    if ([prot containsString:@"X"]) prot_flags |= PROT_EXEC;

    int fd = open([path UTF8String], O_RDONLY);
    if (fd < 0) return [NSString stringWithFormat:@"error\topen %d", errno];

    struct stat st;
    if (fstat(fd, &st) < 0) { close(fd); return @"error\tfstat"; }

    void *base = mmap(NULL, st.st_size, prot_flags, MAP_PRIVATE, fd, 0);
    close(fd);
    if (base == MAP_FAILED) return [NSString stringWithFormat:@"error\tmmap %d", errno];

    return [NSString stringWithFormat:@"%p\t%lld", base, (long long)st.st_size];
}

static NSString *handle_dlopen(NSString *payload) {
    // payload = "<framework or dylib path>"
    void *handle = dlopen([payload UTF8String], RTLD_LAZY | RTLD_LOCAL);
    if (!handle) return [NSString stringWithFormat:@"error\tdlopen %s", dlerror()];
    return [NSString stringWithFormat:@"%p", handle];
}

static NSString *handle_dlsym(NSString *payload) {
    // payload = "<handle_hex>\t<symbol>"
    NSArray<NSString *> *parts = [payload componentsSeparatedByString:@"\t"];
    if (parts.count < 2) return @"error\tbad_payload";

    unsigned long long h = 0;
    sscanf([parts[0] UTF8String], "%llx", &h);
    void *handle = (void *)(uintptr_t)h;
    if (h == 0) handle = RTLD_DEFAULT;

    void *addr = dlsym(handle, [parts[1] UTF8String]);
    if (!addr) return [NSString stringWithFormat:@"error\tdlsym %s", dlerror()];

    return [NSString stringWithFormat:@"%p", addr];
}

// ─── dispatch ───

static NSString *dispatch_op(NSString *op, NSString *payload) {
    if ([op isEqualToString:@"ping"]) return handle_ping(payload);
    if ([op isEqualToString:@"mmap_file"]) return handle_mmap_file(payload);
    if ([op isEqualToString:@"dlopen"]) return handle_dlopen(payload);
    if ([op isEqualToString:@"dlsym"]) return handle_dlsym(payload);
    return [NSString stringWithFormat:@"error\tunknown_op %@", op];
}

static void process_request(void) {
    NSString *content = [NSString stringWithContentsOfFile:kReqPath
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    if (!content) return;

    NSString *line = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@"\t"];
    if (parts.count < 2 || ![parts[0] isEqualToString:@"v1"]) {
        [@"v1\terror\tbad_request\n" writeToFile:kRespPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }

    NSString *op = parts[1];
    NSString *payload = parts.count >= 3 ? parts[2] : @"";

    NSString *result = dispatch_op(op, payload);

    NSString *resp;
    if ([result hasPrefix:@"error\t"]) {
        resp = [NSString stringWithFormat:@"v1\t%@\n", result];
    } else {
        resp = [NSString stringWithFormat:@"v1\tok\t%@\n", result];
    }

    [resp writeToFile:kRespPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // request consumed — remove
    [[NSFileManager defaultManager] removeItemAtPath:kReqPath error:nil];
}

// ─── main loop — poll /tmp/airgenome_bridge_req every 100ms ───

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc >= 2 && strcmp(argv[1], "--once") == 0) {
            // single-shot mode (test)
            process_request();
            return 0;
        }

        fprintf(stderr, "airgenome_helper v1 listening at %s\n", [kReqPath UTF8String]);

        while (1) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:kReqPath]) {
                process_request();
            }
            usleep(100000);   // 100ms
        }
    }
    return 0;
}
