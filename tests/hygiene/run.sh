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
# Isolated prefs domain: the app reads it via RHINO_PREFS_SUITE — a HOME
# override does NOT isolate defaults (cfprefsd keys by user, not $HOME).
SUITE=com.noahkagan.rhino.gate
defaults delete "$SUITE" >/dev/null 2>&1 || true

fail=0

echo "hygiene: [1/3] static scan"

# Deleted-in-Phase-1 files must stay deleted.
for f in \
    OpenSuperWhisper/Engines/RemoteEngine.swift \
    OpenSuperWhisper/Utils/LLMCleanup/RemoteBackend.swift \
    OpenSuperWhisper/Utils/UpdateChecker.swift \
    OpenSuperWhisper/RemoteSettingsSection.swift \
    OpenSuperWhisper/RemoteServerSettingsView.swift \
    OpenSuperWhisper/RemoteCleanupSettingsView.swift \
    OpenSuperWhisper/Utils/LLMCleanup/OllamaBackend.swift \
    OpenSuperWhisper/Utils/PostRecordHook.swift; do
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

echo "hygiene: [2/3] networking call sites classified"

# Every file that can open a network connection must be on this list, each
# with a sanctioned purpose. New networking anywhere else fails the gate —
# classify it here (and defend it in decisions.md) or remove it.
# Not listed but sanctioned: Sparkle updates (inside the Sparkle framework,
# configured by SUFeedURL) and Parakeet model downloads (inside FluidAudio).
ALLOWED_NET_FILES="OpenSuperWhisper/Engines/SenseVoiceModelManager.swift
OpenSuperWhisper/LLMModelManager.swift
OpenSuperWhisper/Utils/UsageReporter.swift
OpenSuperWhisper/WhisperModelManager.swift"

actual=$(grep -rln "URLSession\|URLRequest\|NWConnection\|CFStream\|NSURLConnection" \
    "$ROOT/OpenSuperWhisper" --include='*.swift' | sed "s|$ROOT/||" | sort)
unexpected=$(comm -23 <(echo "$actual") <(echo "$ALLOWED_NET_FILES" | sort))
if [ -n "$unexpected" ]; then
    echo "  FAIL: unclassified networking call sites (the known ones are user-initiated"
    echo "  model downloads and the opt-in usage counts — what is this?):"
    echo "$unexpected" | sed 's/^/    /'
    fail=1
else
    echo "  every networking call site is a model download or the opt-in usage counts"
fi

# The opt-in usage counts (decisions.md 2026-11-02) stay narrow: OFF by default, one
# endpoint, counts only. Each check is a tripwire for the reporter growing beyond that.
REPORTER="$ROOT/OpenSuperWhisper/Utils/UsageReporter.swift"
if ! grep -q '@UserDefault(key: "shareUsageStats", defaultValue: false)' "$ROOT/OpenSuperWhisper/Utils/AppPreferences.swift"; then
    echo "  FAIL: shareUsageStats must default to false (opt-in only)"
    fail=1
fi
urls=$(grep -oE 'https?://[^"]+' "$REPORTER" | sort -u)
if [ "$urls" != "https://rhinovoice.app/api/usage" ]; then
    echo "  FAIL: UsageReporter may only talk to https://rhinovoice.app/api/usage, found:"
    echo "$urls" | sed 's/^/    /'
    fail=1
fi
if ! grep -q 'guard isEnabled, Self.sendingAllowed' "$REPORTER"; then
    echo "  FAIL: UsageReporter.sendIfDue must check the opt-in before sending"
    fail=1
fi
# The payload carries counts only: no transcript text, app names or audio.
payload=$(awk '/struct Payload/,/^    }$/' "$REPORTER")
if echo "$payload" | grep -qiE 'text|transcript|bundle|appName|audio|String\]'; then
    echo "  FAIL: UsageReporter payload grew a content field:"
    echo "$payload" | sed 's/^/    /'
    fail=1
fi

echo "hygiene: [3/3] dynamic egress check"

APP="$ROOT/Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino"
if [ "${FAST:-0}" = "1" ]; then
    echo "  skipped (FAST=1)"
elif [ ! -x "$APP" ]; then
    # The push gate builds before running suites, so this only happens on a
    # bare checkout. Loud skip, not silent pass.
    echo "  SKIPPED: no dev build at $APP — run ./run.sh build first"
else
    # Isolated HOME so the run can't touch (or depend on) the real install's
    # prefs, and we can pin the engine to the repo's tiny whisper model.
        mkdir -p .out && : > .out/egress.txt
    defaults write "$SUITE" selectedEngine whisper
    defaults write "$SUITE" selectedWhisperModelPath "$ROOT/ggml-tiny.en.bin"
    defaults write "$SUITE" aiPostProcessingEnabled -bool false
    defaults write "$SUITE" saveTranscriptionHistory -bool false

    RHINO_PREFS_SUITE="$SUITE" "$APP" transcribe "$ROOT/jfk.wav" > .out/transcript.txt 2> .out/cli-stderr.txt &
    PID=$!
    # Sample the process's open network sockets for its whole lifetime.
    while kill -0 "$PID" 2>/dev/null; do
        lsof -a -p "$PID" -i -n -P 2>/dev/null | tail -n +2 >> .out/egress.txt
        sleep 0.2
    done
    wait "$PID"; status=$?
    defaults delete "$SUITE" >/dev/null 2>&1 || true

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
