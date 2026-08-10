#!/bin/bash
# Hygiene suite: proves "nothing leaves this Mac" and keeps it proved.
#
# 1. Static  — the codebase contains no remote-endpoint strings, no deleted
#              remote files resurrected, no blanket ATS exemption.
# 2. Dynamic — a real end-to-end transcription (CLI, whisper tiny, isolated
#              HOME) opens NO network connection to anything but loopback.
#              Skipped under FAST=1 and when the app isn't built.
#
# If this suite fails, the privacy promise is broken. Fix the code, never
# the gate.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"

fail=0

echo "hygiene: [1/2] static scan"

# Deleted-in-Phase-1 files must stay deleted.
for f in \
    OpenSuperWhisper/Engines/RemoteEngine.swift \
    OpenSuperWhisper/Utils/LLMCleanup/RemoteBackend.swift \
    OpenSuperWhisper/Utils/UpdateChecker.swift \
    OpenSuperWhisper/RemoteSettingsSection.swift \
    OpenSuperWhisper/RemoteServerSettingsView.swift \
    OpenSuperWhisper/RemoteCleanupSettingsView.swift; do
    if [ -e "$ROOT/$f" ]; then
        echo "  FAIL: deleted remote file has reappeared: $f"
        fail=1
    fi
done

# No remote-endpoint strings in app sources. Word-boundary-ish patterns to
# avoid false positives; extend the list rather than loosening a pattern.
FORBIDDEN='api\.openai|api\.groq|groq\.com|openai/v1|/v1/audio/transcriptions|/v1/chat/completions|api\.github\.com'
hits=$(grep -rEn "$FORBIDDEN" "$ROOT/OpenSuperWhisper" --include='*.swift' 2>/dev/null)
if [ -n "$hits" ]; then
    echo "  FAIL: remote endpoint strings in sources:"
    echo "$hits" | sed 's/^/    /'
    fail=1
fi

# ATS must not be blanket-disabled (that exemption existed only for the
# deleted remote engine). Loopback-only NSAllowsLocalNetworking is fine.
if grep -q "NSAllowsArbitraryLoads" "$ROOT/OpenSuperWhisper/OpenSuperWhisper-Info.plist"; then
    echo "  FAIL: NSAllowsArbitraryLoads is back in Info.plist"
    fail=1
fi

[ "$fail" = "0" ] && echo "  static scan clean"

echo "hygiene: [2/2] dynamic egress check"

APP="$ROOT/Build/Build/Products/Debug/OpenSuperWhisper.app/Contents/MacOS/OpenSuperWhisper"
if [ "${FAST:-0}" = "1" ]; then
    echo "  skipped (FAST=1)"
elif [ ! -x "$APP" ]; then
    # The push gate builds before running suites, so this only happens on a
    # bare checkout. Loud skip, not silent pass.
    echo "  SKIPPED: no dev build at $APP — run ./run.sh build first"
else
    # Isolated HOME so the run can't touch (or depend on) the real install's
    # prefs, and we can pin the engine to the repo's tiny whisper model.
    SCRATCH="$(mktemp -d)"
    mkdir -p .out && : > .out/egress.txt
    HOME="$SCRATCH" defaults write fr.my-monkey.opensuperwhisper selectedEngine whisper
    HOME="$SCRATCH" defaults write fr.my-monkey.opensuperwhisper selectedWhisperModelPath "$ROOT/ggml-tiny.en.bin"
    HOME="$SCRATCH" defaults write fr.my-monkey.opensuperwhisper aiPostProcessingEnabled -bool false
    HOME="$SCRATCH" defaults write fr.my-monkey.opensuperwhisper saveTranscriptionHistory -bool false

    HOME="$SCRATCH" "$APP" transcribe "$ROOT/jfk.wav" > .out/transcript.txt 2> .out/cli-stderr.txt &
    PID=$!
    # Sample the process's open network sockets for its whole lifetime.
    while kill -0 "$PID" 2>/dev/null; do
        lsof -a -p "$PID" -i -n -P 2>/dev/null | tail -n +2 >> .out/egress.txt
        sleep 0.2
    done
    wait "$PID"; status=$?
    rm -rf "$SCRATCH"

    if [ "$status" -ne 0 ]; then
        echo "  FAIL: CLI transcription exited $status (see tests/hygiene/.out/cli-stderr.txt)"
        fail=1
    fi
    if ! grep -qi "country" .out/transcript.txt; then
        echo "  FAIL: transcript doesn't look right (see tests/hygiene/.out/transcript.txt)"
        fail=1
    fi
    # Any socket row whose addresses aren't all loopback is an egress attempt.
    offending=$(awk '{ok=1; for(i=9;i<=NF;i++) if ($i ~ /->/ || $i ~ /:[0-9]+$/) { if ($i !~ /127\.0\.0\.1|\[::1\]|localhost/) ok=0 }; if (!ok) print }' .out/egress.txt | sort -u)
    if [ -n "$offending" ]; then
        echo "  FAIL: non-loopback network activity during transcription:"
        echo "$offending" | sed 's/^/    /'
        fail=1
    fi
    [ "$fail" = "0" ] && echo "  transcribed with zero non-loopback sockets"
fi

if [ "$fail" != "0" ]; then
    echo "hygiene: FAIL"
    exit 1
fi
echo "hygiene: PASS"
