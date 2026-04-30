# airgenome native shim build (combined CGEventTap + AX + menu-bar item).
#
# Multi-user deploy target:
#   /Applications/airgenome.app           -- system-wide bundle
#   ~/Library/LaunchAgents/com.airgenome.tap.plist  -- per-user agent
#   ~/Library/Logs/airgenome.app/         -- per-user logs
#
# raw#9 grandfather note -- Makefile + build helpers (osascript JXA, sips,
# iconutil, codesign) are build descriptors, not runtime code.

APP_NAME      = airgenome
APP_BUNDLE    = /Applications/$(APP_NAME).app
LOCAL_APP     = build/$(APP_NAME).app
INNER_BIN     = $(LOCAL_APP)/Contents/MacOS/$(APP_NAME)
INFO_PLIST    = launchd/Info.plist
ICON_ICNS     = build/AppIcon.icns
ICON_PNG_1024 = build/AppIcon_1024.png
ICON_SCRIPT   = scripts/build_icon.applescript

BIN           = build/$(APP_NAME)
# raw 177 single-TCC: launcher.m + winctl.m + hotkey.m linked into same
# binary (NOT separate exes — one bundle id, one TCC row).
SRC           = src/airgenome_tap.m src/airgenome_launcher.m \
                src/airgenome_winctl.m src/airgenome_hotkey.m \
                src/airgenome_loop.m
PLIST_TPL     = launchd/com.airgenome.tap.plist
INSTALL_PLIST = $(HOME)/Library/LaunchAgents/com.airgenome.tap.plist
LOG_DIR       = $(HOME)/Library/Logs/$(APP_NAME).app

# -fobjc-arc: ARC ON for all three .m files (audit 2026-04-30: launcher.m
# crash root cause was static NSArray * fields written without retain; tap.m
# + winctl.m only use CF retain/release on CF types and @autoreleasepool —
# both ARC-clean). NEVER drop -fobjc-arc without re-auditing every static
# strong-typed pointer in the .m sources for retain semantics.
CFLAGS        = -O2 -Wall -Wextra -ObjC -fobjc-arc
# SkyLight is a private framework — added 2026-04-30 for canonical app
# activation from background process (_SLPSSetFrontProcessWithOptions in
# airgenome_hotkey.m). On Tahoe-26 the binary lives in the dyld shared
# cache and only SkyLight.tbd ships on disk; the .tbd's symbol export
# list is what the linker resolves against (verified at SDK path
# System/Library/PrivateFrameworks/SkyLight.framework/SkyLight.tbd).
# Required by yabai/chunkwm/skhd for ~10 years; symbol stable across
# macOS 10.x → 26. raw 213 Tier-C exempt: in-process private API call,
# no admin auth, no shell-out.
FRAMEWORKS    = -framework ApplicationServices -framework Carbon \
                -framework Cocoa -framework AppKit -framework IOKit \
                -F /System/Library/PrivateFrameworks -framework SkyLight

.PHONY: all build app icon install uninstall status logs selftest \
        restart rebuild clean setup-signing launcher-status launcher-restore \
        loop-selftest

# One-time per-user signing cert provisioning. Idempotent.
setup-signing:
	@./scripts/setup_signing_cert.sh

all: app

# ---------------------------------------------------------------------------
# Stage 1: native binary (raw clang output, before bundling)
# ---------------------------------------------------------------------------

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p build
	clang $(CFLAGS) $(FRAMEWORKS) -o $@ $^
	@echo "built: $@ ($$(stat -f%z $@) bytes)"

# ---------------------------------------------------------------------------
# Stage 2: app icon (🧬 emoji rendered to .icns)
# ---------------------------------------------------------------------------

icon: $(ICON_ICNS)

$(ICON_PNG_1024): $(ICON_SCRIPT)
	@mkdir -p build
	@osascript $(ICON_SCRIPT) $(PWD)/$@ > /dev/null
	@echo "built: $@"

$(ICON_ICNS): $(ICON_PNG_1024)
	@rm -rf build/AppIcon.iconset
	@mkdir -p build/AppIcon.iconset
	@for sz in 16 32 128 256 512 ; do \
	    sips -z $$sz $$sz $(ICON_PNG_1024) --out build/AppIcon.iconset/icon_$${sz}x$${sz}.png > /dev/null ; \
	    sz2=$$((sz*2)) ; \
	    sips -z $$sz2 $$sz2 $(ICON_PNG_1024) --out build/AppIcon.iconset/icon_$${sz}x$${sz}@2x.png > /dev/null ; \
	done
	@iconutil -c icns build/AppIcon.iconset -o $@
	@echo "built: $@"

# ---------------------------------------------------------------------------
# Stage 3: .app bundle (Contents/{MacOS,Resources,Info.plist} + codesign)
# ---------------------------------------------------------------------------

app: $(LOCAL_APP)

$(LOCAL_APP): $(BIN) $(ICON_ICNS) $(INFO_PLIST)
	@rm -rf $(LOCAL_APP)
	@mkdir -p $(LOCAL_APP)/Contents/MacOS $(LOCAL_APP)/Contents/Resources
	@cp $(BIN)        $(INNER_BIN)
	@cp $(INFO_PLIST) $(LOCAL_APP)/Contents/Info.plist
	@cp $(ICON_ICNS)  $(LOCAL_APP)/Contents/Resources/AppIcon.icns
	@printf 'APPLairg' > $(LOCAL_APP)/Contents/PkgInfo
	@# Auto-provision a per-user self-signed code-signing cert on first
	@# build so the .app gets a stable designated requirement (cert chain
	@# + bundle id) instead of a per-build cdhash. Stable DR = TCC grants
	@# (Accessibility, Input Monitoring, etc.) survive every rebuild.
	@./scripts/setup_signing_cert.sh >/dev/null 2>&1 || true
	@SIGN_ID=$$(security find-identity -p codesigning -v 2>/dev/null \
	    | grep -o 'airgenome-self-signed' | head -1) ; \
	  if [ -n "$$SIGN_ID" ]; then \
	    codesign --force --deep --sign "$$SIGN_ID" \
	      --identifier com.airgenome.tap \
	      --options runtime \
	      $(LOCAL_APP) 2>&1 | tail -1 ; \
	    echo "  signed with: $$SIGN_ID (stable DR — TCC grant survives rebuilds)" ; \
	  else \
	    codesign --force --deep --sign - $(LOCAL_APP) 2>&1 | tail -1 ; \
	    echo "  WARN: signed ad-hoc (no cert) — TCC grant will reset every rebuild" ; \
	    echo "        run 'make setup-signing' to provision per-user cert" ; \
	  fi
	@xattr -cr $(LOCAL_APP) 2>/dev/null || true
	@echo "built: $(LOCAL_APP) ($$(du -sh $(LOCAL_APP) | awk '{print $$1}'))"

# ---------------------------------------------------------------------------
# Install: deploy bundle to /Applications, render plist with absolute paths,
# bootstrap LaunchAgent.
# ---------------------------------------------------------------------------

install: $(LOCAL_APP)
	@# replace any pre-existing /Applications/airgenome.app
	@rm -rf $(APP_BUNDLE)
	@cp -R $(LOCAL_APP) $(APP_BUNDLE)
	@# per-user log directory
	@mkdir -p $(LOG_DIR)
	@# render plist with /Applications + ~/Library/Logs absolute paths
	@mkdir -p $(HOME)/Library/LaunchAgents
	@sed "s|__BIN_PATH__|$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)|g; s|__LOG_DIR__|$(LOG_DIR)|g" \
	    $(PLIST_TPL) > $(INSTALL_PLIST)
	@launchctl bootout  gui/$$(id -u) $(INSTALL_PLIST) 2>/dev/null || true
	launchctl bootstrap gui/$$(id -u) $(INSTALL_PLIST)
	@echo
	@echo "installed: $(APP_BUNDLE)"
	@echo "logs:      $(LOG_DIR)/airgenome.{log,err}"
	@echo "agent:     $(INSTALL_PLIST)"
	@echo
	@echo "NEXT: System Settings -> Privacy & Security ->"
	@echo "      Accessibility -> enable $(APP_BUNDLE)"
	@echo "      then: make status"

uninstall:
	@launchctl bootout gui/$$(id -u) $(INSTALL_PLIST) 2>/dev/null || true
	@rm -f  $(INSTALL_PLIST)
	@rm -rf $(APP_BUNDLE)
	@# hive raw 181 install/uninstall symmetry (raw 209 launcher inheritance):
	@# remove launcher state files at idempotent rm -f. raw 180 system-state
	@# restore is delegated to `airgenome launcher restore` subcommand for
	@# SIGKILL recovery; this target only handles fs cleanup.
	@rm -f $(HOME)/Library/Application\ Support/airgenome/launcher.jsonl 2>/dev/null || true
	@echo "uninstalled."

# hive raw 209 reference impl: launcher-* phony targets for discoverability.
# These delegate to the bin/airgenome launcher subcommand stub (raw 169
# surgical: do not duplicate logic, route through canonical entry).
launcher-status:
	@$(PWD)/../bin/airgenome launcher status

launcher-restore:
	@$(PWD)/../bin/airgenome launcher restore

restart:
	@launchctl kickstart -k gui/$$(id -u)/com.airgenome.tap 2>/dev/null \
	    || echo "not loaded -- run: make install"

status:
	@launchctl print gui/$$(id -u)/com.airgenome.tap 2>/dev/null \
	    | grep -E "(state|last exit|pid)" \
	    || echo "not loaded -- run: make install"
	@echo
	@echo "bundle: $$([ -d $(APP_BUNDLE) ] && stat -f '%Sm  %N' $(APP_BUNDLE) || echo '(missing -- make install)')"
	@echo "logs:   $(LOG_DIR)"
	@echo
	@echo "native-tiling defaults (com.apple.WindowManager):"
	@for k in EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag EnableTilingOptionAccelerator; do \
	    v=$$(defaults read com.apple.WindowManager $$k 2>/dev/null || echo "(unset)"); \
	    printf "  %-32s %s\n" "$$k" "$$v"; \
	done

logs:
	@tail -n 40 $(LOG_DIR)/airgenome.log $(LOG_DIR)/airgenome.err 2>/dev/null \
	    || echo "no logs yet."

selftest: app
	@# foreground 2s smoke run; expects sentinel line on stderr at SIGTERM.
	@($(INNER_BIN) 2>&1 & echo $$! > build/.pid; sleep 2; kill $$(cat build/.pid)) \
	    | tee build/selftest.log
	@grep -q "__AIRGENOME_TAP_RESULT__" build/selftest.log \
	    && echo "selftest: PASS (sentinel observed)" \
	    || (echo "selftest: FAIL (no sentinel)"; exit 1)

# raw 240 § B.7 step 2 — airgenome_loop.m 단독 unit selftest. tap binary
# 와 격리 (singleton lock 무관). lockfile NB 차단 + interval guard 검증.
# 자식 spawn / watchdog 검증은 별도 stage (실 환경 mock 필요).
loop-selftest:
	@mkdir -p build
	clang $(CFLAGS) -framework Foundation \
	    -DAIRGENOME_LOOP_SELFTEST_MAIN=1 \
	    -o build/loop-selftest src/airgenome_loop.m
	@./build/loop-selftest && echo "loop-selftest: PASS"

rebuild: app restart
	@echo ""
	@echo "[airgenome.app] rebuild done. NEW BINARY = NEW cdhash -> macOS revoked Accessibility."
	@echo "  fix: System Settings -> Privacy & Security -> Accessibility ->"
	@echo "       remove the existing 'airgenome' entry -> re-add /Applications/airgenome.app -> toggle on"
	@echo "  then: make restart"

clean:
	rm -rf build
