# Decisions

Append-only log of non-obvious choices: what was decided and the why that
would otherwise be lost. Newest last. Never rewrite old entries — if a
decision is reversed, append a new entry saying so and why.

Read this before re-litigating anything.

---

**2026-08-13 — The smart-formatting stray-marker backstop is input-aware.**
The small cleanup model sometimes prefixes ordinary one-line prose with a list
marker, but a one-item list is valid output. Rhino strips a one-line marker only
when the original transcription has no explicit list cue; spoken “bullet” /
“number one” cues and existing markers are preserved. This keeps the prose
backstop without undoing formatting the user requested.

**2026-08-13 — Smart formatting is a prompt section inside LLM cleanup, not a
separate pipeline pass.** Turning "item 1, yes, item 2, no" into a list needs
semantic judgment (is this an enumeration or prose?), which deterministic
regexes get wrong in both directions — so the feature rides the existing
cleanup LLM as an extra system-prompt section plus a carve-out in the
user-message wrapper (whose blanket "do not add anything" would otherwise
forbid the bullets). It is off by default and nested under "Clean up with an
LLM" in Settings because it loosens the transform-only contract and requires
the ~1 GB model anyway; onboarding does not flip it on.

**2026-08-13 — Feedback is direct email, not a hosted form or upstream link.**
Rhino mirrors Meeting Coach's small menu-bar feedback form and hands a
prefilled `mailto:` draft to the user's email client at
`noahkagan@gmail.com`. This restores an intentional Rhino-owned feedback path
without adding telemetry, a backend, or any network request made by Rhino.

**2026-08-12 — The app icon uses a committed illustration master, not Apple
Color Emoji.** `Scripts/Assets/rhino-app-icon.png` is the reproducible source;
`Scripts/make-icon.swift` downsamples it with high-quality interpolation and
clips it to Rhino's native macOS squircle for every ICNS size. This removes the
emoji-source blur and keeps the app icon aligned with the AppSumo artwork. The
menu-bar icon remains a monochrome template silhouette because that is the
native macOS treatment for status items.

**2026-08-12 — AppSumo uses Codes, not Licensing.** The marketplace offer is
one $5 AppSumo redemption code with lifetime product updates and usage on
unlimited Apple-silicon Macs. The redemption system is being built. Since the
base code is already unlimited and no higher allowance exists, the initial
listing does not enable code stacking.

**2026-08-10 — Fork OpenSuperWhisper, don't rebuild.** 467 commits of
working hotkey/audio/text-insertion/engine code (MIT-licensed). The work
is stripping remote paths, grafting process, rebranding — not rewriting
solved problems.

**2026-08-10 — This is a product to distribute, not a personal tool.**
Own brand (now Rhino), own site, signed/notarized DMG, full release
pipeline. Cribbed from MeetingCoach's pipeline in Phase 3.

**2026-08-10 — HARD CONSTRAINT: private, all-local.** Nothing goes to any
cloud; open-source on-device models only. This is the differentiator vs.
Wispr Flow ("your voice never leaves your Mac"). Only acceptable network
calls: Sparkle updates to our own appcast, explicit user-initiated model
downloads. Remote ASR and remote LLM cleanup get deleted (code paths, not
just UI) in Phase 1, and a hygiene gate makes the promise regression-proof.

**2026-08-10 — Private mirror, not a GitHub fork.** GitHub can't make a
fork of a public repo private, so `noahdevkagan/rhino-app` is a fresh
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
Sparkle-only and the release-notes feed will live on the Rhino site.

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

**2026-08-10 — The app's final name is Rhino** (Noah: "it just goes
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

**2026-08-11 — CI releases are tag-driven and secret-gated; local
release.sh stays the working fallback.** release.yml (cribbed from
MeetingCoach) runs on every v* tag: the test gate always runs, but the
sign/notarize/publish job checks for the signing secrets first and skips
green with a notice when they're unset — so until Noah uploads secrets,
tags stay quiet and Scripts/release.sh (proven: shipped v0.1.0) is the
publish path, with no risk of a double- or half-publish. CI never bumps
versions: it verifies the tag matches MARKETING_VERSION + CHANGELOG and
fails fast, keeping "what's tagged is what's shipped" true. The
fresh-checkout preamble (cmake configure, libomp vendoring, SwiftPM
resolve + FluidAudio patch) moved to Scripts/prepare-build-deps.sh,
shared by run.sh, make-test-dmg.sh and CI — it also fixes the fresh-clone
bug where run.sh copied libomp into a build/ dir that didn't exist yet.
build.yml is now a thin wrapper calling test-gate.yml (its macos-26 pin
existed for the deleted Apple Speech engine; rust was for the deleted
autocorrect submodule).

**2026-08-11 — Elided-word reconstruction is a cleanup-prompt clause, not
code.** Dropped function words ("Schedule review" for "Schedule the
review", corpus h01) are context-dependent — the opposite of
NumberCompaction's deterministic cases — so the fix is an explicit
restoration rule in the cleanup prompt (with a worked example; the 1.5B
model follows examples, not abstractions), scoped to short function words
with "never add names, facts, or any other words" keeping the
transform-only contract. A/B on the real Qwen2.5-1.5B (greedy, app's
exact prompt assembly): new prompt restores h01's "the" and "a buffer
week before the launch date"; old prompt left both broken; all
pass-through and question-trap cases byte-identical. Reconstruction
therefore only works when cleanup is enabled — by design, dictation
never requires the 1GB model. The prompt also stopped being a pref: its
editing UI died in the 80/20 axe, so a launch migration drops any stored
copy (installs from the editable era would otherwise be pinned to old
wording forever).

**2026-08-11 — Sparkle key rotated (fallback path).** The original EdDSA
key lives only on the marathon dev machine's keychain; releasing from
the laptop meant either exporting it or rotating. Rotated: new keypair
(keychain account "Rhino" on the laptop), new SUPublicEDKey in
Info.plist from 0.1.1 on. Cost, accepted knowingly: the two v0.1.0
installs (Noah + Nick) pin the old public key, so their Sparkle
update to 0.1.1 fails signature verification — they re-download the DMG
once. Every install from 0.1.1 forward updates normally. The Developer
ID cert was likewise re-issued from the laptop (new CSR) rather than
exported — Gatekeeper/notarization accept any valid team cert, so that
rotation costs nothing.

**2026-08-11 — Retired working-name references were scrubbed.** The Rhino
rename now applies to source comments and project documentation as well as
the shipped product. The historical decision entries were updated in place
for this one explicit cleanup so repository-wide name searches cannot revive
stale branding.

**2026-08-11 — Rhino's homepage is a one-screen $20 purchase page.** The
first site pass overbuilt the brief with feature, privacy, setup, FAQ, and
repeat-CTA sections. Noah's screenshots clarified the target: retain only the
header, product hero, PayPal purchase, and a compact footer; put release history
on `/changelog` and the DMG on the post-purchase `/thanks` route. Checkout uses
the same `paypal@okdork.com` account, one-time $20 price, and 30-day guarantee
as MeetingCoach. The visible logo renders the system rhino emoji at its native
display size instead of enlarging the app icon's cropped emoji bitmap, which
keeps it sharp on Retina screens.

**2026-08-11 — The public site lives in `website/` beside the app.** It
is a self-contained Sites/vinext project so web dependencies and builds
cannot disturb Xcode, while the product, release automation, and website
copy still evolve in one repository. The first launch page is intentionally
one route: direct notarized DMG download, concrete local-only privacy proof,
three-step onboarding, product FAQ, and no account or payment flow. Its
download URL is pinned to the tested v0.1.2 asset rather than resolved at
request time; updating that one constant is part of each release until the
release workflow automates it.

**2026-08-11 — The website favicon uses a full rhino, not the app or tray
crop.** The app artwork deliberately zooms into the emoji's face and the tray
art reduces it to a monochrome silhouette; both become ambiguous in a browser
tab. The site now generates a 512px coral tile with the full native rhino emoji
and publishes it through Next's `app/icon.png` convention, which emits an
explicit cache-busted favicon link that browsers reliably discover.

**2026-08-11 — Shortcut hints read `recordingTriggers`, never legacy
slots.** The recorder moved to a unified trigger list, but Home and the
legacy recorder footer still read `modifierOnlyHotkey` / `toggleRecord`.
Fresh installs therefore displayed an em dash even while hold-Fn was
armed. Compact hints now use the first unified trigger (the complete list
remains visible in Settings), so displayed instructions cannot drift from
the keys ShortcutManager actually monitors.

**2026-08-11 — Dictionary editor rows bind by UUID, not array position.**
Deleting a rule synchronously removes its array slot while AppKit is still
ending the popover's focused text-field edit; SwiftUI's generated
`ForEach($entries)` binding then reads that stale slot and traps in
`Array.subscript`. Each row binding now resolves the rule's UUID on every
access. Once removed, teardown reads return the last rendered value and late
text commits are ignored, so deletion remains immediate without retaining an
invalid positional binding.

**2026-08-11 — Modifier-only triggers require Input Monitoring, not just
Accessibility.** Fn appeared to work only while Rhino was focused because its
listen-only `flagsChanged` event tap was created but disabled for other apps by
macOS TCC. Rhino now requests event-listening access when a modifier trigger is
armed, shows Input Monitoring as its own missing permission, and rebuilds the
tap when access arrives. Key-combination-only setups do not request it. We keep
the tap listen-only and subscribe only to modifier-flag changes; switching to a
more powerful active tap merely to reuse Accessibility would broaden capability
without improving the product.

**2026-08-11 — The changelog is the release command's source of truth;
release tags are immutable.** `Scripts/cut-release.sh` derives the next version
from the newest numbered changelog section, rejects versions that are not newer
than the existing tags, and refuses to carry unmerged code or unrelated dirty
files into a release. It selects the tag-driven CI publisher only when all
eight signing/publishing secret names exist; otherwise it uses the proven local
keychain publisher, so the same command works before and after CI credential
setup without double-publishing. The release commit and tag push atomically to
`origin/master`, and neither path force-moves a tag: a shipped version denotes
one exact source commit forever.

**2026-08-12 — AppSumo redemption mirrors MeetingCoach's hashed static gate.**
Rhino's 10,000 random `RH-XXXX-XXXX-XXXX` codes are delivered as a private,
gitignored CSV while the website ships only their SHA-256 hashes. The browser
hashes an entered code locally before revealing the already-public signed DMG;
no plaintext codes, customer data, account system, telemetry, or new backend
exist. This deliberately is a lightweight AppSumo fulfillment gate rather than
one-time license enforcement: it matches the proven MeetingCoach flow and the
download itself is public, so a database would add personal-data and operating
surface without protecting a private asset.

**2026-08-12 — Accessibility is Rhino's single required keyboard TCC grant
(reverses the separate Input Monitoring requirement).** Apple DTS confirms
that Accessibility authorizes both event posting and listening, while Input
Monitoring authorizes listening only. Rhino already needs Accessibility to
insert dictated text, so forcing a second permission for the listen-only Fn
tap was redundant and produced a false-negative loop when System Settings
showed Input Monitoring enabled but the running process still saw cached TCC
state. The tap remains listen-only and watches only modifier flags; it now
accepts either grant for compatibility, while Rhino requests and displays only
Accessibility. Debug builds also use the real TCC result so permission UI can
never claim a global trigger will work when macOS will block it.

**2026-08-12 — First-use shortcut setup uses compact choice cards, without a
full keyboard diagram.** The diagram scaled its keys from the live window width
but reserved height from a hard-coded narrower width, so it escaped its bounds
and covered the model picker in the default 900-point window. The two shortcut
cards already communicate the complete choice and remain the single control;
removing the decorative duplicate makes onboarding shorter and eliminates the
fragile custom keyboard layout.

**2026-08-12 — Sparkle release notes are embedded from the canonical
CHANGELOG section.** Both local and CI publishers extract the exact version's
Markdown into a sidecar matching the DMG name, then run `generate_appcast` with
embedded release notes and refuse to publish an appcast without the Markdown
description. Embedding makes the standard Sparkle update prompt show what
changed without adding another network request or a second source of release
copy; GitHub releases consume the same extracted text.

**2026-08-13 — Dictation hot path: insert before history save; kill dead I/O
probes.** Three fixed overheads sat between the engine finishing and the text
landing, none of which affected transcription quality: (1) `transcribeAudio`
serially awaited an `AVAsset.load(.duration)` whose result (`totalDuration`)
was never read anywhere — removed; (2) `DictationPipeline.process` moved the
WAV into history and awaited a second `AVURLAsset` duration probe BEFORE
pasting — reordered so insertion (what the user is watching) comes first and
the bookkeeping after, with a history-save failure logged instead of surfacing
as a failed dictation (the text already reached the user); (3)
`AudioRecorder.stopRecording` re-opened the just-written file with
`AVAudioPlayer` only to discard sub-1s clips — it now uses the recorder's own
`currentTime` captured before `stop()`. The Silero VAD context is also built
at engine load rather than lazily inside the first dictation. Decode params
were deliberately left untouched (greedy, temp 0, GPU+flash-attn already on):
every remaining millisecond in the bench is whisper decode, and shrinking that
means a smaller model or fewer fallback retries — an accuracy trade this
change refuses. Gate bench (tiny.en, 4 clips, warm): p50 ~470ms → ~435ms;
WER unchanged (0.0% on all main cases, no silence hallucination).

**2026-08-13 — Keep Silero VAD lazy; zero-length recorder output is short
audio.** This reverses only the VAD warm-up portion of the latency decision
above. Whisper engines are themselves created lazily inside the first
`transcribeAudio` call, so building the VAD in `initialize()` merely moved the
same work earlier within that hot path; it also loaded VAD unnecessarily when
timestamps bypass speech detection. VAD therefore remains lazy in
`detectSpeech`. The recorder still avoids reopening its WAV, but a measured
duration of zero (or a missing/non-finite duration) is now discarded alongside
all other sub-second clips instead of sending empty audio into transcription.

**2026-08-18 — Enabling LLM cleanup auto-starts the model download.** With no
model on disk the whole cleanup pass (smart formatting included) silently
returns the text unchanged, and the first v0.1.7 tester read that as
"formatting doesn't work": both toggles sat green while doing nothing. The
toggle is now the consent to fetch the ~1 GB model — flipping it on starts the
download immediately with inline progress, instead of relying on the user to
notice a separate button. The button stays as the retry/fallback path (failed
download, or a relaunch that finds the toggle on with no model), and its hint
now states that cleanup is skipped until the model is present. Explicitly
user-initiated, so it stays within the all-local/no-surprise-network rule.

**2026-08-18 — Desktop release cuts must hard-fail on an unsigned appcast
item.** v0.1.8 was cut from the desktop, whose keychain "Rhino" key is the
pre-rotation one; `generate_appcast` only warned about the SUPublicEDKey
mismatch and published the item with no `edSignature`, which installed apps
download and then reject. `release.sh` now blocks the release before touching
the feed when the new item lacks a signature. Sparkle signing remains
laptop-only by design (see 2026-08-11 rotation entry) — a desktop cut gets
everything ready and stops at the feed step.

**2026-08-18 — Releases move to the desktop; Sparkle key rotated back to the
original keypair.** The laptop holding the 2026-08-11 rotated key is in
another location and this desktop is now the release machine. Its keychain
"Rhino" key turned out to be the ORIGINAL v0.1.0 keypair, so rather than
generating a third key, SUPublicEDKey was rotated back to it. Cost, accepted
knowingly (same shape as 2026-08-11): installs of 0.1.1–0.1.8 pin the laptop
key and cannot verify the next update — they re-download once from the
website; v0.1.0 installs regain auto-update. v0.1.9 re-ships 0.1.8's code
with the new embedded key. If the laptop's key is ever needed again it still
exists there; nothing signed by it is trusted by 0.1.9+ installs.
