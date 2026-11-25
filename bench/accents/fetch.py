#!/usr/bin/env python3
"""Download the clips listed in manifest.tsv into audio/<group>/ as 16 kHz mono WAV.

Usage: fetch.py [--groups au,us]

Audio is never committed (audio/ is gitignored). The datasets-server hands out signed,
expiring asset URLs, so each run looks the rows up again by split + row index rather than
storing URLs, paging the same filter query the manifest came from (100 rows a call keeps
well under the API's rate limit). Already-downloaded clips are skipped, so re-running is cheap.
"""
import argparse
import csv
import json
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from build_manifest import GROUPS, query  # noqa: E402  (same filter the manifest was built with)


def get(url: str, binary: bool = False):
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                data = r.read()
                return data if binary else json.loads(data)
        except Exception as e:
            print(f"retry {attempt + 1}: {e}", file=sys.stderr)
            time.sleep(3 * (attempt + 1))
    raise SystemExit(f"download failed: {url[:120]}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--groups", default="")
    args = ap.parse_args()
    wanted = set(filter(None, args.groups.split(",")))

    rows = list(csv.DictReader(open(HERE / "manifest.tsv"), delimiter="\t"))
    todo = {}
    skipped = 0
    for r in rows:
        if wanted and r["group"] not in wanted:
            continue
        if (HERE / "audio" / r["group"] / f"{r['clip']}.wav").exists():
            skipped += 1
        else:
            todo.setdefault((r["group"], r["split"]), {})[int(r["row"])] = r

    fetched = 0
    for (group, split), by_row in todo.items():
        offset = 0
        while by_row:
            page = query(split, GROUPS[group], offset)
            if not page.get("rows"):
                break
            for item in page["rows"]:
                r = by_row.pop(item["row_idx"], None)
                if r is None:
                    continue
                row = item["row"]
                if Path(row["path"]).stem != r["clip"]:
                    raise SystemExit(f"upstream changed: {split}/{r['row']} is no longer {r['clip']}")
                out = HERE / "audio" / group / f"{r['clip']}.wav"
                out.parent.mkdir(parents=True, exist_ok=True)
                with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
                    tmp.write(get(row["audio"][0]["src"], binary=True))
                    tmp.flush()
                    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1",
                                    tmp.name, str(out)], check=True)
                fetched += 1
            offset += len(page["rows"])
        if by_row:
            print(f"{group}/{split}: {len(by_row)} rows not found upstream", file=sys.stderr)
    print(f"fetched {fetched}, already had {skipped}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
