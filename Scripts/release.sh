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

# Website pre-flight, up front on purpose: these same conditions used to be
# checked only in the deploy step, which sits AFTER the gate and ~10 minutes of
# notarization — a stale link meant discovering the block with a DMG already
# published (v0.1.10). Checked per-file: a multi-file `grep -q` passes when ANY
# file matches, which would wave through a half-updated site.
for f in website/app/thanks/page.tsx website/app/appsumo/redeem-form.tsx; do
    grep -q "v$VERSION/Rhino-$VERSION.dmg" "$f" \
        || { echo "RELEASE BLOCKED: $f doesn't link v$VERSION — update the website download links before releasing"; exit 1; }
done
grep -q "\"$VERSION\"" website/app/changelog/page.tsx \
    || { echo "RELEASE BLOCKED: website/app/changelog/page.tsx has no $VERSION entry — add the release notes before releasing"; exit 1; }

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
# verification after downloading. A cut from a machine without the matching
# key must die here, before the feed is touched (decisions.md 2026-08-18).
grep -E "url=\"[^\"]*v$VERSION/[^\"]*\.dmg\"" dist/appcast.xml | grep -q 'sparkle:edSignature="' \
    || { echo "RELEASE BLOCKED: v$VERSION appcast item is unsigned — this Mac's Sparkle key (account Rhino) does not match the app's SUPublicEDKey; see decisions.md 2026-08-18"; exit 1; }

SHA=$(gh api "repos/$RELEASES_REPO/contents/appcast.xml" -q .sha 2>/dev/null || true)
gh api -X PUT "repos/$RELEASES_REPO/contents/appcast.xml" \
    -f message="Appcast for v$VERSION" \
    -f content="$(base64 -i dist/appcast.xml)" ${SHA:+-f sha="$SHA"} >/dev/null
echo "== feed updated"

echo "== website (download links + changelog ship with every release)"
# The site is served by the rhinovoice-website Worker in Noah's Cloudflare
# account (custom domain rhinovoice.app; cutover 2026-08-18). Deploying here
# means AppSumo redeemers and site downloads always get the release just
# published — no separate manual step.
# Re-checked here (already pre-flighted up top) so the deploy can never ship
# stale links even if this script is entered mid-way. Per-file: a multi-file
# `grep -q` passes when ANY file matches.
for f in website/app/thanks/page.tsx website/app/appsumo/redeem-form.tsx; do
    grep -q "v$VERSION/Rhino-$VERSION.dmg" "$f" \
        || { echo "RELEASE BLOCKED: $f doesn't link v$VERSION — update the website download links (+ changelog page/tests)"; exit 1; }
done
(cd website && npm ci --no-audit --no-fund >/dev/null && npm test >/dev/null && npx wrangler deploy -c dist/server/wrangler.json)
curl -fsS --max-time 15 https://rhinovoice.app/thanks | grep -q "Rhino-$VERSION.dmg" \
    || { echo "RELEASE BLOCKED: live site is not serving v$VERSION after deploy"; exit 1; }
echo "== website live at v$VERSION"

git add -A
git -c user.name="Noah Kagan" -c user.email="noahkagan@gmail.com" \
    commit -q -m "Release v$VERSION" || true
git tag "v$VERSION"
echo "== done: v$VERSION shipped. Push with: git push && SKIP_GATE=1 git push origin v$VERSION"
