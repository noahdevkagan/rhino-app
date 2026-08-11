# Changelog

User-facing notes, newest first. A release tag `vX.Y.Z` cannot be pushed
without a `## X.Y.Z` section here (enforced by scripts/githooks/pre-push).

## Unreleased

(nothing yet)

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
