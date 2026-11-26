# Accent benchmark

WER and latency of every Rhino engine/model on real non-US English speech, against a US control.
Not a push-gate suite: it needs ~40 MB of downloaded audio and the installed models.

Source: Mozilla Common Voice 17.0 English (CC0), via the ungated `fixie-ai/common_voice_17_0`
mirror on Hugging Face, test + validation splits, filtered by the speaker's self-reported accent.
At most 3 clips per speaker, sentences of 5+ words. Audio stays out of git (`audio/` is ignored);
`manifest.tsv` pins the exact clips so a re-fetch gets the same set.

```bash
cd bench/accents
python3 -I build_manifest.py      # only to re-pick clips; manifest.tsv is committed
python3 -I fetch.py               # downloads the 249 clips → audio/<group>/*.wav (16 kHz mono)
./degrade.sh au us                # optional: quiet / noisy / lo-fi copies (needs ffmpeg)
cd ../.. && ./run.sh build && cd bench/accents
./run.sh                          # all configs x all groups, then score.py
CONFIGS="pk-v2 whisper-turbo" ACCENTS="au au-noisy" ./run.sh
```

Groups: `au` Australian, `us` US (control), `gb` England, `in` India/South Asia, `nz` New Zealand
(only 17 clips in the source). Configs: `pk-v2`, `pk-v3`, `whisper-turbo`, `whisper-turbo-q5`,
`whisper-turbo-q8` (each skipped if its model is not installed). The runner uses its own prefs
domain (`com.noahkagan.rhino.bench.accents`), pins Whisper's language to English, and turns off
LLM cleanup and history, so it never touches your real settings.

Scoring (`score.py`): corpus WER per group after a normaliser that ignores casing, punctuation,
numbers-as-digits, contractions, hyphenation and British vs American spelling (Rhino's Brit mode
changes spelling after recognition, so spelling is not a recognition error). Clips that every
engine gets 80%+ wrong are treated as broken Common Voice rows and dropped (the count is printed).
95% intervals are bootstrap over clips; the paired table compares each config with `--baseline`
on the same clips. With 50–60 clips per group, differences under ~2 points are noise.
Latency is the bench's wall time per clip, first (warm-up) clip excluded.

## Quiet input and noise (2026-11-25, decisions.md "Quiet mics")

```bash
./levels.sh au us                    # -24/-30/-36 dB copies -> audio/<g>-q24|q30|q36
python3 mix_noise.py au 10           # seeded pink noise at 10 dB SNR -> audio/au-snr10
python3 mix_noise.py au 10 30        # same, then 30 dB down -> audio/au-snr10q30
python3 ../../tests/asr/gen_noise.py audio/noise --full --speech ../../tests/asr/audio/.tmp/short.wav
OUT=.out/after CONFIGS="pk-v2 pk-v3 whisper-turbo" ACCENTS="noise au-q24 ..." ./run.sh
python3 levels_report.py .out/base .out/after   # WER + empty counts, and words typed on no-speech clips
```
All noise here is synthetic (seeded); nothing is downloaded or committed.
