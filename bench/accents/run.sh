#!/bin/bash
# Accent bench: WER + time per engine/model per accent, on real Common Voice speech.
#
#   bench/accents/run.sh                 # every installed config, every group
#   CONFIGS="pk-v2 pk-v3" ACCENTS="au us" bench/accents/run.sh
#
# Needs a dev build (./run.sh build) and the audio (python3 fetch.py, ~40 MB, gitignored).
# Raw ASR only, through the app's own `bench` CLI with an isolated prefs domain: no AI cleanup,
# English pinned (what a new user with an English Mac gets). Never downloads a model: a
# config whose model is missing is skipped. Not a gate suite: it needs network once for audio
# and takes a few minutes. Results land in .out/ and the table prints at the end.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
SUITE=com.noahkagan.rhino.bench.accents
FLUID="$HOME/Library/Application Support/FluidAudio/Models"
WHISPER="$HOME/Library/Application Support/com.noahkagan.rhino/whisper-models"

[ -x "$APP" ] || { echo "no dev build: run ./run.sh build first"; exit 1; }
[ -d audio/au ] || { echo "no audio: run python3 fetch.py first"; exit 1; }

CONFIGS=${CONFIGS:-"pk-v2 pk-v3 whisper-turbo whisper-turbo-q5"}
ACCENTS=${ACCENTS:-"au us gb in nz"}
OUT=${OUT:-.out}
mkdir -p "$OUT"

configure() {  # config -> prefs; returns 1 when its model isn't on this Mac
    defaults delete "$SUITE" >/dev/null 2>&1 || true
    defaults write "$SUITE" whisperLanguage en
    defaults write "$SUITE" aiPostProcessingEnabled -bool false
    defaults write "$SUITE" saveTranscriptionHistory -bool false
    case "$1" in
        pk-v2|pk-v3)
            [ -d "$FLUID/parakeet-tdt-0.6b-${1#pk-}" ] || return 1
            defaults write "$SUITE" selectedEngine fluidaudio
            defaults write "$SUITE" fluidAudioModelVersion "${1#pk-}" ;;
        whisper-turbo|whisper-turbo-q5|whisper-turbo-q8)
            local f=ggml-large-v3-turbo.bin
            [ "$1" = whisper-turbo-q5 ] && f=ggml-large-v3-turbo-q5_0.bin
            [ "$1" = whisper-turbo-q8 ] && f=ggml-large-v3-turbo-q8_0.bin
            [ -f "$WHISPER/$f" ] || return 1
            defaults write "$SUITE" selectedEngine whisper
            defaults write "$SUITE" selectedWhisperModelPath "$WHISPER/$f" ;;
        *) echo "unknown config $1"; return 1 ;;
    esac
}

for c in $CONFIGS; do
    if ! configure "$c"; then echo "$c SKIPPED: model not on this Mac"; continue; fi
    for g in $ACCENTS; do
        echo "running ${c} on ${g}..." >&2
        RHINO_PREFS_SUITE="$SUITE" "$APP" bench "audio/$g" > "$OUT/${c}__${g}.json" 2> "$OUT/${c}__${g}.log" \
            || echo "$c $g FAILED (see $OUT/${c}__${g}.log)"
    done
done
defaults delete "$SUITE" >/dev/null 2>&1 || true
python3 score.py "$OUT" --baseline "${BASELINE:-pk-v2}"
