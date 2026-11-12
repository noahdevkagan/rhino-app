#!/usr/bin/env python3
"""Score one Parakeet `bench` run against tests/asr/cases/refs.json.

Usage: score.py <version> <bench-json>

Each speech case must stay under its WER bar, `silence` must produce no words,
and every clip must transcribe within the time budget. Bars are per case
because the synthetic voices differ; they were calibrated on an M4 with room
for one extra miss on top of the measured baseline (see BARS).

Prints one line per case plus a `JSON\t{...}` summary; exits nonzero on failure.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "asr"))
from score import wer  # noqa: E402  (shared normalizer: digits, punctuation)

# Max WER % per case. Baseline on an M4 (2026-11-11), v2 and v3 alike: 0% on
# message/prose/technical, and one miss on `short` — the synthetic voice's
# "lunch" reads as "launch", the same miss whisper tiny makes. Each bar allows
# one miss on top of the baseline: one word is 5.9% of `short` (baseline 1 miss,
# so 2 allowed), 3.8% of `message`, 2.2% of `prose`, 2.9% of `technical`.
BARS = {"short": 12.0, "message": 4.0, "prose": 3.0, "technical": 3.0}

# The engine's own inference time per clip ("stages".infer_ms): ~90–150 ms
# here on a debug build. Past this budget the engine fell off its fast path
# (CPU fallback, model recompiled every call), not normal machine noise. Wall
# time ("ms") is not budgeted: the first clip also pays the one-time Core ML
# warm-up (~15 s on a fresh build), which is reported but expected.
MAX_INFER_MS = 1000

# What the engine returns for audio with no speech; the dictation pipeline
# shows a "No speech detected" toast for it instead of typing anything.
NO_SPEECH = "No speech detected in the audio"


def main() -> int:
    version, bench_path = sys.argv[1], Path(sys.argv[2])
    refs = json.loads((HERE.parent / "asr" / "cases" / "refs.json").read_text())
    rows = {Path(r["file"]).stem: r for r in json.loads(bench_path.read_text())}

    fail = False
    summary = {"version": version, "cases": {}}
    for case in list(BARS) + ["silence"]:
        row = rows.get(case)
        if row is None:
            print(f"parakeet {version} {case}: FAIL — no output for this clip")
            fail = True
            continue
        text = row.get("text", "").strip()
        ms = int((row.get("stages") or {}).get("infer_ms", row.get("ms", 0)))
        slow = ms > MAX_INFER_MS
        if case == "silence":
            heard = "" if text == NO_SPEECH else text
            ok = heard == "" and not slow
            print(f"parakeet {version} silence: {'PASS' if ok else 'FAIL'} — "
                  f"{'no words' if not heard else 'hallucinated ' + repr(heard[:80])}")
            summary["cases"][case] = {"words": len(heard.split()), "inferMs": ms}
        else:
            errors, ref_len = wer(refs[case]["text"], text)
            rate = 100.0 * errors / max(ref_len, 1)
            ok = rate <= BARS[case] and not slow
            print(f"parakeet {version} {case}: {'PASS' if ok else 'FAIL'} — "
                  f"WER {rate:.1f}% (max {BARS[case]:.0f}%), {ms} ms inference"
                  + (f" (over {MAX_INFER_MS} ms budget)" if slow else ""))
            if rate > BARS[case]:
                print(f"  hyp: {text[:300]!r}")
            summary["cases"][case] = {"wer": round(rate, 2), "inferMs": ms}
        fail = fail or not ok

    if rows:
        first = min(rows.values(), key=lambda r: r["file"])
        summary["firstClipWallMs"] = int(first.get("ms", 0))
        print(f"parakeet {version}: first clip took {summary['firstClipWallMs']} ms wall "
              "(includes one-time model warm-up; informational)")
    print(f"JSON\t{json.dumps(summary)}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
