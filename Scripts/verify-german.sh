#!/bin/bash
# Manual verification for the wrong-language dictation fixes (German→English /
# German→Russian). Synthesizes German speech with `say`, runs it through the
# real pipeline (the app's own CLI), and checks the output stays German:
# no Cyrillic, and more German than English function words.
#
# Passes:
#   1. Parakeet v3 (fluidaudio) — the engine behind the German→Russian report.
#      Skipped (with instructions) if the v3 model isn't downloaded yet, so a
#      verification run never triggers a multi-gigabyte model download itself.
#   2. Whisper — only if the app has a multilingual (non-.en) model configured.
#   3. LLM cleanup — the German→English report; needs the built-in cleanup
#      model downloaded, otherwise skipped with a note.
#
# Run by hand: ./Scripts/verify-german.sh   (not part of the push gate)
# Prefs are isolated via RHINO_PREFS_SUITE — your app settings are untouched.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
if [ ! -x "$APP" ]; then
    echo "No dev build found — building first (./run.sh build)…"
    ./run.sh build || exit 1
elif [ -n "$(find "$ROOT/OpenSuperWhisper" -name '*.swift' -newer "$APP" -print -quit 2>/dev/null)" ]; then
    # A binary older than the sources would silently verify the UNFIXED code —
    # exactly the stale-build trap this script exists to prevent.
    echo "Dev build is older than the source tree — rebuilding (./run.sh build)…"
    ./run.sh build || exit 1
fi
[ -x "$APP" ] || { echo "error: still no binary at $APP"; exit 1; }

SUITE=com.noahkagan.rhino.german-verify
OUT="$ROOT/Scripts/.german-verify"
mkdir -p "$OUT/audio"
defaults delete "$SUITE" >/dev/null 2>&1 || true

# --- German voice ------------------------------------------------------------
VOICE=$(say -v '?' | sed -n 's/^\(.*[^ ]\)  *de_DE.*/\1/p' | head -1)
if [ -z "$VOICE" ]; then
    echo "error: no German (de_DE) voice installed."
    echo "Install one: System Settings → Accessibility → Spoken Content →"
    echo "System Voice → Manage Voices… → add 'Anna (German)'. Then rerun."
    exit 1
fi
echo "Using German voice: $VOICE"

# --- Test sentences ----------------------------------------------------------
# Dictation-shaped German: messages, numbers, umlauts, a list, and one long
# paragraph (~40s spoken) to exercise the long-form chunked decode path where
# the wrong-language drift lives.
TEXTS=(
"Guten Morgen, ich hoffe, es geht dir gut. Können wir das Treffen auf Dienstag verschieben?"
"Bitte schick mir die Unterlagen bis morgen Abend, danke schön."
"Heute war die Übertragung wieder teilweise auf Russisch, obwohl ich nur Deutsch gesprochen habe."
"Das Wetter in Berlin ist heute sonnig bei einundzwanzig Grad."
"Ich möchte einen Termin beim Zahnarzt für nächste Woche vereinbaren."
"Die Rechnung über dreihundertfünfzig Euro wurde gestern überwiesen."
"Hallo Sabine, vielen Dank für deine Nachricht, ich melde mich später bei dir. Viele Grüße, Noah."
"Wir treffen uns um halb sieben vor dem Bahnhof und gehen dann zusammen essen."
"Nummer eins, den Bericht fertigstellen. Nummer zwei, die E-Mail an das Team senden."
"Liebe Kolleginnen und Kollegen, ich möchte euch heute einen kurzen Überblick über den Stand des Projekts geben. Wir haben in den letzten zwei Wochen große Fortschritte gemacht. Die neue Version der Anwendung läuft stabil und die ersten Rückmeldungen der Tester sind sehr positiv. Es gibt allerdings noch einige offene Punkte, die wir vor der Veröffentlichung klären müssen. Zum einen fehlt noch die Übersetzung der Oberfläche, zum anderen müssen wir die Dokumentation aktualisieren. Ich schlage vor, dass wir uns am Donnerstag um zehn Uhr zusammensetzen und die restlichen Aufgaben verteilen. Bitte bereitet eure Fragen vor und bringt eure Notizen mit. Vielen Dank für eure Unterstützung und bis Donnerstag."
)

for i in "${!TEXTS[@]}"; do
    clip="$OUT/audio/de_$i.aiff"
    [ -f "$clip" ] || say -v "$VOICE" -o "$clip" "${TEXTS[$i]}"
done

# --- Language check helper ---------------------------------------------------
cat > "$OUT/check.py" <<'PY'
import re, sys, unicodedata
text = open(sys.argv[1], encoding="utf-8", errors="replace").read().strip()
words = set(re.findall(r"[a-zäöüß]+", text.lower()))
DE = {"der","die","das","und","ich","ist","nicht","ein","eine","mit","für","wir",
      "auf","dem","den","auch","habe","hoffe","danke","bitte","grüße","bis","uns",
      "möchte","noch","dass","euch","bei","gut","heute","morgen","um","vor","es"}
EN = {"the","and","is","was","are","of","to","have","you","please","with","we",
      "can","this","that","not","my","your","today","tomorrow","thank","thanks"}
cyr = [c for c in text if "CYRILLIC" in unicodedata.name(c, "")]
de, en = len(words & DE), len(words & EN)
if not text:
    print("FAIL  (empty output)"); sys.exit(1)
if cyr:
    print(f"FAIL  (CYRILLIC output — the German→Russian bug): {text[:120]}"); sys.exit(1)
if en > de:
    print(f"FAIL  (came back ENGLISH, de={de} en={en}): {text[:120]}"); sys.exit(1)
if de == 0:
    print(f"WARN  (language unclear): {text[:120]}"); sys.exit(0)
print(f"PASS  (de={de} en={en}): {text[:80]}")
PY

fail=0
run_pass() {  # $1 = pass name
    local name=$1 result
    echo; echo "=== $name ==="
    for i in "${!TEXTS[@]}"; do
        RHINO_PREFS_SUITE="$SUITE" "$APP" transcribe "$OUT/audio/de_$i.aiff" \
            > "$OUT/$name.$i.txt" 2> "$OUT/$name.$i.log" || true
        printf 'clip %2d: ' "$i"
        python3 "$OUT/check.py" "$OUT/$name.$i.txt" || fail=1
    done
}

# Shared prefs for all passes: German selected, history off, cleanup off
# (cleanup gets its own pass so ASR failures aren't masked or blamed wrongly).
defaults write "$SUITE" whisperLanguage de
defaults write "$SUITE" saveTranscriptionHistory -bool false
defaults write "$SUITE" aiPostProcessingEnabled -bool false

# --- Pass 1: Parakeet v3 -----------------------------------------------------
# FluidAudio caches under Models/<repo-name-minus-"-coreml">, so the folder is
# "parakeet-tdt-0.6b-v3" — match both spellings to be safe.
PARAKEET_DIR=$(find "$HOME/Library/Application Support/FluidAudio" -maxdepth 3 -type d \
    -name "parakeet-tdt-0.6b-v3*" 2>/dev/null | head -1)
if [ -n "$PARAKEET_DIR" ]; then
    defaults write "$SUITE" selectedEngine fluidaudio
    defaults write "$SUITE" fluidAudioModelVersion v3
    run_pass parakeet-v3
else
    echo; echo "=== parakeet-v3 SKIPPED: model not downloaded ==="
    echo "Select Parakeet v3 once in the app (Settings → model) to download it, then rerun."
fi

# --- Pass 2: Whisper (only with a multilingual model) ------------------------
WHISPER_MODEL=$(defaults read com.noahkagan.rhino selectedWhisperModelPath 2>/dev/null || true)
case "$WHISPER_MODEL" in
    *.en.bin|"") echo; echo "=== whisper SKIPPED: no multilingual whisper model configured ===";;
    *)  if [ -f "$WHISPER_MODEL" ]; then
            defaults write "$SUITE" selectedEngine whisper
            defaults write "$SUITE" selectedWhisperModelPath "$WHISPER_MODEL"
            run_pass whisper
        else
            echo; echo "=== whisper SKIPPED: configured model file missing ==="
        fi;;
esac

# --- Pass 3: LLM cleanup (the German→English report) -------------------------
echo; echo "=== llm-cleanup ==="
defaults write "$SUITE" aiPostProcessingEnabled -bool true
for i in 0 1 3 6 7 8; do
    RHINO_PREFS_SUITE="$SUITE" "$APP" cleanup "${TEXTS[$i]}" \
        > "$OUT/cleanup.$i.txt" 2> "$OUT/cleanup.$i.log" || true
    if grep -q "not downloaded" "$OUT/cleanup.$i.log"; then
        echo "SKIPPED: built-in cleanup model not downloaded (enable AI cleanup in the app once)."
        break
    fi
    printf 'text %2d: ' "$i"
    python3 "$OUT/check.py" "$OUT/cleanup.$i.txt" || fail=1
done

defaults delete "$SUITE" >/dev/null 2>&1 || true
echo
if [ "$fail" = 0 ]; then
    echo "ALL CHECKS PASSED — full outputs in Scripts/.german-verify/"
else
    echo "FAILURES — see Scripts/.german-verify/ for full outputs and logs"
fi
exit $fail
