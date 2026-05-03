# Quiet Whisper

A calm, paper-textured local dictation app for macOS. Open the window, press one button (or hold space), speak, and the words appear as editable text. History groups by date in a collapsible sidebar. Everything stays on-device.

## Repo

- `QuietWhisper/` — the SwiftUI app
- `design_handoff_quiet_whisper/` — design spec (React/HTML prototype + README)
- `docs/plans/` — archived implementation plans

## Download

Grab the latest `.app` from [Releases](https://github.com/ram-nadella/quiet-whisper/releases). Unzip and drop `QuietWhisper.app` into `/Applications`.

The build is unsigned (ad-hoc), so the first launch needs a one-time Gatekeeper bypass: right-click the app and choose **Open**, then confirm. Or run `xattr -dr com.apple.quarantine /Applications/QuietWhisper.app` once.

## Build

```bash
brew install xcodegen
cd QuietWhisper
xcodegen generate
open QuietWhisper.xcodeproj
```

Requires macOS 14 (Sonoma) or later.

## Releasing

CI ([`.github/workflows/release.yml`](.github/workflows/release.yml)) builds and packages the `.app` automatically:

- Every push to `main` uploads `QuietWhisper-<sha>.zip` as a workflow artifact (Actions tab; requires GitHub login; 90-day retention).
- Pushing a tag matching `v*` creates a public GitHub Release with the zip attached. Cut a release with:

  ```bash
  git tag v0.1.0
  git push origin v0.1.0
  ```

  Use the version from `CFBundleShortVersionString` in [QuietWhisper/project.yml](QuietWhisper/project.yml). The Release shows up under [Releases](https://github.com/ram-nadella/quiet-whisper/releases) within a few minutes.

## More

See [AGENTS.md](AGENTS.md) for the full orientation: layout, build steps, design system rules, conventions, and known FIXMEs.
