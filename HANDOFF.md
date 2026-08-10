# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-10)

- Phase 0 in progress: upstream cloned (467 commits), private repo
  `noahdevkagan/toucan-app` created, template skeleton grafted,
  gate wired to `./run.sh build`.

## Outstanding

- Wire upstream's XCTest suite (`OpenSuperWhisperTests/`) into the gate
  as a `tests/unit/` runner (needs a working `xcodebuild test` invocation).
- Phase 1 (next): delete Remote ASR engine + remote LLM cleanup code
  paths; build `tests/hygiene/` network gate. See `~/toucan/PLAN.md`.

## Next session

Start with: "Read AGENTS.md and ~/toucan/PLAN.md, then begin Phase 1:
remove the Remote ASR engine code path entirely."
