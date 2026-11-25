#!/usr/bin/env python3
"""Score one `bench` run over audio/levels (made by gen_audio.sh / gen_noise.py).

Usage: score_levels.py <label> <bench-json> [--bars quiet-short=PCT,...] [--known clip,clip]

Two rules, both gate failures:
- Every no-speech clip (noise, hum, clicks, dither, digital silence) must produce NO words. A dead
  or noisy mic typing text into the user's document is the failure this exists to catch.
- Every `quiet-*` clip is real speech at a soft-talker level and must stay under its WER bar
  (and never come back empty). Defaults below; suites pass their own via --bars.

--known lists no-speech clips that already typed something before InputLevel (2026-11-25) and
still do, because they reach the engine unchanged: reported as KNOWN GAP, not a failure, so the gate
still fails on any new one. Remove a clip from the list once it is fixed.

Prints one line per clip and a `JSON\t{...}` summary; exits nonzero on failure.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from score import norm, wer  # noqa: E402

NO_SPEECH = "No speech detected in the audio"
# quiet-* clip -> the refs.json case it was made from.
SOURCES = {"quiet-short": "short", "quiet-message": "message", "quiet-after-noise": "short"}
BARS = {"quiet-short": 12.0, "quiet-message": 8.0, "quiet-after-noise": 12.0}


def main() -> int:
    label, bench = sys.argv[1], Path(sys.argv[2])
    bars = dict(BARS)
    if "--bars" in sys.argv:
        for kv in sys.argv[sys.argv.index("--bars") + 1].split(","):
            k, v = kv.split("=")
            bars[k] = float(v)
    known = set()
    if "--known" in sys.argv:
        known = set(sys.argv[sys.argv.index("--known") + 1].split(","))
    refs = json.loads((HERE / "cases" / "refs.json").read_text())
    rows = {Path(r["file"]).stem: r for r in json.loads(bench.read_text() or "[]")}
    expected = sorted(p.stem for p in (HERE / "audio" / "levels").glob("*.wav"))

    fail = False
    noisy_words = 0
    summary = {"label": label, "quiet": {}, "noiseClips": 0, "noiseNonEmpty": []}
    for clip in expected:
        row = rows.get(clip)
        if row is None:
            print(f"{label} levels {clip}: FAIL — no output for this clip")
            fail = True
            continue
        text = row.get("text", "").strip()
        text = "" if text == NO_SPEECH else text
        if clip in SOURCES:
            errors, n = wer(refs[SOURCES[clip]]["text"], text)
            rate = 100.0 * errors / max(n, 1)
            ok = bool(text) and rate <= bars[clip]
            print(f"{label} levels {clip}: {'PASS' if ok else 'FAIL'} — WER {rate:.1f}% "
                  f"(max {bars[clip]:.0f}%){'' if text else ', came back EMPTY'}")
            if not ok:
                print(f"  hyp: {text[:300]!r}")
            summary["quiet"][clip] = round(rate, 2)
        else:
            words = norm(text)
            ok = not words
            summary["noiseClips"] += 1
            if words:
                noisy_words += len(words)
                summary["noiseNonEmpty"].append(clip)
            if words and clip in known:
                print(f"{label} levels {clip}: KNOWN GAP — typed {text[:80]!r}")
                ok = True
            else:
                print(f"{label} levels {clip}: {'PASS — no words' if ok else 'FAIL — typed ' + repr(text[:80])}")
        fail = fail or not ok
    print(f"JSON\t{json.dumps(summary)}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
