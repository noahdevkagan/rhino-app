#!/bin/bash
# One-command release: every improvement can ship.
#
#   ./Scripts/release.sh 0.1.1
#
# Gate → version bump → notarized DMG → GitHub release (public
# rhino-releases repo) → signed Sparkle appcast → installed apps
# auto-update. Requires: a "## <version>" section in CHANGELOG.md,
# notarytool profile "rhino", Sparkle key (keychain account "Rhino").
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>}"
RELEASES_REPO="noahdevkagan/rhino-releases"
ARCHIVE="dist/releases"   # accumulates every shipped DMG; appcast spans them

grep -qE "^##[[:space:]]+${VERSION}([^0-9.]|$)" CHANGELOG.md \
    || { echo "RELEASE BLOCKED: no '## $VERSION' section in CHANGELOG.md"; exit 1; }
git show-ref --verify --quiet "refs/tags/v$VERSION" \
    && { echo "RELEASE BLOCKED: v$VERSION already exists; release tags are immutable"; exit 1; }
if git ls-remote --exit-code --tags origin "refs/tags/v$VERSION" >/dev/null 2>&1; then
    echo "RELEASE BLOCKED: v$VERSION already exists on origin; release tags are immutable"
    exit 1
fi

echo "== gate"
FORCE_GATE=1 ./Scripts/push-gate.sh

echo "== version $VERSION"
./Scripts/bump-release-version.sh "$VERSION"

echo "== notarized dmg"
./Scripts/make-test-dmg.sh
mkdir -p "$ARCHIVE"
rm -f "$ARCHIVE"/*.dmg "$ARCHIVE"/*.md  # only this release; history merges from the feed
DMG="$ARCHIVE/Rhino-$VERSION.dmg"
mv "dist/Rhino-$VERSION-test.dmg" "$DMG"
NOTES_FILE="$ARCHIVE/Rhino-$VERSION.md"
./Scripts/release-notes.sh "$VERSION" > "$NOTES_FILE"

echo "== publish to $RELEASES_REPO"
NOTES="$(cat "$NOTES_FILE")"
gh release create "v$VERSION" "$DMG" --repo "$RELEASES_REPO" \
    --title "Rhino $VERSION" --notes "$NOTES" \
    || gh release upload "v$VERSION" "$DMG" --repo "$RELEASES_REPO" --clobber

echo "== appcast (existing items preserved; new item gets this tag's URL)"
# generate_appcast merges into an existing -o file, so prior releases keep
# their own per-tag URLs while the archive dir only ever holds the new DMG.
curl -fsSL "https://raw.githubusercontent.com/$RELEASES_REPO/main/appcast.xml" \
    -o dist/appcast.xml 2>/dev/null || rm -f dist/appcast.xml
SPARKLE_BIN=$(find SourcePackages/artifacts -type d -name bin -path "*parkle*" | head -1)
# Key via temp file: generate_appcast can't read generate_keys' keychain item
# from a shell (per-binary keychain ACLs), so export-sign-shred each run.
KEYFILE="$(mktemp -u)"
"$SPARKLE_BIN/generate_keys" -x "$KEYFILE" --account Rhino
"$SPARKLE_BIN/generate_appcast" --ed-key-file "$KEYFILE" --embed-release-notes \
    --download-url-prefix "https://github.com/$RELEASES_REPO/releases/download/v$VERSION/" \
    -o dist/appcast.xml "$ARCHIVE"
rm -f "$KEYFILE"
grep -q '<description[^>]*sparkle:format="markdown"' dist/appcast.xml \
    || { echo "RELEASE BLOCKED: Sparkle appcast is missing embedded changelog notes"; exit 1; }
# generate_appcast only WARNS when the keychain key doesn't match the app's
# SUPublicEDKey and then emits the item unsigned — installed apps would fail
# verification after downloading. The signing key lives only on the laptop
# (decisions.md 2026-08-11), so a desktop cut must die here, before the feed
# is touched.
grep -E "url=\"[^\"]*v$VERSION/[^\"]*\.dmg\"" dist/appcast.xml | grep -q 'sparkle:edSignature="' \
    || { echo "RELEASE BLOCKED: v$VERSION appcast item is unsigned — this Mac's Sparkle key does not match the app's SUPublicEDKey (sign on the laptop; see decisions.md 2026-08-11)"; exit 1; }

SHA=$(gh api "repos/$RELEASES_REPO/contents/appcast.xml" -q .sha 2>/dev/null || true)
gh api -X PUT "repos/$RELEASES_REPO/contents/appcast.xml" \
    -f message="Appcast for v$VERSION" \
    -f content="$(base64 -i dist/appcast.xml)" ${SHA:+-f sha="$SHA"} >/dev/null
echo "== feed updated"

git add -A
git -c user.name="Noah Kagan" -c user.email="noahkagan@gmail.com" \
    commit -q -m "Release v$VERSION" || true
git tag "v$VERSION"
echo "== done: v$VERSION shipped. Push with: git push && SKIP_GATE=1 git push origin v$VERSION"
