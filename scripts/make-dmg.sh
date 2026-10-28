#!/bin/bash
# Builds build/MagicClick-<version>.dmg with the app and a link to /Applications.
# Pass "publish" to upload it as a GitHub release for the version in Info.plist.
#
# The app is signed ad hoc unless SIGN_IDENTITY is set. An ad hoc app is not notarized,
# so people must allow it once in System Settings (see README, "First open").
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
DMG="build/MagicClick-$VERSION.dmg"
STAGING=build/dmg

SIGN_IDENTITY="${SIGN_IDENTITY:--}" ./scripts/build.sh

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/MagicClick.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/How to open MagicClick.txt" <<'TEXT'
MagicClick is free and open source, but it is not notarized by Apple.
macOS blocks it the first time. Allow it once like this:

1. Drag MagicClick to the Applications folder.
2. Open MagicClick. macOS says it cannot verify the app. Click "Done".
3. Open System Settings > Privacy & Security.
4. Scroll down to "Security". Next to "MagicClick was blocked", click "Open Anyway".
5. Enter your password, then click "Open Anyway" again.
6. In the MagicClick window, click "Open Accessibility Settings"
   and turn on MagicClick.

Full guide: https://github.com/codeFi/MagicClick#download
TEXT

hdiutil create -volname "MagicClick $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
echo "Ready: $DMG"

if [ "${1:-}" = "publish" ]; then
    gh release create "v$VERSION" "$DMG" --title "MagicClick $VERSION" --notes-file scripts/release-notes.md
fi
