#!/bin/bash
# Latency gate: transcription time per clip through the app's own `bench`
# CLI (loads the model once, times each file). Hermetic like tests/asr:
# isolated $HOME, bundled whisper tiny.
#
# Measures ASR wall time only — full hotkey-release→insertion latency has
# human/UI segments and is measured in the manual corpus (bench/corpus).
# Budget: set from measured actuals (see decisions.md), ratcheted down over
# time. The point is catching a 2x regression, not certifying absolute speed.
#
# FAST=1 skips entirely (tests/asr already exercises the pipeline).
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"

if [ "${FAST:-0}" = "1" ]; then
    echo "latency: skipped (FAST=1)"
    exit 0
fi
# Latency budgets describe this machine class, not virtualized CI hardware.
if [ "${CI:-false}" = "true" ]; then
    echo "latency SKIPPED on CI: budgets are only valid on real hardware"
    exit 0
fi

APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
if [ ! -x "$APP" ]; then
    echo "latency SKIPPED: no dev build — run ./run.sh build first"
    exit 0
fi

# Reuse the asr suite's audio (and generate it if this suite runs first).
(cd ../asr && ./gen_audio.sh >/dev/null)
mkdir -p .out
rm -rf .out/clips && mkdir -p .out/clips
# bench mode takes a directory of wavs; convert the aiff cases once.
for f in ../asr/audio/*.aiff; do
    base=$(basename "$f" .aiff)
    [ -f ".out/clips/$base.wav" ] || afconvert -f WAVE -d LEI16@16000 -c 1 "$f" ".out/clips/$base.wav"
done

SCRATCH="$(mktemp -d)"
BUNDLE=com.noahkagan.rhino
HOME="$SCRATCH" defaults write "$BUNDLE" selectedEngine whisper
HOME="$SCRATCH" defaults write "$BUNDLE" selectedWhisperModelPath "$ROOT/ggml-tiny.en.bin"
HOME="$SCRATCH" defaults write "$BUNDLE" aiPostProcessingEnabled -bool false
HOME="$SCRATCH" defaults write "$BUNDLE" saveTranscriptionHistory -bool false

HOME="$SCRATCH" "$APP" bench .out/clips > .out/bench.json 2> .out/bench.log || {
    echo "latency FAIL: bench run crashed (see tests/latency/.out/bench.log)"
    rm -rf "$SCRATCH"; exit 1
}
rm -rf "$SCRATCH"

python3 - <<'PY'
import json, statistics, sys

# Budget for whisper-tiny on committed clips (≤20s speech), this machine
# class. Measured 2026-08-10: p50 393ms / max 861ms — bar sits ~2x above,
# ratchet down as the pipeline gets faster.
BUDGET_P50_MS = 800
BUDGET_MAX_MS = 2000

results = json.load(open(".out/bench.json"))
times = sorted(r["ms"] for r in results)
if not times:
    sys.exit("latency FAIL: bench produced no results")
p50 = statistics.median(times)
worst = max(times)
line = {"p50": round(p50), "max": round(worst), "clips": len(times)}
print(f"JSON\t{json.dumps(line)}")
ok = p50 <= BUDGET_P50_MS and worst <= BUDGET_MAX_MS
print(f"latency: {'PASS' if ok else 'FAIL'} — p50 {p50:.0f}ms (max {worst:.0f}ms) over {len(times)} clips"
      f" [budget p50<={BUDGET_P50_MS} max<={BUDGET_MAX_MS}]")
sys.exit(0 if ok else 1)
PY
