# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-27)

- **Wrong-language dictation fixed on master, NOT yet released.** Two user
  reports (German→English; German→Russian, from Sabine Jungk), two bugs:
  - #33: LLM cleanup's all-English prompt made the 1.5B model translate —
    output language now pinned in system prompt + per-request wrapper
    (`LLMPostProcessor.swift`).
  - #35 (`dea476e`): `FluidAudioEngine` never passed the selected language
    to Parakeet — now forwards FluidAudio's script-filter hint and runs v3
    with `melChunkContext: false` (upstream #594).
- `Scripts/verify-german.sh` (new, manual): synthesizes German speech, runs
  the real pipeline via the CLI, checks output stays German. Verified on
  Noah's desktop against a fresh build: 10/10 Parakeet clips + cleanup green.
- Unit tests added: `CleanupLanguageRuleTests`, `ParakeetLanguageHintTests`
  (XCTest — not in the push gate, run via xcodebuild test).

## Outstanding

- **Release v0.1.15** so the two reporters actually get the fixes; ask both
  to re-test on their real voices after updating. Remember the FIVE release
  pins (CHANGELOG, thanks page, AppSumo redeem, website changelog,
  rendered-html.test.mjs ×2 DMG names).
- **New bug found during verification:** LLM cleanup converts German number
  words to wrong digits ("einundzwanzig" → "19"). Hits German users with AI
  cleanup on. Likely fix: restrict digit conversion to English or add German
  examples to the cleanup prompt.
- Known gap (documented in code): `SlidingWindowAsrManager` (dictionary
  boosting path + live preview) has no language parameter in FluidAudio
  0.15.4 — patching FluidAudio is the escalation if wrong-language reports
  continue.
- Carried forward: onboarding tester re-run on 0.1.14; Parakeet RSS check
  (#27) never recorded; AudioRecorder start/stop race audit finding; Apple
  Dictation double-🌐 race; `crxnamja/bern` items (input-aware
  capitalization, app-icon refresh).

## Next session

Cut release v0.1.15 (both wrong-language fixes) and notify the two German
reporters; then take the German number-word cleanup bug
("einundzwanzig"→"19", see Outstanding).
