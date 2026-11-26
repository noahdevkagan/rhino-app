#!/usr/bin/env python3
"""Score one `bench` run over audio/levels (made by gen_audio.sh / gen_noise.py).

Usage: score_levels.py <label> <bench-json> [--bars quiet-short=PCT,...] [--known clip=TEXT,...]

Three rules, all gate failures:
- Every no-speech clip (noise, hum, clicks, dither, digital silence) must produce NO words. A dead
  or noisy mic typing text into the user's document is the failure this exists to catch.
- Every `quiet-*` clip is real speech at a soft-talker level and must stay under its WER bar
  (and never come back empty). Defaults below; suites pass their own via --bars.
- Every `keep-*` clip is real speech the old peak rule already sent to the engine (low-SNR speech
  in a quiet room, a short word over room tone) and must still come back with words: the quiet-mic
  boost may only rescue, never drop (decisions.md 2026-11-25).

No-speech clips include `far-*` (a talker 42 dB down, a TV in the next room) and `cellos-*`
(macOS's singing voice): the old rule typed nothing for them and the boost must not change that.

--known pins no-speech clips that already typed something before InputLevel (2026-11-25), with
the exact text they type (compared after normalising). The same text is a KNOWN GAP; any other
text fails, so a boost that makes a known gap worse is caught. Remove an entry once it is fixed.
`clip=*` accepts any text: only for real speech the engine's old path already typed (Whisper's VAD
hears `far-speech` and the old peak bail never ran on it), so typing it is not a regression.

--old-gap lists speech clips (`keep-*`, `quiet-*`) this engine already failed on the old path
before 2026-11-25: reported, not failed. `quiet-short` (speech level about -64 dBFS) is one for
every engine: it is as quiet as `far-speech`, and no level rule can rescue one without typing the
other (decisions.md 2026-11-25, revised).

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
    known = {}
    if "--known" in sys.argv:
        for kv in sys.argv[sys.argv.index("--known") + 1].split(","):
            clip, _, pinned = kv.partition("=")
            known[clip] = None if pinned == "*" else norm(pinned)
    old_gap = set()
    if "--old-gap" in sys.argv:
        old_gap = set(sys.argv[sys.argv.index("--old-gap") + 1].split(","))
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
            if not ok and clip in old_gap:
                print(f"{label} levels {clip}: KNOWN GAP — WER {rate:.1f}%"
                      f"{'' if text else ', EMPTY'}, as on the old path")
                summary["quiet"][clip] = round(rate, 2)
                continue
            print(f"{label} levels {clip}: {'PASS' if ok else 'FAIL'} — WER {rate:.1f}% "
                  f"(max {bars[clip]:.0f}%){'' if text else ', came back EMPTY'}")
            if not ok:
                print(f"  hyp: {text[:300]!r}")
            summary["quiet"][clip] = round(rate, 2)
        elif clip.startswith("keep-"):
            ok = bool(norm(text))
            if not ok and clip in old_gap:
                print(f"{label} levels {clip}: KNOWN GAP — EMPTY, as on the old path")
                summary.setdefault("keep", {})[clip] = ""
                continue
            print(f"{label} levels {clip}: {'PASS' if ok else 'FAIL'} — "
                  f"{'typed ' + repr(text[:60]) if ok else 'came back EMPTY (the old rule typed it)'}")
            summary.setdefault("keep", {})[clip] = text[:60]
        else:
            words = norm(text)
            ok = not words
            summary["noiseClips"] += 1
            if words:
                noisy_words += len(words)
                summary["noiseNonEmpty"].append(clip)
            if words and clip in known:
                ok = known[clip] is None or words == known[clip]
                print(f"{label} levels {clip}: {'KNOWN GAP' if ok else 'FAIL (known gap changed)'}"
                      f" — typed {text[:80]!r}, pinned "
                      f"{'any (old path types it)' if known[clip] is None else ' '.join(known[clip])!r}")
            else:
                print(f"{label} levels {clip}: {'PASS — no words' if ok else 'FAIL — typed ' + repr(text[:80])}")
        fail = fail or not ok
    print(f"JSON\t{json.dumps(summary)}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
