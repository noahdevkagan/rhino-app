# Changelog

User-facing notes, newest first. A release tag `vX.Y.Z` cannot be pushed
without a `## X.Y.Z` section here (enforced by scripts/githooks/pre-push).

## Unreleased

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
