#!/bin/bash
# Smoke suite (placeholder): proves the gate wiring works end-to-end.
# Replace with the first real check as soon as there is something to check.
set -euo pipefail
cd "$(dirname "$0")"

echo "smoke: repo files present"
for f in ../../AGENTS.md ../../HANDOFF.md ../../CHANGELOG.md; do
    [ -f "$f" ] || { echo "missing $f"; exit 1; }
done
echo "smoke: PASS"
