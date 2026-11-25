#!/usr/bin/env python3
"""Pick the accent test set from Mozilla Common Voice 17 (English) and write manifest.tsv.

Usage: build_manifest.py            # rewrites manifest.tsv next to this file

Run once; the committed manifest is the test set. Re-running gives the same rows unless the
upstream mirror changes. Source: the Hugging Face datasets-server API over fixie-ai's ungated
mirror of Common Voice 17.0 (CC0), test + validation splits only (never train, so the clips
are held out from any model that trained on Common Voice's train split). No account, no token.

Selection, per accent: rows whose self-reported accent matches, sentence at least 5 words,
at most MAX_PER_SPEAKER clips per speaker (so one prolific speaker can't decide a group), in
row order, up to TARGET clips. The speaker column is the first 8 hex chars of Common Voice's
own pseudonymous client hash — enough to count distinct speakers, nothing more.
"""
import csv
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
API = "https://datasets-server.huggingface.co/filter"
DATASET = "fixie-ai/common_voice_17_0"
SPLITS = ["test", "validation"]
TARGET = 60
MAX_PER_SPEAKER = 3

# group -> SQL condition on the `accent` column. AU takes any label that mentions Australia
# (people often add a second label); the US control takes only the exact single label so
# it is a clean baseline.
GROUPS = {
    "au": "\"accent\" LIKE '%Australian English%'",
    "us": "\"accent\" = 'United States English'",
    "gb": "\"accent\" = 'England English'",
    "in": "\"accent\" = 'India and South Asia (India, Pakistan, Sri Lanka)'",
    "nz": "\"accent\" LIKE '%New Zealand English%'",
}


def query(split: str, where: str, offset: int) -> dict:
    params = urllib.parse.urlencode({
        "dataset": DATASET, "config": "en", "split": split,
        "where": where, "offset": offset, "length": 100,
    })
    for attempt in range(5):
        try:
            with urllib.request.urlopen(f"{API}?{params}", timeout=60) as r:
                return json.load(r)
        except Exception as e:  # rate limits / transient 5xx
            print(f"retry {attempt + 1}: {e}", file=sys.stderr)
            time.sleep(3 * (attempt + 1))
    raise SystemExit(f"datasets-server unreachable for {split} {where}")


def main() -> int:
    rows_out = []
    for group, where in GROUPS.items():
        picked, per_speaker = [], {}
        for split in SPLITS:
            offset = 0
            while len(picked) < TARGET:
                page = query(split, where, offset)
                rows = page.get("rows", [])
                if not rows:
                    break
                for item in rows:
                    row = item["row"]
                    sentence = " ".join(row["sentence"].split())
                    speaker = row["client_id"][:8]
                    if len(sentence.split()) < 5 or per_speaker.get(speaker, 0) >= MAX_PER_SPEAKER:
                        continue
                    per_speaker[speaker] = per_speaker.get(speaker, 0) + 1
                    picked.append({
                        "group": group, "split": split, "row": item["row_idx"],
                        "clip": Path(row["path"]).stem, "speaker": speaker,
                        "accent": row["accent"], "sentence": sentence,
                    })
                    if len(picked) >= TARGET:
                        break
                offset += len(rows)
            if len(picked) >= TARGET:
                break
        print(f"{group}: {len(picked)} clips, {len(per_speaker)} speakers", file=sys.stderr)
        rows_out += picked

    with open(HERE / "manifest.tsv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows_out[0]), delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows_out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
