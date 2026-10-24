#!/bin/bash
# Packages NeelSpeak.app (from Scripts/build-app.sh) into NeelSpeak.dmg with an
# Applications shortcut. Signs the DMG when SIGN_IDENTITY is set.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/NeelSpeak.app"
DMG="$ROOT/NeelSpeak.dmg"

[ -d "$APP" ] || { echo "NeelSpeak.app not found; run Scripts/build-app.sh first" >&2; exit 1; }

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "NeelSpeak" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG"

if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

shasum -a 256 "$DMG" | sed "s#$ROOT/##" > "$DMG.sha256"
echo "==> done: $DMG"
