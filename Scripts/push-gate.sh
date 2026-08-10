#!/bin/bash
# Push gate: everything that must be true before code leaves this machine.
# Wired up as the pre-push hook (scripts/githooks/pre-push).
#
#   1. Build  — the app compiles / typechecks
#   2. Suites — every tests/*/run.sh passes
#
# Skip in an emergency with: SKIP_GATE=1 git push
# Faster run (suites may honor it to skip slow cases): FAST=1 git push
#
# Keep the whole gate under ~5 minutes, or people will start skipping it.
set -uo pipefail
cd "$(dirname "$0")/.."

# Docs/markdown-only pushes: nothing in them executes, so build + suites
# prove nothing. Short-circuit to keep doc fixes frictionless.
upstream=$(git rev-parse '@{u}' 2>/dev/null)
if [ -n "$upstream" ]; then
    changed=$(git diff --name-only "$upstream"..HEAD)
    if [ -n "$changed" ] && \
       [ -z "$(echo "$changed" | grep -v -e '^docs/' -e '\.md$')" ]; then
        echo "=== push gate PASSED (docs-only push — nothing to test) ==="
        exit 0
    fi
fi

echo "=== push gate ==="
start=$(date +%s)

echo "--- [1/2] build"
./run.sh build || { echo "BUILD FAILED"; exit 1; }

echo "--- [2/2] test suites"
found=0
for runner in tests/*/run.sh; do
    [ -f "$runner" ] || continue
    found=1
    suite=$(basename "$(dirname "$runner")")
    bash "$runner" || { echo "GATE FAILED: tests/$suite"; exit 1; }
done
[ "$found" = "1" ] || echo "(no tests/*/run.sh suites yet)"

echo "=== push gate PASSED in $(( $(date +%s) - start ))s ==="
