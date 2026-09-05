# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-09-05, Noah's Mac: AirPods "Connecting…" hang, both fixes → 0.1.21)

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
