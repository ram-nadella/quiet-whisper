#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Building WhisperDictation..."
swift build -c release 2>&1

echo ""
echo "Build complete: .build/release/WhisperDictation"
