#!/bin/bash
# Builds NeelSpeak.app from the SPM executable + Info.plist + entitlements.
#
# Uses SwiftPM directly so local builds and GitHub tag builds do not depend on
# an Xcode project or scheme. Selecting full Xcode still gives SwiftPM access to
# newer SDKs when available.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/NeelSpeak.app"
CONFIG="${CONFIG:-release}"

cd "$ROOT"

if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    echo "    WARNING: full Xcode not found. Apple Intelligence cleanup requires the macOS 26 SDK."
    echo "    Install Xcode from the App Store for the full cleanup feature set."
fi

echo "==> swift build (-c $CONFIG)"
swift build -c "$CONFIG" --arch arm64
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"
BIN_FILE="$BIN_DIR/NeelSpeak"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_FILE" "$APP/Contents/MacOS/NeelSpeak"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Copy any SwiftPM resource bundles next to the binary so packaged dependencies
# can find their runtime assets.
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
    echo "==> bundling $(basename "$bundle")"
    cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

# Pick a stable self-signed identity if available; fall back to ad-hoc.
# Stable identity = stable designated requirement = TCC grants survive rebuilds.
CERT_NAME="NeelSpeak Local Developer"
if security find-certificate -c "$CERT_NAME" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
    SIGN_IDENTITY="$CERT_NAME"
    echo "==> codesign with stable identity \"$SIGN_IDENTITY\""
else
    SIGN_IDENTITY="-"
    echo "==> codesign ad-hoc (run Scripts/setup-codesign.sh once to make TCC grants persist)"
fi

codesign --force --deep --sign "$SIGN_IDENTITY" \
    --entitlements "$ROOT/Resources/VoiceTyper.entitlements" \
    "$APP"

echo "==> done: $APP"
echo "Run with: open '$APP'  (or '$APP/Contents/MacOS/NeelSpeak' for stdout logs)"
