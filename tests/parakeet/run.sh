#!/bin/bash
# Parakeet gate: the engines users actually dictate with, scored by WER.
#
# tests/asr runs whisper tiny, which catches a broken pipeline but says
# nothing about Parakeet: v2 is what onboarding recommends for English and
# v3 is the default for new installs. This suite runs the same synthetic
# cases (tests/asr/cases/refs.json) through each Parakeet version that is on
# disk, raw ASR only (no cleanup), via the app's `bench` CLI so the model
# loads once and every clip is timed.
#
# Never downloads: a version whose model files are missing is reported as
# SKIPPED (and the suite fails if NO version is installed, so a machine without
# Parakeet can't quietly pass). FAST=1 runs one installed version (v2, else v3).
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SUITE=com.noahkagan.rhino.gate.parakeet

if [ "${CI:-false}" = "true" ]; then
    echo "parakeet SKIPPED on CI: needs the downloaded models and real hardware"
    exit 0
fi

APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
if [ ! -x "$APP" ]; then
    echo "parakeet SKIPPED: no dev build — run ./run.sh build first"
    exit 0
fi

# Same audio as tests/asr (rendered once, gitignored there).
../asr/gen_audio.sh >/dev/null
mkdir -p .out/wav
for src in ../asr/audio/*; do
    name=$(basename "${src%.*}")
    dst=".out/wav/$name.wav"
    # Re-convert when the rendered audio is newer (refs.json changed and was re-rendered).
    [ "$dst" -nt "$src" ] || afconvert -f WAVE -d LEI16@16000 -c 1 "$src" "$dst"
done

MODELS="$HOME/Library/Application Support/FluidAudio/Models"
# Every file the engine needs, so a half-finished download can't make bench fetch the rest
# inside the pre-push hook.
installed() {
    local dir="$MODELS/parakeet-tdt-0.6b-$1" f
    for f in Preprocessor.mlmodelc Encoder.mlmodelc Decoder.mlmodelc parakeet_vocab.json; do
        [ -e "$dir/$f" ] || return 1
    done
    # v3 names its joint model JointDecisionv3.
    ls -d "$dir"/JointDecision*.mlmodelc >/dev/null 2>&1
}

versions=""
for v in v2 v3; do
    if installed "$v"; then
        versions="$versions $v"
    else
        echo "parakeet $v SKIPPED: model not fully downloaded ($MODELS/parakeet-tdt-0.6b-$v)"
    fi
done
if [ -z "$versions" ]; then
    echo "parakeet FAIL: no Parakeet model on this machine — download v2 or v3 in the app (Settings → Model)"
    exit 1
fi
if [ "${FAST:-0}" = "1" ]; then
    versions=$(echo $versions | cut -d' ' -f1)
fi

fail=0
for v in $versions; do
    defaults delete "$SUITE" >/dev/null 2>&1 || true
    defaults write "$SUITE" selectedEngine fluidaudio
    defaults write "$SUITE" fluidAudioModelVersion "$v"
    defaults write "$SUITE" whisperLanguage en
    defaults write "$SUITE" aiPostProcessingEnabled -bool false
    defaults write "$SUITE" saveTranscriptionHistory -bool false

    out=".out/bench-$v.json"
    if ! RHINO_PREFS_SUITE="$SUITE" "$APP" bench .out/wav > "$out" 2> ".out/bench-$v.log"; then
        echo "parakeet $v FAIL: the engine failed to run (model is installed; see tests/parakeet/.out/bench-$v.log)"
        fail=1
        continue
    fi
    python3 score.py "$v" "$out" || fail=1
done
defaults delete "$SUITE" >/dev/null 2>&1 || true
exit $fail
