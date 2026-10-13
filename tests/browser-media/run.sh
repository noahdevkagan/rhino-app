#!/bin/bash
# Real browser DOM/media regression tests, completely offline in a disposable profile.
set -euo pipefail
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ ! -x "$CHROME" ]; then
    echo "browser-media: SKIPPED (Google Chrome not installed; native XCTest coverage still runs)"
    exit 0
fi
mkdir -p .build
swiftc ../../OpenSuperWhisper/BrowserMediaScript.swift export-scripts.swift -o .build/export-scripts
.build/export-scripts > .build/scripts.js
cp checks.js .build/checks.js
cat > .build/fixture.html <<'HTML'
<!doctype html><html><body>
<div id="stage"></div><pre id="result">PENDING</pre>
<script src="scripts.js"></script><script src="checks.js"></script>
</body></html>
HTML
profile=$(mktemp -d "${TMPDIR:-/tmp}/rhino-browser-tests.XXXXXX")
trap 'rm -rf "$profile"' EXIT
node run-chrome.mjs "$CHROME" "$profile"
