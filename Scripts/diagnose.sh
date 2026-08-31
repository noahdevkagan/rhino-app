#!/bin/bash
# Rhino latency diagnostic — for users reporting "it's slow after I stop talking".
#
# Send this file to the user; they run it in Terminal:
#
#   bash ~/Downloads/diagnose.sh
#
# It needs nothing but an installed Rhino.app. It reads their settings, generates
# two synthetic test clips (no mic, no personal audio), times every stage of the
# stop-to-text pipeline through Rhino's own CLI (transcription cold + warm, LLM
# cleanup), prints likely causes, and writes the full report to
# ~/Desktop/rhino-diagnosis.txt for them to email back.
#
# Read-only: it never changes any Rhino setting.
set -uo pipefail

REPORT="$HOME/Desktop/rhino-diagnosis.txt"
DOMAIN="com.noahkagan.rhino"
WORK="$(mktemp -d /tmp/rhino-diagnose.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# --- helpers -----------------------------------------------------------------

# Milliseconds since epoch (perl ships with macOS; python3 may not).
now_ms() { perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000'; }

# defaults read with a fallback for unset keys (unset == app default).
pref() {
    local val
    val=$(defaults read "$DOMAIN" "$2" 2>/dev/null) || val="$3 (default)"
    printf '%-28s %s\n' "$1:" "$val"
}
prefval() { defaults read "$DOMAIN" "$1" 2>/dev/null || echo "$2"; }

say_report() { echo "$1" | tee -a "$REPORT"; }

# --- locate Rhino ------------------------------------------------------------

APP=""
for candidate in "/Applications/Rhino.app" "$HOME/Applications/Rhino.app"; do
    [ -x "$candidate/Contents/MacOS/Rhino" ] && APP="$candidate" && break
done
if [ -z "$APP" ]; then
    echo "ERROR: Rhino.app not found in /Applications. Install Rhino first." >&2
    exit 1
fi
BIN="$APP/Contents/MacOS/Rhino"

: > "$REPORT"
say_report "=== Rhino latency diagnosis — $(date) ==="
say_report ""

# --- system + app info -------------------------------------------------------

say_report "--- Machine ---"
{
    printf '%-28s %s\n' "Mac:" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
    printf '%-28s %s GB\n' "RAM:" "$(( $(sysctl -n hw.memsize) / 1073741824 ))"
    printf '%-28s %s (%s)\n' "macOS:" "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)"
    printf '%-28s %s\n' "Free disk:" "$(df -h / | awk 'NR==2 {print $4}')"
} | tee -a "$REPORT"
say_report ""

say_report "--- Rhino ---"
VERSION=$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo unknown)
printf '%-28s %s\n' "Version:" "$VERSION" | tee -a "$REPORT"
RUNNING="no"
pgrep -x Rhino >/dev/null && RUNNING="yes"
printf '%-28s %s\n' "App currently running:" "$RUNNING" | tee -a "$REPORT"
say_report ""

# --- settings that drive stop-to-text latency --------------------------------

say_report "--- Settings (the ones that matter for speed) ---"
{
    pref "Engine" selectedEngine "whisper"
    MODEL_PATH=$(prefval selectedWhisperModelPath "")
    if [ -n "$MODEL_PATH" ] && [ -f "$MODEL_PATH" ]; then
        printf '%-28s %s (%s)\n' "Whisper model:" "$(basename "$MODEL_PATH")" \
            "$(du -h "$MODEL_PATH" | cut -f1 | tr -d ' ')"
    else
        printf '%-28s %s\n' "Whisper model:" "${MODEL_PATH:-none configured}"
    fi
    pref "Parakeet version" fluidAudioModelVersion "v3"
    pref "Language" whisperLanguage "en"
    pref "Unload model when idle" unloadWhisperModelWhenIdle "0"
    pref "Beam search" useBeamSearch "0"
    pref "AI cleanup (local LLM)" aiPostProcessingEnabled "0"
    pref "Smart formatting" smartFormattingEnabled "0"
    pref "Spoken edits" spokenEditsEnabled "0"
    pref "Live transcription" liveTranscriptionEnabled "0"
} | tee -a "$REPORT"
say_report ""

# --- synthetic clips (no mic, nothing personal) ------------------------------

echo "Generating test audio..."
SHORT_TXT="Let's meet tomorrow at ten thirty to go over the launch plan."
LONG_TXT="Hey team, quick update on the project. We shipped the new onboarding \
flow yesterday and the early numbers look good. Conversion is up about four \
percent and support tickets are flat. Next week we focus on the billing \
migration, and I want everyone to review the rollout checklist before Friday. \
Let me know if anything looks off."
say -o "$WORK/short.aiff" "$SHORT_TXT" 2>/dev/null
say -o "$WORK/long.aiff" "$LONG_TXT" 2>/dev/null
mkdir -p "$WORK/clips"
for f in short long; do
    afconvert -f WAVE -d LEI16@16000 -c 1 "$WORK/$f.aiff" "$WORK/clips/$f.wav"
done
short_dur=$(afinfo "$WORK/clips/short.wav" 2>/dev/null | awk '/estimated duration/ {printf "%.1f", $3}')
long_dur=$(afinfo "$WORK/clips/long.wav" 2>/dev/null | awk '/estimated duration/ {printf "%.1f", $3}')

# --- 1. cold run: model load + transcribe + cleanup (what a first dictation feels like)

say_report "--- Timings ---"
echo "Timing cold start (model load + transcribe + cleanup)... this can take a minute."
t0=$(now_ms)
COLD_OUT=$("$BIN" transcribe "$WORK/clips/short.wav" 2>"$WORK/cold.err")
COLD_RC=$?
t1=$(now_ms)
if [ $COLD_RC -ne 0 ]; then
    say_report "COLD RUN FAILED — this alone may be the bug:"
    tail -5 "$WORK/cold.err" | tee -a "$REPORT"
else
    printf '%-44s %s ms\n' "Cold: load + transcribe ${short_dur}s clip + cleanup:" "$((t1 - t0))" | tee -a "$REPORT"
fi

# --- 2. warm ASR: model loaded once, per-clip transcription time (bench mode)

echo "Timing warm transcription..."
cp "$WORK/clips/short.wav" "$WORK/clips/short2.wav"   # second pass of the same audio
"$BIN" bench "$WORK/clips" > "$WORK/bench.json" 2>"$WORK/bench.err"
if [ -s "$WORK/bench.json" ]; then
    # bench prints [{"file":...,"ms":...,"text":...}]; pull file/ms pairs with sed.
    while IFS=$'\t' read -r fname ms; do
        case "$fname" in
            short.wav)  printf '%-44s %s ms\n' "Warm ASR, ${short_dur}s clip (1-sentence):" "$ms" ;;
            short2.wav) printf '%-44s %s ms\n' "Warm ASR, ${short_dur}s clip (repeat):" "$ms" ;;
            long.wav)   printf '%-44s %s ms\n' "Warm ASR, ${long_dur}s clip (email-length):" "$ms" ;;
        esac
    done < <(sed -e 's/},{/}\n{/g' "$WORK/bench.json" \
             | sed -n 's/.*"file":"\([^"]*\)".*"ms":\([0-9]*\).*/\1\t\2/p') | tee -a "$REPORT"
else
    say_report "WARM BENCH FAILED:"
    tail -5 "$WORK/bench.err" | tee -a "$REPORT"
fi

# --- 3. LLM cleanup pass alone (the post-ASR stage AI cleanup adds) ----------

AI_ON=$(prefval aiPostProcessingEnabled 0)
if [ "$AI_ON" = "1" ]; then
    echo "Timing LLM cleanup pass..."
    t0=$(now_ms)
    "$BIN" cleanup "$LONG_TXT" >/dev/null 2>&1
    t1=$(now_ms)
    printf '%-44s %s ms\n' "LLM cleanup of email-length text (cold):" "$((t1 - t0))" | tee -a "$REPORT"
    t0=$(now_ms)
    "$BIN" cleanup "$SHORT_TXT" >/dev/null 2>&1
    t1=$(now_ms)
    printf '%-44s %s ms\n' "LLM cleanup of 1 sentence (model cached):" "$((t1 - t0))" | tee -a "$REPORT"
else
    say_report "LLM cleanup: OFF — not a factor."
fi
say_report ""

# --- verdict heuristics ------------------------------------------------------

say_report "--- Likely causes (auto-check) ---"
FOUND=0
if [ "$(prefval unloadWhisperModelWhenIdle 0)" = "1" ]; then
    say_report "* 'Unload model when idle' is ON — the model reloads on EVERY dictation,"
    say_report "  so every dictation pays the cold-start time above. Turn it off in"
    say_report "  Settings -> Models. This is the #1 cause of 'way slower than Wispr'."
    FOUND=1
fi
case "$(basename "$(prefval selectedWhisperModelPath "")" 2>/dev/null)" in
    *large*|*medium*)
        say_report "* A large/medium Whisper model is selected — accurate but slow. Switch to"
        say_report "  Parakeet v2 (English) or Whisper turbo in Settings -> Models."
        FOUND=1 ;;
esac
if [ "$(prefval useBeamSearch 0)" = "1" ]; then
    say_report "* Beam search is ON — this multiplies transcription time. Turn it off."
    FOUND=1
fi
[ $FOUND -eq 0 ] && say_report "No obvious setting problem — the timings above tell the story."
say_report ""
say_report "=== End of report ==="

echo ""
echo ">>> Done. Report saved to: $REPORT"
echo ">>> Please email that file back (it contains no audio and no personal text)."
open -R "$REPORT" 2>/dev/null || true
