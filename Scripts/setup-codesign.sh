#!/bin/bash
# One-time setup: create a self-signed code-signing certificate in your login
# keychain so the app's TCC permissions (Accessibility, Microphone) survive
# rebuilds instead of needing re-grant every time.
#
# Why: ad-hoc-signed binaries (codesign --sign -) get a fresh cdhash every
# build, and macOS TCC keys grants on cdhash for ad-hoc apps. A stable
# self-signed cert gives the app a stable designated requirement, so TCC
# treats every rebuild as the same app.
#
# Idempotent: re-running does nothing if the cert already exists.
set -euo pipefail

CERT_NAME="NeelSpeak Local Developer"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

CERT_EXISTS=0
if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    CERT_EXISTS=1
    echo "==> certificate \"$CERT_NAME\" already exists in login keychain"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ "$CERT_EXISTS" = "0" ]; then
    echo "==> generating self-signed code-signing certificate"
    cat > "$TMP/openssl.cnf" <<'EOF'
[req]
distinguished_name = req_dn
x509_extensions = v3_ext
prompt = no

[req_dn]
CN = NeelSpeak Local Developer

[v3_ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
EOF

openssl req -x509 \
    -newkey rsa:2048 \
    -keyout "$TMP/key.pem" \
    -out "$TMP/cert.pem" \
    -days 36500 \
    -nodes \
    -config "$TMP/openssl.cnf" \
    >/dev/null 2>&1

# Wrap key + cert in PKCS12 for security import.
# `-legacy` uses RC2-40/SHA1 which Apple's `security` tool can still import;
# the modern AES-256 default fails with "MAC verification failed".
P12_PASS="temp-import-pass"
openssl pkcs12 -export \
    -legacy \
    -in "$TMP/cert.pem" \
    -inkey "$TMP/key.pem" \
    -name "$CERT_NAME" \
    -out "$TMP/cert.p12" \
    -passout "pass:$P12_PASS" \
    >/dev/null 2>&1

    echo "==> importing into login keychain"
    # -T whitelist lets codesign use the private key without prompting
    security import "$TMP/cert.p12" \
        -k "$KEYCHAIN" \
        -P "$P12_PASS" \
        -T /usr/bin/codesign \
        -T /usr/bin/security

    # Set partition list so codesign can access the key without an interactive
    # "allow access" dialog. This step will prompt once for your login keychain
    # password.
    echo "==> granting codesign access to the new key (may prompt for keychain password)"
    security set-key-partition-list \
        -S apple-tool:,apple:,codesign: \
        -s \
        -k "" \
        "$KEYCHAIN" >/dev/null 2>&1 \
        || echo "    (partition list not updated automatically — codesign may prompt once on first use; click Always Allow)"
fi

# Always ensure trust: a self-signed cert needs an explicit user trust setting
# for codesign to accept it as a valid signing identity. Without this,
# `security find-identity -v -p codesigning` returns 0 valid identities.
if security find-identity -v -p codesigning 2>&1 | grep -q "$CERT_NAME"; then
    echo "==> trust already configured for \"$CERT_NAME\""
else
    echo "==> adding code-signing trust setting for \"$CERT_NAME\""
    # Export the cert from the keychain to a temp PEM (private key not exported)
    security find-certificate -c "$CERT_NAME" -p "$KEYCHAIN" > "$TMP/cert.pem"
    # User-level trust (no sudo), policy = codeSign. May open a GUI password prompt.
    security add-trusted-cert \
        -r trustRoot \
        -p codeSign \
        -k "$KEYCHAIN" \
        "$TMP/cert.pem" \
        || echo "    (trust setting failed — codesign will fall back to ad-hoc)"
fi

echo "==> done"
echo
echo "Future builds of Scripts/build-app.sh will automatically sign with"
echo "\"$CERT_NAME\". After your next rebuild you'll need to grant Accessibility"
echo "ONCE more — that grant will then persist across all future rebuilds."
