#!/bin/bash
# Builds NeelSpeak.app from the SPM executable + Info.plist + entitlements.
#
# Uses xcodebuild when full Xcode is installed (required for MLX Metal shader
# compilation -- without it the Gemma cleanup engine will crash at runtime).
# Falls back to `swift build` otherwise; in that case the app runs but Gemma
# is unavailable and selecting it will crash the process.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/NeelSpeak.app"
CONFIG="${CONFIG:-release}"
SCHEME="NeelSpeak"
XCBUILD_DIR="$ROOT/.xcbuild"

cd "$ROOT"

# Detect whether full Xcode is available (xcodebuild + metal toolchain).
HAS_XCODE=0
if xcode-select -p 2>/dev/null | grep -q "Xcode.app" && command -v xcodebuild >/dev/null 2>&1; then
    if xcrun --find metal >/dev/null 2>&1; then
        HAS_XCODE=1
    fi
fi

if [ "$HAS_XCODE" = "1" ]; then
    # Map "release"/"debug" to "Release"/"Debug" (avoid bash 4 ${VAR^} on macOS bash 3.2)
    CONFIG_CAPS="$(echo "${CONFIG:0:1}" | tr '[:lower:]' '[:upper:]')${CONFIG:1}"
    echo "==> xcodebuild -scheme $SCHEME -configuration $CONFIG_CAPS"
    rm -rf "$XCBUILD_DIR"
    xcodebuild build \
        -scheme "$SCHEME" \
        -configuration "$CONFIG_CAPS" \
        -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath "$XCBUILD_DIR" \
        -quiet
    BIN_DIR="$XCBUILD_DIR/Build/Products/$CONFIG_CAPS"
    BIN_FILE="$BIN_DIR/NeelSpeak"
else
    echo "==> swift build (-c $CONFIG)"
    echo "    WARNING: full Xcode not found. The Gemma cleanup engine will not work."
    echo "    Install Xcode from the App Store and re-run to enable Gemma."
    swift build -c "$CONFIG" --arch arm64
    BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"
    BIN_FILE="$BIN_DIR/NeelSpeak"
fi

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_FILE" "$APP/Contents/MacOS/NeelSpeak"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Copy any SwiftPM resource bundles (e.g. mlx-swift_Cmlx.bundle that holds
# default.metallib) next to the binary so MLX can find them at runtime.
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
    echo "==> bundling $(basename "$bundle")"
    cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

echo "==> ad-hoc codesign with entitlements"
codesign --force --deep --sign - \
    --entitlements "$ROOT/Resources/VoiceTyper.entitlements" \
    "$APP"

echo "==> done: $APP"
echo "Run with: open '$APP'  (or '$APP/Contents/MacOS/NeelSpeak' for stdout logs)"
