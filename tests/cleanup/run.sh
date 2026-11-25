#!/bin/bash
# Cleanup gate: the LLM pass users get, scored for fidelity AND effect.
#
# Feeds fixed transcripts (cases.json) through the app's real cleanup path
# (`Rhino cleanup --stdin`: spoken punctuation, spoken edits, the model pass,
# every guard, number formatting, message layout) with the shipped model.
# score.py then checks two directions, because the guards make one-sided
# tests meaningless: a broken model whose output the guards reject still
# returns the transcript untouched, which would pass any "did no harm" check.
#   - fidelity: no spoken content words lost, none invented, required
#     phrases kept (the harmful rewrites from docs/performance-audit-2026-10-05.md)
#   - effect: lists become lists, spoken edits get applied, messages get laid out
#
# Light tidy runs with `cleanupOnlyWhenNeeded` OFF and spoken edits ON so the model runs on
# every case, the worst case for fidelity. Polished runs with both left at the user defaults
# (on / off): Polished itself must force the model and spoken edits, and this proves it does. Never downloads: the suite reuses the model the
# installed Rhino already has, or skips when none is on this machine.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
# One suite per run: worktrees run this gate side by side, and a shared suite gets
# deleted by the other run halfway through this one.
SUITE=com.noahkagan.rhino.gate.cleanup.$$
# An interrupted run must not leave its per-run suite behind.
cleanup_suite() {
    defaults delete "$SUITE" >/dev/null 2>&1 || true
    rm -f "$HOME/Library/Preferences/$SUITE.plist"
}
trap cleanup_suite EXIT
trap 'cleanup_suite; exit 130' INT TERM

if [ "${CI:-false}" = "true" ]; then
    echo "cleanup SKIPPED on CI: needs the 1 GB cleanup model and real hardware"
    exit 0
fi
if [ "${FAST:-0}" = "1" ]; then
    echo "cleanup SKIPPED (FAST=1): ~15 s of model inference"
    exit 0
fi

APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
if [ ! -x "$APP" ]; then
    echo "cleanup SKIPPED: no dev build — run ./run.sh build first"
    exit 0
fi

# The dev build (com.noahkagan.rhino.dev) looks for the model in its own
# Application Support folder. Point it at the copy the installed app already
# downloaded instead of fetching another 1 GB.
MODEL=qwen2.5-1.5b-instruct-q4_k_m.gguf
SUPPORT="$HOME/Library/Application Support"
DEV_MODEL="$SUPPORT/com.noahkagan.rhino.dev/llm-models/$MODEL"
if [ ! -e "$DEV_MODEL" ]; then
    if [ -f "$SUPPORT/com.noahkagan.rhino/llm-models/$MODEL" ]; then
        mkdir -p "$(dirname "$DEV_MODEL")"
        ln -s "$SUPPORT/com.noahkagan.rhino/llm-models/$MODEL" "$DEV_MODEL"
        echo "cleanup: linked the installed app's model into Rhino Dev"
    else
        # Fail, like tests/parakeet: a machine without the model must not pass the gate untested.
        echo "cleanup FAIL: cleanup model not downloaded (download it in Rhino → Settings → Output → Cleanup, or FAST=1 to skip)"
        exit 1
    fi
fi

mkdir -p .out

# Two passes. "Light tidy" (level 2) runs cases.json with today's prefs. "Polished" (level 3)
# runs cases.json again, so instruction-bait and question-bait must still pass through
# unanswered, plus cases-polished.json. A case's optional "polished" object overrides its
# fields for the level-3 pass. LEVEL=2 or LEVEL=3 runs one pass only.
python3 - <<'PY'
import json
base = json.load(open("cases.json"))
extra = json.load(open("cases-polished.json"))
level3 = []
for c in base + extra:
    c = dict(c)
    c.update(c.pop("polished", {}))
    level3.append(c)
json.dump(level3, open(".out/cases-level3.json", "w"), indent=1)
PY

run_pass() {  # name cases-file polish(true|false)
    local name=$1 cases=$2 polish=$3
    defaults delete "$SUITE" >/dev/null 2>&1 || true
    defaults write "$SUITE" aiPostProcessingEnabled -bool true
    defaults write "$SUITE" smartFormattingEnabled -bool true
    if [ "$polish" = "false" ]; then
        defaults write "$SUITE" spokenEditsEnabled -bool true
        defaults write "$SUITE" cleanupOnlyWhenNeeded -bool false
    fi
    defaults write "$SUITE" cleanupPolishEnabled -bool "$polish"
    defaults write "$SUITE" numberFormattingStyle smart
    defaults write "$SUITE" whisperLanguage en
    defaults write "$SUITE" saveTranscriptionHistory -bool false
    # A record of what the pass ran with.
    defaults read "$SUITE" > ".out/$name.prefs" 2>&1

    python3 -c 'import json,sys; [print(c["input"]) for c in json.load(open(sys.argv[1]))]' "$cases" \
        | RHINO_PREFS_SUITE="$SUITE" "$APP" cleanup --stdin > ".out/$name.json" 2> ".out/$name.log"
    local status=$?
    cleanup_suite
    if [ $status -ne 0 ]; then
        echo "cleanup FAIL ($name): CLI exited $status (see tests/cleanup/.out/$name.log)"
        return 1
    fi
    if grep -q "built-in model not downloaded\|LLM cleanup is off" ".out/$name.log"; then
        echo "cleanup FAIL ($name): the model did not load, so nothing was tested (see tests/cleanup/.out/$name.log)"
        return 1
    fi
    echo "== $name =="
    python3 score.py "$cases" ".out/$name.json" ".out/$name.log"
}

fail=0
if [ "${LEVEL:-both}" != "3" ]; then
    run_pass cleanup cases.json false || fail=1
fi
if [ "${LEVEL:-both}" != "2" ]; then
    run_pass polished .out/cases-level3.json true || fail=1
fi
exit $fail
