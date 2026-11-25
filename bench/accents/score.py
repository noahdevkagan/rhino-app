#!/usr/bin/env python3
"""Score accent bench runs: WER and latency per engine/model per accent group.

Usage: score.py <results-dir> [--baseline CONFIG]

<results-dir> holds one `<config>__<group>.json` per run (the app's `bench` output). Prints a
markdown table (WER %, 95% bootstrap interval, clips, speakers, median and p90 time per clip)
and, with --baseline, the paired WER difference of every other config against it per group,
with its own bootstrap interval: an interval that straddles 0 means "no measurable change".

WER here is corpus WER per group (total word edits / total reference words) after a
normaliser that only removes formatting differences: case, punctuation, hyphens, digits vs
number words, US vs British spelling, a few spoken-form variants. It never forgives a
wrong word.
"""
import csv
import json
import random
import re
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).parent
NO_SPEECH = "No speech detected in the audio"

ONES = "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen " \
       "fifteen sixteen seventeen eighteen nineteen".split()
TENS = "_ _ twenty thirty forty fifty sixty seventy eighty ninety".split()


def say(n: int) -> str:
    if n < 20:
        return ONES[n]
    if n < 100:
        return TENS[n // 10] + ("" if n % 10 == 0 else " " + ONES[n % 10])
    if n < 1000:
        return ONES[n // 100] + " hundred" + ("" if n % 100 == 0 else " " + say(n % 100))
    if n < 1_000_000:
        return say(n // 1000) + " thousand" + ("" if n % 1000 == 0 else " " + say(n % 1000))
    return str(n)


def year(n: int) -> str:
    """1984 -> nineteen eighty four (how people read years in Common Voice sentences)."""
    if 1100 <= n <= 1999 and n % 100 != 0:
        return say(n // 100) + " " + (("oh " + ONES[n % 100]) if n % 100 < 10 else say(n % 100))
    return say(n)


# Spelling variants folded to one form on BOTH sides (Brit mode, and Common Voice's mix of
# British and American sentences, must not count as errors).
SPELLING = {
    "colour": "color", "colours": "colors", "coloured": "colored", "favour": "favor",
    "favourite": "favorite", "favourites": "favorites", "honour": "honor", "honours": "honors",
    "honoured": "honored", "labour": "labor", "neighbour": "neighbor", "neighbours": "neighbors",
    "neighbourhood": "neighborhood", "behaviour": "behavior", "harbour": "harbor",
    "humour": "humor", "rumour": "rumor", "flavour": "flavor", "vapour": "vapor",
    "armour": "armor", "endeavour": "endeavor", "parlour": "parlor", "savour": "savor",
    "centre": "center", "centres": "centers", "centred": "centered", "metre": "meter",
    "metres": "meters", "theatre": "theater", "theatres": "theaters", "litre": "liter",
    "fibre": "fiber", "calibre": "caliber", "sombre": "somber", "spectre": "specter",
    "travelled": "traveled", "travelling": "traveling", "traveller": "traveler",
    "cancelled": "canceled", "cancelling": "canceling", "labelled": "labeled",
    "modelled": "modeled", "fuelled": "fueled", "jewellery": "jewelry", "grey": "gray",
    "defence": "defense", "offence": "offense", "licence": "license", "practise": "practice",
    "catalogue": "catalog", "dialogue": "dialog", "programme": "program", "programmes": "programs",
    "cheque": "check", "tyre": "tire", "tyres": "tires", "aluminium": "aluminum",
    "plough": "plow", "mould": "mold", "storey": "story", "pyjamas": "pajamas",
    "sceptical": "skeptical", "manoeuvre": "maneuver", "analogue": "analog",
    "okay": "ok", "mr": "mister", "mrs": "missus", "dr": "doctor", "st": "saint",
    "percent": "per cent",
}
ISE = re.compile(r"^(\w{3,})is(e|ed|es|ing|ation|ations)$")
ISE_KEEP = {"advise", "advised", "advises", "advising", "comprise", "comprised", "comprises",
            "compromise", "compromised", "despise", "despised", "devise", "devised", "exercise",
            "exercised", "exercises", "improvise", "improvised", "otherwise", "premise",
            "premises", "promise", "promised", "promises", "revise", "revised", "supervise",
            "supervised", "surprise", "surprised", "surprises", "televise", "televised", "wise",
            "rise", "raise", "raised", "praise", "praised", "noise", "poise", "expertise",
            "enterprise", "franchise", "merchandise", "concise", "precise", "paradise",
            "disguise", "disguised", "chastise", "cruise", "bruise", "treatise", "demise",
            "arise", "arises", "arising", "apprise", "incise", "excise", "circumcise"}


def fold(word: str) -> str:
    if word.endswith("'s") and len(word) > 2:
        return fold(word[:-2]) + "'s"
    word = SPELLING.get(word, word)
    if word not in ISE_KEEP:
        m = ISE.match(word)
        if m:
            word = f"{m.group(1)}iz{m.group(2)}"
    return word


CONTRACTIONS = {
    "we're": "we are", "you're": "you are", "they're": "they are", "i'm": "i am",
    "it's": "it is", "that's": "that is", "there's": "there is", "here's": "here is",
    "what's": "what is", "he's": "he is", "she's": "she is", "let's": "let us",
    "don't": "do not", "doesn't": "does not", "didn't": "did not", "can't": "cannot",
    "won't": "will not", "isn't": "is not", "aren't": "are not", "wasn't": "was not",
    "weren't": "were not", "haven't": "have not", "hasn't": "has not", "couldn't": "could not",
    "wouldn't": "would not", "shouldn't": "should not", "i've": "i have", "we've": "we have",
    "you've": "you have", "they've": "they have", "i'll": "i will", "we'll": "we will",
    "you'll": "you will", "it'll": "it will", "i'd": "i would", "we'd": "we would",
}


def norm(s: str, join_hyphens: bool = False) -> list[str]:
    s = s.lower().replace("’", "'").replace("‘", "'")
    s = re.sub(r"(\w) ' (\w)", r"\1'\2", s)                 # "don ' t" (Common Voice typing)
    if join_hyphens:                                        # home-made == homemade
        s = re.sub(r"(\w)-(\w)", r"\1\2", s)
    s = re.sub(r"(\d),(\d{3})", r"\1\2", s)               # 1,000 -> 1000
    s = re.sub(r"(\d+)\s*%", r"\1 per cent", s)
    s = re.sub(r"\$(\d+)", r"\1 dollars", s)
    s = re.sub(r"(\d+)(st|nd|rd|th)\b", r"\1", s)          # ordinals: compare the number
    s = re.sub(r"\b\d+\b", lambda m: year(int(m.group())) if len(m.group()) == 4 else say(int(m.group())), s)
    s = re.sub(r"[-–—/]", " ", s)
    s = re.sub(r"[^\w\s']", " ", s)
    s = re.sub(r"(^|\s)'|'(\s|$)", " ", s)                  # quotes, not apostrophes
    out = []
    for w in s.split():
        out += fold(CONTRACTIONS.get(w, w)).split()
    return out


def edits(r: list[str], h: list[str]) -> int:
    prev = list(range(len(h) + 1))
    for i, rw in enumerate(r, 1):
        cur = [i] + [0] * len(h)
        for j, hw in enumerate(h, 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (rw != hw))
        prev = cur
    return prev[-1]


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def boot(pairs, n=2000, seed=7):
    """95% interval of corpus WER over clip resamples. pairs = [(edits, ref_len)]."""
    rnd = random.Random(seed)
    vals = []
    for _ in range(n):
        s = [pairs[rnd.randrange(len(pairs))] for _ in pairs]
        vals.append(100 * sum(e for e, _ in s) / max(1, sum(l for _, l in s)))
    return pct(vals, 0.025), pct(vals, 0.975)


def boot_diff(a, b, n=2000, seed=7):
    """95% interval of WER(b) - WER(a), paired by clip. a, b = [(edits, ref_len)] same order."""
    rnd = random.Random(seed)
    vals = []
    for _ in range(n):
        idx = [rnd.randrange(len(a)) for _ in a]
        ra = sum(a[i][1] for i in idx)
        vals.append(100 * (sum(b[i][0] for i in idx) - sum(a[i][0] for i in idx)) / max(1, ra))
    return pct(vals, 0.025), pct(vals, 0.975)


GROUP_NAMES = {"au": "Australian", "us": "US (control)", "gb": "England", "in": "India/S. Asia",
               "nz": "New Zealand"}


def name(group: str) -> str:
    base, _, kind = group.partition("-")
    return GROUP_NAMES[base] + (f", {kind}" if kind else "")


def load(results: Path):
    manifest = list(csv.DictReader(open(HERE / "manifest.tsv"), delimiter="\t"))
    refs = {(r["group"], r["clip"]): r for r in manifest}
    data = {}  # config -> group -> list of (clip, edits, reflen, infer_ms, wall_ms, hyp)
    for f in sorted(results.glob("*__*.json")):
        config, group = f.stem.rsplit("__", 1)
        rows = []
        for row in json.loads(f.read_text() or "[]"):
            clip = Path(row["file"]).stem
            ref = refs.get((group.split("-")[0], clip))  # au-noisy scores against au
            if ref is None:
                continue
            hyp = row.get("text", "")
            hyp = "" if hyp.strip() == NO_SPEECH else hyp
            # Hyphenated compounds are a spelling choice either way (home-made, home made,
            # homemade): score the kinder of the two readings.
            r = norm(ref["sentence"])
            e = min(edits(norm(ref["sentence"], j), norm(hyp, k)) for j in (0, 1) for k in (0, 1))
            infer = (row.get("stages") or {}).get("infer_ms", row.get("ms", 0))
            rows.append((clip, e, len(r), infer, row.get("ms", 0), hyp))
        rows.sort()
        data.setdefault(config, {})[group] = rows
    return refs, data


def main() -> int:
    results = Path(sys.argv[1])
    baseline = sys.argv[sys.argv.index("--baseline") + 1] if "--baseline" in sys.argv else None
    refs, data = load(results)
    found = {g for d in data.values() for g in d}
    groups = sorted(found, key=lambda g: (list(GROUP_NAMES).index(g.split("-")[0]), g))

    # A clip that EVERY engine gets mostly wrong is a broken Common Voice row (the audio is a
    # different sentence from its text, or unintelligible), not an accent result. Drop those
    # from every config alike and say how many went. Needs two or more configs to judge.
    # Judged on the clean clips only, then dropped from that group's degraded copies too.
    if len(data) >= 2:
        for g in [g for g in groups if "-" not in g]:
            per_clip = {}
            for by_group in data.values():
                for c, e, n, *_ in by_group.get(g, []):
                    per_clip.setdefault(c, []).append(e / max(1, n))
            bad = {c for c, ws in per_clip.items() if len(ws) == len(data) and min(ws) >= 0.8}
            if bad:
                print(f"{name(g)}: dropped {len(bad)} clip(s) every engine missed "
                      f"(broken reference): {', '.join(sorted(bad))}", file=sys.stderr)
                for by_group in data.values():
                    for k in [k for k in by_group if k.split("-")[0] == g]:
                        by_group[k] = [r for r in by_group[k] if r[0] not in bad]

    print("| Engine / model | Accent | Clips (speakers) | WER % | 95% interval | Median ms/clip | p90 ms |")
    print("|---|---|---|---|---|---|---|")
    summary = {}
    for config, by_group in data.items():
        for g in groups:
            rows = by_group.get(g)
            if not rows:
                continue
            pairs = [(e, n) for _, e, n, *_ in rows]
            w = 100 * sum(e for e, _ in pairs) / sum(n for _, n in pairs)
            lo, hi = boot(pairs)
            speakers = len({refs[(g.split("-")[0], c)]["speaker"] for c, *_ in rows})
            ms = [m for *_, m, _ in rows]  # wall time per clip, as the user waits for it
            ms = ms[1:] if len(ms) > 1 else ms   # first clip pays model warm-up
            print(f"| {config} | {name(g)} | {len(rows)} ({speakers}) | {w:.1f} | "
                  f"{lo:.1f}–{hi:.1f} | {statistics.median(ms):.0f} | {pct(ms, 0.9):.0f} |")
            summary.setdefault(config, {})[g] = {"wer": round(w, 2), "ci": [round(lo, 2), round(hi, 2)],
                                                 "clips": len(rows), "median_ms": statistics.median(ms)}
    if baseline and baseline in data:
        print(f"\nPaired WER change vs `{baseline}` (negative = fewer errors; interval straddling 0 = noise)\n")
        print("| Engine / model | Accent | Δ WER (points) | 95% interval |")
        print("|---|---|---|---|")
        for config, by_group in data.items():
            if config == baseline:
                continue
            clean = [g for g in groups if "-" not in g]
            for g in groups + (["all"] if len(clean) > 1 else []):
                gs = clean if g == "all" else [g]   # "all" = every clean clip pooled
                a = {(k, c): (e, n) for k in gs for c, e, n, *_ in data[baseline].get(k, [])}
                b = {(k, c): (e, n) for k in gs for c, e, n, *_ in by_group.get(k, [])}
                common = sorted(set(a) & set(b))
                if not common:
                    continue
                pa, pb = [a[c] for c in common], [b[c] for c in common]
                d = 100 * (sum(e for e, _ in pb) - sum(e for e, _ in pa)) / sum(n for _, n in pa)
                lo, hi = boot_diff(pa, pb)
                label = f"All clean ({len(common)} clips)" if g == "all" else name(g)
                print(f"| {config} | {label} | {d:+.1f} | {lo:+.1f} to {hi:+.1f} |")
    (results / "summary.json").write_text(json.dumps(summary, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
