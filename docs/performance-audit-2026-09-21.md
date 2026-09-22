# Post-dictation latency audit — 2026-09-21

Garrett reports an intermittent wait **after dictation**, and confirms smart
formatting is enabled. His Mac, app version, ASR model, spoken-edits setting,
language setting, clip lengths, and whether delays follow idle periods are
unknown. This audit identifies reproducible slow paths; it does not establish
which one Garrett encountered.

**Conclusion:** optimize the cleanup path and cold/queued work before choosing
a smaller speech model. Warm recognition is already fast on this M4. Formatting
requires the LLM to reproduce the whole transcript, and a spoken-edit pass can
destroy its prepared prompt cache, causing seconds of avoidable work.

## Evidence and scope

- Source reviewed: `27cbc2a` (v0.1.24 tree).
- Primary measurements: installed `/Applications/Rhino.app`, version 0.1.24,
  Apple M4, macOS 15.7.9. These are release-app CLI measurements, not a new build
  of the workspace. CLI exits before GUI startup and does not replace the running app.
- 236 CLI results across baseline, longer clips, feature combinations and
  moderate CPU contention. Runs are sequential; no overlapping benchmark jobs.
- ASR: four existing synthetic-speech fixtures, 4.38–10.66 seconds, eight rounds
  per model. Tables exclude the first round (seven samples per clip).
- Cleanup: four different inputs in alternating order, six rounds per setting;
  discard the first round (five samples per input). Combined-feature and CPU-load
  runs use four rounds (three warm samples per input). Alternating inputs avoids
  giving repeated identical transcripts an unrealistically favorable cache hit.
- Longer ASR inputs repeat the prose fixture to 30/60/120 seconds. These measure
  throughput only; repeated synthetic speech is not a natural long-form quality test.
- CPU contention: four bounded Python busy workers, terminated after measurement.
  This is neither full-system saturation nor GPU/memory/thermal pressure. Normal
  applications remained open. Small samples and sequential order limit causal claims.
- Initial audit CLI preferences used unique `RHINO_PREFS_SUITE` domains, removed afterward.
  Existing local models were used. During the initial audit, no production source, real preferences,
  recording history, or running-app lifecycle was changed.
- Reproduction scripts, input text, raw JSON/logs and summary are in
  `.context/performance-audit/` (`benchmark.py`, `extended.py`, `summary.json`).
  That directory is gitignored; this document preserves the findings in the repo.

## What the user is waiting for

Release → synchronous recorder stop → dictation FIFO → shared ASR gate → model
load if needed → audio read/recognition → optional spoken edits → cleanup and
smart formatting → clipboard/keyboard event → target app displays text.

History persistence follows insertion. A second recording can start while the
first is processing, but its output still waits for the serial pipeline. The
busy indicator also follows pipeline drain, so it can outlast paste dispatch;
record text-arrival and indicator-dismissal separately before interpreting
“loading” as actual model loading.
Existing measurements do not cover this complete chain, and dispatching a paste
event is not proof that the destination has rendered the text.

## Measured costs

Warm ASR, milliseconds (median by clip):

| Engine / condition | 4.4 s clip | 8.8 s clip | 7.7 s clip | 10.7 s clip |
|---|---:|---:|---:|---:|
| Parakeet v2 | 62 | 69 | 75 | 80 |
| Parakeet v3 | 69 | 85 | 103 | 111 |
| Parakeet v2, four CPU workers | 86 | 94 | 103 | 112 |

Audio reading/conversion was about 0–2 ms in the ordinary cases; dictionary
post-processing was rounded to 0 ms with dictionary disabled. Warm v2 medians
for repeated 30/60/120-second input were 139/254/371 ms (three samples each).
These figures must not be generalized to Garrett's unknown hardware/model.

Warm cleanup, milliseconds (median; separate text fixtures from ASR):

| Configuration | “sounds good” | 13-word request | 42-word email | Spoken correction sentence |
|---|---:|---:|---:|---:|
| Plain cleanup | 97 | 228 | 683 | 239 |
| Smart formatting | 104 | 239 | 731 | 296 |
| Spoken edits | 104 | 238 | 710 | 1,117 |
| Smart formatting + spoken edits | 115 | 265 | 781 | 2,362 |
| Both features, four CPU workers | 123 | 286 | 852 | 2,678 |

The final column contains “actually make that”; it triggers the edit pass only
when spoken edits are enabled. Formatting alone is inexpensive **when its prompt
is already cached**. That qualification is central to the intermittent behavior.
Neither these cleanup figures nor ASR alone are release-to-visible-text timings.

Cold observations need separate interpretation:

- First smart-formatting CLI cleanup: 3,403 ms in one run, including model/context
  load and prompt evaluation. Another combined-feature process started at 1,919 ms.
  These are observations, not a cold-start distribution.
- First v3 CLI transcription: 14,808 ms, while its actual audio stages totaled
  only 89 ms. Most time was outside those stages, in engine initialization.
  It is not a 14.8-second recognition result. GUI startup normally preloads ASR;
  this example matters when initialization lands on the critical path.

## Ranked opportunities

### 1. Preserve prompt caches across spoken edits and smart formatting

**Confirmed behavior; highest measured avoidable feature interaction.**
[`LLMPostProcessor.process`](../OpenSuperWhisper/Utils/LLMPostProcessor.swift#L110)
runs edits and cleanup serially. [`LlamaContext`](../OpenSuperWhisper/Llama/LlamaContext.swift#L405)
keeps only the longest prefix shared with the immediately preceding prompt.
The edit prompt and formatting prompt differ near their beginning.

An isolated harness compiled the current cleanup sources against the matching
local llama/ggml libraries, adding timing/token counters and stubbing only
preferences/model location/language labels. It confirmed 1,380 tokens reused
for an ordinary warmed formatting request, versus only six shared tokens on
switches between edits and cleanup. An English prewarm retained 316 tokens;
Auto → detected-English retained 279. Host timing around `llama_decode` is not
an independent GPU stage measurement: asynchronous GPU work can surface later.

An isolated two-cache prototype preserved sequence state in RAM and reused the
same model. The result reproduced with the run order reversed:

| Run order | Baseline correction + formatting | Cached prototype | Absolute saving |
|---|---:|---:|---:|
| Baseline, then prototype | 2,338 ms | 577 ms | 1,761 ms |
| Prototype, then baseline | 2,182 ms | 432 ms | 1,750 ms |

Each median uses six warm correction cases (two alternating inputs, three
rounds), with a 1.5-second simulated recording interval for prewarm. All **24
paired outputs were byte-identical** across the two experiments. Stored
snapshots peaked at **50.1 MiB**; the initial run's median save/restore switch
cost was **6.2 ms**. Ordinary request medians were 289 → 333 ms in the first
experiment and 244 → 240 ms in reverse order (three samples per variant in each
experiment): no stable improvement is established on the already-warm ordinary
path. Raw results: `.context/performance-audit/cache-experiment.json`; source:
`CachedLlamaContext.swift`, `CacheProbe.swift`, and compile-command JSON in the
same directory. This is a promising experiment, not a production-ready fix.

The prototype stores complete sequence states, then applies existing exact-token
prefix rewind before generation. Production must bound cache keys/bytes, release
snapshots on idle unload and settings changes, and validate cross-input isolation.
Snapshotting only reusable prefixes could reduce memory further. No snapshot
state was persisted; inputs were synthetic. Existing baseline mistakes also stayed
identical (one correction incorrectly becomes “four fifteen”); byte parity is
not proof of transcript correctness.

Preserve a bounded prompt state per pass using the same model, with strict token
validation on restoration. Avoid loading a second full model. Keep spoken-edit
semantics: the decision log records why merging edits into the cleanup prompt
failed on the actual 1.5B model. Validate mixed sequential inputs, languages,
formatting, idle unload, cancellation, memory use, and output parity before shipping.

### 2. Keep cold preparation out of the post-release path

**Code-proven exposure; field frequency unknown.**
The cleanup backend unloads after five minutes and warms at recording start.
That already hides much of the cost. However, a short take can finish before
loading/prefill completes and wait behind it on the inference queue. Changing
model/settings can also invalidate readiness. ASR `reloadEngine()` explicitly
defers initialization until the next transcription, and the engine loader lacks
an in-flight load task shared by all callers.

Improve deduplicated preparation on recording start/model selection **only when
files are already downloaded**. Measure time spent waiting for readiness. For
smart formatting, prefill the exact prompt before it is needed. Consider a
memory-pressure-aware retention policy instead of blindly retaining the model
forever; that is a RAM/latency tradeoff, not a free optimization.

Sources: [backend unload/prewarm](../OpenSuperWhisper/Utils/LLMCleanup/BuiltInLlamaBackend.swift#L17),
[engine loader](../OpenSuperWhisper/TranscriptionService.swift#L63),
[recording-start warm-up](../OpenSuperWhisper/Indicator/IndicatorWindow.swift#L148).

### 3. Measure and prioritize interactive work in the queues

**Code-proven exposure; unmeasured benefit.**
File imports, reruns, and dictations all acquire one FIFO ASR permit. A short
interactive dictation can wait behind a long file or another model's load.
One-off model reruns invalidate the current engine and invalidate again on
restoration. Dictations themselves wait for preceding cleanup and post-insertion
bookkeeping before the next item starts.

Instrument queue waits separately; prioritize waiting dictations over pending
background files while retaining dictation order. A priority queue cannot
preempt an already-running long file: that requires safe chunk boundaries or
engine cancellation/resumption, not unsafe concurrent access to the same context.
Move avoidable history bookkeeping off the next dictation's critical path only
if measured significant. Preserve insertion order and target semantics.

Sources: [shared gate](../OpenSuperWhisper/TranscriptionService.swift#L175),
[one-off model lifecycle](../OpenSuperWhisper/TranscriptionService.swift#L150),
[pipeline](../OpenSuperWhisper/DictationPipeline.swift#L109).

### 4. Reduce unnecessary preview and warm-up work

**Conditional opportunities; not the default path.**
Live preview is opt-in. It uses overlapping small ASR windows, then the app
cancels it and transcribes the entire WAV again. The preview is deliberately
lower accuracy and lacks the final path's language hint: directly pasting it
would change correctness. Explore sharing final-quality incremental recognition
with the final pass only as a separate quality-gated project.

Shorter-term: ensure preview teardown releases pending inference promptly;
the controller does not await cancellation before final ASR and its mic-buffer
stream is unbounded. Pinned FluidAudio 0.15.4 cancellation signals its task
without waiting for termination. Resource contention under load is a hypothesis
to measure, not established by the CLI tests. Its preview vocabulary loader
also rebuilds CTC vocabulary on every start, unlike the final engine's cache.
Share that cache and refuse implicit download in this path.

`prewarm()` ignores the captured target app even though `process()` skips every
LLM pass in supported AI/terminal apps. Pass the target through and skip that
unnecessary preparation. For Auto language, prewarm only the stable common
prefix rather than a known-to-change language/wrapper suffix. The harness saw
about 29 ms difference between median Auto and explicit-English runs, but the
sequential small sample does not establish a 29 ms guaranteed saving. Most
of the formatting prefix survives; this is not the multi-second issue.

Sources: [preview config](../OpenSuperWhisper/Engines/StreamingTranscriptionController.swift#L71),
[stop/queue handoff](../OpenSuperWhisper/Indicator/IndicatorWindow.swift#L217),
[preview vocabulary](../OpenSuperWhisper/Engines/StreamingTranscriptionController.swift#L201),
[prewarm vs process gates](../OpenSuperWhisper/Utils/LLMPostProcessor.swift#L45).

### 5. Reduce the remaining cleanup generation cost

**Measured dominant steady-state work; behavior-sensitive changes.**
Even with perfect prefix reuse, the model generates the entire output token by
token. Longer messages therefore cost more. Prompt shortening mainly helps
cache misses; it will not eliminate the measured ~0.7-second email generation.
Potential experiments: compact edit output applied deterministically, verified
speculative decoding, or a smaller cleanup model. Each needs output-quality
and language regression evaluation. There is no evidence here for silently
skipping formatting on short inputs or merging the two prompts.

LLM execution currently has no wall-clock deadline or cooperative abort inside
its token loop, despite a comment mentioning timeout fallback. A deadline with
raw-text fallback could cap waiting, but changes the product contract and must
actually stop work on the serial inference queue; merely returning early leaves
following dictations blocked. Keep complete transcripts and all truncation guards.

### 6. Check blocking insertion/stop tails after measuring them

**Code-proven blocking sites; no measured contribution in these runs.**
Recorder stop synchronously waits for its state queue, including a slow in-flight
Bluetooth start. Make stop asynchronous while preserving start/stop ordering.
In typing mode, editable-target Accessibility requests run synchronously with
0.5-second per-request timeouts. Default paste mode already avoids those calls.
When automatic clipboard copying is off, insertion first snapshots every type
of clipboard data; large or lazily supplied clipboard contents can be expensive.
Measure snapshot time without reading/logging contents. Preserve clipboard
restoration semantics when changing this.

The 120 ms delay before optional Return is **after paste dispatch**. The delayed
clipboard restore is also asynchronous. Neither is a blanket 120/500 ms delay
before initial text insertion, and neither should be removed as a supposed win.
The recent caret-query/entrance fix addresses record-start responsiveness, not
Garrett's clarified post-dictation complaint.

Sources: [recorder stop](../OpenSuperWhisper/AudioRecorder.swift#L299),
[insertion policy](../OpenSuperWhisper/Utils/TranscriptInserter.swift#L40),
[clipboard snapshot](../OpenSuperWhisper/Utils/ClipboardUtil.swift#L21),
[paste before history](../OpenSuperWhisper/DictationPipeline.swift#L206).

## Measurement changes to ship alongside optimization

Add a local-only per-dictation timing record, using a monotonic clock and a
recording ID: release received, recorder stopped, queue wait, engine-gate wait,
engine ready/load, ASR stages, cleanup-queue wait, prefill readiness, edit pass,
formatting pass, insertion dispatch, and history completion. Include engine,
feature flags, language mode, prompt-cache hit counts, token counts and thermal
state; never transcript text, audio, target document contents, or network telemetry.
Use a controlled local text field to measure event dispatch → visible insertion.

The current latency gate uses Whisper tiny, excludes cleanup and GUI insertion,
and skips timing budgets on CI. The CLI `bench` also excludes cleanup. Its first
row can include model load because CLI does not run GUI launch preload. The
existing stage structure covers Parakeet audio load/inference/post only, leaving
exactly the cold/queue/cleanup delays most relevant here outside its scope.

Add a release-build benchmark for shipping Parakeet + Qwen with smart formatting,
with/without edit cues; first use, warm, five-minute idle, model switch, long input,
preview on/off, background file queue, CPU load and real UI insertion. Report
p50/p95 separately by scenario with enough samples (these exploratory n=3–7 runs
are insufficient to characterize p95). Compare output parity/quality alongside
latency. Never use a faster but incomplete transcript as a successful result.

## Recommended order

1. Add end-to-end timing and verify Garrett's feature/model/idle pattern.
2. Preserve formatting/edit prompt caches and validate output parity and memory.
3. Fix cold preparation/deduplication and interactive queue priority.
4. Address preview and insertion tails when the new measurements implicate them.
5. Evaluate larger recognition/cleanup architecture changes only after these wins.

The initial deliverable was the audit, with local experiments and evidence.
The user then authorized implementation of the cache optimization below.


## Implementation follow-up (same day)

User authorized executing the cache optimization after reviewing this audit.
`LlamaContext` now preserves **one inactive system-prefix snapshot**, with the
same model and serial inference queue. Unlike the exploratory full-sequence
prototype, snapshots contain no transcript or output tokens. The combined byte
cap during a swap is 64 MiB; snapshots disappear with the idle-unloaded context.
Exact-token validation and final-token evaluation remain in place. Oversized
snapshots or restore failures fall back to ordinary decoding. Truncated/failed
inference clears the active sequence before it can be cached.

The first optimized-source harness run measured 504 ms for warm correction plus
formatting (six samples), versus the prior baseline's 2,182 ms; ordinary requests
were 264 ms versus 244 ms (three samples; uncontrolled run-to-run noise). All 12
paired outputs matched. This is a local benchmark, not Garrett's end-to-end result.
App build passed. Full app unit suite: 418 passed, six skipped, zero failures;
the new real-model cache regression **ran and passed** (not skipped).
Output parity against installed v0.1.24: **108/108 cleanup comparisons matched**:
24 each for default, formatting, edits, and combined; 12 additional combined
Auto multilingual inputs. The combined and multilingual checks compared warm
sequential processes on both sides; the original three configurations compared
cold per-line baseline against sequential branch output. ASR output parity:
seven offline and five stable boosted clips matched; two boosted clips were
excluded because unchanged baseline runs differed. The recurring parity harness
now includes the combined formatting+edits configuration.

Logs: `.context/performance-audit/{unit-summary.json,parity.log,combined-parity.log}`.
Installed app and real preferences remain unchanged. This change has not been
released or installed. Other audit proposals remain follow-up work.


Final validation: privacy hygiene passed including the dynamic egress check;
ASR accuracy/silence, latency (Whisper tiny p50 422 ms / max 779 ms), smoke and
release-automation suites passed. Shell syntax and `git diff --check` passed.
These gate latency figures are regression checks for Whisper tiny, not the
cleanup speedup measured above. The new cache regression ran on the actual
local Qwen model; the six skips were other tests in the existing suite.
