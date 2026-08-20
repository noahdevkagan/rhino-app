# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-19, late)

- **Rhino v0.1.12 shipped:** immutable tag `v0.1.12` at release commit
  `c1b630c`. Notarized app+DMG published to rhino-releases, signed appcast
  updated, rhinovoice.app (thanks/AppSumo/changelog) verified live at 0.1.12.
  Contains the full user-feedback round (PR #26, which also carried PR #25's
  auto-paste/permissions fixes; #25 closed as superseded): onboarding
  overhaul, Parakeet download progress, crash fixes (mic-tap NSException,
  abort-flag use-after-free). Release gotcha discovered: a release touches
  FOUR version pins — CHANGELOG.md, thanks/redeem pages, changelog page,
  and website/tests/rendered-html.test.mjs (the tests hardcode the DMG name;
  release.sh fails its website step if stale).
- **PR #27 open (`crxnamja/parakeet-model-cache`):** fixes the
  memory-growth half of the user report — FluidAudio rebuilds all CoreML
  MLModels on every downloadAndLoad (no internal cache); live preview
  reloaded per dictation and boosting loaded a second copy per
  transcription. New ParakeetModelCache actor shares one set per version;
  evicted on engine switch. Gate green; wants a manual RSS check across ~10
  live-preview dictations before merge.

## Outstanding

- Audit findings still open: AudioRecorder start (detached) vs stop (main) race (orphaned hot mic on
  fast press-release); Apple Dictation double-press-🌐 racing double-tap-lock.
- Crash reporter had no traces — ask if they run live preview (gates the
  mic-tap bug) and for Console.app crash reports if it recurs.
- From the 2026-08-18 session (branch `crxnamja/bern`): input-aware
  capitalization and app-icon refresh still open.

## Next session

Manually verify PR #27 (dictate ~10 times with live preview on, watch RSS
stay flat), then merge it and consider tagging v0.1.13.
