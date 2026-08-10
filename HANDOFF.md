# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-10, end of day-1 marathon)

- App is **Rhino** (repos noahdevkagan/rhino + rhino-app; in-app rebrand
  deferred until the quality gate passes, per PLAN.md Phase 4).
- Phases 0–1 done and pushed: skeleton + gate; every remote code path
  deleted (ASR, LLM cleanup, GitHub update ping, Ollama, post-record
  hook); history off by default; ATS re-enabled; migrations + Keychain
  scrub. NOTE: PLAN.md was rewritten mid-day — decisions.md records where
  we diverged (deletion kept over compile-guards) and what was adopted.
- Quality harness live: tests/asr (WER + silence guard), tests/latency
  (budgets 800/2000ms from actuals), tests/hygiene (static + networking
  classification + dynamic lsof), bench/scorecard.py trend,
  bench/corpus/ tooling for the 30-item personal benchmark.
- Real bug found & fixed by the new gate: silence hallucinated "you"
  (VAD-empty + near-silent clip now returns "").
- CI is on-demand/release-only (macOS minutes bill 10x on private repos).
- Gate runs in ~16s warm; all suites green; unit tests green.

## Outstanding (needs Noah)

- **Record the 30-item corpus** (bench/corpus/README.md) and run the
  head-to-head vs Wispr Flow — this is the go/no-go quality measurement
  everything else waits on.
- Manual checks: WiFi-off dictation proof + tests/insertion-manual.md.
- Dogfood daily: `cd ~/rhino-app && ./run.sh`.
- Decide domain/brand assets for Rhino (site, icon) — Phase 4.
- For release later: Apple Developer ID cert, notary app-specific
  password, Sparkle EdDSA keypair (upstream docs/PUBLISHING.md has the
  full recipe; adapt, don't replace).

## Next session

Start with: "Read AGENTS.md, decisions.md, and ~/rhino/PLAN.md. If corpus
recordings exist in bench/corpus/audio/, score them and fix the largest
measured gap; otherwise continue Phase 4 prep that needs no credentials."
