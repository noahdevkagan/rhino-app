#!/bin/bash
# Set the marketing version and advance the shared build number exactly once.
# Kept separate so local and CI-driven release cuts cannot drift.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: bump-release-version.sh <version>}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || { echo "invalid release version: $VERSION"; exit 1; }

python3 - "$VERSION" <<'PY'
import re
import sys

version = sys.argv[1]
path = "OpenSuperWhisper.xcodeproj/project.pbxproj"
with open(path) as handle:
    project = handle.read()

marketing_versions = set(re.findall(r"MARKETING_VERSION = ([^;]+);", project))
build_numbers = set(re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", project))
if len(marketing_versions) != 1:
    raise SystemExit(f"expected one shared marketing version, found {sorted(marketing_versions)}")
if len(build_numbers) != 1:
    raise SystemExit(f"expected one shared build number, found {sorted(build_numbers)}")

current_version = marketing_versions.pop()
current_build = int(build_numbers.pop())
if current_version == version:
    print(f"   marketing {version}, build {current_build} (already set)")
    raise SystemExit(0)

project = re.sub(
    r"MARKETING_VERSION = [^;]+;",
    f"MARKETING_VERSION = {version};",
    project,
)
project = re.sub(
    r"CURRENT_PROJECT_VERSION = \d+;",
    f"CURRENT_PROJECT_VERSION = {current_build + 1};",
    project,
)
with open(path, "w") as handle:
    handle.write(project)
print(f"   marketing {version}, build {current_build + 1}")
PY
