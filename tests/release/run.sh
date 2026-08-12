#!/bin/bash
# Release automation checks that do not build, sign, tag, push, or publish.
set -euo pipefail
cd "$(dirname "$0")/../.."

echo "release: shell syntax"
bash -n Scripts/bump-release-version.sh
bash -n Scripts/cut-release.sh
bash -n Scripts/release.sh

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

cat > "$fixture_dir/valid.md" <<'EOF'
# Changelog

## Unreleased

## 2.4.1 — 2026-08-11

- Fixed the thing.

## 2.4.0 — 2026-08-10

- Previous release.
EOF

version="$(./Scripts/cut-release.sh --print-version "$fixture_dir/valid.md")"
[ "$version" = "2.4.1" ] \
    || { echo "release FAIL: expected 2.4.1, got $version"; exit 1; }

cat > "$fixture_dir/no-notes.md" <<'EOF'
# Changelog

## 2.4.1 — 2026-08-11

## 2.4.0 — 2026-08-10

- Previous release.
EOF

if ./Scripts/cut-release.sh --print-version "$fixture_dir/no-notes.md" >/dev/null 2>&1; then
    echo "release FAIL: accepted a release heading with no note bullets"
    exit 1
fi

mkdir -p "$fixture_dir/project/Scripts" \
    "$fixture_dir/project/OpenSuperWhisper.xcodeproj"
cp Scripts/bump-release-version.sh "$fixture_dir/project/Scripts/"
cat > "$fixture_dir/project/OpenSuperWhisper.xcodeproj/project.pbxproj" <<'EOF'
MARKETING_VERSION = 2.4.0;
CURRENT_PROJECT_VERSION = 51;
MARKETING_VERSION = 2.4.0;
CURRENT_PROJECT_VERSION = 51;
EOF
"$fixture_dir/project/Scripts/bump-release-version.sh" 2.4.1 >/dev/null
[ "$(grep -c 'MARKETING_VERSION = 2.4.1;' "$fixture_dir/project/OpenSuperWhisper.xcodeproj/project.pbxproj")" = "2" ] \
    || { echo "release FAIL: marketing version was not updated everywhere"; exit 1; }
[ "$(grep -c 'CURRENT_PROJECT_VERSION = 52;' "$fixture_dir/project/OpenSuperWhisper.xcodeproj/project.pbxproj")" = "2" ] \
    || { echo "release FAIL: build number was not advanced exactly once"; exit 1; }
"$fixture_dir/project/Scripts/bump-release-version.sh" 2.4.1 >/dev/null
grep -q 'CURRENT_PROJECT_VERSION = 53;' "$fixture_dir/project/OpenSuperWhisper.xcodeproj/project.pbxproj" \
    && { echo "release FAIL: retry advanced the build number twice"; exit 1; }

if grep -q 'git tag -f' Scripts/release.sh Scripts/cut-release.sh; then
    echo "release FAIL: release tags must never be force-moved"
    exit 1
fi

grep -q 'FORCE_GATE=1 ./Scripts/push-gate.sh' Scripts/release.sh \
    || { echo "release FAIL: local releases can skip the full gate"; exit 1; }

for secret in \
    MACOS_CERT_P12_BASE64 MACOS_CERT_PASSWORD MACOS_DEVELOPER_ID_APP \
    MACOS_TEAM_ID MACOS_NOTARY_APPLE_ID MACOS_NOTARY_PASSWORD \
    SPARKLE_ED_PRIVATE_KEY RELEASES_TOKEN; do
    grep -q "$secret" .github/workflows/release.yml \
        || { echo "release FAIL: CI precheck missing $secret"; exit 1; }
done

echo "release: PASS"
