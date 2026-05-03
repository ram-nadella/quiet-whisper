# Quiet Whisper — macOS app implementation plan

## Context

`design_handoff_quiet_whisper/` is a complete, high-fidelity React/HTML prototype of a calm, paper-textured local dictation app for macOS. The README is exhaustive: it specifies tokens, type scale, motion, copy, the recording state machine, hold-space behavior, and the "what-not-to-do" list (no menubar, no global hotkey, no telemetry, no audio retention, no decorative chrome).

There is **no Swift code yet** — we are building the production app from scratch, recreating the design pixel-for-pixel where SwiftUI permits and idiomatically where it doesn't.

**Decisions already made (from clarification):**
- **SwiftUI** native macOS app
- **WhisperKit** for on-device transcription
- **SwiftData** for snippet + settings persistence
- Project lives at `/Users/ram/code/misc/quiet-whisper/QuietWhisper`

**Deployment target:** macOS 14 Sonoma (required by SwiftData). Apple Silicon recommended but not required — WhisperKit runs CPU on Intel, slower but functional.

---

## Project layout

```
QuietWhisper/
├── QuietWhisper.xcodeproj
├── QuietWhisper/
│   ├── QuietWhisperApp.swift          ← @main, WindowGroup, model container
│   ├── Models/
│   │   ├── Snippet.swift              ← @Model — id, title, text, createdAt, durationSec
│   │   └── AppSettings.swift          ← @Observable — model, autoPunct, dark; @AppStorage-backed
│   ├── Audio/
│   │   ├── Recorder.swift             ← AVAudioEngine tap → published RMS amplitude
│   │   └── Transcriber.swift          ← async wrapper around WhisperKit
│   ├── Theme/
│   │   ├── PaperTheme.swift           ← color tokens (light + dark), animated Environment
│   │   ├── Typography.swift           ← Fraunces / Inter / JetBrains Mono helpers
│   │   └── Icons.swift                ← stroke SVG paths reproduced as SwiftUI Shapes
│   ├── Views/
│   │   ├── ContentView.swift          ← HStack: Sidebar | MainColumn
│   │   ├── TopBar.swift               ← 44pt bar, centered italic title, theme + gear
│   │   ├── Sidebar/
│   │   │   ├── SidebarView.swift      ← grouped notes, "Notes" heading, +/collapse
│   │   │   ├── SidebarItem.swift      ← title/meta row + 2-click delete confirm
│   │   │   └── DateGrouping.swift     ← Today/Yesterday/This week/Earlier partition
│   │   ├── Stages/
│   │   │   ├── EmptyStage.swift       ← hero + DotWave + RecordButton
│   │   │   ├── RecordingStage.swift   ← listening eyebrow + DotWave + timer + stop
│   │   │   ├── TranscribingStage.swift ← italic "Transcribing…" + 3-dot spinner
│   │   │   └── EditorStage.swift      ← meta + title + body + footer pill
│   │   ├── Components/
│   │   │   ├── DotWave.swift          ← Canvas, 21 dots, RAF-style TimelineView loop
│   │   │   ├── RecordButton.swift     ← circle ↔ rounded-square morph, halo when active
│   │   │   ├── IconButton.swift       ← 28×28 ghost button
│   │   │   ├── KeyCap.swift           ← <kbd> equivalent
│   │   │   └── EditorFooterPill.swift ← copy + small DotWave + small record
│   │   └── Settings/
│   │       ├── SettingsModal.swift    ← .sheet with custom blurred backdrop
│   │       ├── SettingGroup.swift
│   │       ├── ModelRow.swift         ← radio + label + meta + RECOMMENDED pill
│   │       ├── ToggleRow.swift
│   │       └── PaperToggle.swift      ← 32×19 capsule with 15px thumb
│   ├── Input/
│   │   └── SpaceKeyMonitor.swift      ← NSEvent local monitor for hold-space
│   ├── Resources/
│   │   ├── Fraunces-*.ttf             ← bundled (Variable or 400 weight)
│   │   ├── Inter-*.ttf
│   │   └── JetBrainsMono-*.ttf
│   └── Info.plist                     ← NSMicrophoneUsageDescription
└── QuietWhisperTests/
    ├── DateGroupingTests.swift
    └── AmplitudeMathTests.swift
```

---

## Implementation order

### 1. Project scaffold
- Create SwiftUI app target, deployment target macOS 14, App Sandbox **on**, Microphone entitlement **on**, Hardened Runtime on.
- `Info.plist`: `NSMicrophoneUsageDescription = "Quiet Whisper transcribes audio on this device. Nothing leaves your Mac."`
- Add SPM dependency: `https://github.com/argmaxinc/WhisperKit` (latest tagged release).
- Bundle Fraunces / Inter / JetBrains Mono TTFs; register in `Info.plist` under `ATSApplicationFontsPath` (or load at launch via `CTFontManagerRegisterFontsForURL`).

### 2. Theme + tokens (`Theme/`)
- Port both `lightTheme` and `darkTheme` from `qw-tokens.jsx` verbatim — same hex values, same `rgba()` opacities. **No pure black, no pure white.**
- Expose via `EnvironmentValues.paperTheme` so every view reads the active theme.
- Theme swap: animate `Color` interpolation over 240 ms (`withAnimation(.easeInOut(duration: 0.24))` around the toggle).
- Type scale lives in `Typography.swift` as `Font` extensions: `.paperHero`, `.paperEditorTitle`, `.paperEditorBody`, `.paperSidebarTitle`, `.paperMetaMono`, `.paperRecordingTimer`, etc.
- Reproduce the 9 stroke icons (`Icon.Sidebar/Settings/Sun/Moon/Plus/Trash/Copy/Close/Check/Chevron`) as SwiftUI `Shape`s or `Path`s — each at 16×16 viewBox, `strokeLineCap(.round)`, stroke widths matching the JSX (1.1 / 1.25 / 1.5 by icon).

### 3. Window chrome (`QuietWhisperApp.swift` + `ContentView.swift`)
- `WindowGroup { ContentView() }`, default size 1180×780, `.windowStyle(.hiddenTitleBar)` to hide the OS title and let our centered italic "Quiet Whisper" sit in the toolbar.
- `.windowResizability(.contentSize)` with min size ~880×560.
- **No** `MenuBarExtra`, **no** `Settings { }` scene other than the in-app modal — explicit per the README.
- The README's "traffic lights move into the sidebar when open" is implemented natively: `NSWindow.titlebarAppearsTransparent = true` and a leading 82pt padding on the closed-sidebar top bar; when open, sidebar takes the leading 260pt and absorbs the traffic-light area.

### 4. Data layer (`Models/`)
- `Snippet`: `@Model` with `id: UUID`, `title: String`, `text: String`, `createdAt: Date`, `durationSec: Int`.
- `AppSettings`: simple `@Observable` class with `@AppStorage` for `model`, `autoPunct`, `dark`, `sidebarOpen`. Defaults: `.small`, `true`, `false`, `false`.
- `ModelContainer` configured in `QuietWhisperApp.swift`; default location is Application Support — fits the "no remote sync" requirement.
- **Audio is not retained** (v1 explicitly drops audio playback).

### 5. Components

#### `DotWave` (`Components/DotWave.swift`)
- `TimelineView(.animation)` driving a per-frame `tick`; computes 21 per-dot amplitudes using the exact formulas from `qw-wave.jsx` (bell envelope `1 - d²·0.45`, phase `sin(t·3.2 + i·0.5)`, jitter `sin(t·5.1 + i·1.7)·0.15`).
- Sizing presets: `lg (3 base / 8 range / 10 gap / 56h)`, `md`, `sm` — match table in README.
- Idle: dots at base size with sin drift at 0.6 Hz, opacity 0.7, `dotIdle` color.
- Active: per-dot size scales with live amplitude, opacity `0.35 + a·0.6`, color `dotActive`.
- Render with `Canvas` (single GPU pass for 21 dots vs. 21 SwiftUI views).
- **Only ship the `dots` variant.** README is explicit: bars/blob are exploratory, do not ship.

#### `RecordButton`
- 72pt circle (44pt for `SmallRecordButton`).
- Background `recordBg`, inner glyph `recordFg`.
- Inner shape: idle = circle at 32% size; active = `RoundedRectangle(cornerRadius: 3)` at 28% size. Animate with `.animation(.easeInOut(duration: 0.18), value: active)`.
- Halo when active: `.shadow(color: theme.dotIdle, radius: 0, y: 0)` ring approximated with an outer `Circle().stroke(theme.dotIdle, lineWidth: 8)` + drop shadow.
- Hover (idle only): `.offset(y: -1)` + larger shadow, 220 ms ease.

#### `IconButton`
- 28×28, radius 6, ghost. Background transitions: transparent → `hover` → `active`. 120 ms.

#### `EditorFooterPill`
- Pill: `panel` bg, `line` border, `shadow`, radius 100, padding 10×14. Above it, a vertical gradient from `bg.opacity(0)` → `bg` so scrolled body fades under softly.
- Children: `Copy` button (34pt, swaps to `Check` for 1600 ms after click), 1×18 divider, `DotWave size: .sm count: 15`, divider, `RecordButton size: 44`.

### 6. Stages (`Views/Stages/`)
Each stage is a top-level view chosen by `RecordingState`:

```swift
enum RecordingState { case idle, recording, transcribing }
```

The main column shows:
- `EmptyStage` if `idle && selectedSnippet == nil`
- `EditorStage(snippet)` if `idle && selectedSnippet != nil`
- `RecordingStage` if `recording`
- `TranscribingStage` if `transcribing`

Stage-specific notes:

- **EmptyStage:** Hero (38pt Fraunces, `ink`, letter-spacing -0.8, "A quiet place to think out loud."), italic subhead (15pt mute) with inline `KeyCap` showing `space`, then `DotWave .lg` idle, then big `RecordButton`. Vertically centered.
- **RecordingStage:** Mono uppercase "● listening" eyebrow with the dot pulsing (1.4 s ease-in-out, opacity 0.3↔0.9, scale 1↔1.25 — implemented via `.symbolEffect` or a custom `TimelineView`), italic "Take your time.", active `DotWave` driven by `Recorder.amplitude`, tabular timer `MM:SS.t` (mm:ss in `ink`, `.t` in `mute`), stop button, "release space to stop" hint.
- **TranscribingStage:** Italic 22pt "Transcribing…" + three 6pt dots cycling at 180 ms. Show until `Transcriber` returns; do **not** cap to 2.2 s in production.
- **EditorStage:** Scroll view, max-width 680pt, padding 48 / 64 / 160 (top / x / bottom). Meta line (mono uppercase 10.5pt, `·` separators at 50% opacity). Editable title (`TextField` styled to look like 34pt Fraunces). Editable body (`TextEditor` → 18pt Fraunces, line-height per density). Footer meta "{N} words · saved". Both fields: 300 ms debounced `onChange` → `modelContext.save()`. Footer pill pinned to the bottom over the gradient fade.

### 7. Audio + transcription (`Audio/`)

#### `Recorder`
```swift
@Observable final class Recorder {
    var amplitude: Double = 0     // 0...1, smoothed
    var isRecording: Bool = false
    func start() async throws -> URL  // returns a temp WAV URL
    func stop() async
}
```
- `AVAudioEngine` with an input tap on `inputNode` at 16 kHz mono (matches Whisper input).
- On each buffer: time-domain RMS → `min(1, rms * 4.5)` → exponential smoothing `0.35` (exact constants from README).
- On stop: write the accumulated PCM to a temp `.wav` at 16 kHz mono int16, return the URL.
- Permission: first call invokes `AVCaptureDevice.requestAccess(for: .audio)`. If denied, surface a `MicPermissionState.denied` and the Empty/Recording stages render a calm "Microphone access needed" panel with one button → opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`. The big record button is disabled while denied. **Never silently fall back to simulated audio** (README is explicit).

#### `Transcriber`
```swift
final class Transcriber {
    func load(model: WhisperModel) async throws       // lazy, idempotent
    func transcribe(_ wav: URL) async throws -> String
}
```
- Wraps `WhisperKit`. Bundle Whisper Small as the default; allow runtime download of other sizes via WhisperKit's downloader (out of scope to *bundle* all sizes — just to allow them).
- `autoPunct` setting: WhisperKit handles punctuation by default for Whisper models; the toggle currently maps to a post-process strip-and-lowercase if disabled (acceptable v1 behavior — note in code comment).
- Delete the temp WAV after transcription returns.

### 8. Sidebar (`Views/Sidebar/`)
- `SidebarView` 260pt wide, `sidebar` bg, right border `line`. Slide animation: animate width 0↔260 with `.animation(.easeInOut(duration: 0.26), value: sidebarOpen)` matching the JSX cubic-bezier visually.
- Top region (44pt, padding-left 82pt to clear the traffic lights): italic "Notes" + `+` and collapse `IconButton`s.
- `groupByDate(snippets)` — port verbatim from `qw-sidebar.jsx`. Boundaries are start-of-today, start-of-yesterday, start-of-week (today − 7 days). Empty groups not rendered. Keep the labels exactly as `Today / Yesterday / This week / Earlier`.
- `SidebarItem`: 10×14 padding, radius 6. Hover and selected backgrounds from theme. Title (Inter 13/500), meta `formatTime · formatDuration` (mono 10.5/mute). Two-click delete: first click of the trash icon flips background to `danger` and `recordFg` icon, arms a 2 s timer; second click within window → `modelContext.delete(snippet)`. Mouse-out cancels.
- Sidebar empty state: italic serif "Nothing here yet. / Press the button to start." (centered, 13pt, mute).

### 9. Settings modal (`Views/Settings/`)
- Implemented as a custom overlay (not `.sheet`, because the README specifies a full-app blurred backdrop). `ZStack` over `ContentView`: backdrop with `.background(.ultraThinMaterial)` tinted to match the JSX (`rgba(26,24,21,0.25)` light, `rgba(0,0,0,0.5)` dark). Click backdrop = close.
- Modal: 480pt wide, `panel` bg, radius 12, `line` border, theme shadow. Enter animation: opacity 0→1 + offsetY 10→0 over 200 ms.
- Sections (each `SettingGroup`): mono uppercase eyebrow + optional italic-serif hint + content.
  1. **TRANSCRIPTION MODEL** — five `ModelRow` rows (tiny / base / **small** + RECOMMENDED pill / medium / voxtral). Selected row gets `selected` bg + `line` border + 7×7 dot inside the 14×14 ring. Voxtral is shown but disabled with a `coming soon` label until a local Voxtral runtime ships.
  2. **LANGUAGE** — read-only `SelectRow` showing "English (US)" + "More languages coming soon."
  3. **TRANSCRIPTION** — `ToggleRow` "Auto-insert punctuation" (default on).
  4. **APPEARANCE** — `ToggleRow` "Dark mode".
- `PaperToggle`: 32×19 capsule, off → `muteSoft`, on → `ink`. 15pt `panel` thumb slides 13pt in 180 ms ease.

### 10. Hold-space input (`Input/SpaceKeyMonitor.swift`)
- `NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp])` on the main window.
- Match `event.keyCode == 49` (space). Ignore if `event.window?.firstResponder` is an `NSTextView`/`NSTextField`. Ignore if settings modal is open. Ignore `event.isARepeat` for keyDown.
- On keyDown while idle → `held = true; recorder.start()`. On keyUp while `held && recording` → stop. This satisfies both press-and-hold *and* click-toggle (the big button click path is independent).

### 11. State plumbing (`Views/ContentView.swift`)
- `@State var recState: RecordingState = .idle`
- `@State var selectedID: PersistentIdentifier?`
- `@Query(sort: \Snippet.createdAt, order: .reverse) var snippets`
- `@Environment(\.modelContext) var ctx`
- Transitions match the prototype's machine:
  - `idle` --[click record / hold space]--> `recording` (`recorder.start()`, set start time)
  - `recording` --[click stop / release space]--> `transcribing` (`recorder.stop()`, hand wav to `Transcriber`)
  - `transcribing` --[await transcribe]--> `idle` (insert new `Snippet`, select it)
- The 100 ms elapsed timer for the recording display is a `Timer.publish(every: 0.1)` only while `recState == .recording`.

### 12. What we are NOT building (per README)
- ❌ MenuBarExtra
- ❌ Global hotkey
- ❌ Telemetry / crash reporting that ships transcripts
- ❌ Markdown mode, summarization, AI rewrite, tags
- ❌ Audio retention / playback
- ❌ Streaming transcription (batch only)
- ❌ Pause/resume
- ❌ The `bars` / `blob` waveform variants
- ❌ Decorative iconography, gradients (other than the editor footer fade), glassmorphism
- ❌ Network calls (verifiable with Little Snitch)

---

## Critical files to reference during implementation

The prototype is the spec. Keep these open while building:

- `design_handoff_quiet_whisper/README.md` — single source of truth for tokens, sizes, copy, and acceptance.
- [qw-tokens.jsx](design_handoff_quiet_whisper/prototype/qw-tokens.jsx) — exact color hex + icon paths to port.
- [qw-wave.jsx](design_handoff_quiet_whisper/prototype/qw-wave.jsx) — `DotWave` math (lines 38–52), `RecordButton` halo math (lines 142–148), `useMicAmplitude` RMS pipeline (lines 211–246).
- [qw-app.jsx](design_handoff_quiet_whisper/prototype/qw-app.jsx) — recording state machine (lines 78–113), hold-space rules (lines 116–146), editor debounced autosave (lines 444–452).
- [qw-sidebar.jsx](design_handoff_quiet_whisper/prototype/qw-sidebar.jsx) — `groupByDate` (lines 4–19), 2-click delete (lines 80–88), settings modal layout.
- `screenshots/03-editor.png` and `04-recording.png` — visual reference for the two states most likely to drift.

---

## Verification

End-to-end manual test (the README's acceptance checklist):

1. Build & run. App opens to **EmptyStage** with hero copy + DotWave + big record button.
2. **First record:** click the button → microphone permission prompt with the calm copy. Grant.
3. Hold space (focus on window, not on a text field) → `RecordingStage` appears, DotWave responds to voice, timer ticks, "release space to stop" visible. Release → `TranscribingStage` for 1–3 s → `EditorStage` populated with the transcript.
4. Edit title and body → wait 300 ms → relaunch the app → edits persisted.
5. Open sidebar (icon button). Verify groups appear: Today, then anything older. Hover an item → trash icon appears. Click trash → red confirm. Click within 2 s → deleted. Click trash, mouse out, mouse back → no longer armed.
6. Settings: toggle dark mode → 240 ms color crossfade across the whole window, no pure black/white anywhere. Toggle auto-punct, change model → settings persist across relaunch.
7. Backdrop click closes settings. Esc also closes (nice-to-have; not in spec).
8. **Network check:** run with Little Snitch in "alert" mode; verify zero outbound connections during record/transcribe/edit. Model download from WhisperKit is the only allowed network event and only when a non-bundled model is selected.

Unit tests (small but worthwhile):
- `DateGroupingTests` — verify `groupByDate` partitions correctly across day boundaries (mock `Date.now`).
- `AmplitudeMathTests` — verify the RMS → boost → smoothing pipeline produces 0 for silence and ~0.5 for nominal speech-level RMS.

Visual diff: place each `screenshots/0X-*.png` next to a SwiftUI screenshot at the same window size and compare. Fix anything off by more than a couple of pixels in spacing or off-hue in color.

---

## Open questions to surface as we build

These are flagged in the README as v2 candidates — confirm with you before adding any:

1. **Bundle vs. download Whisper Small** — bundling adds ~244 MB to the app size; downloading on first launch keeps the binary small but means a one-time wait. Recommend: download on first launch with a calm progress indicator.
2. **Voxtral row** — currently no shippable local Voxtral runtime. Render the row disabled with "experimental" + a `coming soon` tag, or omit until it's real?
3. **Fraunces font** — bundle the variable font (~250 KB) or substitute Apple's New York for system parity? Recommend: bundle Fraunces; the design's character depends on it.
