/* winctl_geometry_ref.c — C reference harness for the winctl geometry kernel.
 *
 * Byte-for-byte transcription of `winctl_target_rect` from
 * native/src/airgenome_winctl.m (the Cocoa-free math island), lifted out of
 * the .m so it builds with plain `cc` (no Cocoa link) for RUNEQ vs the
 * winctl_geometry.hexa port. CGRect is replaced by a 4-double struct; the
 * arithmetic is identical (same operators, same 100.0/120.0 literal, same
 * clamp order). Emits "<x> <y> <w> <h>" with %.6f — matches the hexa harness.
 *
 * argv: action vfx vfy vfw vfh cwx cwy cww cwh
 */
#include <stdio.h>
#include <stdlib.h>

typedef struct { double x, y, w, h; } Rect;

static Rect winctl_target_rect(int action, Rect vf, Rect curWin) {
    Rect r;
    switch (action) {
        case 1: /* Maximize */
            return vf;
        case 2: { /* 100/120 center (≈83.33%) */
            const double scale = 100.0 / 120.0;
            double w = vf.w * scale;
            double h = vf.h * scale;
            r.x = vf.x + (vf.w - w) / 2;
            r.y = vf.y + (vf.h - h) / 2;
            r.w = w; r.h = h;
            return r;
        }
        case 3: /* Left half */
            r.x = vf.x; r.y = vf.y; r.w = vf.w / 2; r.h = vf.h;
            return r;
        case 4: /* Right half */
            r.x = vf.x + vf.w / 2; r.y = vf.y; r.w = vf.w / 2; r.h = vf.h;
            return r;
        case 5: { /* Center only — preserve current size */
            double w = curWin.w;
            double h = curWin.h;
            if (w > vf.w) w = vf.w;
            if (h > vf.h) h = vf.h;
            r.x = vf.x + (vf.w - w) / 2;
            r.y = vf.y + (vf.h - h) / 2;
            r.w = w; r.h = h;
            return r;
        }
        case 6: /* Top half (상 최대) */
            r.x = vf.x; r.y = vf.y; r.w = vf.w; r.h = vf.h / 2;
            return r;
        case 7: /* Bottom half (하 최대) */
            r.x = vf.x; r.y = vf.y + vf.h / 2; r.w = vf.w; r.h = vf.h / 2;
            return r;
        default:
            return curWin;
    }
}

int main(int argc, char **argv) {
    if (argc < 10) { fprintf(stderr, "need 9 args\n"); return 2; }
    int action = atoi(argv[1]);
    Rect vf  = { atof(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]) };
    Rect cur = { atof(argv[6]), atof(argv[7]), atof(argv[8]), atof(argv[9]) };
    Rect r = winctl_target_rect(action, vf, cur);
    printf("%.6f %.6f %.6f %.6f\n", r.x, r.y, r.w, r.h);
    return 0;
}
