# Rhino

**Hold a key. Talk. Your words appear — and they never leave your Mac.**

Rhino is a fast, private, local-only dictation app for macOS. On-device
speech models, on-device AI cleanup, no account, no telemetry. A private
downstream of the MIT-licensed
[OpenSuperWhisper](https://github.com/my-monkeys/OpenSuperWhisper) —
see [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).

> Status: pre-release, building toward a signed, notarized DMG.
> Requires macOS 14+, Apple Silicon recommended.

## What it does

- ⌨️ **Global shortcut** — a key combo or a single modifier (Right ⌥, Fn…),
  with hold-to-record: hold to speak, release to insert into any app.
- ⚡ **Fast** — Parakeet on-device with a live preview as you speak.
- 📖 **Dictionary** — your names and jargon spelled right, every time.
- 🧠 **AI cleanup** — optional punctuation/casing cleanup on the built-in
  on-device model (Qwen2.5 1.5B, runs in-process). The raw transcription is
  kept verbatim if the model misbehaves.
- 🗂 **Local history + stats** — everything stores to THIS Mac: search past
  dictations, rerun with a different model, see words dictated and time
  saved. One toggle turns it off; retention caps in between.
- 📁 **Files too** — drag audio in, or `Rhino transcribe file.m4a` from the
  terminal.

## Privacy, precisely

Your audio, transcripts, context, and AI cleanup never leave your Mac.
There is deliberately no remote transcription engine and no telemetry. The
only network calls are update checks (signed Sparkle feed) and model
downloads you trigger yourself — enforced by `tests/hygiene`, which fails
any push that opens a non-localhost connection during dictation.

## Build & develop

```sh
git submodule update --init --recursive
brew install cmake libomp rust
git config core.hooksPath Scripts/githooks
./run.sh          # build + launch (./run.sh build to build only)
```

See `AGENTS.md` for the full development guide and `decisions.md` for why
things are the way they are.

## License

MIT — see [LICENSE](LICENSE) and [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md)
for the excellent open-source work Rhino builds on.
