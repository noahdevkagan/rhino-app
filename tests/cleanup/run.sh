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
# `cleanupOnlyWhenNeeded` is OFF here so the model runs on every case, the
# worst case for fidelity. Never downloads: the suite reuses the model the
# installed Rhino already has, or skips when none is on this machine.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SUITE=com.noahkagan.rhino.gate.cleanup

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
        echo "cleanup SKIPPED: cleanup model not downloaded (download it in Rhino → Settings → Output → Cleanup)"
        exit 0
    fi
fi

mkdir -p .out
defaults delete "$SUITE" >/dev/null 2>&1 || true
defaults write "$SUITE" aiPostProcessingEnabled -bool true
defaults write "$SUITE" smartFormattingEnabled -bool true
defaults write "$SUITE" spokenEditsEnabled -bool true
defaults write "$SUITE" cleanupOnlyWhenNeeded -bool false
defaults write "$SUITE" numberFormattingStyle smart
defaults write "$SUITE" whisperLanguage en
defaults write "$SUITE" saveTranscriptionHistory -bool false

python3 -c 'import json,sys; [print(c["input"]) for c in json.load(open("cases.json"))]' \
    | RHINO_PREFS_SUITE="$SUITE" "$APP" cleanup --stdin > .out/cleanup.json 2> .out/cleanup.log
status=$?
defaults delete "$SUITE" >/dev/null 2>&1 || true
if [ $status -ne 0 ]; then
    echo "cleanup FAIL: CLI exited $status (see tests/cleanup/.out/cleanup.log)"
    exit 1
fi
if grep -q "built-in model not downloaded\|LLM cleanup is off" .out/cleanup.log; then
    echo "cleanup FAIL: the model did not load, so nothing was tested (see tests/cleanup/.out/cleanup.log)"
    exit 1
fi

python3 score.py cases.json .out/cleanup.json .out/cleanup.log
