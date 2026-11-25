#!/bin/bash
# Render each refs.json case to audio once (idempotent — existing files are
# kept, so runs are deterministic per machine). Audio is gitignored; the
# reference TEXT in refs.json is the source of truth.
#
# Also writes silence.wav (10s of digital silence) — the hallucination guard — and the
# levels/ set (decisions.md 2026-11-25): synthetic noise, clicks and dead-mic audio that must
# produce nothing, plus quiet copies of the speech that must still transcribe.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p audio

python3 - <<'PY'
import json, os, subprocess, struct, wave

refs = json.load(open("cases/refs.json"))
for key, spec in refs.items():
    out = f"audio/{key}.aiff"
    if os.path.exists(out):
        continue
    cmd = ["say", "-v", spec["voice"], "-o", out]
    if "rate" in spec:
        cmd += ["-r", str(spec["rate"])]
    subprocess.run(cmd + [spec["text"]], check=True)
    print(f"rendered {out}")

# 10 seconds of 16kHz mono digital silence. A dictation app must produce
# NOTHING from it — Whisper famously hallucinates ("Thank you.") on silence.
out = "audio/silence.wav"
if not os.path.exists(out):
    with wave.open(out, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
        w.writeframes(struct.pack("<h", 0) * 16000 * 10)
    print(f"rendered {out}")
PY

# levels/: every file is derived from the rendered speech or synthesised from a fixed seed.
mkdir -p audio/.tmp
[ -f audio/.tmp/short.wav ] || afconvert -f WAVE -d LEI16@16000 -c 1 audio/short.aiff audio/.tmp/short.wav
[ -f audio/.tmp/message.wav ] || afconvert -f WAVE -d LEI16@16000 -c 1 audio/message.aiff audio/.tmp/message.wav
# Short words, a whisper and a sung line, rendered by macOS `say` (nothing downloaded).
render() {  # name voice text
    [ -f "audio/.tmp/$1.wav" ] && return
    say -v "$2" -o "audio/.tmp/$1.aiff" "$3" && afconvert -f WAVE -d LEI16@16000 -c 1 "audio/.tmp/$1.aiff" "audio/.tmp/$1.wav"
}
render hi Samantha "Hi."
render okay Samantha "Okay."
render sure Daniel "Sure."
render whisper Whisper "Send it to me tomorrow."
render cellos Cellos "We will send the draft before lunch and review it on the plane."
python3 gen_noise.py audio/levels --speech audio/.tmp/short.wav \
    --lowsnr audio/.tmp/short.wav --far audio/.tmp/message.wav --cellos audio/.tmp/cellos.wav \
    --words audio/.tmp/hi.wav,audio/.tmp/okay.wav,audio/.tmp/sure.wav,audio/.tmp/whisper.wav
python3 - <<'PY'
import os, sys
sys.path.insert(0, ".")
from gen_noise import read, write, db
# Soft talkers, scaled by PEAK: quiet-short sits under the old -48 dBFS bail (it used to come
# back empty), quiet-message above it (it used to lose words).
for name, src, peak_db in (("quiet-short", "short", -54), ("quiet-message", "message", -40)):
    out = f"audio/levels/{name}.wav"
    if os.path.exists(out):
        continue
    x = read(f"audio/.tmp/{src}.wav")
    g = db(peak_db) / max(abs(v) for v in x)
    write(out, [v * g for v in x])
    print(f"rendered {out}")
PY
