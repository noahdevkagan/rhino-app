#!/usr/bin/env python3
"""Merge "Help improve accuracy" pairs into the bundled CommonCorrections.json.

Input: the JSON from GET https://rhinovoice.app/api/admin/corrections-summary (pairs taught on
3+ different Macs, already scrubbed twice). Output: an updated bundle file and a Markdown report
for the weekly PR body. Run by .github/workflows/improve-weekly.yml; a human merges the PR.

Rules (decisions.md 2026-11-02, "Opt-in correction sharing"):
  * at least MIN_INSTALLS different Macs (re-checked here, not just trusted from the server)
  * the pair passes the same scrub as the app (CorrectionScrub) — mirrored below
  * English/auto only for now: the bundled list applies to every dictation, so a pair taught in
    one language must not rewrite another
  * no rewriting of common English words (their→there would break everyone who meant "their")
  * conflicts: when one heard phrase maps to several fixes, only a clear winner (2x the
    runner-up) is taken
  * never a rule that grows on a second pass (corrected contains heard), because the dictionary
    runs again after cleanup
  * existing entries are never changed or removed by the bot; at most MAX_NEW additions per run

Exit code 0 always on valid input; prints `changed=true|false` for GitHub Actions.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MIN_INSTALLS = 3
MAX_NEW = 50
MAX_WORDS = 5
MAX_CHARS = 60
ALLOWED_LANGUAGES = {"", "en", "auto"}

# Same as CorrectionScrub.personalPatterns (Swift) and personalPatterns (website/app/_lib/corrections.ts).
PERSONAL = [
    re.compile(r"[^\s@]+@[^\s@]+\.[^\s@]+"),
    re.compile(r"\b(https?://|www\.)", re.I),
    re.compile(r"\b[a-z0-9-]+\.(com|net|org|io|app|ai|co|dev|me|us|uk|de)\b", re.I),
    re.compile(r"\d[\d\s.,-]{2,}\d"),
    re.compile(r"\d{4,}"),
    re.compile(r"\b(sk|pk|rk|ghp|gho|xox[abp]|akia)[-_][A-Za-z0-9]", re.I),
    re.compile(r"[A-Za-z0-9_\-]{24,}"),
    re.compile(r"\b(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Za-z])[A-Za-z0-9]{12,}\b"),
]

# Words people dictate on purpose. A crowd "fixing" one of these is fixing its own context, not
# Rhino's hearing, and a global rewrite would break everyone else.
COMMON_WORDS = set("""
a about after again all also am an and any are as at be because been before being but by can
could did do does doing done down each even every few for from get go going good got had has
have he her here hers him his how i if in into is it its it's just know like make me might mine
more most much must my no not now of off on once one only or other our ours out over own said
same say see she should so some such than that the their theirs them then there these they
they're this those though through to too two under until up us very was way we well were what
when where which while who whom whose why will with would yes yet you your you're yours
accept except affect effect lose loose weather whether right write hear here know no new knew
buy by bye sea see week weak where wear were peace piece plain plane principal principle
""".split())


def collapse(text: str) -> str:
    return " ".join(text.split())


def shareable(text: str) -> bool:
    return (
        0 < len(text) <= MAX_CHARS
        and any(ch.isalpha() for ch in text)
        and len(text.split(" ")) <= MAX_WORDS
        and not re.search(r"[\x00-\x1f\x7f<>]", text)
        and not any(p.search(text) for p in PERSONAL)
    )


def grows_on_second_pass(heard: str, corrected: str) -> bool:
    return re.search(r"(?<!\w)" + re.escape(heard) + r"(?!\w)", corrected, re.I) is not None


def candidates(summary: dict) -> tuple[list[dict], list[str]]:
    """Pairs worth bundling, plus a log of why others were skipped."""
    skipped: list[str] = []
    by_heard: dict[str, list[dict]] = {}
    for raw in summary.get("pairs", []):
        heard = collapse(str(raw.get("heard", "")))
        corrected = collapse(str(raw.get("corrected", "")))
        installs = int(raw.get("installs", 0) or 0)
        languages = {l for l in str(raw.get("languages", "") or "").split(",")}
        label = f"`{heard}` → `{corrected}` ({installs} Macs)"
        if installs < MIN_INSTALLS:
            skipped.append(f"{label}: under {MIN_INSTALLS} Macs")
        elif heard == corrected or not shareable(heard) or not shareable(corrected):
            skipped.append(f"{label}: fails the share scrub")
        elif not languages <= ALLOWED_LANGUAGES:
            skipped.append(f"{label}: non-English ({', '.join(sorted(languages - {''}))})")
        elif heard.lower() in COMMON_WORDS:
            skipped.append(f"{label}: rewrites a common word")
        elif grows_on_second_pass(heard, corrected):
            skipped.append(f"{label}: would grow on a second dictionary pass")
        else:
            by_heard.setdefault(heard.lower(), []).append(
                {"heard": heard, "corrected": corrected, "installs": installs}
            )

    picked: list[dict] = []
    for options in by_heard.values():
        options.sort(key=lambda p: -p["installs"])
        best = options[0]
        if len(options) > 1 and best["installs"] < 2 * options[1]["installs"]:
            alts = ", ".join(f"`{o['corrected']}` ({o['installs']})" for o in options)
            skipped.append(f"`{best['heard']}`: no clear winner between {alts}")
            continue
        picked.append(best)
    return picked, skipped


def merge(bundle: dict, picked: list[dict]) -> tuple[dict, list[dict]]:
    entries = list(bundle.get("entries", []))
    existing = {collapse(e["heard"]).lower() for e in entries}
    added: list[dict] = []
    for pair in sorted(picked, key=lambda p: (-p["installs"], p["heard"].lower())):
        if len(added) >= MAX_NEW:
            break
        if pair["heard"].lower() in existing:
            continue
        existing.add(pair["heard"].lower())
        added.append(pair)
    entries.extend(added)
    entries.sort(key=lambda e: e["heard"].lower())
    out = dict(bundle)
    out["entries"] = entries
    return out, added


def report(added: list[dict], skipped: list[str], generated_at: str) -> str:
    lines = [
        "Weekly accuracy update from people who opted in to **Help improve accuracy**.",
        "",
        f"Summary generated {generated_at or 'just now'}. Each pair below was taught with "
        f"\"Fix a word\" on at least {MIN_INSTALLS} different Macs. `CommonCorrectionsTests` replays "
        "every bundled pair; a person's own dictionary always overrides these.",
        "",
        "### Added",
    ]
    lines += [f"- `{p['heard']}` → `{p['corrected']}` ({p['installs']} Macs)" for p in added] or ["- none"]
    if skipped:
        lines += ["", "<details><summary>Skipped</summary>", ""] + [f"- {s}" for s in skipped] + ["", "</details>"]
    lines += ["", "Review before merging: a wrong rule rewrites everyone's dictation. Not auto-merged."]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--summary", required=True, type=Path)
    ap.add_argument("--bundle", required=True, type=Path)
    ap.add_argument("--report", required=True, type=Path)
    args = ap.parse_args(argv)

    summary = json.loads(args.summary.read_text())
    bundle = json.loads(args.bundle.read_text())
    picked, skipped = candidates(summary)
    updated, added = merge(bundle, picked)
    if added:
        args.bundle.write_text(json.dumps(updated, indent=2, ensure_ascii=False) + "\n")
    args.report.write_text(report(added, skipped, str(summary.get("generatedAt", ""))))
    print(f"added {len(added)}, skipped {len(skipped)}", file=sys.stderr)
    print(f"changed={'true' if added else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
