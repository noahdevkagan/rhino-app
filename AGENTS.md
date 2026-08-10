# Agent guide — Rhino

Read this first. It is written for AI coding agents (Codex, Claude Code,
Cursor, …) and for humans who like commands over prose.

## Session workflow (context management)

This file is the seed doc — it auto-loads into every session. Three habits
keep long sessions and handoffs lossless:

1. **Plan before building.** Before any multi-step change, write the plan
   into `HANDOFF.md` under "Current state" → it survives context compaction.
2. **Log the why.** When you make (or reverse) a non-obvious design choice,
   append one entry to `decisions.md`: what was decided and why. Read it
   before re-litigating anything.
3. **Hand off at the end.** When the user wraps up ("done", "that's it for
   today"), run the `/handoff` skill: it rewrites `HANDOFF.md` (state,
   outstanding, next-session prompt) and commits. A SessionStart hook in
   `.claude/settings.json` injects `HANDOFF.md` into every new session
   automatically.

**What this is:** Rhino — a macOS dictation app (hold a hotkey, speak,
release, text lands in whatever app has focus). Private fork of
OpenSuperWhisper (MIT), being rebranded and hardened. **HARD CONSTRAINT:
all-local, zero cloud.** On-device ASR (whisper.cpp / Parakeet /
SenseVoice) and embedded-only LLM cleanup (llama.cpp/Qwen in-process — no
Ollama, no remote). The only acceptable network calls: Sparkle update
checks to our own appcast and explicit user-initiated model downloads.
Anything else that touches the network is a bug — tests/hygiene enforces
this. The build plan lives in the sibling repo `~/rhino` (PLAN.md).

## Setup (one time)

```bash
git config core.hooksPath Scripts/githooks  # enables the push gate (see Tests)
git submodule update --init --recursive     # whisper.cpp, llama.cpp, autocorrect
brew install cmake libomp rust
# optional, prettier xcodebuild output: gem install xcpretty
```

## Build & run

```bash
./run.sh build   # build only (Debug, unsigned) → Build/Build/Products/Debug/OpenSuperWhisper.app
./run.sh         # build + launch with logs in the terminal
```

A dev copy is the one under `Build/Build/Products/Debug/`; an installed
copy lives in /Applications. `run.sh` re-signs dev builds with a stable
identity so TCC (mic/accessibility) permissions survive rebuilds.

## Tests / push gate

Every `git push` runs `Scripts/push-gate.sh`: build → each `tests/*/run.sh`
suite. Docs/markdown-only pushes short-circuit. Escape hatches:
`SKIP_GATE=1 git push` (emergency), `FAST=1 git push` (skip slow cases).
Run the gate directly any time: `./Scripts/push-gate.sh`. Per-suite runners
live in each `tests/*/run.sh`.

Release tags are gated separately: pushing `vX.Y.Z` requires a `## X.Y.Z`
section in `CHANGELOG.md` at the tagged commit.

Upstream's own unit tests live in `OpenSuperWhisperTests/` (xcodebuild
test) — not yet wired into the gate; see HANDOFF.md.

## Repo map

| Path | What lives there |
|---|---|
| `OpenSuperWhisper/` | The app: SwiftUI views, `DictationPipeline.swift`, `Engines/` (whisper.cpp / Parakeet / SenseVoice), `Llama/` (local LLM cleanup), `Indicator/`, `Onboarding/`, CLI |
| `OpenSuperWhisperTests/` | Upstream unit tests (XCTest) |
| `libwhisper/` | CMake wrapper around whisper.cpp + llama.cpp submodules |
| `asian-autocorrect/` | Rust autocorrect submodule (builds a dylib) |
| `run.sh` | Dev build+run entry point (cmake → cargo → xcodebuild) |
| `make_release.sh`, `notarize_app.sh` | Upstream release flow (to be replaced in Phase 3) |
| `Scripts/` | Upstream helper scripts + `push-gate.sh` + `githooks/` (ours) |
| `tests/` | Push-gate suites: `hygiene` (privacy), `asr` (WER), `latency`, `smoke`; `insertion-manual.md` is human-run |
| `bench/` | Scorecard trend (`history.jsonl`) + `corpus/` (Noah's-voice head-to-head vs Wispr Flow) |
| `.github/workflows/test-gate.yml` | Same gate on CI; release workflows must `workflow_call` it |
| `docs/` | Upstream docs (PUBLISHING.md, release notes) |

## Gotchas (agents hit these)

- **Case-insensitive filesystem:** `Scripts/` and `scripts/` are the same
  directory on macOS, `build/` and `Build/` likewise. Never add a path
  that differs from an existing one only by case — git will happily record
  both and checkouts get weird.
- First build is slow: cmake-configures libwhisper, cargo-builds the
  autocorrect dylib, fetches sherpa-onnx, resolves SwiftPM packages, and
  patches FluidAudio. Subsequent builds are incremental.
- `run.sh` expects Homebrew libomp at `/opt/homebrew/opt/libomp` and
  vendors dylibs into `build/` — don't clean that dir casually.
- Don't kill a running dev app with `pkill OpenSuperWhisper` while testing
  dictation — you'll orphan the mic session; quit it from the menu bar.
- The privacy constraint is enforced socially for now: grep for new remote
  endpoints before merging anything. The hygiene gate (Phase 1) will make
  it mechanical.
