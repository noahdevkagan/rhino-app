#!/bin/bash
# Everything a fresh checkout needs before xcodebuild can run. Idempotent;
# called by run.sh (dev), Scripts/make-test-dmg.sh (release) and CI, so a
# clean clone — laptop or runner — builds with no manual steps.
#
#   1. cmake-configure libwhisper (the xcodeproj embeds libwhisper/build/…)
#   2. vendor libomp into build/ (the xcodeproj CopyFiles phase ships it)
#   3. resolve SwiftPM packages, then patch the FluidAudio checkout
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Configuring libwhisper..."
cmake -G Xcode -B libwhisper/build -S libwhisper

echo "Vendoring libomp.dylib..."
LIBOMP="${LIBOMP_PATH:-/opt/homebrew/opt/libomp/lib/libomp.dylib}"
[ -f "$LIBOMP" ] || { echo "libomp not found at $LIBOMP (brew install libomp)"; exit 1; }
mkdir -p build
cp "$LIBOMP" build/libomp.dylib
install_name_tool -id "@rpath/libomp.dylib" build/libomp.dylib
codesign --force --sign - build/libomp.dylib

echo "Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -scheme OpenSuperWhisper \
    -derivedDataPath build -clonedSourcePackagesDirPath SourcePackages \
    -skipPackagePluginValidation -skipMacroValidation -quiet

# Patch FluidAudio's vocabulary rescorer to prefer longer matching spans
# (keyword boosting quality, e.g. "My-Monkey" matched as one term). Idempotent;
# fails loudly if the target moved (so a FluidAudio bump can't silently skip it).
checkout="SourcePackages/checkouts/FluidAudio"
patch_file="patches/fluidaudio-vocabulary-rescorer.patch"
target="$checkout/Sources/FluidAudio/ASR/Parakeet/SlidingWindow/CustomVocabulary/Rescorer/VocabularyRescorer+TokenRescoring.swift"

[ -f "$patch_file" ] || { echo "Missing FluidAudio patch: $patch_file"; exit 1; }
[ -f "$target" ] || { echo "Missing FluidAudio source checkout: $target"; exit 1; }

if grep -q "Prefer longer spans" "$target"; then
    echo "FluidAudio vocabulary rescorer patch already applied."
else
    echo "Applying FluidAudio vocabulary rescorer patch..."
    if ! patch --silent --forward -d "$checkout" -p1 < "$patch_file" \
        && ! grep -q "Prefer longer spans" "$target"; then
        echo "Failed to apply FluidAudio vocabulary rescorer patch."
        exit 1
    fi
fi
