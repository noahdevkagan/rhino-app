# Release → paste latency audit — 2026-09-23 (v0.1.26)

Follow-up to `performance-audit-2026-09-21.md`, whose #1 item (prompt-cache
snapshots across spoken edits + formatting) shipped in 0.1.25. This pass
re-measures the whole post-release path on v0.1.26 using Noah's actual settings:
Parakeet v2, English, cleanup + smart formatting + spoken edits on, paste mode,
Copy-to-clipboard on, no live preview, no dictionary boost. Apple M4.

**Conclusion:** the LLM cleanup is 70–90% of the wait, and it is almost entirely
token-by-token generation of a transcript the model mostly copies. Two changes
would cut most of it without changing any output:

1. **Prompt-lookup speculative decoding**: 1.5–5.7× faster cleanup on dictations
   over ~15 words; 195/195 outputs byte-identical to shipping.
2. **Absorb the first-decode warm-up in prewarm**: saves ~400 ms on the first
   dictation after every idle unload, which is **56%** of Noah's dictations.

## Where the time goes (warm, per stage)

| Stage | Cost | Notes |
|---|---:|---|
| Recorder stop → enqueue | not instrumented | synchronous on state queue; no sleeps on the release path |
| Parakeet v2 ASR | 62–82 ms | 4–11 s clips, installed 0.1.26 CLI `bench`, n=5 each |
| LLM cleanup | 140 ms – 4.3 s | scales with output length, ~12–17 ms per generated token |
| Paste dispatch | ~1 ms | Copy-to-clipboard on → no clipboard snapshot on this path |

Prompt evaluation is negligible once the prefix is prefilled (2–10 ms for the
transcript tokens). **Generation is the cost:** one full forward pass per output
token, memory-bandwidth-bound (~1 GB of weights read per token).

Noah's last 30 days (45 dictations, timestamps/lengths only): median clip 8.6 s /
23 words, p75 67 words, p90 244 words. **25 of 45 (56%) came after >5 min idle**,
i.e. after the LLM context's idle unload.

## 1. Prompt-lookup speculative decoding (largest win)

Cleanup output is mostly the transcript copied, with punctuation/number/list
edits. So draft the next tokens by finding the output's recent n-gram in the
transcript, have the model check the whole draft in one batched pass, keep the
prefix where its greedy choice matches, and rewind the KV cache past the first
mismatch. Every emitted token is still the model's own argmax, so this is the
same greedy decode, just with fewer forward passes. No second model, no extra memory.

Measured on this M4, the batched verify cost is lumpy (Metal switches kernels
by batch size):

| Tokens per pass | 1 | 2 | 4 | 8 | 16 | 32 | 64 |
|---|---:|---:|---:|---:|---:|---:|---:|
| ms | 13 | 18 | 37 | 72 | 50 | 49 | 84 |

So the prototype drafts either 1 token (cheap probe on a weak match) or up to
31 tokens (when the last ≥4 output tokens match the transcript), drafting only
from the transcript, never from the system prompt's examples.

Results (isolated harness compiling production `LLMPostProcessor` +
`BuiltInLlamaBackend` + a modified `LlamaContext` against the same pinned llama.cpp;
real Qwen2.5-1.5B Q4_K_M; Noah's config; prewarm + 1.2 s pause before each; medians
of rounds 2–3; baseline = unmodified production `LlamaContext`):

| Input | Words | Baseline | Speculative |
|---|---:|---:|---:|
| "Sounds good." | 2 | 136 ms | 132 ms |
| Short request | 13 | 298 ms | 165–182 ms |
| Email paragraph | 27 | 536–553 ms | 203–284 ms |
| Email w/ numbers | 42 | 759 ms | 451–475 ms |
| Paragraph | 56 | 1,014 ms | 298–326 ms |
| Recap email | 77 | 1,408 ms | 424–456 ms |
| Launch-plan brain dump | 249 | 4,054–4,865 ms | 722–1,463 ms (median 757) |
| Grocery list → bullets | 14 | 464 ms | 501 ms (break-even) |
| Numbered list | 36 | 575 ms | 568–611 ms (break-even) |
| Spoken edit + formatting (2 passes) | 20 | 909 ms | 767–803 ms |

Sum of the 16 standard inputs' medians: 9.4–11.7 s → 6.2–6.5 s across interleaved
runs. **Parity: 195/195 byte-identical** (four speculative runs × 48 = 16 inputs × 3 rounds, across policy variants, plus 3 long).
Lists and heavy reformatting diverge from the transcript, so drafts get rejected
there. The policy keeps those at baseline speed but can't speed them up.

**Caveats before shipping:**
- Parity is empirical. Batched and single-token Metal kernels round differently,
  so a near-tie argmax could in principle flip. Validate with
  `bench/parity/parity.sh` (all configs, multilingual), the real-model unit tests,
  and a larger transcript set.
- The cost curve (and so the thresholds) is M4-specific. Check on an M1/M3
  before release; keep thresholds conservative.
- Truncation semantics must be kept exactly (`lastGenerationTruncated`, budget,
  clear-on-failure). The prototype does, but it needs its own unit tests.

Prototype: `.context/speed-audit/spec-LlamaContext.swift` (gitignored), roughly
80 lines added to `generate`. Settings used: `SPEC_MINMATCH=4 SPEC_PROBE=1 SPEC_COOLDOWN=0 SPEC_K=31`.

## 2. First decode after a context load costs ~400 ms extra

After an idle unload, recording-start prewarm reloads the model (~190 ms) and
prefills the 1,380-token prefix (~1,050 ms) while the user speaks. But the first
`generate` on a fresh context still takes **~510 ms** for "sounds good" versus
~105 ms for the second (4 rounds, in-process). Metal pipelines compile once per
process, so this is per-context first-decode setup. A throwaway 2-token
`generate` right after prefill (inside prewarm, on the inference queue) moved it
off the critical path: first real cleanup **95–103 ms**.

Because 56% of Noah's dictations follow a >5 min idle, this is ~400 ms off more
than half of his dictations, for a few lines in `BuiltInLlamaBackend.prewarm`.
Clips shorter than ~1.7 s after idle still wait for the remaining prep.

## 3. Idle unload window (product call)

The 5-minute unload is why 56% of dictations start cold. At 30 minutes, 17 of
45 would have been cold instead of 25 (8 more dictations, 18%, fully warm). The
cost is ~1.2 GB held resident longer. A memory-pressure-driven release
(`DispatchSource.makeMemoryPressureSource`) could hold it longer on roomy Macs
and still free it under pressure. Worth doing only after #2, which removes most
of the per-cold penalty anyway.

## 4. Instrument release → paste end-to-end

The unified log only has record-start events; nothing covers stop → ASR → LLM →
paste in the GUI. Add `Diag.mark`s (monotonic ms, no text): stop received,
ASR done, each LLM pass (tokens, decodes), paste dispatched. That makes the
field effect of #1/#2 visible. Separately, `MainThreadWatchdog` is still logging a
fake "stalled ≥18446744073s" line (wrapping subtraction, found 2026-09-17):
**8,122 lines in the last 2 days**, drowning out real diagnostics.

## Checked, not worth changing

- **ASR**: 62–82 ms warm, and ~250 ms even for 90 s of audio. Not the bottleneck.
- **Insertion**: ⌘V dispatch ~1 ms; with Copy-to-clipboard on there's no
  clipboard snapshot. (Users with it off pay an eager snapshot of the old
  clipboard before paste. Unmeasured, and could be moved to recording start if it matters.)
- **Smaller/lower-quant LLM**: quality risk, and speculative decoding gets the
  win with zero output change.
- **Merging edit + cleanup passes / pasting the live preview**: already rejected
  (decisions.md 2026-08-26, 2026-09-21).
- **CPU thread count**: all layers are on Metal; decode is bandwidth-bound at
  ~12 ms/token (~88 GB/s of the M4's ~120 GB/s).

## Reproduce

`.context/speed-audit/`: `compile-{base,spec}.sh`, `Probe.swift` (env `INPUTS`,
`ROUNDS`), `ColdProbe.swift`, `compare.py <base> <spec>`, inputs and raw
JSON/stderr for every run cited above. ASR: `RHINO_PREFS_SUITE=<tmp> Rhino bench clips/`.


## Implementation follow-up (same day)

Noah authorized #1 and #2. Both live in `LlamaContext`:

- `generate` does prompt-lookup speculative decoding (`draftTokens`,
  `decodeVerifyBatch`), with the policy the prototype settled on. A
  `speculativeDecoding: false` init flag keeps the plain loop for parity tests.
- `prefill` runs the single-token and 32-token verify shapes once per fresh
  context and rewinds them (`warmDecodeShapesIfNeeded`).

Validation: app build passed. Full unit suite **424 passed, 6 skipped (pre-existing),
0 failed**, including the new `LlamaSpeculativeDecodingTests`: draft-selection unit
tests, plus a real-model test comparing speculative vs plain output across formatting,
edits, German, a long dictation, and budget truncation (flags and text). `parity.sh` vs
installed 0.1.26: **96/96 cleanup identical** (default, formatting, edits, combined),
ASR identical. Extra multilingual Auto/German check: 16/16 identical. Gate suites
(hygiene, ASR, smoke, release, latency p50 376 ms) all pass. Harness timings with the
production code: 16-input medians sum 9.0 s → 6.1 s, 249 words 4.3 s → 0.74 s (48/48 +
3/3 identical); cold first cleanup after load 500 → 150 ms.

Remaining: the M1/M3 threshold check, and a GUI stopwatch in real apps. A cold
generate with no prefill (CLI, first file-drop after load) now also pays the
verify-shape setup once (~200 ms observed in CLI). Dictations always prefill at
recording start.
