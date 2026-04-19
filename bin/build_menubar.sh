#!/usr/bin/env bash
# bin/build_menubar.sh — T4 menubar build (hexa-only via hexa_v2 transpiler)
# 산출: build/artifacts/airgenome-menubar (static, dlopen objc framework)
set -euo pipefail

ROOT="${AIRGENOME_ROOT:-${AIRGENOME:-$HOME/Dev/airgenome}}"
HXV2="${HEXA_LANG:-$HOME/Dev/hexa-lang}/self/native/hexa_v2"
RUNTIME="${HEXA_LANG:-$HOME/Dev/hexa-lang}/self/runtime.c"
SRC="$ROOT/bin/menubar.hexa"
ART="$ROOT/build/artifacts"
OUT_C="$ART/menubar.c"
OUT_BIN="$ART/airgenome-menubar"

[ -x "$HXV2"  ] || { echo "❌ hexa_v2 missing: $HXV2"  >&2; exit 1; }
[ -f "$RUNTIME" ] || { echo "❌ runtime.c missing: $RUNTIME" >&2; exit 1; }
[ -f "$SRC"   ] || { echo "❌ src missing: $SRC"   >&2; exit 1; }

mkdir -p "$ART"
cp -f "$RUNTIME" "$ART/runtime.c"

echo "[1/3] hexa_v2 transpile → C"
"$HXV2" "$SRC" "$OUT_C"

echo "[2/3] FFI marshalling post-process (TAG_STR 포인터 + msg_float ABI)"
# hexa_v2 0.x codegen 버그 우회 — 2026-04-19 업데이트 (AG-Q4 루트원인):
#   hexa_v2 codegen 이 `(X.tag==TAG_INT?X.i:(int64_t)X.f)` → `(HX_IS_INT(X)?HX_INT_U(X):(int64_t)HX_FLOAT(X))` 로 변경됐으나
#   TAG_STR 포인터 처리가 여전히 누락됨. 문자열 인자가 float bit 로 reinterpret 되어 garbage 전달 →
#   objc_getClass("NSApplication") 등 전부 NULL 반환 → 메뉴바 아이콘 안뜨는 주증상.
#   1) TAG_STR 패치: 새 codegen 패턴도 `hexa_ffi_marshal_arg(X)` 로 치환 (4-way switch — STR/INT/FLOAT/BOOL 전부 처리)
#   2) msg_float CGFloat ABI: `double _da1` helper 로 ARM64 d0 레지스터 경유 강제
perl -i -pe 's/\(([a-zA-Z_]\w*)\.tag==TAG_INT\?\1\.i:\(int64_t\)\1\.f\)/hexa_ffi_marshal_arg($1)/g' "$OUT_C"
perl -i -pe 's/\(HX_IS_INT\(([a-zA-Z_]\w*)\)\?HX_INT_U\(\1\):\(int64_t\)HX_FLOAT\(\1\)\)/hexa_ffi_marshal_arg($1)/g' "$OUT_C"
# msg_float 특화 — CGFloat ABI 수정
perl -i -pe 's{typedef int64_t \(\*__ffi_ftyp_msg_float\)\(int64_t, int64_t, int64_t\);}{typedef int64_t (*__ffi_ftyp_msg_float)(int64_t, int64_t, double);}' "$OUT_C"
perl -i -0pe 's{HexaVal msg_float\(HexaVal obj, HexaVal sel, HexaVal a1\) \{\n    int64_t __r = \(\(__ffi_ftyp_msg_float\)__ffi_sym_msg_float\)\(hexa_ffi_marshal_arg\(obj\), hexa_ffi_marshal_arg\(sel\), \(HX_IS_FLOAT\(a1\)\?HX_FLOAT\(a1\):\(double\)HX_INT\(a1\)\)\);}{HexaVal msg_float(HexaVal obj, HexaVal sel, HexaVal a1) \{\n    double _da1 = (HX_IS_FLOAT(a1)?HX_FLOAT(a1):(HX_IS_INT(a1)?(double)HX_INT(a1):0.0));\n    int64_t __r = ((__ffi_ftyp_msg_float)__ffi_sym_msg_float)(hexa_ffi_marshal_arg(obj), hexa_ffi_marshal_arg(sel), _da1);}s' "$OUT_C"

echo "[3/3] clang compile → native binary (AppKit + CoreFoundation link)"
clang -O2 -I"${HEXA_LANG:-$HOME/Dev/hexa-lang}/self" -framework AppKit -framework CoreFoundation -o "$OUT_BIN" "$OUT_C"

# [AG-Q4 smoke] hexa_v2 codegen 변경으로 FFI patch 가 no-op 되는 regression 방지.
# AIRGENOME_MENUBAR_TEST=1 로 실행 → TEST DONE PASS 없으면 FFI marshalling 깨진 것.
# BUILD_MENUBAR_SKIP_SMOKE=1 로 bypass (오프라인/CI 용).
if [ "${BUILD_MENUBAR_SKIP_SMOKE:-0}" != "1" ]; then
    echo "[smoke] TEST mode self-check"
    smoke_out=$(AIRGENOME_MENUBAR_TEST=1 "$OUT_BIN" 2>&1 || true)
    if echo "$smoke_out" | grep -q "TEST DONE PASS"; then
        echo "✅ smoke TEST DONE PASS"
    else
        echo "❌ smoke FAIL — FFI marshalling broken (codegen regression 가능성)" >&2
        echo "$smoke_out" | grep -E "TEST|FAIL" | head -10 >&2
        exit 1
    fi
fi

echo "✅ built: $OUT_BIN"
ls -la "$OUT_BIN"
