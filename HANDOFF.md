# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-19)

- **PR #26 open (`crxnamja/address-user-feedback`, stacked on PR #25):**
  addresses the 4-item external user report + Noah's onboarding review.
  Onboarding: live-permissions section (AX self-registration via prompt),
  honest Fn / Right ⌘ trigger cards writing `recordingTriggers`, two-model
  pick (Parakeet v3 RECOMMENDED / Whisper Large v3 Turbo) + separate
  "Optional add-on" cleanup section, grouped-cell restyle, centered 620pt
  column, window sized to fit scroll-free, Fn/emoji-picker conflict
  auto-fixed at Continue (disclosed one-line; full story + undo in
  Settings → Dictation footnote). Parakeet downloads show real progress
  (onboarding + Settings). Crash fixes: streaming mic-tap orphaned after
  audio-device changes (NSException on next dictation), WhisperEngine
  abort-flag use-after-free on cancel-vs-completion, ContentViewModel timer
  deinit. Full push gate passed. **Upgrade impact:** existing installs get
  only the crash fixes, Settings Parakeet progress, and the Fn-emoji
  footnote (informational — the auto-fix runs only at onboarding Continue);
  all onboarding changes are fresh-install-only.
- **PR #25 (`crxnamja/fix-auto-paste-insertion`) must land first** — #26
  contains its commits and shrinks once it merges.

## Outstanding

- Audit findings deliberately not fixed (design first): per-dictation
  Parakeet CoreML model reloads (StreamingTranscriptionController.start /
  FluidAudioEngine boosting path — RSS churn that reads as a leak);
  AudioRecorder start (detached) vs stop (main) race (orphaned hot mic on
  fast press-release); Apple Dictation double-press-🌐 racing double-tap-lock.
- Crash reporter had no traces — ask if they run live preview (gates the
  mic-tap bug) and for Console.app crash reports if it recurs.
- From the 2026-08-18 session (branch `crxnamja/bern`): input-aware
  capitalization and app-icon refresh still open.

## Next session

Merge PR #25, then rebase/merge PR #26. After both land, pick up the
deferred Parakeet model-reload fix (cache one loaded AsrModels across
dictations) — it's the likeliest explanation for "feels like a memory leak".
