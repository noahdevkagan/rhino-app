# Personal benchmark corpus — your voice, ~3 minutes

The quality target ("at least 90% of Wispr Flow's useful output") is
measured HERE — the gate corpus is synthetic audio on a tiny model and only
catches regressions. This is the real thing: your voice, scored against the
text you *meant* to produce.

## Record (~3 minutes, once)

```bash
brew install sox            # one-time, terminal recorder
cd ~/rhino-app/bench/corpus
./record.sh                 # guided: read prompt → speak → Enter → next
```

10 items: 4 short messages, 2 email-length, 4 hard cases (names, numbers,
a self-correction, ums). Speak like you actually dictate. If what you said
drifted from the prompt, edit that item's `intended` in items.json — we
score against intent, not verbatim speech.

## Score Rhino (~1 minute, repeatable per release)

```bash
./score-corpus.sh
```

## Compare against other services

Play the same clips into Wispr Flow / SuperWhisper / whatever (or
re-dictate the same items live there), paste each output into
`results/<service>/<id>.txt`, then:

```bash
python3 score-personal.py results/rhino-fluidaudio results/wispr
```

Prints zero-fix rate (usable without touching the keyboard), WER vs
intended, and the head-to-head ratio (target ≥ 90%).

Audio and results are gitignored — your voice never enters git history.
items.json and summary.json are committed.
