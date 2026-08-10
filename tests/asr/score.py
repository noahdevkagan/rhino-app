#!/usr/bin/env python3
"""Score one ASR case: word error rate of the hypothesis against refs.json.

Usage: score.py <case> <hypothesis-file> [--max-wer PCT]

Chunking and punctuation vary run to run, so the gate scores normalized WER
over the whole transcript — never exact text. `silence` is special-cased:
any word at all is a hallucination and fails.

Prints a `JSON\t{...}` line (machine-readable) plus a human verdict; exits
nonzero on failure. bench/scorecard.py reuses wer()/norm() by import.
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent

# The model emits digit forms; refs are written the way a person would say
# them. Fold hypothesis digits back to words before scoring.
NUMBER_FORMS = {
    "fifty percent": "50%",
    "ten": "10",
    "thursday": "thursday",
}


def norm(s: str) -> list[str]:
    s = s.lower()
    for words, digits in NUMBER_FORMS.items():
        s = s.replace(digits.lower(), words)
    s = re.sub(r"[^\w\s]", " ", s)
    return s.split()


def wer(ref: str, hyp: str) -> tuple[int, int]:
    """(edit distance, reference length) over normalized words."""
    r, h = norm(ref), norm(hyp)
    d = [[0] * (len(h) + 1) for _ in range(len(r) + 1)]
    for i in range(len(r) + 1):
        d[i][0] = i
    for j in range(len(h) + 1):
        d[0][j] = j
    for i in range(1, len(r) + 1):
        for j in range(1, len(h) + 1):
            cost = 0 if r[i - 1] == h[j - 1] else 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
    return d[len(r)][len(h)], len(r)


def main() -> int:
    case = sys.argv[1]
    hyp_path = Path(sys.argv[2])
    max_wer = 5.0
    if "--max-wer" in sys.argv:
        max_wer = float(sys.argv[sys.argv.index("--max-wer") + 1])

    hyp = hyp_path.read_text().strip() if hyp_path.exists() else ""

    if case == "silence":
        words = norm(hyp)
        ok = len(words) == 0
        print(f"JSON\t{json.dumps({'case': case, 'hallucinatedWords': len(words)})}")
        print(f"asr {case}: {'PASS — no hallucination' if ok else 'FAIL — hallucinated: ' + hyp[:120]!r}")
        return 0 if ok else 1

    refs = json.loads((HERE / "cases" / "refs.json").read_text())
    ref = refs[case]["text"]
    errors, ref_len = wer(ref, hyp)
    rate = 100.0 * errors / max(ref_len, 1)
    ok = rate <= max_wer
    print(f"JSON\t{json.dumps({'case': case, 'wer': round(rate, 2), 'errors': errors, 'refWords': ref_len})}")
    print(f"asr {case}: {'PASS' if ok else 'FAIL'} — WER {rate:.1f}% (max {max_wer:.0f}%)")
    if not ok:
        print(f"  hyp: {hyp[:300]!r}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
