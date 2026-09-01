#!/bin/bash
# Output-parity harness: prove a branch didn't change what users get.
#
# Builds the base ref in a temp worktree (reused across runs), then compares
# byte-for-byte against the current dev build:
#
#   1. LLM cleanup over corpus.txt, in three configs (default, smart
#      formatting, spoken edits). The branch side runs `cleanup --stdin` —
#      every line through ONE process, the app's real dictation-after-
#      dictation pattern — so cross-dictation state (e.g. the KV prefix
#      cache) is exercised against the base's isolated per-line runs.
#      Greedy decoding is deterministic: any byte difference is a real
#      behavioral change.
#   2. ASR bench texts over generated clips (1s–25s, incl. the >15s chunked
#      path, real speech, silence), offline AND dictionary-boosted. The
#      boosted path is nondeterministic run-to-run upstream (FluidAudio
#      sliding-window; observed on unchanged master), so the base is run
#      twice and clips unstable base-vs-base are excluded before comparing.
#
# Usage:
#   bench/parity/parity.sh [base-ref]        # default origin/master
#   BASE_APP=/path/to/Rhino bench/parity/parity.sh   # skip base build
#
# Needs: a current dev build (./run.sh build), the Parakeet + built-in LLM
# models already downloaded (run the app once), sox-free — uses `say`.
# Uses an isolated prefs suite; never touches your real settings.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
BASE_REF="${1:-origin/master}"
SUITE=com.noahkagan.rhino.parity
OUT="$ROOT/bench/parity/.out"
BRANCH_APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
[ -x "$BRANCH_APP" ] || { echo "no dev build — run ./run.sh build first"; exit 1; }

# --- Base build (worktree keyed by commit, reused) -------------------------
if [ -z "${BASE_APP:-}" ]; then
    BASE_SHA=$(git -C "$ROOT" rev-parse --short "$BASE_REF") || exit 1
    BASE_DIR="/tmp/rhino-parity-base-$BASE_SHA"
    BASE_APP="$BASE_DIR/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
    if [ ! -x "$BASE_APP" ]; then
        echo "building base $BASE_REF ($BASE_SHA) in $BASE_DIR (first run is slow)..."
        git -C "$ROOT" worktree add -f "$BASE_DIR" "$BASE_REF" >/dev/null || exit 1
        (cd "$BASE_DIR" && git submodule update --init --recursive && ./run.sh build) \
            > "$BASE_DIR.build.log" 2>&1 \
            || { echo "base build failed — see $BASE_DIR.build.log"; exit 1; }
    fi
fi
echo "base app:   $BASE_APP"
echo "branch app: $BRANCH_APP"

rm -rf "$OUT" && mkdir -p "$OUT/clips"

# --- Shared prefs ----------------------------------------------------------
defaults delete "$SUITE" >/dev/null 2>&1 || true
defaults write "$SUITE" selectedEngine fluidaudio
defaults write "$SUITE" fluidAudioModelVersion v2
defaults write "$SUITE" saveTranscriptionHistory -bool false
defaults write "$SUITE" customDictionaryEnabled -bool true
defaults write "$SUITE" customDictionaryBoostEnabled -bool false
python3 - <<'PY' | xxd -p | tr -d '\n' > "$OUT/dict.hex"
import json, uuid
print(json.dumps([
    {"id": str(uuid.uuid4()).upper(), "original": "wispr flow", "replacement": "Wispr Flow",
     "alternates": [], "spacing": "standalone"},
    {"id": str(uuid.uuid4()).upper(), "original": "app sumo", "replacement": "AppSumo",
     "alternates": [], "spacing": "standalone"}]), end="")
PY
defaults write "$SUITE" customDictionaryData -data "$(cat "$OUT/dict.hex")"

FAILURES=0

# --- 1. LLM cleanup parity -------------------------------------------------
defaults write "$SUITE" aiPostProcessingEnabled -bool true
base_perline() {  # $1 = output json
    echo '[' > "$1"; local first=1
    while IFS= read -r line; do
        local o
        o=$(RHINO_PREFS_SUITE="$SUITE" "$BASE_APP" cleanup "$line" --json 2>/dev/null)
        [ $first = 1 ] || echo ',' >> "$1"; first=0
        python3 -c '
import json, sys
o = json.loads(sys.argv[1])
print(json.dumps({"input": sys.argv[2], "text": o["text"]}))' "$o" "$line" >> "$1"
    done < corpus.txt
    echo ']' >> "$1"
}
for config in default smartfmt spokenedits; do
    case $config in
        default)     defaults write "$SUITE" smartFormattingEnabled -bool false
                     defaults write "$SUITE" spokenEditsEnabled -bool false ;;
        smartfmt)    defaults write "$SUITE" smartFormattingEnabled -bool true ;;
        spokenedits) defaults write "$SUITE" smartFormattingEnabled -bool false
                     defaults write "$SUITE" spokenEditsEnabled -bool true ;;
    esac
    echo "cleanup [$config]: base per-line..."
    base_perline "$OUT/cleanup-base-$config.json"
    echo "cleanup [$config]: branch sequential (--stdin)..."
    RHINO_PREFS_SUITE="$SUITE" "$BRANCH_APP" cleanup --stdin < corpus.txt \
        2>/dev/null > "$OUT/cleanup-branch-$config.json"
    python3 - "$OUT" "$config" <<'PY' || FAILURES=$((FAILURES+1))
import json, sys
out, config = sys.argv[1], sys.argv[2]
base = {r['input']: r['text'] for r in json.load(open(f'{out}/cleanup-base-{config}.json'))}
branch = {r['input']: r['text'] for r in json.load(open(f'{out}/cleanup-branch-{config}.json'))}
diffs = [k for k in base if base[k] != branch.get(k)]
for k in diffs:
    print(f"  DIFF {k!r}\n    base:   {base[k]!r}\n    branch: {branch.get(k)!r}")
print(f"cleanup [{config}]: {'PASS — identical' if not diffs else 'FAIL — ' + str(len(diffs)) + ' diffs'} "
      f"({len(base)} inputs)")
sys.exit(1 if diffs else 0)
PY
done
defaults write "$SUITE" spokenEditsEnabled -bool false

# --- 2. ASR parity ---------------------------------------------------------
defaults write "$SUITE" aiPostProcessingEnabled -bool false
gen() { say -v "$2" ${4:+-r "$4"} -o "$OUT/say.aiff" "$3" \
        && afconvert -f WAVE -d LEI16@16000 -c 1 "$OUT/say.aiff" "$OUT/clips/$1.wav"; }
gen c1-short Samantha "Ship it on Friday."
gen c2-mid Daniel "The quarterly numbers came in stronger than expected, and the team wants to move the launch up by a week."
gen c3-long Karen "Before we finalize the announcement, please review the pricing table, confirm the discount codes work in the sandbox, and make sure the support docs mention the new refund window, because last time we missed that."
gen c4-chunked Fred "Here is the plan for the week. Monday we finish the onboarding flow and hand it to design review. Tuesday is reserved for bug triage and the accessibility audit. On Wednesday the marketing site gets its new pricing page. Thursday we cut the release candidate and run the full regression suite. Friday morning we ship, and in the afternoon we write the retrospective."
gen c5-fast Samantha "This is a fast talker reading a long sentence about metrics dashboards and conversion funnels to stress the decoder." 260
cp "$ROOT/jfk.wav" "$OUT/clips/c6-jfk.wav"
python3 -c '
import wave, sys
w = wave.open(sys.argv[1], "w")
w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
w.writeframes(b"\x00" * 16000 * 2 * 10); w.close()' "$OUT/clips/c7-silence.wav"
rm -f "$OUT/say.aiff"

for mode in offline boosted; do
    if [ $mode = boosted ]; then
        defaults write "$SUITE" customDictionaryBoostEnabled -bool true
    else
        defaults write "$SUITE" customDictionaryBoostEnabled -bool false
    fi
    echo "asr [$mode]: base run 1..."
    RHINO_PREFS_SUITE="$SUITE" "$BASE_APP" bench "$OUT/clips" 2>/dev/null > "$OUT/asr-base1-$mode.json"
    echo "asr [$mode]: base run 2 (stability check)..."
    RHINO_PREFS_SUITE="$SUITE" "$BASE_APP" bench "$OUT/clips" 2>/dev/null > "$OUT/asr-base2-$mode.json"
    echo "asr [$mode]: branch..."
    RHINO_PREFS_SUITE="$SUITE" "$BRANCH_APP" bench "$OUT/clips" 2>/dev/null > "$OUT/asr-branch-$mode.json"
    python3 - "$OUT" "$mode" <<'PY' || FAILURES=$((FAILURES+1))
import json, sys
out, mode = sys.argv[1], sys.argv[2]
b1 = {r['file']: r['text'] for r in json.load(open(f'{out}/asr-base1-{mode}.json'))}
b2 = {r['file']: r['text'] for r in json.load(open(f'{out}/asr-base2-{mode}.json'))}
br = {r['file']: r['text'] for r in json.load(open(f'{out}/asr-branch-{mode}.json'))}
unstable = sorted(f for f in b1 if b1[f] != b2[f])
stable = sorted(f for f in b1 if f not in unstable)
diffs = [f for f in stable if b1[f] != br.get(f)]
for f in diffs:
    print(f"  DIFF {f}\n    base:   {b1[f]!r}\n    branch: {br.get(f)!r}")
note = f", {len(unstable)} excluded as base-unstable: {unstable}" if unstable else ""
print(f"asr [{mode}]: {'PASS — identical' if not diffs else 'FAIL — ' + str(len(diffs)) + ' diffs'} "
      f"({len(stable)} stable clips{note})")
sys.exit(1 if diffs else 0)
PY
done

defaults delete "$SUITE" >/dev/null 2>&1 || true
echo
if [ "$FAILURES" -eq 0 ]; then
    echo "parity: PASS — branch output matches $BASE_REF byte-for-byte"
else
    echo "parity: FAIL — $FAILURES section(s) differ (see DIFF lines above)"
fi
exit "$FAILURES"
