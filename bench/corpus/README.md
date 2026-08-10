# Personal benchmark corpus — Noah's voice, real dictations

The plan's quality target ("at least 90% of Wispr Flow's useful output") is
measured HERE, not in tests/asr — the gate corpus is synthetic `say` audio
on a tiny model and only catches regressions. This corpus is the real thing:
your voice, your phrasing, scored against the text you *meant* to produce.

## One-time recording session (~30 min)

1. Open `items.json` — 30 prompts: 10 short messages/AI prompts, 10
   email-length prose, 10 hard cases (fillers, self-corrections, lists,
   names, numbers, technical terms). Edit freely to match what you actually
   dictate day to day.
2. For each item, record yourself saying it naturally (QuickTime → New Audio
   Recording, or any recorder): speak like you dictate, fillers and
   restarts included. Save as `audio/<id>.m4a`.
3. In `items.json`, `intended` is the text you'd want to SEND — fillers
   removed, restarts resolved. Adjust it after recording if what you said
   drifted from the prompt. Score against intent, not verbatim speech.

## Scoring a candidate (repeatable, per release)

    ./score-corpus.sh              # runs every clip through the dev build
    ./score-corpus.sh --engine parakeet-v2   # config under test

For Wispr Flow (no CLI): play each clip into it via a virtual mic (BlackHole)
or re-dictate the same items live, paste its output into
`results/wispr/<id>.txt`, then:

    python3 score-personal.py results/wispr

Metrics per candidate (written to `results/<name>/summary.json`):
- zero-fix rate — % of items whose output matches intended after
  normalization (usable without touching the keyboard)
- WER vs intended
- meaning-changing failures (flagged for manual review when WER > 15%)

Compare candidates side by side:

    python3 compare.py results/rhino-parakeet-v2 results/wispr

Audio and results are gitignored (your voice stays out of git history);
items.json and summaries are committed.
