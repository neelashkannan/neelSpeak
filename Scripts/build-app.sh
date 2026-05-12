#!/bin/bash
# Builds NeelSpeak.app from the SPM executable + Info.plist + entitlements.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/NeelSpeak.app"
CONFIG="${CONFIG:-release}"

cd "$ROOT"

echo "==> swift build (-c $CONFIG)"
swift build -c "$CONFIG" --arch arm64

BIN_PATH="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/NeelSpeak" "$APP/Contents/MacOS/NeelSpeak"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> ad-hoc codesign with entitlements"
codesign --force --deep --sign - \
    --entitlements "$ROOT/Resources/VoiceTyper.entitlements" \
    "$APP"

echo "==> done: $APP"
echo "Run with: open '$APP'  (or '$APP/Contents/MacOS/NeelSpeak' for stdout logs)"
