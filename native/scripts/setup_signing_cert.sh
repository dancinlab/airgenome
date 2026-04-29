#!/usr/bin/env bash
# native/scripts/setup_signing_cert.sh
#
# One-time setup: create a per-user self-signed code-signing certificate
# and import it into the login keychain. Subsequent `codesign` invocations
# reference this cert identity, which gives the .app a STABLE designated
# requirement (cert chain + bundle id) instead of a per-build cdhash.
#
# Why this matters: macOS TCC (Accessibility, Input Monitoring, etc.)
# matches granted entries by their designated requirement. Ad-hoc signed
# binaries embed cdhash directly into the DR, so every rebuild produces
# a new cdhash and macOS revokes the grant. Cert-signed binaries embed
# cert-leaf-hash + identifier into the DR, which is invariant across
# rebuilds — the user grants ONCE per cert install, then never again.
#
# Idempotent: re-running this script when the cert is already imported
# is a no-op.
#
# Multi-user safe: each user has their own login keychain, so each user
# runs this once on their own machine.

set -euo pipefail

CERT_NAME="${AIRGENOME_CERT_NAME:-airgenome-self-signed}"
CERT_DIR="$HOME/.airgenome/signing"
KEY_FILE="$CERT_DIR/$CERT_NAME.key"
CER_FILE="$CERT_DIR/$CERT_NAME.cer"
P12_FILE="$CERT_DIR/$CERT_NAME.p12"
LOGIN_KC="$HOME/Library/Keychains/login.keychain-db"

mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"

# Already imported?
if security find-identity -p codesigning -v 2>&1 \
        | grep -q "\"$CERT_NAME\""; then
    echo "[airgenome-cert] '$CERT_NAME' already in keychain. ok."
    exit 0
fi

# Generate the cert if the source files don't exist yet.
if [ ! -f "$KEY_FILE" ] || [ ! -f "$CER_FILE" ]; then
    echo "[airgenome-cert] generating self-signed code-signing cert..."
    openssl req -newkey rsa:2048 -nodes \
        -keyout "$KEY_FILE" \
        -x509 -days 3650 \
        -out "$CER_FILE" \
        -subj "/CN=$CERT_NAME/O=airgenome" \
        -addext "basicConstraints=CA:FALSE" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        2>&1 | tail -3
    chmod 600 "$KEY_FILE"
fi

# Import the cert (PEM) and the private key (PEM/PKCS#8) into the login
# keychain SEPARATELY. macOS Sequoia/Tahoe `security` does not accept
# OpenSSL 3.x PKCS#12 bundles even with -legacy ciphers, so we sidestep
# the bundle and let Keychain Services link the key+cert automatically
# via matching public-key fingerprint.
#
# -A allows any application (e.g. /usr/bin/codesign) to use the private
# key without prompting. -T can scope this further if needed.
security import "$CER_FILE" \
    -k "$LOGIN_KC" \
    -A \
    -t cert 2>&1 | tail -3 || true
security import "$KEY_FILE" \
    -k "$LOGIN_KC" \
    -A \
    -t priv 2>&1 | tail -3 || true

# Mark the imported cert as user-trusted for code-signing. -d sets the
# user (default) trust domain, no sudo needed. Without this, the cert
# is in the keychain but `security find-identity -p codesigning` will
# not list it, and codesign refuses to use it.
security add-trusted-cert -d -r trustRoot \
    -p codeSign \
    -k "$LOGIN_KC" \
    "$CER_FILE" 2>&1 | tail -3 || true

# Allow codesign / Apple toolchain to use the imported private key
# without prompting on each invocation. This sets the partition-list
# ACL on the key. Empty -k password works for the unlocked login
# keychain. Best-effort; harmless if it fails.
security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "" \
    "$LOGIN_KC" >/dev/null 2>&1 || true

# Verify.
if security find-identity -p codesigning -v | grep -q "\"$CERT_NAME\""; then
    echo "[airgenome-cert] '$CERT_NAME' imported. codesign will pick it up automatically."
    echo "  cert dir: $CERT_DIR"
    echo "  next: make app  (will codesign with the new identity)"
else
    echo "[airgenome-cert] FAIL: cert not visible in 'security find-identity -p codesigning'." >&2
    echo "  fix: 1) Keychain Access → login → 인증서 → '$CERT_NAME' 항목 신뢰 → '코드 서명' 항상 신뢰" >&2
    echo "       2) re-run this script" >&2
    exit 1
fi
