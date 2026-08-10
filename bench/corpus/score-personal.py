#!/usr/bin/env python3
"""Score a results directory against items.json's intended texts.

    score-personal.py results/<label> [results/<other> ...]

One directory: per-item table + summary.json.
Multiple: side-by-side comparison (the head-to-head vs Wispr Flow).

Zero-fix = normalized output equals normalized intended text (usable
without touching the keyboard). WER over intended text otherwise.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent.parent / "tests" / "asr"))
from score import norm, wer  # noqa: E402


def score_dir(d: Path, items: dict) -> dict:
    rows = []
    for item in items:
        f = d / f"{item['id']}.txt"
        if not f.exists():
            continue
        hyp = f.read_text().strip()
        errors, ref_len = wer(item["intended"], hyp)
        rate = 100.0 * errors / max(ref_len, 1)
        rows.append({
            "id": item["id"], "tier": item["tier"],
            "zeroFix": norm(item["intended"]) == norm(hyp),
            "wer": round(rate, 1),
            "review": rate > 15.0,
        })
    if not rows:
        sys.exit(f"no scored items in {d}")
    summary = {
        "label": d.name,
        "items": len(rows),
        "zeroFixRate": round(100.0 * sum(r["zeroFix"] for r in rows) / len(rows), 1),
        "meanWer": round(sum(r["wer"] for r in rows) / len(rows), 1),
        "needsReview": [r["id"] for r in rows if r["review"]],
        "byTier": {
            tier: round(100.0 * sum(r["zeroFix"] for r in rows if r["tier"] == tier)
                        / max(sum(1 for r in rows if r["tier"] == tier), 1), 1)
            for tier in ("short", "email", "hard")
        },
    }
    (d / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def main() -> None:
    items = json.loads((HERE / "items.json").read_text())["items"]
    summaries = [score_dir(Path(a), items) for a in sys.argv[1:]]
    for s in summaries:
        print(f"\n{s['label']}: zero-fix {s['zeroFixRate']}% · mean WER {s['meanWer']}%"
              f" · {s['items']} items · by tier {s['byTier']}")
        if s["needsReview"]:
            print(f"  review for meaning changes (WER>15%): {', '.join(s['needsReview'])}")
    if len(summaries) == 2:
        a, b = summaries
        ratio = a["zeroFixRate"] / max(b["zeroFixRate"], 0.1) * 100
        print(f"\nhead-to-head: {a['label']} reaches {ratio:.0f}% of {b['label']}'s zero-fix rate"
              f" (target ≥ 90%)")


if __name__ == "__main__":
    main()
