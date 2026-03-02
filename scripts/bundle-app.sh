#!/bin/bash
set -e

cd "$(dirname "$0")/.."

APP_NAME="Whisper Dictation"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS="${BUNDLE_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Build release binary
echo "Building release binary..."
swift build -c release

# Create bundle structure
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp .build/release/WhisperDictation "$MACOS/WhisperDictation"

# Copy Info.plist
cp Info.plist "$CONTENTS/Info.plist"

# Copy Metal shader if it exists (needed for GPU acceleration)
METAL_LIB=$(find whisper.cpp/build -name "*.metallib" 2>/dev/null | head -1)
if [ -n "$METAL_LIB" ]; then
    cp "$METAL_LIB" "$RESOURCES/"
fi

# Also copy the embedded metal shader
METAL_EMBED=$(find whisper.cpp/build -name "ggml-metal-embed.metal" 2>/dev/null | head -1)
if [ -n "$METAL_EMBED" ]; then
    cp "$METAL_EMBED" "$RESOURCES/"
fi

echo ""
echo "Built: $BUNDLE_DIR"
echo "Run with: open \"$BUNDLE_DIR\""
