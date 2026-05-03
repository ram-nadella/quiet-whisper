# Quiet Whisper

A calm, paper-textured local dictation app for macOS. Open the window, press one button (or hold space), speak, and the words appear as editable text. History groups by date in a collapsible sidebar. Everything stays on-device.

## Repo

- `QuietWhisper/` — the SwiftUI app
- `design_handoff_quiet_whisper/` — design spec (React/HTML prototype + README)
- `docs/plans/` — archived implementation plans

## Build

```bash
brew install xcodegen
cd QuietWhisper
xcodegen generate
open QuietWhisper.xcodeproj
```

Requires macOS 14 (Sonoma) or later.

## More

See [AGENTS.md](AGENTS.md) for the full orientation: layout, build steps, design system rules, conventions, and known FIXMEs.
