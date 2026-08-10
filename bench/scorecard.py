#!/usr/bin/env python3
"""One screen per push: WER + latency for the gate corpus, next to the
previous recorded run, with deltas and WARN flags.

    bench/scorecard.py            # compare + print (read-only)
    bench/scorecard.py --record   # re-score, append to bench/history.jsonl
    bench/scorecard.py --summary FILE   # also append markdown (CI)

Informational by design (exit 0 either way) — a WARN is a reason to look,
not an automated block. Records carry machine/model/commit so trends from
different machines are never silently mixed (per PLAN.md Phase 3).

Reads the JSON lines that tests/asr and tests/latency leave in their .out/
directories — run those suites (the push gate does) before --record.
"""
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).parent.parent
HISTORY = ROOT / "bench" / "history.jsonl"

WARN_WER_PP = 1.0      # WER up more than 1 percentage point
WARN_LATENCY_PCT = 25  # p50 latency up more than 25%


def read_out_json(path: Path) -> dict | None:
    """Last JSON\t{...} line from a suite output capture, if present."""
    if not path.exists():
        return None
    for line in reversed(path.read_text().splitlines()):
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def collect_current() -> dict | None:
    asr_dir = ROOT / "tests" / "asr" / ".out"
    wers = []
    for f in sorted(asr_dir.glob("*.txt")) if asr_dir.exists() else []:
        pass  # transcripts; scores come from score.py reruns below
    # Re-score from the saved transcripts so --record never needs a re-run.
    sys.path.insert(0, str(ROOT / "tests" / "asr"))
    try:
        import score  # noqa: E402
    except ImportError:
        return None
    refs = json.loads((ROOT / "tests" / "asr" / "cases" / "refs.json").read_text())
    for case, spec in refs.items():
        hyp_file = asr_dir / f"{case}.txt"
        if not hyp_file.exists():
            continue
        errors, ref_len = score.wer(spec["text"], hyp_file.read_text().strip())
        wers.append(100.0 * errors / max(ref_len, 1))
    if not wers:
        return None

    lat = None
    lat_file = ROOT / "tests" / "latency" / ".out" / "bench.json"
    if lat_file.exists():
        times = sorted(r["ms"] for r in json.loads(lat_file.read_text()))
        if times:
            lat = times[len(times) // 2]

    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                            capture_output=True, text=True).stdout.strip() or "unknown"
    return {
        "corpus": "gate-tiny",
        "meanWer": round(sum(wers) / len(wers), 2),
        "maxWer": round(max(wers), 2),
        "cases": len(wers),
        "latencyP50Ms": lat,
        "machine": platform.node(),
        "model": "ggml-tiny.en",
        "commit": commit,
        "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def main() -> int:
    record = "--record" in sys.argv
    summary_file = None
    if "--summary" in sys.argv:
        summary_file = Path(sys.argv[sys.argv.index("--summary") + 1])

    history = []
    if HISTORY.exists():
        history = [json.loads(l) for l in HISTORY.read_text().splitlines() if l.strip()]

    curr = collect_current()
    if curr is None:
        print("scorecard: no fresh suite output found (run tests/asr first) — showing history only")
        curr = history[-1] if history else None
        record = False
    if curr is None:
        print("scorecard: no data at all yet")
        return 0

    prev = next((h for h in reversed(history)
                 if h.get("corpus") == curr["corpus"] and h.get("machine") == curr.get("machine")
                 and h != curr), None)

    lines = ["", "=== scorecard (informational) ==="]
    warn = []

    def fmt(label, cur, pre, unit="", flip=False):
        d = ""
        if pre is not None and cur is not None:
            delta = cur - pre
            arrow = "▲" if delta > 0 else ("▼" if delta < 0 else "=")
            d = f"  (prev {pre}{unit} {arrow}{abs(round(delta, 2))}{unit})"
        lines.append(f"  {label:<14} {cur}{unit}{d}")

    fmt("mean WER", curr["meanWer"], prev and prev.get("meanWer"), "%")
    fmt("max WER", curr["maxWer"], prev and prev.get("maxWer"), "%")
    if curr.get("latencyP50Ms") is not None:
        fmt("latency p50", curr["latencyP50Ms"], prev and prev.get("latencyP50Ms"), "ms")
    lines.append(f"  corpus {curr['corpus']} · {curr['cases']} cases · {curr['model']} · {curr['machine']} · {curr['commit']}")

    if prev:
        if curr["meanWer"] - prev.get("meanWer", 0) > WARN_WER_PP:
            warn.append(f"WARN: mean WER up {curr['meanWer'] - prev['meanWer']:.1f}pp vs {prev['commit']}")
        p_lat, c_lat = prev.get("latencyP50Ms"), curr.get("latencyP50Ms")
        if p_lat and c_lat and (c_lat - p_lat) / p_lat * 100 > WARN_LATENCY_PCT:
            warn.append(f"WARN: latency p50 up {(c_lat - p_lat) / p_lat * 100:.0f}% vs {prev['commit']}")
    lines += warn or ["  no warnings"]

    print("\n".join(lines))
    if summary_file:
        with summary_file.open("a") as f:
            f.write("### Rhino scorecard\n```\n" + "\n".join(lines) + "\n```\n")

    if record:
        with HISTORY.open("a") as f:
            f.write(json.dumps(curr) + "\n")
        print(f"  recorded → bench/history.jsonl ({len(history) + 1} records)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
