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

APP="$ROOT/Build/Build/Products/Debug/OpenSuperWhisper.app/Contents/MacOS/OpenSuperWhisper"
if [ ! -x "$APP" ]; then
    echo "asr SKIPPED: no dev build — run ./run.sh build first"
    exit 0
fi

./gen_audio.sh
mkdir -p .out

SCRATCH="$(mktemp -d)"
BUNDLE=fr.my-monkey.opensuperwhisper
HOME="$SCRATCH" defaults write "$BUNDLE" selectedEngine whisper
HOME="$SCRATCH" defaults write "$BUNDLE" selectedWhisperModelPath "$ROOT/ggml-tiny.en.bin"
HOME="$SCRATCH" defaults write "$BUNDLE" aiPostProcessingEnabled -bool false
HOME="$SCRATCH" defaults write "$BUNDLE" saveTranscriptionHistory -bool false

fail=0
run_case() {
    local case=$1 ext=$2; shift 2
    HOME="$SCRATCH" "$APP" transcribe "audio/${case}.${ext}" > ".out/${case}.txt" 2> ".out/${case}.log" || true
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

rm -rf "$SCRATCH"
exit $fail
