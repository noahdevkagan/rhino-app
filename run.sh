#!/bin/zsh

JUST_BUILD=false
if [[ "$1" == "build" ]]; then
    JUST_BUILD=true
fi

# cmake-configure libwhisper, vendor libomp, resolve SwiftPM, patch FluidAudio.
# Shared with make-test-dmg.sh and CI so a fresh checkout builds anywhere.
"$(dirname "$0")/Scripts/prepare-build-deps.sh"
if [[ $? -ne 0 ]]; then
    echo "Build dependency preparation failed!"
    exit 1
fi

# Build the app
echo "Building OpenSuperWhisper..."
BUILD_OUTPUT=$(xcodebuild -scheme OpenSuperWhisper -configuration Debug -jobs 8 -derivedDataPath build -quiet -destination 'platform=macOS,arch=arm64' -skipPackagePluginValidation -skipMacroValidation -UseModernBuildSystem=YES -clonedSourcePackagesDirPath SourcePackages -skipUnavailableActions CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO OTHER_CODE_SIGN_FLAGS="--entitlements OpenSuperWhisper/OpenSuperWhisper.entitlements" build 2>&1)

# sudo gem install xcpretty
if command -v xcpretty &> /dev/null
then
    echo "$BUILD_OUTPUT" | xcpretty --simple --color
else
    echo "$BUILD_OUTPUT"
fi

# Check if build output contains BUILD FAILED or if the command failed
if [[ $? -eq 0 ]] && [[ ! "$BUILD_OUTPUT" =~ "BUILD FAILED" ]]; then
    echo "Building successful!"
    cp CHANGELOG.md ./Build/Build/Products/Debug/Rhino.app/Contents/Resources/CHANGELOG.md
    # Re-sign with a stable identity so macOS keeps granted TCC permissions
    # across rebuilds (no-op / ad-hoc fallback when no identity is available).
    "$(dirname "$0")/Scripts/dev-codesign.sh" "./Build/Build/Products/Debug/Rhino.app" || true
    if $JUST_BUILD; then
        exit 0
    fi
    echo "Starting the app..."
    # Remove quarantine attribute if exists
    xattr -d com.apple.quarantine ./Build/Build/Products/Debug/Rhino.app 2>/dev/null || true
    # Run the app and show logs
    ./Build/Build/Products/Debug/Rhino.app/Contents/MacOS/Rhino
else
    echo "Build failed!"
    exit 1
fi 