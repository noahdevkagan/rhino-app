# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-11, end of the two-day marathon)

- The app is **Rhino v0.1.0**: rebranded (bundle id com.noahkagan.rhino,
  coral face icon, menu-bar rhino silhouette, forced light mode), main
  window is sidebar + Home stats/History/Dictionary per Noah's mockups.
- 80/20 axe done: Rules, SenseVoice/Apple Speech, Rust autocorrect,
  translation, extra triggers, knobs — all deleted; bundle ships only
  whisper.cpp + libomp + Sparkle (DMG 28→14MB).
- Defaults ON: hold-Fn dictate, launch at login, menu-bar start, history,
  dictionary. Cleanup is an onboarding offer (explicit 1GB download).
- Shareable build: `Scripts/make-test-dmg.sh` → signed, NOTARIZED,
  stapled DMG (notarytool profile "rhino"; Sparkle keys exist, feed
  inert until rhinovoice.app + first release).
- Deterministic NumberCompaction ("forty-two thousand"→"42,000") runs on
  every transcription; unit-tested.
- **Benchmark (Noah's voice, 10 items): Rhino 80% zero-fix / 5.3% WER —
  beats Wispr Flow (44%); Typeless (100%) is the standing bar.** Grid:
  `bench/corpus/score-personal.py results/*`.
- Gate prefs leak fixed (RHINO_PREFS_SUITE); suites can no longer rewrite
  real settings.

## Outstanding

- Noah: re-record e02 + h01 (`rm audio/{e02,h01}.m4a && ./record.sh`) —
  realistic shot at 90-100% zero-fix; optionally dictate h03 into Wispr.
- Next quality lever: elided-word reconstruction in cleanup ("Schedule
  the review" — Rhino AND Wispr both dropped the "the"; Typeless's LLM
  reconstructs). Then email-tier polish.
- Release pipeline (tag → CI gate → sign/notarize → DMG → Sparkle
  appcast → site): creds exist locally; needs the workflow + rhinovoice
  .app registration + site. Crib docs/PUBLISHING.md + MeetingCoach.
- Localizable.xcstrings still carries orphaned keys for cut features
  (harmless); prune someday.
- CI test-gate.yml still builds with old assumptions (submodule list
  changed after autocorrect removal) — verify with a workflow_dispatch
  run before relying on it for releases.

## Next session

Start with: "Read AGENTS.md and decisions.md. If bench/corpus has fresh
recordings, rescore and update the head-to-head; then build elided-word
reconstruction into the cleanup pass and corpus-test it."
