# Tests

One directory per concern, each with a self-contained `run.sh` that exits
nonzero on failure. The push gate (`scripts/push-gate.sh`) runs every
`tests/*/run.sh` automatically — adding a suite here adds it to the gate,
no wiring needed.

Conventions (from MeetingCoach, where this layout proved itself):

- Each `run.sh` is runnable alone from anywhere: it `cd`s to its own dir.
- Honor `FAST=1` to skip the slow cases when the env var is set.
- Build artifacts go in a gitignored `.build/` inside the suite dir.
- Scenarios that can only be verified by a human (real calls, real
  hardware) live in a `*-manual.md` checklist, clearly marked as never
  run automatically — so nobody mistakes "documented" for "tested".

`smoke/` is a placeholder — replace it with the first real suite.

`browser-media/run.sh` checks the production browser pause/resume script against
real HTML media in isolated, offline headless Chrome. Requires Swift, Node and
Google Chrome; reports a skip if Chrome is absent. Native browser coordination
is covered by XCTest regardless. Signed per-app Automation/YouTube/Safari checks
remain manual in `media-playback-manual.md`.
