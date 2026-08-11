#!/bin/bash
# ASR gate: every case through the real pipeline (the app's own CLI), scored
# by WER. Hermetic: isolated $HOME, the repo's bundled whisper tiny model,
# no downloads. The gate detects REGRESSION — absolute quality is measured
# separately in bench/ with the real shipping models.
#
# FAST=1 runs only `short` + `silence`.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
# Isolated prefs domain: the app reads it via RHINO_PREFS_SUITE — a HOME
# override does NOT isolate defaults (cfprefsd keys by user, not $HOME).
SUITE=com.noahkagan.rhino.gate
defaults delete "$SUITE" >/dev/null 2>&1 || true

# WER thresholds are calibrated on real hardware; virtualized CI runners
# underrun audio pipelines and score far worse (MeetingCoach measured 35%
# vs a 5% bar). Local push gates own this suite; CI loudly skips.
if [ "${CI:-false}" = "true" ]; then
    echo "asr SKIPPED on CI: WER thresholds are only valid on real hardware"
    exit 0
fi

APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
if [ ! -x "$APP" ]; then
    echo "asr SKIPPED: no dev build — run ./run.sh build first"
    exit 0
fi

./gen_audio.sh
mkdir -p .out

defaults write "$SUITE" selectedEngine whisper
defaults write "$SUITE" selectedWhisperModelPath "$ROOT/ggml-tiny.en.bin"
defaults write "$SUITE" aiPostProcessingEnabled -bool false
defaults write "$SUITE" saveTranscriptionHistory -bool false

fail=0
run_case() {
    local case=$1 ext=$2; shift 2
    RHINO_PREFS_SUITE="$SUITE" "$APP" transcribe "audio/${case}.${ext}" > ".out/${case}.txt" 2> ".out/${case}.log" || true
    python3 score.py "$case" ".out/${case}.txt" "$@" || fail=1
}

# short is only 17 words, so one substitution is 5.9% — bar at 7% lets one
# tiny-model miss through (baseline: "lunch"→"launch") and fails at two.
run_case short aiff --max-wer 7
run_case silence wav
if [ "${FAST:-0}" != "1" ]; then
    run_case message aiff
    run_case prose aiff
    run_case technical aiff
fi

defaults delete "$SUITE" >/dev/null 2>&1 || true
exit $fail
