# Speed and accuracy audit — 2026-10-05 (master 2742e11, 0.1.34 + unreleased)

Third audit, after `performance-audit-2026-09-21.md` (prompt cache) and
`performance-audit-2026-09-23.md` (speculative decoding, cold-start warm-up). First
one to measure accuracy as well as speed, and the first run on real dictations: the
85 recordings in Noah's local history (35 minutes, 5,800 words, Aug 11 – Oct 5),
replayed through each stage with his settings (Parakeet v2, English, cleanup + smart
formatting + spoken edits, filler removal, dictionary on, boost off). Apple M4.
Audit only: no production code changed.

**Conclusions**

1. Speed is in good shape and has not regressed. After release, the median dictation
   lands in about 0.25 s and 90% land within 0.7 s. The LLM cleanup pass is still
   two thirds of that time.
2. The cleanup pass is now the main accuracy risk, not just the main cost. On real
   dictations it returned the text unchanged 58% of the time, and when it did change
   words it sometimes deleted a sentence, reordered words, or wrote the message the
   speaker was asking an AI to write.
3. Speech recognition itself is accurate (about 1% word error on a public test set).
   Its real weakness is proper nouns: "AppSumo" came out right only about a third of
   the time.
4. Two shipped features produce wrong text: the dictionary "boost" toggle (drops
   whole sentences) and the number formatter on "million".

## Speed

### Where the time goes (warm, installed 0.1.31 release build, 85 real clips)

| Stage | p50 | p90 | max | Notes |
|---|---:|---:|---:|---|
| Parakeet v2 ASR | 100 ms | 215 ms | 435 ms | 65 ms + 2.4 ms per second of audio |
| LLM cleanup (when it runs) | 335 ms | 893 ms | 2,039 ms | 84 transcripts, 2–431 words |
| Release → paste, all dictations | 234 ms | 661 ms | 1,973 ms | 4 of 83 over 1 s |
| … apps that get cleanup (63%) | 364 ms | 943 ms | 1,973 ms | Slack, Chrome, Conductor, Notes, Bear |
| … verbatim apps (37%) | 141 ms | 226 ms | 409 ms | Claude, ChatGPT, terminals skip the LLM |

Release → paste here is ASR + cleanup; recorder stop and paste dispatch are still not
instrumented in the GUI (see "Carried over").

- **No regression since 0.1.31.** Master and installed 0.1.31 produce identical ASR
  text on 85/85 clips and identical cleanup output on 84/84. The new local audio
  reader (PR #77) costs about 2 ms per clip. The usage gate adds two defaults reads.
  (The debug build is ~35% slower in ASR inference; all figures above are the release build.)
- **Speculative decoding holds up on real text.** The longest dictations (285–431
  words) clean up in 1.3–2.0 s; audit 2 measured 4–5 s for 249 words before it.
- **Cold starts are unchanged: 48 of 85 dictations (56%) follow a >5 min idle**, so
  the LLM context has been unloaded. Recording-start prewarm hides the reload for
  clips longer than about 1.7 s; only 3 of the 27 cold dictations bound for cleanup
  were shorter than 2.5 s. Without prewarm the first cleanup costs about 1.9 s. At a
  30-minute unload window, 30 of 85 would be cold instead of 48.

### Whisper is 14× slower than Parakeet

Same 85 clips, installed release build:

| Engine | p50 | p90 | max |
|---|---:|---:|---:|
| Parakeet v2 | 100 ms | 215 ms | 435 ms |
| Parakeet v3 (multilingual) | about 1.4× v2 | | |
| Whisper large-v3-turbo (q5) | 1,394 ms | 3,390 ms | 11,385 ms |

(v3 was only run on the debug build: 21.2 s for the set against 14.0–15.8 s for v2.)

A Whisper user waits 1.4–3.4 s before cleanup even starts. Onboarding already
recommends Parakeet v2 for English. Parakeet v3 covers 25 European languages at
roughly a tenth of Whisper's latency and scored better than Whisper turbo on the English test
below, so it is the better default for those languages too.

### Speed opportunities, in order of payoff

1. **Stop running the LLM when it has nothing to do** (see Accuracy #1). It is 66% of
   post-release time and a no-op on 58% of dictations.
2. **Steer multilingual users from Whisper to Parakeet v3** where the language is supported.
3. **Longer or memory-pressure-driven idle unload** (audit 2, item 3). Unchanged.

## Accuracy

### 1. LLM cleanup: mostly a no-op, occasionally harmful

84 real transcripts through `cleanup --stdin` with Noah's settings (deterministic:
two runs byte-identical):

| What cleanup did | Count |
|---|---:|
| Returned the text unchanged | 49 (58%) |
| Layout or punctuation only (paragraphs, list lines, commas) | 12 |
| Changed words, harmless (dropped a leading "and", fixed a garble) | ~16 |
| Changed words, harmful | 7 |

The harmful cases, all of which passed every existing guard:

- **Deleted a sentence.** A 71-word dictation came back 46 words long; a full
  24-word sentence in the middle was gone. The 0.3× length floor does not see this.
- **Followed the instruction instead of transcribing it.** "…write a message to them
  asking for the max discount possible, do it in a very creative and funny way…"
  became a drafted message with a greeting and sign-off. Dictated into Chrome.
- **Invented words.** "Hey Jane, really looking, really liked your place" became
  "Really looking forward to it. Really liked your place".
- **Reordered words.** "screen like I do" became "I do like a screen."
- **Mangled a prompt.** "Draft Matt a message to see if…" became "Draft Matt: See if…".
- **Dropped a lead-in** ("Two tweet things I was thinking about this morning that
  could be good ideas") while relabelling the rest "Tweet 1 / Tweet 2".
- One more dropped the word "bot" from "ads bot".

Three of the seven were dictated into Claude, where cleanup is skipped in practice
(`verbatimInAIApps`). The other four were in Chrome and did ship. So on the 53
dictations that really get cleanup, roughly 1 in 13 came out worse than the raw
transcript, against 30 of 53 where cleanup changed nothing at all.

Why it is mostly a no-op: Parakeet v2 already punctuates and capitalizes, filler
removal and number formatting are deterministic, so the model's remaining job is
layout (lists, message shape, paragraphs).

**Options, cheapest first**

- **(a) Word-retention guard.** After cleanup, compare input and output as bags of
  words. Reject (keep the raw text) when the output drops many content words or adds
  several that were never said, unless a spoken-edit cue is present. A crude
  prototype (reject at ≥4 content words dropped and >8% of the text, or ≥3 new
  content words) catches the sentence deletion and the drafted message, the two
  worst cases, and passes everything harmless. It also rejects the one real list
  (list cues like "one / two / three" are legitimately removed), so it needs a
  list-cue exemption. No latency cost.
- **(b) Cue gate, like spoken edits already have.** Only run cleanup when the
  transcript contains something for it to format: a greeting or sign-off, list
  cues, "new line / new paragraph". On this data that skips the LLM for 67 of 84
  dictations (71% of LLM time), and removes 6 of the 7 harmful rewrites. Cost: 10
  dictations lose a punctuation or paragraph tweak and one loses a garble fix. This
  is a behavior change and needs Noah's call.
- **(c) More verbatim targets.** Conductor (10 of 85 dictations) and Cursor-style
  agent apps are prompts too but are not on the verbatim list. Browser AI tabs cannot
  be detected today: `sourceURL` is empty on all 85 history rows.

### 2. Recognition: strong in general, weak on proper nouns

Ground truth (156 clips, 26 speakers, 3,006 words from LibriSpeech dev-clean; raw
WER including spelling variants like "favor/favour"):

| Engine | WER | ASR p50 |
|---|---:|---:|
| Parakeet v2 | 1.46% | 93 ms |
| Parakeet v3 | 2.10% | 103 ms |
| Whisper large-v3-turbo q5 | 2.69% | 1,443 ms |

About two thirds of v2's 44 "errors" are spelling or compounding variants, so the
real error rate is under 1%. This is clean read speech; it shows the engine ranking
and that nothing is broken, not what dictation feels like.

On Noah's own recordings there is no ground truth, so the three engines were
compared with each other (v2 vs v3: 6.1% of words differ; v2 vs Whisper: 5.8%; v2 is
deterministic run to run). Where two engines agree against v2, the pattern is
consistent:

- **Brand and people names.** "AppSumo" was said at least 9 times; v2 got it right 3
  times and otherwise produced Apsumo, Upsumo, Hapsumo, "that sumo", "Epson will"
  and "Absolute". "SendFox" → "Sandfox" (right 1 of 5). "Ilona" → "Alona" (0 of 3).
  "Beehiiv" → "Beehive", "Wispr Flow" → "Whisperflow".
- **Decoder glitches**, about 1 per 1,000 words: "I' reallyve" (for "I've really"),
  "it is's", "adsot bt andom" (for "ads bot and"). Cleanup fixed one of three.
- Whisper turbo knows the brand names but drops phrases more often; v3 keeps "uh/um".

**The dictionary fixes most of the name errors today.** Adding four spelling-only
entries (AppSumo, SendFox, Ilona, Beehiiv) to a copy of Noah's settings corrected 11
words across the 85 clips (AppSumo 3→6 correct, SendFox 1→4, Ilona 0→3) with zero
false changes and no measurable latency. The far misses ("Hapsumo", "that sumo",
"Epson will") need explicit "hears it as" alternates; "Beehive" is protected by the
real-word guard.

### 3. Dictionary "boost" drops and invents text

Settings → Output → dictionary boost (off by default) routes Parakeet through the
sliding-window decoder. With Noah's five-term dictionary on the same 85 clips:

- 5.4% of all words lost (5,856 → 5,541). One 33-word dictation came back as 6
  words; a 188-word one lost 46.
- Dictionary terms inserted where they were not said ("Seann", "Klaviyo").
- 13.8% of words differ from the normal path.
- 6–7× slower (98.6 s vs 15.8 s for the set; about 40 ms per second of audio).

The plain dictionary (text replacement + sound-alikes) does the job without any of
this. Recommend removing the toggle for Parakeet, or at least hiding it.

### 4. Number formatter turns "million" into digits everywhere

Standalone probe of `NumberCompaction.apply(_, style: .smart)`:

| Said | Typed |
|---|---|
| Million Dollar Weekend | 1,000,000 Dollar Weekend |
| Thanks a million. | Thanks a 1,000,000. |
| One in a million. | One in a 1,000,000. |
| It was a million dollar idea. | It was a 1,000,000 dollar idea. |

The first one is in Noah's real history (his own book title). "tier ones", "one of a
kind", "one by one" and "I for one" are handled correctly.

### 5. Accuracy is not measured anywhere repeatable

- `bench/corpus` (the "≥90% of Wispr Flow" target) has prompts but no audio or
  results on this machine or any workspace. The target has never been scored.
- The push gate's ASR suite runs whisper-tiny on synthetic speech. The shipping
  engine (Parakeet v2) and the cleanup pass have no accuracy regression check.
- This audit's two harnesses could become that check: the LibriSpeech subset for the
  engines (3 s to run on Parakeet), and a cleanup fidelity test (word retention over
  a fixed transcript set) for the LLM.

## Carried over from audit 2 (still open)

- **No stop → paste timing in the GUI.** Three days of unified log held 3 dictation
  starts and one paste mark; nothing covers ASR, LLM passes or the total. The numbers
  in this audit come from replaying clips through the CLI.
- **Watchdog log spam.** The fake "main thread stalled ≥18446744073s" line (wrapping
  subtraction in `MainThreadWatchdog.check`) was logged 2,979 times in the last 3 days.
- M1/M3 check of the speculative-decoding thresholds.

## Recommended order

1. Number formatter: leave idiomatic and title-case "million" as words. Small.
2. Remove or hide the Parakeet boost toggle. Small.
3. Add a word-retention guard to cleanup (option a). Small, no latency cost.
4. Decide on the cue gate (option b). Largest speed win left and removes most
   harmful rewrites, but changes behavior.
5. Add Conductor and similar agent apps to the verbatim list.
6. Noah: add AppSumo, SendFox, Ilona to the dictionary (with "Hapsumo" as an
   alternate), and record the 3-minute personal corpus.
7. Stop → paste Diag marks and the watchdog fix.

## Reproduce

Everything lives in `.context/audit3/` (gitignored; contains transcripts of Noah's
dictations, so it must not be committed):

- `run.sh <dev|inst> <bench|cleanup> <label> [clips-dir]` runs the app CLI under the
  isolated prefs suite `com.noahkagan.rhino.audit3` (a copy of the real prefs via
  `defaults export | defaults import`, history off; deleted at the end of this audit).
- `clips/` symlinks the history WAVs; `libri-clips/` + `libri-ref.json` are the
  ground-truth subset (openslr.org/resources/31/dev-clean-2.tar.gz, 6 clips per speaker, seed 7).
- `wer.py` normalizes and scores; `out/*.json` holds every run cited here;
  `cleanup-rows.json` has the per-dictation before/after.
- `nc/main.swift` compiles `NumberCompaction.swift` standalone for the "million" probes.

Limits: one Mac (M4), one speaker for the real-dictation data, 85 clips. Cross-engine
disagreement is not an error rate. The harmful-rewrite count is my reading of the
diffs. Machine load was 4–6 during the timed runs (other workspaces), so absolute
times are slightly pessimistic.
