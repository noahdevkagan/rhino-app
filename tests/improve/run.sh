#!/bin/bash
# Improvement-loop suite: the weekly merge script (Scripts/improve) obeys its rules, the bundled
# CommonCorrections.json is valid, and the three copies of the share scrub (app, website, script)
# haven't drifted. Pure Python, seconds, no build needed.
set -uo pipefail
cd "$(dirname "$0")/../.."
python3 -m unittest Scripts/improve/test_merge_corrections.py
