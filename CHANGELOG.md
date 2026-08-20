# Changelog

User-facing notes, newest first. A release tag `vX.Y.Z` cannot be pushed
without a `## X.Y.Z` section here (enforced by scripts/githooks/pre-push).

## 0.1.13 — 2026-08-20

- Smart formatting now lays dictated emails out as emails — greeting on its
  own line, a blank line between thoughts, sign-off and name on their own
  lines — instead of one long run-on line.
- Say "new line" or "new paragraph" while dictating (with smart formatting
  on) to insert real breaks. Sentences that just happen to contain those
  words are left alone.
- Memory no longer climbs dictation after dictation with Parakeet: the
  speech model is loaded once and reused, instead of being rebuilt for every
  dictation and live preview.

## 0.1.12 — 2026-08-19

- First-time setup now walks you through the two permissions Rhino needs,
  with live status — and it registers Rhino in the Accessibility list for
  you, so the toggle is right there instead of a hunt through System
  Settings.
- Setup is simpler: pick one of two speech models (Parakeet v3 is
  recommended), with punctuation cleanup as a clearly optional add-on. The
  other model variants still live in Settings → Models.
- The dictate-key choice in setup now actually applies — it silently stayed
  Fn before, whatever you picked. The alternative key is now Right ⌘.
- After setup, pressing Fn no longer pops the Mac's emoji picker
  mid-dictation. Emoji stays available with ⌃⌘Space; undo anytime in
  System Settings → Keyboard.
- Parakeet downloads show a real progress bar, plus a note while the model
  is optimized for your Mac — no more wondering if the spinner is stuck.
- Fixed a crash that could hit the next dictation after AirPods or your
  microphone changed, and a rare crash when cancelling with Esc just as a
  transcription finished.
- Dictations no longer vanish silently when the Accessibility grant has
  gone stale: the text stays on the clipboard with a notice explaining the
  one-time fix, and Settings → Dictation shows live permission status.

## 0.1.11 — 2026-08-19

- First-time setup no longer fails with a "TranscriptionError error 0" dialog
  when Parakeet was already downloaded: the checkmarked model is now the one
  Continue actually verifies, instead of the Whisper default.
- The menu bar shows a red dot and an "Install Update…" item when an update
  is ready to install; both clear once you're up to date.
- Speech-model load failures now explain what went wrong in plain words
  instead of a raw error code.

## 0.1.10 — 2026-08-18

- Home and History are now one screen: your dictation stats sit on top with
  your history and search right below.
- The active model is shown on Home, so you can always see what's doing the
  transcribing — click it to switch models.
- Settings opens inside the main window and was redesigned with Apple-style
  grouped cells.
- The recording indicator is now a compact black pill docked at the bottom of
  the screen, showing the app you're dictating into and a live waveform.
- The live transcription preview shows your words sooner and the bubble
  expands smoothly instead of snapping.
- About Rhino: thank you to Paul Stamatiou for all the feedback.

## 0.1.9 — 2026-08-18

- Same app as 0.1.8, re-issued with a new update-signing key after moving
  releases to a new machine. Installed 0.1.1–0.1.8 copies can't verify this
  update automatically — download this version once from the website and
  future updates work normally again.

## 0.1.8 — 2026-08-18

- Turning on "Clean up with an LLM" now downloads the on-device cleanup model
  automatically, so cleanup and Smart formatting work right away instead of
  silently doing nothing until the model was fetched by hand.
- Update prompts now include the matching changelog notes, so you can see
  what's new before installing each Rhino update.

## 0.1.7 — 2026-08-13

- Added a menu-bar feedback form that opens a prefilled email straight to
  Noah, including the running Rhino version.
- Added optional Smart formatting under Settings → Output → Cleanup, turning
  dictated enumerations into bulleted or numbered lists entirely on-device.
- Made finished dictations appear sooner by removing redundant audio work and
  moving history bookkeeping after text insertion.

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
