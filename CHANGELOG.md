# Changelog

User-facing notes, newest first. A release tag `vX.Y.Z` cannot be pushed
without a `## X.Y.Z` section here (enforced by scripts/githooks/pre-push).

## Unreleased

- Added a menu-bar feedback form that opens a prefilled email straight to
  Noah, including the running Rhino version.

## 0.1.6 — 2026-08-12

- Removed the oversized keyboard diagram from first-time setup so it no longer
  covers the shortcut and speech-model choices.

## 0.1.5 — 2026-08-12

- Updated Rhino's app icon with crisp high-resolution artwork that stays sharp
  at every macOS icon size.

## 0.1.4 — 2026-08-12

- Fixed the Fn shortcut getting stuck in an Input Monitoring permission loop
  even after access was enabled. Rhino now uses its existing Accessibility
  permission for both global Fn detection and typing into other apps.

## 0.1.3 — 2026-08-12

- Fixed the Fn shortcut permission flow so dictation works while other apps
  are focused, with a clear prompt for the required Input Monitoring access.
- Fixed a crash when deleting a dictionary rule while one of its text fields
  was focused.
- Fixed the Home screen showing a dash instead of the active dictation
  shortcut.

## 0.1.2 — 2026-08-11

- "Open System Settings" in the permissions banner now takes you straight
  to the exact privacy pane (Microphone, then Accessibility) instead of
  the Privacy & Security front page.

## 0.1.1 — 2026-08-11

- **Hands-free mode**: double-press your dictation shortcut to lock
  recording on — nothing to hold — and press it again to stop. On by
  default; toggle in Settings → Dictation.
- Dictation failures now say what went wrong (like "Model not loaded —
  check Settings → Models") instead of a bare "Transcription failed".
- Home shows a banner when no speech model is installed, with a button
  that takes you straight to the model downloads.
- Setup now verifies your chosen model actually loads before finishing,
  and interrupted model downloads are detected and retried instead of
  silently breaking every dictation.
- Cleanup now restores short words the engine dropped ("Schedule review"
  → "Schedule the review") when the optional cleanup model is enabled.

## 0.1.0 — 2026-08-11

- Rhino is born: new name, icon, menu-bar rhino, and a redesigned home
  with your dictation stats.
- Hold **Fn** to dictate (default), release to insert. Launch at login and
  live in the menu bar, on by default.

- Radically simplified: removed per-app rules, the SenseVoice and Apple
  Speech engines, translation, mouse/latch/submit trigger modes, the
  indicator layout editor, and the advanced decoding knobs. One shortcut,
  two engines (Parakeet + Whisper), sane defaults.
- Faster first dictation: the speech engine and cleanup model now load at
  launch instead of on your first recording.
- New Rhino app icon and a rhino menu-bar icon.
- Dictation history is on by default, stored only on this Mac; the main
  window now shows your stats (words, time saved, speed), history, and
  the dictionary.

- Silence no longer produces text: dictating nothing (or a dead mic) now
  inserts nothing, instead of an occasional hallucinated word.
- AI cleanup now always runs on the built-in on-device model; the Ollama
  server option and the post-record shell hook were removed.

- All-local, provably: removed the Remote (OpenAI-compatible/Groq)
  transcription engine and remote LLM cleanup entirely — every engine and
  cleanup model now runs on your Mac. Existing remote configurations fall
  back to Whisper / the built-in cleanup model, and stored remote API keys
  are removed from the Keychain.
- Removed the GitHub release-check ping; updates go only through the
  signed Sparkle feed, checked over HTTPS.
- Ollama cleanup connections are now restricted to this machine
  (localhost) — remote Ollama URLs are refused.
- New hygiene test gate: every push must transcribe end-to-end with zero
  non-localhost network connections.
- Initial skeleton from ~/app-template.
