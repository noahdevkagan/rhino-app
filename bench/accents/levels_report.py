#!/usr/bin/env python3
"""Before/after table for the quiet-mic work (decisions.md 2026-11-25).

Usage: levels_report.py <before-dir> <after-dir>

Each dir holds run.sh output (`<config>__<group>.json`). For every speech group: corpus WER and
the number of clips that came back empty, before and after. For the `noise` group (made by
tests/asr/gen_noise.py --full): how many no-speech clips produced any text, and which.
`quiet-after-noise` in that group is speech and is reported separately.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from score import NO_SPEECH, edits, norm, load  # noqa: E402

SPEECH_IN_NOISE = "quiet-after-noise"
SHORT_REF = "Can you send me the latest draft before lunch? I want to review it on the plane."


def text(row):
    t = row.get("text", "").strip()
    return "" if t == NO_SPEECH else t


def speech(dirpath):
    _, data = load(Path(dirpath))
    out = {}
    for config, groups in data.items():
        for g, rows in groups.items():
            if not rows:
                continue
            e = sum(r[1] for r in rows)
            n = sum(r[2] for r in rows)
            empty = sum(1 for r in rows if not r[5].strip())
            out[(config, g)] = (100 * e / max(n, 1), empty, len(rows))
    return out


def noise(dirpath):
    out = {}
    for f in Path(dirpath).glob("*__noise.json"):
        config = f.stem.rsplit("__", 1)[0]
        rows = json.loads(f.read_text() or "[]")
        heard = {Path(r["file"]).stem: text(r) for r in rows}
        tail = heard.pop(SPEECH_IN_NOISE, None)
        out[config] = (heard, tail)
    return out


def main():
    before, after = sys.argv[1], sys.argv[2]
    sb, sa = speech(before), speech(after)
    print("| Config | Group | Clips | WER before | WER after | Empty before | Empty after |")
    print("|---|---|---|---|---|---|---|")
    for key in sorted(set(sb) | set(sa)):
        b, a = sb.get(key), sa.get(key)
        fmt = lambda v, i: "-" if v is None else (f"{v[i]:.1f}%" if i == 0 else str(v[i]))
        clips = (a or b)[2]
        print(f"| {key[0]} | {key[1]} | {clips} | {fmt(b, 0)} | {fmt(a, 0)} | {fmt(b, 1)} | {fmt(a, 1)} |")

    nb, na = noise(before), noise(after)
    print("\n| Config | No-speech clips | Typed words before | Typed words after | Punctuation-only before / after | quiet-after-noise before / after |")
    print("|---|---|---|---|---|---|")
    for config in sorted(set(nb) | set(na)):
        hb, tb = nb.get(config, ({}, None))
        ha, ta = na.get(config, ({}, None))
        # A clip "typed something" when it produced any word; a bare "." is reported but not counted.
        bad_b = {k: v for k, v in hb.items() if norm(v)}
        bad_a = {k: v for k, v in ha.items() if norm(v)}
        dots_b = sum(1 for v in hb.values() if v and not norm(v))
        dots_a = sum(1 for v in ha.values() if v and not norm(v))

        def tail(t):
            if t is None:
                return "-"
            return f"{100 * edits(norm(SHORT_REF), norm(t)) / len(norm(SHORT_REF)):.0f}% WER" if t else "EMPTY"
        print(f"| {config} | {len(ha or hb)} | {len(bad_b)} | {len(bad_a)} | {dots_b} / {dots_a} | {tail(tb)} / {tail(ta)} |")
        for k, v in sorted(bad_b.items()):
            print(f"  before {config} {k}: {v[:80]!r}")
        for k, v in sorted(bad_a.items()):
            print(f"  after  {config} {k}: {v[:80]!r}")


if __name__ == "__main__":
    main()
