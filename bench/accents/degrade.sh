#!/bin/bash
# Make harder copies of a group's clips, closer to a laptop dictation than a Common Voice read:
#   <group>-quiet  : 24 dB quieter (a far-off or low-gain mic)
#   <group>-noisy  : pink noise mixed in at about 10 dB SNR (fan, café)
#   <group>-lofi   : 300–3400 Hz band, 8 kHz round trip (Bluetooth headset mic / call quality)
# Usage: degrade.sh au us        (needs ffmpeg; output in audio/, gitignored)
# Then score them like any group: ACCENTS="au-noisy us-noisy" ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
for g in "$@"; do
    for kind in quiet noisy lofi; do
        mkdir -p "audio/$g-$kind"
        for src in audio/"$g"/*.wav; do
            dst="audio/$g-$kind/$(basename "$src")"
            [ -f "$dst" ] && continue
            case $kind in
                quiet) ffmpeg -loglevel error -i "$src" -af "volume=-24dB" -ar 16000 -ac 1 "$dst" ;;
                noisy) ffmpeg -loglevel error -i "$src" -f lavfi -i "anoisesrc=color=pink:amplitude=0.03:seed=7" \
                           -filter_complex "[0:a]loudnorm=I=-23[s];[s][1:a]amix=inputs=2:duration=first:normalize=0" \
                           -ar 16000 -ac 1 "$dst" ;;
                lofi)  ffmpeg -loglevel error -i "$src" -af "highpass=f=300,lowpass=f=3400,aresample=8000,aresample=16000" \
                           -ar 16000 -ac 1 "$dst" ;;
            esac
        done
    done
done
