#!/bin/bash
# Build a shareable test DMG: Release build, Developer ID deep-signed with
# hardened runtime, packaged. NOT notarized (testers click through one
# Gatekeeper prompt: System Settings → Privacy & Security → "Open Anyway").
# The release pipeline will add notarization on top of this exact flow.
#
#   ./Scripts/make-test-dmg.sh          → dist/Rhino-<version>-test.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${DEVELOPER_ID_APP:-Developer ID Application: noah kagan (U433SX7BT8)}"
ENTITLEMENTS="OpenSuperWhisper/OpenSuperWhisper.entitlements"

echo "== release build"
xcodebuild -scheme OpenSuperWhisper -configuration Release -derivedDataPath build \
  -clonedSourcePackagesDirPath SourcePackages -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation -quiet \
  CODE_SIGNING_ALLOWED=NO build

APP_SRC="build/Build/Products/Release/Rhino.app"
[ -d "$APP_SRC" ] || { echo "no Release app at $APP_SRC"; exit 1; }

VERSION=$(defaults read "$(pwd)/$APP_SRC/Contents/Info" CFBundleShortVersionString)
STAGE="$(mktemp -d)/Rhino"
mkdir -p "$STAGE" dist
cp -R "$APP_SRC" "$STAGE/Rhino.app"
APP="$STAGE/Rhino.app"

echo "== deep sign (inside-out; notarization-shaped even though we skip it)"
SIGN=(codesign --force --timestamp --options runtime --sign "$IDENTITY")

# Sparkle's nested helpers must be signed individually, deepest first.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
    "${SIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
    "${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
    "${SIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
    "${SIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
    "${SIGN[@]}" "$SPARKLE"
fi
# Any other frameworks/dylibs, deepest first.
find "$APP/Contents/Frameworks" -depth \( -name "*.dylib" -o -name "*.framework" \) \
    ! -path "*Sparkle.framework*" 2>/dev/null | while read -r item; do
    "${SIGN[@]}" "$item"
done
# The app last, with entitlements.
"${SIGN[@]}" --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict "$APP"
echo "   signed & verified"

echo "== dmg"
ln -s /Applications "$STAGE/Applications"
DMG="dist/Rhino-$VERSION-test.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "Rhino" -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
echo "== done: $DMG"
du -h "$DMG"
