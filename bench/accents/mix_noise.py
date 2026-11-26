#!/usr/bin/env python3
"""Speech in genuinely loud noise, for the quiet-mic work (decisions.md 2026-11-25).

Usage: mix_noise.py <group> <snr-db> [<attenuation-db>]
Writes audio/<group>-snr<snr>[q<att>]/ : each clip with seeded pink noise mixed in at the given
speech-to-noise ratio (speech RMS over its loud half vs noise RMS), then the whole mix attenuated
by <attenuation-db> (a soft talker in a noisy room). Noise is synthetic (tests/asr/gen_noise.py).
"""
import math
import os
import random
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent.parent / "tests" / "asr"))
from gen_noise import db, pink, read, write  # noqa: E402

group, snr = sys.argv[1], float(sys.argv[2])
att = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
out = HERE / "audio" / (f"{group}-snr{snr:g}" + (f"q{att:g}" if att else ""))
out.mkdir(parents=True, exist_ok=True)
for i, src in enumerate(sorted((HERE / "audio" / group).glob("*.wav"))):
    dst = out / src.name
    if dst.exists():
        continue
    x = read(str(src))
    # Speech level = RMS of the louder half of 20 ms frames (ignores leading/trailing silence).
    frames = sorted((sum(v * v for v in x[j:j + 320]) / 320 for j in range(0, len(x) - 320, 320)))
    loud = frames[len(frames) // 2:] or [1e-9]
    speech_rms = math.sqrt(sum(loud) / len(loud))
    n = pink(len(x), random.Random(1000 + i))
    n_rms = math.sqrt(sum(v * v for v in n) / len(n)) or 1.0
    g = speech_rms * db(-snr) / n_rms
    a = db(-att)
    write(str(dst), [(x[k] + n[k] * g) * a for k in range(len(x))])
