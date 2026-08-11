# Decisions

Append-only log of non-obvious choices: what was decided and the why that
would otherwise be lost. Newest last. Never rewrite old entries — if a
decision is reversed, append a new entry saying so and why.

Read this before re-litigating anything.

---

**2026-08-10 — Fork OpenSuperWhisper, don't rebuild.** 467 commits of
working hotkey/audio/text-insertion/engine code (MIT-licensed). The work
is stripping remote paths, grafting process, rebranding — not rewriting
solved problems.

**2026-08-10 — This is a product to distribute, not a personal tool.**
Own brand (Toucan), own site, signed/notarized DMG, full release
pipeline. Cribbed from MeetingCoach's pipeline in Phase 3.

**2026-08-10 — HARD CONSTRAINT: private, all-local.** Nothing goes to any
cloud; open-source on-device models only. This is the differentiator vs.
Wispr Flow ("your voice never leaves your Mac"). Only acceptable network
calls: Sparkle updates to our own appcast, explicit user-initiated model
downloads. Remote ASR and remote LLM cleanup get deleted (code paths, not
just UI) in Phase 1, and a hygiene gate makes the promise regression-proof.

**2026-08-10 — Private mirror, not a GitHub fork.** GitHub can't make a
fork of a public repo private, so `noahdevkagan/toucan-app` is a fresh
private repo holding the full upstream history, with upstream kept as a
git remote (`upstream`) for future pulls.

**2026-08-10 — Gate scripts live in `Scripts/` (capital S), not
`scripts/`.** Upstream already has `Scripts/`; macOS's case-insensitive
filesystem would silently merge the two while git records both paths.
Hooks path is `Scripts/githooks`.

**2026-08-10 — No Dependabot.** Config deleted, its 8 auto-PRs closed.
Submodule/SwiftPM auto-bumps are risky here (run.sh patches FluidAudio
source; whisper.cpp/llama.cpp bumps need real testing). Deps get bumped
deliberately, gated by the push gate.

**2026-08-10 — Phase 1: Remote ASR engine and remote LLM cleanup deleted
(code paths, not hidden UI).** 7 app files + 9 test files removed, plus
all prefs/UI plumbing. Stale `selectedEngine == "remote"/"groq"` migrates
to "whisper"; stored `aiBackend == "remote"` migrates to "builtin"; the
three remote API keys are scrubbed from the Keychain on launch (no code
can use them anymore). `usedLocalFallback` stays as a DB column and an
always-false flag so old history rows keep decoding.

**2026-08-10 — UpdateChecker deleted (the second update path).** Upstream
had Sparkle AND an unauthenticated GitHub-releases poll that pinged
api.github.com with the user's IP when Settings opened. Sparkle to our own
appcast is the ONE sanctioned update channel; the Updates tab is now
Sparkle-only and the release-notes feed will live on the Toucan site.

**2026-08-10 — Ollama cleanup endpoint is loopback-pinned in code.** The
endpoint field is free text, so `OllamaBackend` refuses any host that
isn't localhost/127.0.0.1/::1 — no DNS resolution (could change under
us), no LAN ranges (another machine is still another machine).

**2026-08-10 — ATS re-enabled.** `NSAllowsArbitraryLoads` existed solely
for the remote engine; replaced with `NSAllowsLocalNetworking` only.
Sparkle + model downloads are HTTPS and pass full ATS.

**2026-08-10 — PLAN.md was rewritten upstream (00:29) and the session
discovered it late.** The new plan wanted compile-time guards instead of
deletion; Noah chose to KEEP the deletion (privacy is the product; deleted
code can't regress; upstream fixes become cherry-picks). Adopted from the
new plan instead: no Ollama in v1, no post-record hook, history off by
default, layered privacy verification, personal-corpus benchmark before
public quality claims, rebrand last.

**2026-08-10 — App renamed Toucan → Rhino** (Noah: "it just goes
forward"). Repos are noahdevkagan/rhino (plan) and noahdevkagan/rhino-app
(code); local clones ~/rhino and ~/rhino-app. In-app rebrand (bundle id,
icon, Sparkle feed) still deferred to the productization phase per plan.

**2026-08-10 — Ollama backend and post-record hook removed from v1.**
Embedded llama.cpp/Qwen is the only cleanup backend (one less process,
socket, and misconfigurable endpoint); the hook was an unbounded egress
channel ("run any shell command with the transcript"). Both come back only
if measured demand justifies the support surface. aiBackend normalizes to
"builtin" on launch.

**2026-08-10 — Transcription history is OFF by default.** A log of
everything you ever said is opt-in, not opt-out (privacy-safe defaults per
plan). Existing installs that had it on keep their stored choice.

**2026-08-10 — Silence-hallucination fix in WhisperEngine.** When Silero
VAD finds no speech AND the clip peaks below 0.004 (digital silence / dead
mic, two orders of magnitude under real speech), return "" instead of
running whisper — tiny models hallucinate "you"/"Thank you." on silence
and that text would be typed into the user's document. A quiet sentence
the VAD merely missed still goes through whole (peak check fails).
Found by the tests/asr silence case on its first run.

**2026-08-10 — Gate ASR/latency suites run the bundled whisper-tiny in an
isolated $HOME.** Hermetic (no downloads, no real-prefs contamination) and
fast, at the cost of not measuring the shipping engine — the gate detects
regressions; absolute quality lives in bench/corpus (Noah's voice, real
models, vs Wispr Flow). Latency budgets set from measured actuals
(p50 393ms / max 861ms → bars at 800/2000ms), ratchet down over time.

**2026-08-10 — tests/hygiene is the privacy regression gate.** Static:
forbidden endpoint strings, resurrected remote files, ATS exemption.
Dynamic: a real CLI transcription in an isolated $HOME with `lsof`
sampling — any non-loopback socket fails the gate. The detector itself is
negative-tested (a synthetic remote lsof row must trip it). Fix the code,
never the gate.
**2026-08-10 — History ON by default (reverses the earlier off-default).**
Noah's call: "it should store everything to the local computer." Local
history is the product's memory — the Home stats page, rerun, and search
are its payoff. The privacy promise is "never leaves your Mac", not
"never exists". The privacy-safe-defaults idea survives as the retention
caps and the one-toggle off switch surfaced at the top of History.

**2026-08-10 — Main window is sidebar + Home/History/Dictionary**, per
Noah's Typeless mockups (white-first, stat tiles, dictionary as a
first-class tab). Settings stays its own window.

**2026-08-10 — Upstream-facing UI stripped; Sparkle neutered until we
have our own feed.** Feedback tab, Ko-fi, their GitHub links: gone (MIT
only requires the license notice, which stays). SUEnableAutomaticChecks
is false and the Check-for-Updates entry points are removed because the
feed URL still targets upstream's appcast — an "update" from there would
replace the hardened build with stock OpenSuperWhisper.

**2026-08-10 — In-app rebrand executed (pulled forward from Phase 4 by
Noah).** Rhino.app / com.noahkagan.rhino, module name pinned to
OpenSuperWhisper so 460+ files and all tests keep compiling — display
identity and code identity are deliberately decoupled. One-time migration
carries prefs + Application Support across the bundle-id change; TCC
can't migrate and re-prompts once. Icon is generated code
(Scripts/make-icon.swift), not a binary asset — regenerate, don't edit.
Forced light appearance: white-first is the design, not a theme option.

**2026-08-10 — The 80/20 axe (Noah: "cut it all").** Removed: per-app
Rules (model rules, formatting profiles, ask/auto modes, browser-URL
capture + its AppleScript automation permission), SenseVoice and Apple
Speech engines (whisper + parakeet remain; sherpa-onnx/onnxruntime
vendoring goes with them), Asian autocorrect (and the entire Rust/cargo
build dependency), translation-to-English, mouse-button/latch-with-space/
stop-and-submit/paste-last/voice-command-submit triggers (one shortcut or
modifier + Esc remains), indicator layout editor + on-bubble buttons +
text-scale UI (position picker incl. notch stays), whisper tuning knobs
and editable cleanup-prompt/filler-regex UI (prefs keep good defaults),
volume ducking (pause-media stays). Rationale: settings sprawl nobody
opens, native deps that slow every build, and permissions that widen the
privacy surface. Everything is one git revert away if measured demand
returns.

**2026-08-10 — Speed: engine + LLM warm at launch.** The selected ASR
engine and (when cleanup is on) the llama context load at launch instead
of on the first dictation — first hotkey of the day now behaves like the
tenth. Guarded on completed onboarding so preload can never trigger a
surprise model download.

**2026-08-10 — App icon is a face crop, menu bar is a silhouette** (both
generated by Scripts/make-icon.swift from the rhino emoji — the app-icon
zoom parameters and the alpha-mask silhouette live in code, so brand art
later is a script edit, not an asset hunt).

**2026-08-11 — Deterministic number compaction runs before the LLM.**
"forty-two thousand" → "42,000", "thirty-eight percent" → "38%",
"four p. m." → "4pm" — as code, not prompting: the corpus proved the 1.5B
model won't comply reliably (h02). Deliberately conservative: bare small
number words ("the one thing", "one-on-one", "two lemons") and ambiguous
runs ("ten thirty") are left alone — a wrong conversion types itself into
the user's document. Halved corpus WER (12.6 → 7.8 → 5.3 with variants).

**2026-08-11 — Gate prefs isolation is RHINO_PREFS_SUITE, not $HOME.**
The suites' `HOME=$SCRATCH defaults write` never isolated anything:
`defaults` and the app both talk to cfprefsd, which keys domains by USER.
Every gate run silently rewrote the developer's real settings (engine →
whisper-tiny, history off) — the source of the night's mystery pref
drift. Now scripts seed a named suite and the app opts into it via env.

**2026-08-11 — Benchmark uses accept-variants.** Formatting taste
($42,000 vs 42k, 4:00pm vs 4pm, bullets, resolved self-corrections) never
decides the score: items carry human-reviewed acceptable outputs, best
match wins, same bar applied to every engine. First honest head-to-head:
Typeless 10/10, Rhino 8/10 (80% of target; both remaining misses are
recording artifacts, not product gaps).

**2026-08-11 — Cleanup is offered in onboarding, still opt-in.** A
"Punctuation & cleanup — recommended" card with an explicit ~1GB download
button; enabling toggles aiPostProcessingEnabled and preloads. Dictation
never requires it.

**2026-08-11 — Hands-free lock is a double-tap, not the single-tap
toggle.** Double-press the trigger inside 0.35s to lock recording on
(release stops nothing; next press stops), `doubleTapLock` pref, on by
default, toggle in Settings → Shortcut. The second press deliberately
does not arm push-to-talk's hold timer, so double-tap-and-hold still
locks. Single-tap toggle and hold-to-talk are unchanged — the lock only
rescues the case where a second press lands while recording is live,
which previously killed the recording.

**2026-08-11 — Transcription failures say why; onboarding proves the
model loads.** The shared-DMG new-user failure: every engine error
collapsed into a bare "Transcription failed" flash. Now the flash and
the failed history row name the actionable cause (model not loaded /
audio unreadable), onboarding's Continue test-loads the selected engine
before setup can finish (a truncated download otherwise fails on every
first dictation — worst first impression), and whisper downloads are
size-checked (≥95% of catalog size) with stale partial files deleted
instead of short-circuiting retries as "done".
