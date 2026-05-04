#!/usr/bin/env bash
# build-icns.sh — Quiet Whisper
# Renames the iconset PNGs to Apple's @2x convention and runs iconutil
# to produce AppIcon.icns. Run from this directory on macOS.

set -euo pipefail

cd "$(dirname "$0")"

ICONSET="AppIcon.iconset"

if [ ! -d "$ICONSET" ]; then
  echo "error: $ICONSET not found (run from the brand/ directory)"
  exit 1
fi

# Rename -at2x.png -> @2x.png
for f in "$ICONSET"/*-at2x.png; do
  [ -e "$f" ] || continue
  mv "$f" "${f/-at2x/@2x}"
done

# Build the .icns
iconutil -c icns "$ICONSET" -o AppIcon.icns

echo "✓ AppIcon.icns written"
