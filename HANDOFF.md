# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-11, end of the two-day marathon)

### Completed check (2026-08-11)

- Retired working-name references are gone from tracked source and docs.
- Last complete personal-corpus comparison: Rhino 8/10 zero-fix (80%, 5.3%
  WER), Typeless 10/10 (100%), Wispr Flow 4/9 (44%; h03 was not captured).
- Today's elided-word cleanup passed a live local-Qwen A/B and fixes the known
  h01 miss, so Rhino projects to 9/10 (90%); a fresh full-corpus score still
  needs the private audio/results from the original benchmark Mac.
- Fresh gate run: 1.47% mean WER, zero silence hallucinations, and 410ms p50 /
  870ms max ASR latency across four clips.

### Completed local-audio benchmark rerun (2026-08-11)

- Rhino's 4-clip synthetic gate: every installed engine scored 3/4 zero-fix;
  one “lunch”→“launch” substitution gives 1/122 errors (0.82% weighted WER).
- Extended 24-clip synthetic set (509 words), Rhino's standard output pipeline
  with AI cleanup off (no Rhino cleanup model is installed on this Mac):
  Whisper large-v3-turbo 20/24 zero-fix (83.3%), 1.57% weighted WER;
  Parakeet v2 17/24 (70.8%), 1.57%; Parakeet v3 17/24, 1.96%.
- Whisper is best for zero-fix usability and technical names; v2 ties its raw
  WER because Whisper's few misses include a long-clip truncation. These are
  macOS synthesized voices, useful for regression testing but not a substitute
  for the missing 10-item natural-voice personal corpus.

### Completed natural-voice / 8→9 experiments (2026-08-11)

- Balanced ten-clip sample from locally stored Typeless recordings (392 reference words):
  Q5 Whisper 3/10 exact agreement and 10.71% WER-to-Typeless. This is an
  agreement metric, not ground truth; the separate human-reviewed personal corpus remains 8/10.
- Full 1.6GB large-v3-turbo produced the same 3/10 and 10.71% WER, while steady-state
  p50 rose from 1.91s (Q5) to 2.52s. Do not make it the default on this evidence.
- Alternate decodes: beam 10.46% WER, temperature 0.2/0.4 10.20%, Parakeet 12.50%.
  Even an impossible ground-truth oracle choosing the best decoder per clip only reached
  9.44% WER and still 3/10 exact, so confidence retry cannot supply the missing +1 alone.
- Qwen raised WER from 10.71% to 11.22%; a perfect raw-vs-Qwen guard merely restores
  10.71%. It is a safety requirement, not an accuracy gain on this sample.
- A local vocabulary/context prompt fixed `Yu` and improved WER to 10.20%, but not exact
  agreement. Universal product direction: locally learned per-user terms plus contextual
  correction; do not hard-code Noah-specific names.
- Simulating one learned correction (`Aemon`/`Amen` → `AppSumo`) increased exact agreement
  from 3/10 to 4/10. This was the only tested mechanism that converted a failed clip into
  a perfect clip, supporting correction learning as the most credible universal +1 lever.

- The app is **Rhino v0.1.0**: rebranded (bundle id com.noahkagan.rhino,
  coral face icon, menu-bar rhino silhouette, forced light mode), main
  window is sidebar + Home stats/History/Dictionary per Noah's mockups.
- 80/20 axe done: Rules, SenseVoice/Apple Speech, Rust autocorrect,
  translation, extra triggers, knobs — all deleted; bundle ships only
  whisper.cpp + libomp + Sparkle (DMG 28→14MB).
- Defaults ON: hold-Fn dictate, launch at login, menu-bar start, history,
  dictionary. Cleanup is an onboarding offer (explicit 1GB download).
- Shareable build: `Scripts/make-test-dmg.sh` → signed, NOTARIZED,
  stapled DMG (notarytool profile "rhino"; Sparkle keys exist, feed
  inert until rhinovoice.app + first release).
- Deterministic NumberCompaction ("forty-two thousand"→"42,000") runs on
  every transcription; unit-tested.
- **Benchmark (Noah's voice, 10 items): Rhino 80% zero-fix / 5.3% WER —
  beats Wispr Flow (44%); Typeless (100%) is the standing bar.** Grid:
  `bench/corpus/score-personal.py results/*`.
- Gate prefs leak fixed (RHINO_PREFS_SUITE); suites can no longer rewrite
  real settings.

## Outstanding

- Noah: re-record e02 + h01 (`rm audio/{e02,h01}.m4a && ./record.sh`) —
  realistic shot at 90-100% zero-fix; optionally dictate h03 into Wispr.
- Next quality lever: elided-word reconstruction in cleanup ("Schedule
  the review" — Rhino AND Wispr both dropped the "the"; Typeless's LLM
  reconstructs). Then email-tier polish.
- Release pipeline (tag → CI gate → sign/notarize → DMG → Sparkle
  appcast → site): creds exist locally; needs the workflow + rhinovoice
  .app registration + site. Crib docs/PUBLISHING.md + MeetingCoach.
- Localizable.xcstrings still carries orphaned keys for cut features
  (harmless); prune someday.
- CI test-gate.yml still builds with old assumptions (submodule list
  changed after autocorrect removal) — verify with a workflow_dispatch
  run before relying on it for releases.

## Next session

Start with: "Read AGENTS.md and decisions.md. If bench/corpus has fresh
recordings, rescore and update the head-to-head; then build elided-word
reconstruction into the cleanup pass and corpus-test it."
