# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-20, late)

- **Rhino v0.1.14 shipped:** immutable tag `v0.1.14` at release commit
  `202e4e6`. Notarized app+DMG on rhino-releases, appcast item signed and
  live, rhinovoice.app verified at 0.1.14. Contents: onboarding rebuilt as
  a numbered 1-2-3 wizard with auto-advance (#31, from tester feedback
  "looked like a settings screen"), update badge drawn on the rhino
  menu-bar icon (#29), menu-bar "Dictionary…" ⌘D item (#30).
- Release pins are now FIVE files: CHANGELOG.md, thanks page, AppSumo
  redeem form, website changelog page, and website/tests/
  rendered-html.test.mjs (TWO hardcoded DMG names, lines ~71 and ~115).
  release.sh pre-flights the first four; the tests fail the website step
  on the fifth.
- Dev preview recipe for onboarding/fresh-install states (isolated prefs
  via RHINO_PREFS_SUITE, macOS missing-window-at-launch quirk, System
  Events driving) is saved in Claude's project memory.

## Outstanding

- Wizard onboarding hasn't been re-tested by the tester whose feedback
  drove it — ask them to redo fresh setup on 0.1.14.
- PR #27's Parakeet model cache shipped in 0.1.13, but the planned manual
  RSS check (~10 live-preview dictations, flat memory) was never recorded
  — watch for memory-growth reports.
- Audit findings still open: AudioRecorder start (detached) vs stop (main)
  race (orphaned hot mic on fast press-release); Apple Dictation
  double-press-🌐 racing double-tap-lock.
- Crash reporter had no traces — ask if they run live preview (gates the
  mic-tap bug) and for Console.app crash reports if it recurs.
- From branch `crxnamja/bern`: input-aware capitalization and app-icon
  refresh still open.

## Next session

Ask the onboarding tester to redo fresh setup on v0.1.14 and collect
feedback; then take the AudioRecorder start/stop race audit finding.
