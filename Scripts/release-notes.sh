#!/bin/bash
# Print one version's Markdown release notes from CHANGELOG.md.
# Sparkle consumes this output as Rhino-<version>.md beside the release DMG.
set -euo pipefail

VERSION="${1:?usage: release-notes.sh <version> [changelog]}"
CHANGELOG="${2:-CHANGELOG.md}"

python3 - "$VERSION" "$CHANGELOG" <<'PY'
import re
import sys

version, path = sys.argv[1:]
if re.fullmatch(r"\d+\.\d+\.\d+", version) is None:
    raise SystemExit(f"invalid release version: {version}")

heading = re.compile(rf"^##\s+{re.escape(version)}(?:\s|$)")
with open(path, encoding="utf-8") as changelog:
    lines = changelog.readlines()

start = next((index + 1 for index, line in enumerate(lines) if heading.match(line)), None)
if start is None:
    raise SystemExit(f"{path}: no '## {version}' release heading")

notes = []
for line in lines[start:]:
    if line.startswith("## "):
        break
    notes.append(line.rstrip())

while notes and not notes[0]:
    notes.pop(0)
while notes and not notes[-1]:
    notes.pop()

if not any(line.lstrip().startswith("- ") for line in notes):
    raise SystemExit(f"{path}: ## {version} needs at least one release-note bullet")

print("\n".join(notes))
PY
