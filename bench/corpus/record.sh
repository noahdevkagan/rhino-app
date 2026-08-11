#!/bin/bash
# Guided ~3-minute corpus recording. Shows each prompt; you speak it
# naturally (fillers welcome), press Enter to stop, next one appears.
# Re-running skips items that already have audio (delete audio/<id>.m4a
# to redo one).
#
# Uses sox (`rec`) for hands-free terminal recording: brew install sox
set -euo pipefail
cd "$(dirname "$0")"
command -v rec >/dev/null || { echo "needs sox: brew install sox"; exit 1; }
mkdir -p audio

python3 -c "
import json
for it in json.load(open('items.json'))['items']:
    note = f\"   ({it['note']})\" if 'note' in it else ''
    print(f\"{it['id']}\t{it['intended']}{note}\")
" | while IFS=$'\t' read -r id text; do
    [ -f "audio/$id.m4a" ] && { echo "✓ $id already recorded"; continue; }
    echo
    echo "──────────────────────────────────────────────"
    echo "  SAY: $text"
    echo "──────────────────────────────────────────────"
    read -r -p "  Enter to START recording $id... " _
    # 16kHz mono wav; convert to m4a after. rec stops on Ctrl-C... instead
    # record in background and stop on Enter for a smoother loop.
    rec -q -r 16000 -c 1 "audio/$id.wav" &
    RECPID=$!
    read -r -p "  🎙  recording — Enter to STOP... " _
    kill -INT "$RECPID" 2>/dev/null; wait "$RECPID" 2>/dev/null || true
    afconvert -f m4af -d aac "audio/$id.wav" "audio/$id.m4a" && rm "audio/$id.wav"
    echo "  saved audio/$id.m4a"
done

echo
echo "All recorded. Score Rhino with:  ./score-corpus.sh"
echo "Then paste other services' outputs into results/<service>/<id>.txt"
echo "and compare:  python3 score-personal.py results/* "
