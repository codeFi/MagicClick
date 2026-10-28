#!/bin/bash
# Builds MagicClick.app into build/. Pass "install" to copy it to ~/Applications and open it.
#
# Signing: set SIGN_IDENTITY to a certificate name from `security find-identity -v -p codesigning`.
# A real certificate keeps the Accessibility permission across rebuilds. Without one the app is
# signed ad hoc, and you must turn the permission off and on again after each rebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/MagicClick.app
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MagicClick"

if [ ! -f Resources/AppIcon.icns ]; then
    swift scripts/make-icon.swift
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MagicClick"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${SIGN_IDENTITY:--}"
codesign --force --options runtime --sign "$IDENTITY" "$APP"
echo "Built $APP (signed with: $IDENTITY)"

if [ "${1:-}" = "install" ]; then
    mkdir -p "$HOME/Applications"
    pkill -x MagicClick 2>/dev/null && sleep 1 || true
    rm -rf "$HOME/Applications/MagicClick.app"
    cp -R "$APP" "$HOME/Applications/MagicClick.app"
    open "$HOME/Applications/MagicClick.app"
    echo "Installed to ~/Applications/MagicClick.app"
fi
