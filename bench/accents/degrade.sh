#!/bin/bash
# Make harder copies of a group's clips, closer to a laptop dictation than a Common Voice read:
#   <group>-quiet  : 24 dB quieter (a far-off or low-gain mic)
#   <group>-quietgain : the quiet copy peak-normalised back to -3 dBFS (what gain normalisation would do)
#   <group>-noisy  : mild pink noise, about 22-25 dB SNR measured (a quiet fan; NOT cafe-level noise)
#   <group>-lofi   : 300–3400 Hz band, 8 kHz round trip (Bluetooth headset mic / call quality)
# Usage: degrade.sh au us        (needs ffmpeg; output in audio/, gitignored)
# Then score them like any group: ACCENTS="au-noisy us-noisy" ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
for g in "$@"; do
    for kind in quiet quietgain noisy lofi; do
        mkdir -p "audio/$g-$kind"
        srcdir="audio/$g"; [ "$kind" = quietgain ] && srcdir="audio/$g-quiet"
        for src in "$srcdir"/*.wav; do
            dst="audio/$g-$kind/$(basename "$src")"
            [ -f "$dst" ] && continue
            case $kind in
                quiet) ffmpeg -loglevel error -i "$src" -af "volume=-24dB" -ar 16000 -ac 1 "$dst" ;;
                quietgain)
                    peak=$(ffmpeg -hide_banner -i "$src" -af volumedetect -f null - 2>&1 |
                               sed -n 's/.*max_volume: \(-\{0,1\}[0-9.]*\) dB.*/\1/p')
                    gain=$(python3 -c "print(round(-3 - ($peak), 2))")
                    ffmpeg -loglevel error -i "$src" -af "volume=${gain}dB" -ar 16000 -ac 1 "$dst" ;;
                noisy) ffmpeg -loglevel error -i "$src" -f lavfi -i "anoisesrc=color=pink:amplitude=0.03:seed=7" \
                           -filter_complex "[0:a]loudnorm=I=-23[s];[s][1:a]amix=inputs=2:duration=first:normalize=0" \
                           -ar 16000 -ac 1 "$dst" ;;
                lofi)  ffmpeg -loglevel error -i "$src" -af "highpass=f=300,lowpass=f=3400,aresample=8000,aresample=16000" \
                           -ar 16000 -ac 1 "$dst" ;;
            esac
        done
    done
done
