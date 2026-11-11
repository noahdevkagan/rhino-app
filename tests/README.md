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

Suites: `hygiene` (privacy/egress), `asr` (whisper tiny WER), `parakeet`
(Parakeet v2/v3 WER and inference time), `cleanup` (LLM cleanup fidelity and
effect), `latency`, `release`, `smoke`. `parakeet` and `cleanup` need models
already on this Mac and skip on CI and with `FAST=1`.

`cleanup/cases.json` entries with `known_gap` are measured failures of the
shipped model: printed as KNOWN GAP every run, they don't fail the gate. When
the scorer says one now passes, delete its `known_gap` to lock it in.
