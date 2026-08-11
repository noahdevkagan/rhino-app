# Changelog

User-facing notes, newest first. A release tag `vX.Y.Z` cannot be pushed
without a `## X.Y.Z` section here (enforced by scripts/githooks/pre-push).

## Unreleased

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
