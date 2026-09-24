# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-09-11, taipei workspace: customer-feedback triage → fixes)

### Master merge (2026-09-24, halifax workspace)

Merged origin/master (e7e9e84) into local/test-speed-plus-media. Resolved
HANDOFF.md by preserving the optimization/recovery notes and master's shipped
0.1.27 status; retained both sides of bench/history.jsonl in date order.
App code merged without conflicts. Next: full push gate and push to PR #59.

### Warm-up failure recovery (2026-09-24, halifax workspace)

Implemented: clear uncertain KV state if either warm-up decode or rewind fails;
mark decode shapes warm only after all required steps succeed. Real-model
failure/retry regression added. Build and seven speculative/cache tests pass
(zero skips); 48/48 benchmark outputs byte-identical to the pre-fix branch.
Timing is observational: sum of warm input medians 6.17 s before / 6.50 s after
in separate runs. Model, prompts, draft policy and truncation behavior intact.
Committed and pushed in PR #59; full push gate passed. Not installed or
released. Logs: `.context/speed-audit/warmup-fix*`.

### Release→paste speed audit #2 (2026-09-23, halifax workspace)

Audit only, no production change: `docs/performance-audit-2026-09-23.md`. On v0.1.26
with Noah's settings, LLM generation is 70–90% of the wait (ASR 62–82 ms, paste ~1 ms).
(1) Prompt-lookup speculative decoding prototype: 249 words 4.3 s→0.76 s, 77 words
1.4 s→0.44 s, lists break-even, 195/195 outputs byte-identical. (2) First generate on
a fresh context costs +400 ms; a 2-token throwaway in prewarm removes it. 56% of Noah's
dictations follow the 5-min idle unload. Next: implement #2 (tiny), then #1 with
parity harness + real-model tests; add stop→paste Diag marks; fix watchdog log spam.
Harness: `.context/speed-audit/`.

**Implemented (Noah: "do both"), uncommitted:** `LlamaContext` speculative decoding +
prefill decode-shape warm-up, new `LlamaSpeculativeDecodingTests`. Build ✓, unit
424 pass / 6 skip / 0 fail, parity.sh vs installed 0.1.26 96/96 cleanup + ASR
identical, multilingual 16/16, gate suites ✓. Not installed/released. Next: commit/PR,
check thresholds on an M1/M3, then stop→paste Diag marks + watchdog log-spam fix.

### Free sharing shipped — v0.1.27 (2026-09-23, pretoria workspace)

User said “ship it.” Released 0.1.27 / build 76, source commit/tag b308275,
pushed to origin/master. Public release:
https://github.com/noahdevkagan/rhino-releases/releases/tag/v0.1.27
Signed app and DMG both accepted by Apple; stapled DMG validation passes.
Sparkle signed item published in rhino-releases main at 9ae2555; website
Cloudflare deployment 9bc2d1b1-f1d1-4597-bcc4-bee3546de333 is live. Verified
/thanks, /appsumo’s redeem-form JS, and /changelog serve the new version.
Raw GitHub feed was still CDN-cached at 0.1.26 immediately after publishing
(max-age 300); GitHub contents API confirms the signed 0.1.27 item on main.
Tag-triggered CI is also running: Actions run 35957628009.

Shipped UI: “Happy Rhino Day! 🦏” / “Give 3 friends Rhino Voice for free.”
Menu-bar sharing and one-time idle popup after five successful dictations.
Selectable AppSumo listing URL + user-supplied coupon `rhinofree`; both copy
actions include coupon. No recipient tracking or app networking; three friends
is honor-based. Coupon validity is user-provided; no checkout performed.

Validation: 421 unit tests pass; complete local ASR, latency, dynamic privacy,
release/smoke gate passes; website 9/9 tests pass. One release-gate attempt hit
929 ms latency while another workspace’s Rhino process used CPU; unchanged
standalone recheck passed at 460 ms and full release retry passed. Limits unchanged.
Logs and preview screenshots: `.context/share-check/` (release retry log contains
publication details). No replacement of /Applications/Rhino.app in this session.
Dev copy previously reported missing/stale permissions; other workspace processes
have since run Rhino, so do not assume this workspace’s dev app remains active.

### Clipboard-history fix (2026-09-22, madrid-v1 workspace)

Implemented: clipboard borrows now publish text and the standard transient
marker together so Maccy ignores temporary dictation entries when Copy to
clipboard is off. Ordinary copies and clipboard restoration are unchanged.
Validated all 12 ClipboardRestoreTests against production ClipboardUtil.swift
in an isolated XCTest runner using named macOS pasteboards: all pass; the new
marker assertions fail against HEAD's original utility. Static hygiene passes.
Full app build blocked by uninitialized whisper.cpp/llama.cpp submodules.
Logs/runner: `.context/clipboard-tests/`; build: `.context/clipboard-build.log`.
Not installed or released; live Maccy end-to-end testing remains outstanding.

### Prompt-cache implementation (2026-09-21, windhoek workspace)

Implemented the user-authorized cache optimization in `LlamaContext.swift`.
One inactive system-prefix snapshot survives switches between formatting and
spoken edits; one model, existing serial queue, no transcript/output snapshots.
Combined serialized-state cap during swaps: 64 MiB. Exact-token/logits checks
and fail-closed truncation behavior retained; idle context unload frees caches.
Other audit proposals remain separate follow-up work. App/settings untouched.

Validation: app build passed; full unit suite 418 passed / six skipped / zero
failures, with the new real-model cache test running and passing. Output parity
against installed v0.1.24: 108/108 cleanup comparisons identical (24 each default,
formatting, edits, combined; 12 combined Auto multilingual). ASR parity: seven
offline and five stable boosted clips identical; two boosted clips excluded as
unstable on unchanged baseline. `bench/parity/parity.sh` now includes combined
formatting+edits for future checks. Hygiene (including dynamic egress), ASR,
latency, smoke and release suites all passed; latency p50 422 ms / max 779 ms.
Production-source isolated benchmark: warm corrections+formatting 504 ms vs
2,182 ms baseline, 12/12 paired outputs identical. No install/release/commit.

### Performance audit (2026-09-21, windhoek workspace)

Audit complete in `docs/performance-audit-2026-09-21.md`; raw measurements and
isolated prototype live in `.context/performance-audit/`. Garrett clarified the
issue is AFTER dictation and uses smart formatting. His model/Mac/spoken-edits
setting are unknown. Production source and real preferences remain unchanged.

236 installed v0.1.24 CLI results on this M4: warm Parakeet v2 62–80 ms for
4–11 s fixtures; formatting cleanup 239 ms sentence / 731 ms 42-word email;
spoken correction + formatting 2,362 ms. Cold CLI runs include loading and do
not measure the preloaded GUI. Shared edit/cleanup KV cache is a confirmed
slow path: the edit prompt displaces the 1,380-token warmed formatting prefix.
An isolated same-model two-cache prototype reduced this path by ~1.75 s in
both run orders (2.34→0.58 s and 2.18→0.43 s), with 24/24 paired outputs
identical and ~50 MiB snapshots. See audit for limitations. No fix shipped.

Next: end-to-end local release→paste instrumentation, bounded per-pass prompt
cache implementation with full parity/quality/memory validation, deduplicated
model readiness and foreground queue priority. Do not replace accurate final
ASR with the deliberately lower-quality live caption. Do not merge the edit
and cleanup prompts: past real-model probes rejected that design.

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
