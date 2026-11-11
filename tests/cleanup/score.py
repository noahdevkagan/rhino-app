#!/usr/bin/env python3
"""Score one `Rhino cleanup --stdin` run against cases.json.

Usage: score.py <cases.json> <cleanup.json> <cleanup.log>

Per case, in this order:
  - must_contain       every phrase appears (case-sensitive for brand names,
                       except the first letter, which lists capitalize)
  - must_contain_any   at least one appears
  - must_not_contain   none appears (case-insensitive)
  - min_lines / max_lines / min_list_items   layout happened (or didn't)
  - kind keep|list     content-word diff, input → output: fail on ≥2 spoken
                       content words dropped or ≥2 never-spoken words invented.
                       Function words, fillers, layout cues and numbers are
                       ignored (they legitimately come and go). `edit` cases
                       skip this, since applying an edit drops words on purpose.

A case marked `"known_gap": "<why>"` is a failure we have measured on the
shipped model and accepted for now: it is printed as KNOWN GAP and does not
fail the suite. If it starts passing, the line says so — delete the field
to lock the improvement in.

Also prints how many cleanup passes the app's own guards rejected per case
(a rejected pass falls back to the transcript, so a case can "pass" only
because the guard caught a bad rewrite; that should be visible).

Prints one line per case plus a `JSON\t{...}` summary; exits nonzero on failure.
"""
import json
import re
import sys
from pathlib import Path

MAX_DROPPED = 1   # fail at 2
MAX_INVENTED = 1  # fail at 2

# Mirrors CleanupFidelityGuard.ignorable, plus ordinals ("twelfth" → "12th").
IGNORABLE = set("""
a an the and or but so to of in on at for with that this it is was be i you we he
she they them just like really well okay ok alright all right um uh yeah know mean
number item step bullet point next new line paragraph
first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth
thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth
twentieth thirtieth
zero one two three four five six seven eight nine ten eleven twelve thirteen
fourteen fifteen sixteen seventeen eighteen nineteen twenty thirty forty fifty
sixty seventy eighty ninety hundred thousand million billion percent dollar dollars
""".split())

LIST_ITEM = re.compile(r"^\s*(?:[-*•]|\d+[.)])\s+\S")


def words(text: str) -> list[str]:
    text = text.lower().replace("’", "'")
    return [w.strip("'") for w in re.split(r"[^a-z0-9']+", text) if w.strip("'")]


def content_bag(text: str) -> dict[str, int]:
    bag: dict[str, int] = {}
    for w in words(text):
        if w in IGNORABLE or any(ch.isdigit() for ch in w):
            continue
        bag[w] = bag.get(w, 0) + 1
    return bag


def word_diff(spoken: str, written: str) -> tuple[list[str], list[str]]:
    a, b = content_bag(spoken), content_bag(written)
    dropped = [w for w, n in a.items() for _ in range(n - b.get(w, 0))]
    invented = [w for w, n in b.items() for _ in range(n - a.get(w, 0))]
    return dropped, invented


def has(phrase: str, text: str) -> bool:
    """Case-sensitive (brand names), except the phrase's first letter: list
    items and sentence starts get capitalized ("passport" → "- Passport")."""
    first, rest = phrase[:1], phrase[1:]
    return (first.lower() + rest) in text or (first.upper() + rest) in text


def check(case: dict, out: str) -> list[str]:
    problems = []
    flat = " ".join(out.split())  # phrases may straddle a line break
    for p in case.get("must_contain", []):
        if not has(p, flat):
            problems.append(f"missing {p!r}")
    anyof = case.get("must_contain_any")
    if anyof and not any(has(p, flat) for p in anyof):
        problems.append(f"missing any of {anyof!r}")
    for p in case.get("must_not_contain", []):
        if p.lower() in flat.lower():
            problems.append(f"contains {p!r}")

    lines = [l for l in out.splitlines() if l.strip()]
    if "min_lines" in case and len(lines) < case["min_lines"]:
        problems.append(f"{len(lines)} lines (min {case['min_lines']})")
    if "max_lines" in case and len(lines) > case["max_lines"]:
        problems.append(f"{len(lines)} lines (max {case['max_lines']})")
    items = sum(1 for l in lines if LIST_ITEM.match(l))
    if "min_list_items" in case and items < case["min_list_items"]:
        problems.append(f"{items} list items (min {case['min_list_items']})")

    if case.get("kind") in ("keep", "list"):
        dropped, invented = word_diff(case["input"], out)
        if len(dropped) > MAX_DROPPED:
            problems.append(f"dropped {dropped}")
        if len(invented) > MAX_INVENTED:
            problems.append(f"invented {invented}")
    return problems


def rejections(log: str, n: int) -> list[int] | None:
    """Rejections per case, or None if the log can't be attributed.

    The app logs with print(), which is block-buffered when stdout isn't a
    terminal, so these lines all arrive at exit, after the CLI's own
    "cleanup line i/n" markers. They do stay in order, and with
    cleanupOnlyWhenNeeded off every case runs exactly one cleanup pass:
    the k-th "LLM cleanup pass" line is case k, and a rejection belongs to
    the pass just before it.
    """
    counts: list[int] = []
    for line in log.splitlines():
        if line.startswith("LLM cleanup pass:"):
            counts.append(0)
        elif line.startswith("LLM cleanup rejected") and counts:
            counts[-1] += 1
    return counts if len(counts) == n else None


def main() -> int:
    cases = json.loads(Path(sys.argv[1]).read_text())
    rows = json.loads(Path(sys.argv[2]).read_text())
    log = Path(sys.argv[3]).read_text(errors="replace")

    if len(rows) != len(cases):
        print(f"cleanup FAIL: {len(rows)} outputs for {len(cases)} cases")
        return 1
    rejected = rejections(log, len(cases))
    total_rejected = sum(1 for l in log.splitlines() if l.startswith("LLM cleanup rejected"))

    fail = False
    summary = {"cases": {}, "rejected": total_rejected}
    for i, (case, row) in enumerate(zip(cases, rows)):
        cid = case["id"]
        if row.get("input", "").strip() != case["input"].strip():
            print(f"cleanup {cid}: FAIL — output row {i + 1} is for a different input")
            fail = True
            continue
        out = row.get("text", "")
        problems = check(case, out)
        gap = case.get("known_gap")
        rej = f", guard rejected {rejected[i]}" if rejected and rejected[i] else ""
        if not problems:
            status = "PASS" + (" (known gap now passes: remove known_gap)" if gap else "")
        elif gap:
            status = f"KNOWN GAP ({gap}): " + "; ".join(problems)
        else:
            status = "FAIL — " + "; ".join(problems)
            fail = True
        print(f"cleanup {cid}: {status}{rej}, {row.get('ms', 0)} ms")
        if problems:
            print(f"  out: {out[:300]!r}")
        summary["cases"][cid] = {"ok": not problems, "knownGap": bool(gap), "ms": row.get("ms", 0)}

    if rejected is None:
        print(f"cleanup: guard rejected {total_rejected} pass(es) "
              "(couldn't attribute them to cases: pass count didn't match)")
    print(f"JSON\t{json.dumps(summary)}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
