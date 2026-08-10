#!/bin/bash
# Render each refs.json case to audio once (idempotent — existing files are
# kept, so runs are deterministic per machine). Audio is gitignored; the
# reference TEXT in refs.json is the source of truth.
#
# Also writes silence.wav (10s of digital silence) — the hallucination guard.
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
