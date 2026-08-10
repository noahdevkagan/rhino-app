# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-10)

- Phase 0 done: skeleton grafted, gate green, pushed to
  noahdevkagan/toucan-app (Dependabot disabled, its PRs closed).
- Phase 1 done in working tree: Remote ASR + remote LLM cleanup deleted,
  UpdateChecker (GitHub ping) deleted, Ollama loopback-pinned, ATS
  re-enabled, prefs migrations + Keychain scrub added. tests/hygiene
  passes (static scan + dynamic lsof-during-transcription, detector
  negative-tested). See decisions.md for each rationale.

## Outstanding

- Manual WiFi-off proof (plan's Phase 1 verification): WiFi off → full
  hotkey dictation flow into a real app. Needs a human at the keyboard.
- Localizable.xcstrings still carries orphaned remote/Groq UI strings
  (unused keys, harmless) — clean up with the Phase 3 rebrand pass.
- `docs/` + Readme screenshots still show the remote engine — full doc
  refresh lands with the Phase 3 rebrand.
- Wire `xcodebuild test` (upstream unit suite) into the gate as
  tests/unit/run.sh — decide budget: it needs ~2-4 min.

## Next session

Start with: "Read AGENTS.md and ~/rhino/PLAN.md, then begin Phase 2:
port MeetingCoach's ASR harness (~/coach-latest/tests/asr) as tests/asr."
