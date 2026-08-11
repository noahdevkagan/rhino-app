#!/bin/bash
# Build a shareable DMG: Release build, Developer ID deep-signed with
# hardened runtime, notarized + stapled (app AND dmg), packaged. Opens
# clean on any Mac, no Gatekeeper prompts.
#
#   ./Scripts/make-test-dmg.sh          → dist/Rhino-<version>-test.dmg
#   NOTARY_PROFILE=rhino by default; set SKIP_NOTARIZE=1 to skip (testers
#   then need System Settings → Privacy & Security → "Open Anyway").
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${DEVELOPER_ID_APP:-Developer ID Application: noah kagan (U433SX7BT8)}"
ENTITLEMENTS="OpenSuperWhisper/OpenSuperWhisper.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-rhino}"

# Credentials: locally the notarytool keychain profile ("rhino"); on CI there
# is no keychain profile, so NOTARY_APPLE_ID/NOTARY_PASSWORD/NOTARY_TEAM_ID
# env vars (from repo secrets) select explicit-credential mode instead.
NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
if [ -n "${NOTARY_APPLE_ID:-}" ]; then
    NOTARY_ARGS=(--apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$NOTARY_TEAM_ID")
fi

# notarytool submit --wait can exit 0 on an Invalid submission; grep the
# status line and dump the log on anything but Accepted (MeetingCoach's
# hardening, ported).
notarize_file() {
    local target="$1"
    local out subid status
    out="$(xcrun notarytool submit "$target" "${NOTARY_ARGS[@]}" --wait 2>&1 | tee /dev/stderr)"
    subid="$(printf '%s\n' "$out" | awk '/^[[:space:]]*id:/ {print $2; exit}')"
    status="$(printf '%s\n' "$out" | awk '/^[[:space:]]*status:/ {print $2}' | tail -1)"
    if [ "$status" != "Accepted" ]; then
        echo "!! Notarization failed (status: ${status:-unknown})" >&2
        [ -n "$subid" ] && xcrun notarytool log "$subid" "${NOTARY_ARGS[@]}" >&2 || true
        exit 1
    fi
}

echo "== build deps (fresh-checkout safe; idempotent on a dev machine)"
./Scripts/prepare-build-deps.sh

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
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"

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

if [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
    echo "== notarize app (a few minutes)"
    ZIP="$(mktemp -d)/Rhino.zip"
    ditto -c -k --keepParent "$APP" "$ZIP"
    notarize_file "$ZIP"
    # Staple the .app itself: users drag it out of the DMG, and an unstapled
    # app fails Gatekeeper offline.
    xcrun stapler staple "$APP"
fi

echo "== dmg"
ln -s /Applications "$STAGE/Applications"
DMG="dist/Rhino-$VERSION-test.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "Rhino" -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
    echo "== notarize dmg"
    notarize_file "$DMG"
    xcrun stapler staple "$DMG"
    spctl -a -t open --context context:primary-signature -vv "$DMG" || true
fi

echo "== done: $DMG"
du -h "$DMG"
