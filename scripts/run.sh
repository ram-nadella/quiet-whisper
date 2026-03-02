#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Build if needed
if [ ! -f .build/release/WhisperDictation ]; then
    echo "Building first..."
    ./scripts/build.sh
fi

echo "Running WhisperDictation..."
.build/release/WhisperDictation
