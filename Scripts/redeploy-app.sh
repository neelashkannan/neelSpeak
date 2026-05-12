#!/bin/bash
# Freshly redeploys NeelSpeak to /Applications and clears stale local permission rows.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="NeelSpeak"
BUNDLE_ID="com.neelspeak.app"
OLD_BUNDLE_ID="com.voicetyper.app"
DEST="/Applications/$APP_NAME.app"

cd "$ROOT"

echo "==> stopping old app processes"
pkill -x "$APP_NAME" 2>/dev/null || true
pkill -x "VoiceTyper" 2>/dev/null || true

echo "==> resetting stale macOS permission rows"
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null || true
tccutil reset Accessibility "$OLD_BUNDLE_ID" 2>/dev/null || true
tccutil reset Microphone "$OLD_BUNDLE_ID" 2>/dev/null || true

echo "==> clearing app preferences"
defaults delete "$BUNDLE_ID" 2>/dev/null || true
defaults delete "$OLD_BUNDLE_ID" 2>/dev/null || true

echo "==> removing old app copies"
rm -rf "$DEST" \
       "$HOME/Applications/$APP_NAME.app" \
       "$HOME/Applications/VoiceTyper.app" \
       "$ROOT/$APP_NAME.app" \
       "$ROOT/VoiceTyper.app"

echo "==> staging Parakeet model for NeelSpeak"
"$ROOT/Scripts/stage-parakeet.sh" || true

echo "==> building app bundle"
"$ROOT/Scripts/build-app.sh"

echo "==> installing fresh app to $DEST"
rm -rf "$DEST"
cp -R "$ROOT/$APP_NAME.app" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
codesign --verify --deep --strict "$DEST"

echo "==> launching $DEST"
open "$DEST"

echo "==> done"
echo "Enable Microphone and Accessibility for: $DEST"
