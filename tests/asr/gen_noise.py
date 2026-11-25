#!/usr/bin/env python3
"""Synthesise the no-speech set: audio a dictation app must type NOTHING for.

Usage: gen_noise.py <out-dir> [--full] [--speech <16 kHz mono wav>]

Every clip is generated from a fixed seed (pure Python, no downloads, no recordings), so the set
is identical on every machine and nothing binary is committed. All of it is SYNTHETIC: white,
pink and brown noise stand in for room tone / fan / hiss, a 60 Hz series for mains hum, short
decaying noise bursts for keyboard clicks, and a +-1 LSB signal for a dead mic's dither.

Default (gate) set: one clip per kind, at levels on both sides of the old -48 dBFS peak bail.
--full adds every kind at every level (the bench set in decisions.md 2026-11-25).
--speech adds `quiet-after-noise.wav`: two seconds of room tone, then the given speech 30 dB down
(a soft talker who starts late). Unlike the rest it MUST transcribe.

Levels are RMS dBFS unless the name says `pk` (peak dBFS, for impulsive sounds).
"""
import math
import os
import random
import struct
import sys
import wave

SR = 16000


def db(x):
    return 10 ** (x / 20)


def white(n, rng):
    return [rng.gauss(0, 1) for _ in range(n)]


def pink(n, rng):
    # Paul Kellet's refined filter: -3 dB/octave within 0.05 dB above 9 Hz.
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(n):
        w = rng.gauss(0, 1)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out.append(b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362)
        b6 = w * 0.115926
    return out


def brown(n, rng):
    # Leaky integrator of white noise (-6 dB/octave), the rumble of a fan or HVAC.
    y, out = 0.0, []
    for _ in range(n):
        y = 0.995 * y + rng.gauss(0, 1) * 0.1
        out.append(y)
    return out


def hum(n, rng):
    ph = rng.random() * 2 * math.pi
    return [sum(math.sin(2 * math.pi * 60 * k * i / SR + ph * k) / k for k in (1, 2, 3, 5))
            for i in range(n)]


def fan(n, rng):
    # Brown rumble + a little hum + slow (0.5 Hz) blade modulation.
    b, h = brown(n, rng), hum(n, rng)
    return [(b[i] * 3 + h[i] * 0.3) * (1 + 0.2 * math.sin(2 * math.pi * 0.5 * i / SR))
            for i in range(n)]


def keyboard(n, rng):
    # Typing: 4-9 keystrokes a second, each a 10-30 ms decaying noise burst, over faint hiss.
    out = [rng.gauss(0, 1) * 0.002 for _ in range(n)]
    t = int(rng.uniform(0.05, 0.3) * SR)
    while t < n:
        length = int(rng.uniform(0.010, 0.030) * SR)
        amp = rng.uniform(0.5, 1.0)
        for i in range(length):
            if t + i < n:
                out[t + i] += amp * rng.gauss(0, 1) * math.exp(-i / (length / 4))
        t += int(rng.uniform(1 / 9, 1 / 4) * SR)
    return out


def click(n, rng):
    # One pop (a mic bumped, a key release) in otherwise digital silence.
    out = [0.0] * n
    at = n // 2
    for i in range(40):
        out[at + i] = math.exp(-i / 6) * (1 if i % 2 == 0 else -1)
    return out


def burst(n, rng):
    # A 60 ms broadband blip (a cough-length thump, a cable crackle) in faint hiss.
    out = [rng.gauss(0, 1) * 0.001 for _ in range(n)]
    at, length = n // 2, int(0.06 * SR)
    for i in range(length):
        out[at + i] += rng.gauss(0, 1) * math.sin(math.pi * i / length)
    return out


def scale_rms(x, level_db):
    rms = math.sqrt(sum(v * v for v in x) / len(x)) or 1.0
    g = db(level_db) / rms
    return [v * g for v in x]


def scale_peak(x, level_db):
    pk = max(abs(v) for v in x) or 1.0
    g = db(level_db) / pk
    return [v * g for v in x]


def write(path, x):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, round(v * 32767)))) for v in x))


def read(path):
    with wave.open(path) as w:
        assert w.getframerate() == SR and w.getnchannels() == 1 and w.getsampwidth() == 2
        raw = w.readframes(w.getnframes())
    return [v / 32768 for v in struct.unpack(f"<{len(raw) // 2}h", raw)]


# (name, generator, how to level it, gate levels, full levels)
KINDS = [
    ("white", white, "rms", [-65], [-75, -65, -55, -45]),
    ("pink", pink, "rms", [-50], [-75, -65, -55, -45]),
    ("brown", brown, "rms", [-65, -55], [-75, -65, -55, -45]),
    ("hum", hum, "rms", [-60, -45], [-70, -60, -50, -40]),
    ("fan", fan, "rms", [-45], [-65, -55, -45]),
    ("keyboard", keyboard, "pk", [-50, -30], [-50, -40, -30, -20]),
    ("click", click, "pk", [-40, -20], [-40, -20, -6]),
    ("burst", burst, "pk", [-50, -30], [-50, -30, -15]),
]


def main():
    out = sys.argv[1]
    full = "--full" in sys.argv
    speech = sys.argv[sys.argv.index("--speech") + 1] if "--speech" in sys.argv else None
    os.makedirs(out, exist_ok=True)
    seconds = 6 if full else 4
    n = SR * seconds

    def emit(name, x):
        path = os.path.join(out, name + ".wav")
        if not os.path.exists(path):
            write(path, x)

    emit("digital-silence", [0.0] * n)
    # A dead or muted input that still carries the converter's +-1 LSB dither.
    rng = random.Random(1)
    emit("dither-1lsb", [rng.choice((-1, 0, 0, 1)) / 32767 for _ in range(n)])
    for seed, (kind, gen, how, gate, levels) in enumerate(KINDS, start=10):
        for level in (levels if full else gate):
            tag = f"{'pk' if how == 'pk' else 'rms'}{-level}"
            rng = random.Random(seed * 100 - level)
            x = gen(n, rng)
            x = scale_peak(x, level) if how == "pk" else scale_rms(x, level)
            emit(f"{kind}-{tag}", x)

    if speech:
        rng = random.Random(7)
        voice = [v * db(-30) for v in read(speech)]
        tone = scale_rms(pink(2 * SR + len(voice), rng), -70)
        emit("quiet-after-noise", [tone[i] + (voice[i - 2 * SR] if i >= 2 * SR else 0.0)
                                   for i in range(len(tone))])


if __name__ == "__main__":
    main()
