#!/bin/bash
# Changelog-driven, one-command release.
#
#   1. Add the newest "## X.Y.Z" section to CHANGELOG.md.
#   2. Run ./Scripts/cut-release.sh.
#
# The script uses the tag-triggered CI publisher when all of its signing
# secrets are configured. Until then it transparently uses release.sh and the
# signing credentials on this Mac. Both paths finish with one atomic push of
# the release commit and immutable tag to origin/master.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="noahdevkagan/rhino-app"
CHANGELOG="CHANGELOG.md"

die() {
    echo "RELEASE BLOCKED: $*" >&2
    exit 1
}

version_from_changelog() {
    python3 - "$1" <<'PY'
import re
import sys

path = sys.argv[1]
heading = re.compile(r"^##\s+(\d+\.\d+\.\d+)(?:\s|$)")
with open(path) as handle:
    lines = handle.readlines()

for index, line in enumerate(lines):
    match = heading.match(line)
    if not match:
        continue
    notes = []
    for candidate in lines[index + 1:]:
        if candidate.startswith("## "):
            break
        if candidate.strip():
            notes.append(candidate)
    if not any(note.lstrip().startswith("- ") for note in notes):
        raise SystemExit(f"{path}: ## {match.group(1)} needs at least one release-note bullet")
    print(match.group(1))
    raise SystemExit(0)

raise SystemExit(f"{path}: no numbered '## X.Y.Z' release heading found")
PY
}

if [ "${1:-}" = "--print-version" ]; then
    version_from_changelog "${2:-$CHANGELOG}"
    exit 0
fi
[ "$#" -eq 0 ] || die "usage: ./Scripts/cut-release.sh"

VERSION="$(version_from_changelog "$CHANGELOG")" \
    || die "the newest numbered changelog section is not releasable"
TAG="v$VERSION"

command -v git >/dev/null || die "git is required"
command -v gh >/dev/null || die "GitHub CLI (gh) is required"

# A release cut may include a pending changelog edit/commit, but never code or
# unrelated files. Product fixes must already be merged to origin/master.
while IFS= read -r status_line; do
    [ -z "$status_line" ] && continue
    path="${status_line:3}"
    [ "$path" = "$CHANGELOG" ] \
        || die "working tree contains '$path'; commit or stash everything except $CHANGELOG"
done <<EOF
$(git status --porcelain --untracked-files=all)
EOF

echo "== refresh origin/master + tags"
git fetch --quiet origin master --tags
git merge-base --is-ancestor origin/master HEAD \
    || die "this checkout is behind or diverged from origin/master"

outgoing="$(git diff --name-only origin/master..HEAD)"
if [ -n "$outgoing" ] && [ -n "$(printf '%s\n' "$outgoing" | grep -v "^${CHANGELOG}$" || true)" ]; then
    die "unmerged code is ahead of origin/master; merge the fixes before cutting the release"
fi

git show-ref --verify --quiet "refs/tags/$TAG" \
    && die "$TAG already exists; release tags are immutable"

python3 - "$VERSION" "$(git tag --list 'v[0-9]*' | tr '\n' ' ')" <<'PY'
import re
import sys

candidate = tuple(map(int, sys.argv[1].split(".")))
versions = []
for tag in sys.argv[2].split():
    if re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        versions.append(tuple(map(int, tag[1:].split("."))))
if versions and candidate <= max(versions):
    latest = ".".join(map(str, max(versions)))
    raise SystemExit(f"RELEASE BLOCKED: {sys.argv[1]} must be newer than existing v{latest}")
PY

required_secrets="
MACOS_CERT_P12_BASE64
MACOS_CERT_PASSWORD
MACOS_DEVELOPER_ID_APP
MACOS_TEAM_ID
MACOS_NOTARY_APPLE_ID
MACOS_NOTARY_PASSWORD
SPARKLE_ED_PRIVATE_KEY
RELEASES_TOKEN
"
secret_names="$(gh api --paginate "repos/$REPO/actions/secrets" \
    --jq '.secrets[].name' 2>/dev/null || true)"
ci_ready=1
for secret in $required_secrets; do
    printf '%s\n' "$secret_names" | grep -qx "$secret" || ci_ready=0
done

if [ "$ci_ready" = "1" ]; then
    echo "== CI signing secrets found; preparing $TAG"
    # The same website pre-flight release.sh runs locally. The CI path never
    # calls release.sh, so without this an immutable tag gets created for a
    # release the workflow then refuses to deploy.
    for f in website/app/thanks/page.tsx website/app/appsumo/redeem-form.tsx; do
        grep -q "v$VERSION/Rhino-$VERSION.dmg" "$f" \
            || die "$f doesn't link v$VERSION — update the website download links before releasing"
    done
    grep -q "\"$VERSION\"" website/app/changelog/page.tsx \
        || die "website/app/changelog/page.tsx has no $VERSION entry — add the release notes before releasing"
    FORCE_GATE=1 ./Scripts/push-gate.sh
    ./Scripts/bump-release-version.sh "$VERSION"
    git add "$CHANGELOG" OpenSuperWhisper.xcodeproj/project.pbxproj
    if ! git diff --cached --quiet; then
        git -c user.name="Noah Kagan" -c user.email="noahkagan@gmail.com" \
            commit -q -m "Release $TAG"
    fi
    git tag "$TAG"
else
    echo "== CI signing secrets incomplete; publishing $TAG with local credentials"
    ./Scripts/release.sh "$VERSION"
fi

[ "$(git rev-parse "$TAG^{commit}")" = "$(git rev-parse HEAD)" ] \
    || die "$TAG does not point at the release commit"

echo "== push release commit + tag atomically"
# The gate already ran locally and runs again in the tag workflow. Skipping
# the pre-push hook here avoids a third full build while keeping branch+tag
# all-or-nothing.
SKIP_GATE=1 git push --atomic origin \
    "HEAD:refs/heads/master" "refs/tags/$TAG"

if [ "$ci_ready" = "1" ]; then
    echo "== done: $TAG pushed; GitHub Actions is signing and publishing it"
    echo "   https://github.com/$REPO/actions/workflows/release.yml"
else
    echo "== done: $TAG shipped locally and pushed; CI will verify the tag"
fi
