#!/bin/bash
# Builds a signed and notarized MagicClick zip. Pass "publish" to upload it as a GitHub release.
#
# Needs, one time:
#   1. A "Developer ID Application" certificate in your keychain.
#   2. A notarytool login saved as a keychain profile:
#        xcrun notarytool store-credentials notary --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID
#
# SIGN_IDENTITY is required, so a release is never signed with the wrong certificate by mistake:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh
# Set NOTARY_PROFILE if your keychain profile is not called "notary".
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
IDENTITY="${SIGN_IDENTITY:?Set SIGN_IDENTITY to the full name of your Developer ID Application certificate}"
PROFILE="${NOTARY_PROFILE:-notary}"
APP=build/MagicClick.app
ZIP="build/MagicClick-$VERSION.zip"

SIGN_IDENTITY="$IDENTITY" ./scripts/build.sh

echo "Sending to Apple for notarization. This takes a few minutes…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

# Attach the ticket so the app opens offline too, then zip the stapled app.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --verbose=2 "$APP"
echo "Ready: $ZIP"

if [ "${1:-}" = "publish" ]; then
    gh release create "v$VERSION" "$ZIP" --title "MagicClick $VERSION" --notes "Signed and notarized build. Unzip, move MagicClick.app to Applications, open it, and allow Accessibility access when asked."
fi
