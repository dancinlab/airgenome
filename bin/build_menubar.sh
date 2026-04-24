#!/usr/bin/env bash
# bin/build_menubar.sh — T4 menubar build (hexa-only via hexa_v2 transpiler)
# 산출: build/artifacts/airgenome-menubar (static, dlopen objc framework)
set -euo pipefail

ROOT="${AIRGENOME_ROOT:-${AIRGENOME:-$HOME/core/airgenome}}"
HXV2="${HEXA_LANG:-$HOME/core/hexa-lang}/self/native/hexa_v2"
RUNTIME="${HEXA_LANG:-$HOME/core/hexa-lang}/self/runtime.c"
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

echo "[2/4] FFI marshalling post-process (TAG_STR 포인터 + msg_float ABI)"
# hexa_v2 0.x codegen 버그 우회:
#   1) (X.tag==TAG_INT?X.i:(int64_t)X.f) 는 TAG_STR 일 때 포인터 소실
#      → hexa_ffi_marshal_arg(X) 로 교체 (TAG_STR 포인터, FLOAT bit-reinterpret 등 전부 처리)
#   2) msg_float 은 int64_t arg typedef 로 호출 → ARM64 ABI 에서 d0 아닌 x2 에 전달되어 CGFloat 소실
#      → __ffi_ftyp_msg_float 시그니처를 double 로, 호출부도 double 로
perl -i -pe 's/\(([a-zA-Z_]\w*)\.tag==TAG_INT\?\1\.i:\(int64_t\)\1\.f\)/hexa_ffi_marshal_arg($1)/g' "$OUT_C"
# msg_float 특화 — CGFloat ABI 수정
perl -i -pe 's{typedef int64_t \(\*__ffi_ftyp_msg_float\)\(int64_t, int64_t, int64_t\);}{typedef int64_t (*__ffi_ftyp_msg_float)(int64_t, int64_t, double);}' "$OUT_C"
perl -i -pe 's{HexaVal msg_float\(HexaVal obj, HexaVal sel, HexaVal a1\) \{\n    int64_t __r = \(\(__ffi_ftyp_msg_float\)__ffi_sym_msg_float\)\(hexa_ffi_marshal_arg\(obj\), hexa_ffi_marshal_arg\(sel\), hexa_ffi_marshal_arg\(a1\)\);}{HexaVal msg_float(HexaVal obj, HexaVal sel, HexaVal a1) \{\n    double _da1 = (a1.tag==TAG_FLOAT?a1.f:(a1.tag==TAG_INT?(double)a1.i:0.0));\n    int64_t __r = ((__ffi_ftyp_msg_float)__ffi_sym_msg_float)(hexa_ffi_marshal_arg(obj), hexa_ffi_marshal_arg(sel), _da1);}s' "$OUT_C"

# [#2 2026-04-24] ObjC launcher 와 link 충돌 방지 — hexa_v2 가 emit 하는
# `int main(int, char**)` 를 `hexa_autogen_main` 으로 rename. 실제 main 은
# bin/menubar_launcher.m 이 제공.
perl -i -pe 's/^int main\(int argc, char\*\* argv\)/int hexa_autogen_main(int argc, char** argv)/' "$OUT_C"
# hexa_autogen_main 의 끝부분이 `u_main();` 호출 (hexa 의 원래 main 진입) —
# ObjC launcher 경로에서는 setup/tick 을 따로 부르므로 원본 main 진입 제거.
# hexa_autogen_main 은 globals/FFI dlsym 만 초기화하는 역할로 한정.
perl -i -pe 's/^    u_main\(\);//' "$OUT_C"

LAUNCHER="$ROOT/bin/menubar_launcher.m"
[ -f "$LAUNCHER" ] || { echo "❌ launcher missing: $LAUNCHER" >&2; exit 1; }

echo "[3/4] clang compile — hexa C + ObjC launcher (AppKit/Foundation link)"
clang -O2 -framework AppKit -framework Foundation -framework CoreFoundation \
    -o "$OUT_BIN" "$OUT_C" "$LAUNCHER"

echo "[4/4] verify — main symbol 은 launcher 소스에서 와야 함"
nm "$OUT_BIN" 2>/dev/null | grep -E ' T _main$' >/dev/null || { echo "❌ no _main symbol" >&2; exit 1; }

echo "✅ built: $OUT_BIN"
ls -la "$OUT_BIN"
