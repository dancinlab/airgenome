#!/usr/bin/env bash
# bin/build_app.sh — airgenome .app bundle 빌드 (type=app harness 대응)
# 산출: build/Airgenome.app (menubar 단일 바이너리 담은 Cocoa accessory app)
set -euo pipefail

ROOT="${AIRGENOME_ROOT:-${AIRGENOME:-$HOME/core/airgenome}}"
BUILD="$ROOT/build"
APP="$BUILD/Airgenome.app"
BIN_SRC="$ROOT/build/artifacts/airgenome-menubar"

# 1. menubar native binary 빌드 (하위 스크립트 재사용)
if [ ! -x "$BIN_SRC" ] || [ "$ROOT/bin/menubar.hexa" -nt "$BIN_SRC" ]; then
    echo "[1/4] build_menubar — native binary"
    "$ROOT/bin/build_menubar.sh"
fi

# 1.5. 강제 harness gate — V5 (ObjC launcher) 스모크: heartbeat refresh 검증.
echo "[2/5] test_menubar smoke gate"
if ! "$ROOT/bin/test_menubar.sh" "$BIN_SRC"; then
    echo "❌ harness FAIL — bundle/deploy 중단" >&2
    exit 1
fi

# 2. .app bundle 구조 생성
echo "[3/5] bundle → $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_SRC" "$APP/Contents/MacOS/Airgenome"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Airgenome</string>
    <key>CFBundleDisplayName</key><string>AirGenome</string>
    <key>CFBundleIdentifier</key><string>com.need-singularity.airgenome</string>
    <key>CFBundleExecutable</key><string>Airgenome</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><true/>
    <key>NSSupportsSuddenTermination</key><true/>
</dict>
</plist>
PLIST

# 3. ad-hoc codesign (macOS Gatekeeper 허용)
echo "[4/5] codesign --force --deep -s -"
codesign --force --deep --sign - "$APP" 2>&1 | tail -3 || true
xattr -cr "$APP" 2>/dev/null || true

# 4. /Applications/Airgenome.app 으로 deploy + launchd 재bootstrap.
# DEPLOY=skip 환경변수로 bypass 가능 (CI / hexa 단독 검증 등).
if [ "${DEPLOY:-do}" = "skip" ]; then
    echo "[5/5] deploy SKIP (DEPLOY=skip)"
else
    echo "[5/5] deploy → /Applications + launchd rebootstrap"
    DEST="/Applications/Airgenome.app"
    pkill -9 -f "$DEST" 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    # cp 후 bundle hash 가 변하므로 destination 에서 재서명 필요.
    codesign --force --deep --sign - "$DEST" 2>&1 | tail -1 || true
    UID_=$(id -u)
    AGENT="$HOME/Library/LaunchAgents/com.airgenome.menubar.plist"
    if [ -f "$AGENT" ]; then
        launchctl bootout "gui/$UID_/com.airgenome.menubar" 2>/dev/null || true
        sleep 1
        launchctl bootstrap "gui/$UID_" "$AGENT" 2>/dev/null || true
    fi
fi

echo "✅ built: $APP"
ls -la "$APP/Contents/MacOS/"
