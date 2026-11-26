#!/bin/bash
# Quiet-mic copies of a group's clips at fixed attenuations, for the gain / silence work
# (decisions.md 2026-11-25): <group>-q24, -q30, -q36 are 24/30/36 dB quieter than the source
# (a soft talker, a mic across the room, an input-gain slider near the bottom).
# Usage: levels.sh au us     (needs ffmpeg; output in audio/, gitignored)
# Then: CONFIGS="pk-v2 whisper-turbo" ACCENTS="au-q24 au-q30 au-q36" ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
for g in "$@"; do
    for db in ${LEVELS:-24 30 36}; do
        mkdir -p "audio/$g-q$db"
        for src in audio/"$g"/*.wav; do
            dst="audio/$g-q$db/$(basename "$src")"
            [ -f "$dst" ] && continue
            ffmpeg -loglevel error -i "$src" -af "volume=-${db}dB" -ar 16000 -ac 1 -c:a pcm_s16le "$dst"
        done
    done
done
