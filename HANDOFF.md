# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-09-11, taipei workspace: customer-feedback triage → fixes)

### Fn-to-recording launch-delay evaluation (2026-09-17, sarajevo workspace)

Implemented plan: shorten the entrance to 120 ms; resolve caret and window
title on background queues using the captured target PID; reject late results
from previous recordings. Preserve recorder serialization and device fallback.
Build passed; relevant regression checks below. Existing timing excludes event
delivery, first audio, and first rendered frame; animation is a hypothesis,
not a measured 350 ms startup penalty.

Diagnostic complete against the installed v0.1.23 app's unified hot-path log
(nine Fn starts, cursor-position indicator). From the logged key-down handler
to `AVAudioRecorder.record()` returning: median 77 ms, range 56–231 ms. The
median synchronous UI path was only ~8 ms; actual audio setup after it was
~66 ms. The entrance effect was a possible contributor: 50% scale / +20 pt /
zero opacity and a 0.35-response spring. The slow 231 ms tail included a 55 ms
caret query and a 50 ms start method (not individually instrumented inside),
followed by a 99 ms recorder start.

Implemented on user request: 120 ms entrance (0.95 scale / 4 pt motion), and
asynchronous PID-pinned caret/title queries with stale-result guards. The
bubble initially appears at the mouse and then moves to the resolved caret.
Only after further measurement should we prototype reuse
of the prepared `AVAudioRecorder` (current init+record median 43 ms, but stale
AirPods-device risk makes this the risky option). The 0.3 s hold threshold does
not delay start. Separate diagnostic bug found: `MainThreadWatchdog.check()`
uses wrapping subtraction, so a heartbeat racing ahead of its sampled `now`
logs a fake 18,446,744,073-second stall; fix independently, not as the latency
solution. Build passed; 24 targeted tests for caret decisions, indicator
layout, recording duration, AirPods fallback/taps and chime passed. Static
privacy hygiene passed (dynamic egress check skipped). All 30 trigger/access
regression tests also passed (54 targeted tests total).
No physical-key-to-first-audio/frame timing has been measured; the installed
app was subsequently superseded by the dev launch at the user's request.

Measurement completed after the user enabled dev Accessibility: 18 real Fn
starts at 13:15:40–13:15:57, Sep 17, PID 11826. Handler-to-record-return median
50.7515 ms, maximum 66.899 ms, minimum 44.419 ms. Earlier nine-sample baseline
was median 77 ms / maximum 231 ms. Separate sessions and rapid warm presses:
these are observed results, not a controlled causal benchmark or guaranteed
upper bound. Dev build remains running; installed app on disk is untouched.
Earlier synthetic probes produced zero events before permissions were granted
and are excluded. `.context/startup-timings.py` pairs unified-log events.

### Auto-detect cleanup language fix (2026-09-15, shanghai workspace)

Confirmed against the installed v0.1.22 binary and real embedded Qwen 1.5B
model: this is a cleanup regression specific to language Auto-detect. Across 36
sequential cleanup probes (six representative German inputs repeated six
times), five of the six inputs were deterministically translated into English;
the email-shaped input stayed German. Setting the same isolated prefs suite to
explicit German kept all six outputs German. Fixed by resolving Auto locally
with Apple's on-device `NLLanguageRecognizer` when confidence is ≥0.80, feeding
the resulting named language to cleanup, and rejecting any confident
input/output language switch as a final fail-closed guard. The rebuilt app kept
all 36/36 probes German. Build and the complete `OpenSuperWhisperTests` suite
pass; `Scripts/verify-german.sh` now tests cleanup under both `de` and `auto`.
The separate number-word bug remains: `einundzwanzig` became 18 before the fix
and 19 with named German cleanup.

Customer report (kids-movie user) triaged; Noah is shipping 0.1.21 for the
AirPods wedge separately. **All three fixes below are implemented, gate-green,
and up as PR #51** (`crxnamja/customer-feedback-triage-v1`; tests in
CustomerFeedbackGuardsTests; decisions.md 2026-09-11):

1. **Stuck indicator hardening** — decode-state watchdog (bubble hides after
   120s if the pipeline never drains), Esc dismisses the bubble in ANY state
   (was recording-only, and Rhino kept swallowing Esc system-wide while
   stuck), `hide()` now clears an orphaned panel even with no view model.
   (A menu-bar "Cancel Dictation" item was built, then removed on Noah's
   review.)
2. **Verbatim in AI & terminal apps** — LLM cleanup is skipped when the
   dictation's captured target app (the previously-unused `bundleID` param
   of `LLMPostProcessor.process`) is an AI assistant or terminal, so
   meta-instructions meant for Claude pass through verbatim. Pref
   `verbatimInAIApps`, default ON.
3. **Long-recording hold** — a clip ≥5 min (movie-while-recording case) is
   copied to the clipboard + flashed instead of auto-pasted; history still
   saves. Pref `reviewLongRecordings`, default ON.
   Both toggles live under Settings → Advanced → Safeguards (Noah's call).

Not done here (needs the 1.5B probe cycle): delimiting the transcript in the
cleanup prompt (fenced block) as injection hardening for non-verbatim apps.

## Previous state (2026-09-05, Noah's Mac: AirPods "Connecting…" hang, both fixes → 0.1.21)

Noah's report: AirPods on, hotkey → "Connecting…" forever, app looked hung.
Log showed the live-preview tap raising an ObjC exception (stale engine
format after AirPods reconnected) that wedged the main dispatch queue; the
WAV kept recording. Branch `claude/airpods-live-preview-fix` carries:
(1) the reapplied 2026-09-01 disconnect fix (revert of revert 8f9c407),
(2) fresh AVAudioEngine per tap + hardware format + `RhinoCatchObjCException`
guard (MicTap.swift, ObjCExceptionCatcher.m via Bridge.h), MicTapTests.
Staged 0.1.21 (CHANGELOG, website pins + rendered-html test). Noah field-tests
on landing: AirPods dictation, AirPods-reconnect-then-dictate, AirPods-into-
case-then-dictate (expect built-in mic fallback ≤4s). See decisions.md
2026-09-05 and 2026-09-01.

## Previous state (2026-08-31, davao workspace: merging master into latency PR)

Current plan: fetch the latest `origin/master`, merge it into
`crxnamja/parakeet-latency-trim`, preserve both sides of the append-only
`bench/history.jsonl` and `decisions.md` conflicts, validate the resolved
tree, then commit and push the merge branch.

### Latency work completed before merge

Stop-to-text latency PR implemented and gated (field report: 3.2s clip
603ms warm ASR, 986ms median stop-to-text vs Wispr Flow 677ms). Shipped in
this branch: stage instrumentation (bench JSON "stages", "ASR stages:" /
"LLM cleanup pass:" log lines, `Rhino cleanup --repeat`), warm-up inference
at Parakeet load, samples-based FluidAudio invocation, CTC boost-vocabulary
cache, LlamaContext KV-prefix reuse + recording-start prefill. Measured on
this Mac (M4, macOS 15.6): warm 3.2s offline ASR 80ms; boosted 240→82ms;
cleanup one-sentence 655→300ms, smart-formatting 2,550→404ms. The field ASR
slowness did NOT reproduce here — next diagnose report will carry the stage
split. Details in decisions.md (4 entries, 2026-08-31). Full push gate green.
Verification: new `bench/parity/parity.sh` byte-compared this branch vs
master (cleanup ×3 configs ×24 inputs incl. sequential shared-KV mode via
new `cleanup --stdin`; ASR offline+boosted) — all identical. Found the
boost path nondeterministic on unchanged master (decisions.md). Report on
PR #39. Follow-up for Noah's M3 Max: stopwatch + bench there (steps in the
PR comment).

## Previous state (2026-08-27, overnight)

- **Master is fully staged for v0.1.15 — NOT yet tagged/released.** Noah
  aborted last night's cut mid-run ("just wait for all"); everything since
  merged in. Contents: spoken edits (self-corrections as a dedicated
  pre-cleanup LLM pass, #34), long-email formatting + no-period sign-off
  (#34), media resume via CoreAudio probe (#32), both wrong-language fixes
  (#33 cleanup pin, #35 Parakeet hint), AudioRecorder serial-queue race fix
  (#36), OpenSuperWhisper→Rhino scrub (#37), onboarding now recommends
  Parakeet v2 for English (Noah's call; Whisper turbo is the non-English
  row; v3 stays in Settings → Models).
- All FIVE release pins already point at 0.1.15 (CHANGELOG has the section;
  thanks page, AppSumo redeem, website changelog + entry, rendered-html
  test ×2). cut-release validated the section parses.
- CI hardening: pushes to `claude/**` branches now trigger Build Check
  (session containers have no local gate); one run per branch head via
  concurrency; the XCTest bundle is gate stage 2 locally AND on CI
  (`FAST=1` skips locally). CI release publish still skips (no signing
  secrets) — releases go through Noah's Mac.
- Spoken edits verified on the real 1.5B via `Rhino cleanup` probes on
  Noah's Mac: prompt-section design failed (model ignores delete-words
  instructions inside the keep-every-word cleanup contract), dedicated
  cue-gated pass works. See decisions.md 2026-08-26/27.

## Outstanding

- Smart formatting misses lists behind a hedged lead-in: "…which number
  one noah number two cypress…" stays prose (Noah repro 2026-08-31; CLI
  repro confirms — works without "which"). Fix = add a worked example to
  smartFormattingPrompt; needs the usual 1.5B probe cycle. Own small PR.

- **Noah's morning command** (his tree may hold a half-made local release
  from the abort):
  `git checkout master && git tag -d v0.1.15 2>/dev/null; git reset --hard origin/master && git pull && ./Scripts/cut-release.sh`
  Then notify the two German reporters to re-test.
- German number-word cleanup bug ("einundzwanzig" → "19") — restrict digit
  conversion to English or add German examples.
- Baseline cleanup sometimes drops a lead-in phrase ("She said …") — seen
  in probes, pre-existing; worth a bench case.
- `SlidingWindowAsrManager` (boost path + live preview) has no language
  parameter in FluidAudio 0.15.4; patch FluidAudio if reports continue.
- Carried forward: onboarding tester re-run; Parakeet RSS check (#27) never
  recorded; Apple Dictation double-🌐 race; `crxnamja/bern` items.

## Next session

Confirm v0.1.15 shipped (tag + appcast live, rhinovoice.app at 0.1.15);
then take the German number-word cleanup bug.
