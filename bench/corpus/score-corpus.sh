#!/bin/bash
# Run every recorded corpus clip through the dev build and score against
# the intended text. Results land in results/<label>/.
#
#   ./score-corpus.sh                     # label defaults to rhino-<engine>
#   ./score-corpus.sh --label rhino-parakeet-v2
#
# Records are made by YOU (see README.md) into audio/<id>.m4a — this script
# only replays them. Uses your real app config (not an isolated HOME): the
# corpus measures the app as configured for daily use.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"

LABEL="${2:-rhino-$(defaults read com.noahkagan.rhino selectedEngine 2>/dev/null || echo default)}"
[ "${1:-}" = "--label" ] && LABEL="$2"

APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
[ -x "$APP" ] || { echo "no dev build — run ./run.sh build first"; exit 1; }
ls audio/*.m4a >/dev/null 2>&1 || { echo "no recordings in audio/ — see README.md"; exit 1; }

OUT="results/$LABEL"
mkdir -p "$OUT"
for clip in audio/*.m4a; do
    id=$(basename "$clip" .m4a)
    [ -f "$OUT/$id.txt" ] && continue
    echo "transcribing $id..."
    "$APP" transcribe "$clip" > "$OUT/$id.txt" 2>/dev/null || echo "(failed)" > "$OUT/$id.txt"
done

python3 score-personal.py "$OUT"
