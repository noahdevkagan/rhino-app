#!/bin/bash
# Push gate: everything that must be true before code leaves this machine.
# Wired up as the pre-push hook (Scripts/githooks/pre-push).
#
#   1. Build     — the app compiles / typechecks
#   2. Suites    — every tests/*/run.sh passes (hygiene, asr, latency, …)
#   3. Scorecard — WER/latency vs the previous record (informational)
#
# Skip in an emergency with: SKIP_GATE=1 git push
# Faster run (suites may honor it to skip slow cases): FAST=1 git push
#
# Keep the whole gate under ~5 minutes, or people will start skipping it.
set -uo pipefail
cd "$(dirname "$0")/.."

upstream=$(git rev-parse '@{u}' 2>/dev/null)
if [ -n "$upstream" ] && [ "${FORCE_GATE:-0}" != "1" ]; then
    changed=$(git diff --name-only "$upstream"..HEAD)
    # Bench-record-only pushes skip the gate entirely — the gate itself
    # appends those records, so testing them again would loop forever.
    if [ -n "$changed" ] && \
       [ -z "$(echo "$changed" | grep -v -e '^bench/history\.jsonl$')" ]; then
        echo "=== push gate SKIPPED (outgoing commits touch only bench history) ==="
        exit 0
    fi
    # Docs/markdown-only pushes: nothing in them executes, so build + suites
    # prove nothing. Short-circuit to keep doc fixes frictionless.
    if [ -n "$changed" ] && \
       [ -z "$(echo "$changed" | grep -v -e '^docs/' -e '\.md$')" ]; then
        echo "=== push gate PASSED (docs-only push — nothing to test) ==="
        exit 0
    fi
fi

echo "=== push gate ==="
start=$(date +%s)

echo "--- [1/3] build"
./run.sh build || { echo "BUILD FAILED"; exit 1; }

echo "--- [2/3] test suites"
found=0
for runner in tests/*/run.sh; do
    [ -f "$runner" ] || continue
    found=1
    suite=$(basename "$(dirname "$runner")")
    bash "$runner" || { echo "GATE FAILED: tests/$suite"; exit 1; }
done
[ "$found" = "1" ] || echo "(no tests/*/run.sh suites yet)"

echo "--- [3/3] scorecard (informational)"
python3 bench/scorecard.py --record || true
# Commit the appended record so the trend survives; rides with the next
# push (the record-only skip above keeps that from looping).
if ! git diff --quiet -- bench/history.jsonl 2>/dev/null; then
    git add bench/history.jsonl
    git commit -q -m "Gate benchmark record for $(git rev-parse --short HEAD)" -- bench/history.jsonl || true
fi

echo "=== push gate PASSED in $(( $(date +%s) - start ))s ==="
