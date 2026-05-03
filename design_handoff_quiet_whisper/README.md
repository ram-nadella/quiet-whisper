# Handoff: Quiet Whisper

A local-first dictation app for macOS — a calm, paper-textured surface for thinking out loud. The user presses one button (or holds space), speaks at their own pace, and the words appear as editable text. History is grouped by date in a collapsible sidebar. Everything stays on-device.

---

## About these files

The files in `prototype/` are **design references built in HTML + React (Babel/JSX, no build step)**. They are not production code to ship — they exist to communicate the look, feel, and behavior of the intended product. Your job is to **recreate this design in the target codebase**.

Recommended target: **a native macOS app (SwiftUI)** since the design and constraints (always-local transcription, single quiet window, no menubar/HUD chrome) are platform-specific. If a different stack is required, pick the framework that best matches the codebase you're working in and translate the design tokens, component structure, and interactions one-for-one.

For the actual transcription engine, the prototype simulates the call. In production you should integrate either:
- **whisper.cpp** (C++ port of OpenAI Whisper, runs Core ML on Apple Silicon) — most mature path
- **WhisperKit** (Swift framework, Apple-first, well-suited to SwiftUI)
- **Voxtral** (Mistral) once a local runtime is available

All inference must run on-device. Microphone permission must be requested with a clear, calm prompt; no telemetry, no network calls.

---

## Fidelity

**High-fidelity.** The prototype shows final colors, typography, spacing, motion, and copy. Recreate pixel-for-pixel where the host platform allows; translate idiomatically where it doesn't (e.g., use SwiftUI's native sidebar collapse animation rather than reimplementing the JS one, but match the duration and easing).

---

## Files in this handoff

```
design_handoff_quiet_whisper/
├── README.md                      ← this file
├── prototype/
│   ├── Quiet Whisper.html         ← entry point — open in any browser
│   ├── qw-tokens.jsx              ← design tokens (colors, fonts, icons, seed data)
│   ├── qw-wave.jsx                ← waveform component, record button, mic hook
│   ├── qw-sidebar.jsx             ← sidebar + settings modal + form controls
│   ├── qw-app.jsx                 ← main app, state machine, all screens
│   └── tweaks-panel.jsx           ← in-design tweaks shell (not part of the product)
└── screenshots/
    ├── 01-empty-light.png         ← idle state, sidebar closed
    ├── 02-empty-with-sidebar.png  ← idle state, sidebar open w/ history
    ├── 03-editor.png              ← viewing/editing a saved snippet
    ├── 04-recording.png           ← recording in progress
    ├── 05-settings.png            ← settings modal
    └── 06-dark.png                ← dark mode (inverted paper)
```

The Tweaks panel in the bottom-right of the prototype is a design-time tool for exploring variants. **It is not part of the product.** The values committed into `TWEAK_DEFAULTS` are the intended production defaults (see "Design Tokens" below).

---

## Design system

### Aesthetic principle

> "Paper." Off-white surfaces, ink as the only color, generous whitespace, serif display type. The app should feel like opening a notebook, not launching an app.

No gradients, no glows, no glassmorphism, no decorative iconography. The single moment of warmth is the live waveform during recording — soft pulsing dots, never aggressive bars.

### Color tokens

Defined in `prototype/qw-tokens.jsx`. Two themes: **light** (default) and **dark** (inverted paper — warm near-black, *not* pure black).

#### Light mode

| Token       | Value                             | Usage                                          |
|-------------|-----------------------------------|------------------------------------------------|
| `bg`        | `#f6f4ef`                         | App background                                 |
| `panel`     | `#ffffff`                         | Modals, footer pill                            |
| `panelSoft` | `#faf8f3`                         | Settings rows, soft fills                      |
| `sidebar`   | `#efece5`                         | Sidebar surface                                |
| `ink`       | `#1a1815`                         | Primary text, record button bg                 |
| `inkSoft`   | `#3a352d`                         | Secondary text                                 |
| `mute`      | `#8a857b`                         | Tertiary text, meta labels                    |
| `muteSoft`  | `#b5b0a4`                         | Placeholder, disabled                          |
| `line`      | `rgba(26,24,21,0.08)`             | Borders, dividers                              |
| `lineSoft`  | `rgba(26,24,21,0.04)`             | Subtle dividers                                |
| `hover`     | `rgba(26,24,21,0.04)`             | Hover backgrounds                              |
| `selected`  | `rgba(26,24,21,0.07)`             | Selected sidebar item                          |
| `recordBg`  | `#1a1815`                         | Record button fill (= `ink`)                   |
| `recordFg`  | `#f6f4ef`                         | Record button glyph (= `bg`)                   |
| `dotIdle`   | `rgba(26,24,21,0.18)`             | Waveform dots when idle                        |
| `dotActive` | `rgba(26,24,21,0.78)`             | Waveform dots when recording                   |
| `danger`    | `#a8443a`                         | Delete confirm state                           |

#### Dark mode

| Token       | Value                             |
|-------------|-----------------------------------|
| `bg`        | `#17150f`                         |
| `panel`     | `#1e1b15`                         |
| `panelSoft` | `#1a1812`                         |
| `sidebar`   | `#141209`                         |
| `ink`       | `#f0ebe0`                         |
| `inkSoft`   | `#c9c3b6`                         |
| `mute`      | `#7a756b`                         |
| `muteSoft`  | `#5a554c`                         |
| `line`      | `rgba(240,235,224,0.08)`          |
| `lineSoft`  | `rgba(240,235,224,0.04)`          |
| `hover`     | `rgba(240,235,224,0.04)`          |
| `selected`  | `rgba(240,235,224,0.07)`          |
| `recordBg`  | `#f0ebe0`                         |
| `recordFg`  | `#17150f`                         |
| `dotIdle`   | `rgba(240,235,224,0.18)`          |
| `dotActive` | `rgba(240,235,224,0.82)`          |
| `danger`    | `#d87268`                         |

Dark mode is "inverted paper": ink and bg flip, but it stays warm. **Do not use pure black or pure white anywhere.**

### Shadows

```
light: 0 1px 2px rgba(26,24,21,0.04), 0 8px 32px rgba(26,24,21,0.06)
dark:  0 1px 2px rgba(0,0,0,0.2),     0 8px 32px rgba(0,0,0,0.4)
```

### Typography

| Role          | Family                                                   | Notes                                  |
|---------------|----------------------------------------------------------|----------------------------------------|
| Reading       | **Fraunces**, "Iowan Old Style", Georgia, serif          | Editor body & title, hero copy         |
| UI / chrome   | **Inter**, system-ui, sans-serif                         | Sidebar items, buttons                 |
| Mono / micro  | **JetBrains Mono**, ui-monospace, Menlo                  | Meta labels, timer, group headers      |

Fraunces is loaded via Google Fonts in the prototype. On macOS native, you can substitute **New York** (Apple's serif) for very similar feel; if you want Fraunces specifically, bundle it.

#### Type scale

| Use                       | Size | Weight | Line-height | Letter-spacing |
|---------------------------|------|--------|-------------|----------------|
| Editor — title            | 34px | 400    | 1.15        | -0.6           |
| Editor — body (default)   | 18px | 400    | 1.65        | 0.1            |
| Empty state — hero        | 38px | 400    | 1.15        | -0.8           |
| Empty state — subhead     | 15px | 400 *italic* | 1.55  | 0              |
| Settings — group title    | 22px | 400    | 1.2         | -0.2           |
| Sidebar — item title      | 13px | 500    | 1.3         | 0              |
| Sidebar — meta            | 10.5px | 400  | 1.3         | 0.4            |
| Group header (mono)       | 10px | 500    | 1.3         | 1.2 (uppercase) |
| Recording timer           | 22px | 400    | 1            | 0.5 (tabular)  |
| "listening" eyebrow       | 11px | 400    | 1            | 1.5 (uppercase) |

#### Density (line-height in editor body)

- compact: 1.45
- regular: 1.65 (default — committed)
- comfy: 1.85

### Spacing

The prototype uses ad-hoc px values. Normalize to a **4-px scale** (4, 8, 12, 16, 20, 24, 32, 40, 48, 64) when porting. Key values used:

- Sidebar width: **260px** (collapses to 0 with 260ms ease)
- Top bar height: **44px**
- Editor content padding: **48px / 64px / 160px** (top / x / bottom — the bottom leaves room for the floating footer pill)
- Editor max content width: **680px**, centered
- Modal width: **480px**
- Modal padding: **20–24px**

### Radius

- Window: **14px** (the macOS chrome — replace with native window in production)
- Modals: **12px**
- Sidebar items, settings rows: **6px**
- Footer pill: **100px** (full pill)
- Record button: 50% (circle)
- Inputs / segmented controls: **6–8px**

### Motion

- **Sidebar slide:** width 0 ↔ 260, **260ms** `cubic-bezier(.4,0,.2,1)`
- **Theme swap:** background 240ms ease (long enough to feel intentional, not jarring)
- **Record button press:** 220ms ease — circle morphs into rounded square (square radius 3px) when active; an 8px halo (color `dotIdle`) appears around it
- **Modal enter:** 200ms — opacity 0→1, translateY 10px→0, with 4px backdrop blur fading in
- **Sidebar item hover/select:** 120ms ease background only
- **Waveform idle:** dots gently drift (sin wave, 0.6Hz, ±4% scale) — *almost* imperceptible
- **Waveform active:** per-dot phase-shifted sine (3.2Hz) modulated by mic amplitude × bell-shaped envelope (center dots respond more)
- **Recording dot pulse** (the small "● listening" indicator): 1.4s ease-in-out infinite, opacity 0.3↔0.9, scale 1↔1.25

---

## Screens

There are **four primary screens** in the main column, plus the sidebar and settings modal. The app is a single window — no menubar item, no floating HUD, no hover-anywhere mic. It exists when explicitly opened.

### Window chrome

Standard macOS window. Width 1180, height 780 (the prototype shows a Mac shell — in a real SwiftUI app this is the system-provided NSWindow). Traffic lights live in the top-left of the window. **No app title in the title bar** — the app's name appears as a small italic serif label centered in the top toolbar (`Quiet Whisper`, 14px, mute color, italic).

When sidebar is **closed**, the top bar's left padding is 82px to clear the traffic lights. When **open**, the traffic lights live inside the sidebar instead and the top bar's left padding shrinks to 12px.

### Top bar

44px tall, bottom border `line`. Contents (left to right):

- (Sidebar-closed only) Sidebar-toggle icon button (28×28, ghost)
- flex spacer
- Centered title `Quiet Whisper` (absolute-positioned, pointer-events none)
- Theme toggle (sun in dark mode, moon in light mode)
- Settings (gear) button

Icon buttons: 28×28, radius 6, transparent → `hover` → `active` background. Icon color `inkSoft`. Stroke-only SVGs at 16×16 viewbox, stroke-width 1.25.

### Screen 1 — Empty / idle (`screenshots/01-empty-light.png`)

Centered column inside the main area:

1. Hero line in serif: **"A quiet place to think out loud."** (38px, color `ink`)
2. Subhead in italic serif: **"Press and hold ⌨space, or click the button. Take your time — there's no rush."** (15px italic, color `mute`, max-width 420px)
3. **DotWave** in idle state (21 dots, ~3px each, color `dotIdle`)
4. **Big record button** — 72px circle, fill `recordBg`, 32% inner dot in `recordFg`. On hover: lifts 1px and adds a soft 4px shadow.

`<kbd>` inline in the subhead uses mono font, 1px line border, 4px radius, `panel` background.

### Screen 2 — Recording (`screenshots/04-recording.png`)

Same centered layout, replaces hero copy:

1. Mono eyebrow `● listening` (uppercase, letter-spacing 1.5, color `mute`). The dot has the pulse animation.
2. Italic serif: **"Take your time."** (18px italic, color `inkSoft`)
3. **DotWave** in active state — same 21 dots, but now sized 3–11px each, modulated by live mic amplitude through a bell envelope. Center dots are visibly louder than edge dots.
4. **Tabular timer** in mono: `MM:SS.t` — minutes and seconds in `ink`, decisecond in `mute` (e.g. `00:24.7`)
5. **Stop button** — same 72px circle, but with an 8px halo (`dotIdle` color) and a soft drop shadow. Inner shape morphs from circle to 16×16 rounded square (3px radius).
6. Footer mono hint: **"release space to stop"** — only shown if recording was started via space key (currently always shown for simplicity; refine in production)

### Screen 3 — Transcribing (interstitial)

Brief stage between recording-stop and text-appears.

1. Italic serif: **"Transcribing…"** (22px italic, color `inkSoft`)
2. Three small dots (6×6, color `ink`), one fully opaque at a time, cycling every 180ms.

Duration is `min(2200ms, 600ms + recordedSeconds × 60ms)` in the prototype. In production, this is the actual time the local model takes — show the spinner until the model returns.

### Screen 4 — Editor (`screenshots/03-editor.png`)

The main writing surface. Centered column max-width 680px, padding `48px 64px 160px`.

1. **Meta line** (mono, uppercase, 10.5px, color `mute`):
   `TODAY · 11:24 AM · 28S` — joined by `·` separators at 50% opacity
2. **Title** — editable single-line `<textarea>` styled to look like display type. 34px Fraunces, weight 400, letter-spacing -0.6, line-height 1.15. No border, transparent background. Auto-grows.
3. **Body** — editable `<textarea>` auto-growing. 18px Fraunces, line-height per density setting (default 1.65), letter-spacing 0.1. `text-wrap: pretty`.
4. **Footer meta** below body: **"N words · saved"** (mono, 10.5px, color `mute`)

Both title and body autosave debounced at 300ms (no save indicator — the text reads "saved" because that's the steady state).

### Editor footer pill

Pinned to the bottom of the editor, centered, with a fade gradient from transparent to `bg` above it (so text scrolls under softly).

A pill: `panel` background, `line` border, `shadow`, radius 100, padding `10px 14px`. Contents:

- **Copy button** (34×34 ghost circle, `Icon.Copy`). When clicked, copies body to clipboard and morphs to `Icon.Check` for 1600ms.
- 1px × 18px divider in `line`
- **DotWave** small (15 dots, ~2px each)
- 1px × 18px divider in `line`
- **Small record button** — same as the big one but 44px. Pressing it starts a new recording (which replaces the editor with the recording stage).

### Screen 5 — Sidebar (`screenshots/02-empty-with-sidebar.png`)

260px column, background `sidebar`, right border `line`. Closed by default; user toggles via the sidebar icon. Slide animation 260ms.

Top region (44px tall, padding-left 82px to clear traffic lights — which now live inside the sidebar):

- Italic serif heading **"Notes"** (15px, color `ink`)
- Right-aligned: **+** icon (new note) and **sidebar-collapse** icon — both 28×28 ghost buttons

History list, scrollable, padding 4px 8px 20px:

#### Date groups (in order, only rendered if non-empty)

1. **Today**
2. **Yesterday**
3. **This week** (anything in the last 7 days that isn't today/yesterday)
4. **Earlier**

Each group label: mono, 10px, weight 500, uppercase, letter-spacing 1.2, padding `10px 14px 6px`, color `mute`.

#### Sidebar item

- Padding `10px 14px`, radius 6, gap 1px between items
- States: idle / `hover` background / `selected` background
- Two lines:
  - Title (Inter 13px, weight 500, color `ink`, single-line ellipsis). When hovered, right-padded 22px to make room for the delete button.
  - Meta (mono 10.5px, color `mute`): `11:24 am · 28s` (formatted time + duration)
- **Delete button** appears on hover at top-right (20×20 radius-4). First click turns the button red (`danger` background, `recordFg` icon) and arms a 2-second confirm window. Second click within that window deletes. If the user mouses out, the confirm resets.

#### Empty state

If the user has no notes:

> *Nothing here yet.*<br>*Press the button to start.*

(Italic serif, 13px, color `mute`, centered, padding-top 40px)

### Screen 6 — Settings modal (`screenshots/05-settings.png`)

Centered modal, 480px wide. Backdrop is `rgba(0,0,0,0.5)` (dark) or `rgba(26,24,21,0.25)` (light), 4px blur. Click backdrop to close. Modal has `panel` background, radius 12, `line` border, `shadow`.

#### Header (border-bottom `lineSoft`, padding `20px 24px 16px`)

- Title **"Settings"** (Fraunces 22px)
- Close icon (✕) — 28×28 ghost button

#### Body sections (each with mono uppercase eyebrow + optional italic-serif hint + content rows)

1. **TRANSCRIPTION MODEL**
   Hint: *"All models run locally. Nothing leaves this device."*
   Five model rows:
   - Whisper Tiny — `39M · fastest · lowest accuracy`
   - Whisper Base — `74M · fast`
   - **Whisper Small** — `244M · balanced` — with a `RECOMMENDED` pill (mono 9px, 1px border)
   - Whisper Medium — `769M · accurate · slower`
   - Voxtral Mini — `Mistral · 1B · experimental`

   Each row: 10px×12px padding, radius 6, custom radio dot (14×14 circle, 7×7 inner fill when selected). Selected row gets `selected` background + `line` border.

2. **LANGUAGE**
   A `SelectRow` showing **English (US)** with hint *"More languages coming soon."* (Read-only for v1.)

3. **TRANSCRIPTION**
   Toggle: **"Auto-insert punctuation"** — *"Adds commas, periods, and capitals from speech patterns."*
   Default: **on**.

4. **APPEARANCE**
   Toggle: **"Dark mode"** — *"Inverted paper — warm near-black with ivory ink."*

#### Toggle

32×19 capsule. Off: `muteSoft` background. On: `ink` background. White 15×15 thumb slides 13px in 180ms ease. 1px shadow on thumb.

---

## Components

### `<DotWave>`

Props: `theme, active, amplitude, count = 21, size: 'lg' | 'md' | 'sm'`.

Renders a row of dots whose size and opacity are driven by the active mic amplitude (a 0..1 number). Uses an internal RAF loop so animation doesn't depend on parent re-renders.

Per-dot amplitude formula (active state):

```
center = count / 2
d = abs(i - center) / center
envelope = 1 - d² × 0.45            // bell shape
phase = sin(t × 3.2 + i × 0.5) × 0.5 + 0.5
jitter = sin(t × 5.1 + i × 1.7) × 0.15
ampDot = clamp(0.12, 1, amp × envelope × (0.55 + phase × 0.55) + jitter)
```

Idle state: dots are tiny (0.08 + small drift), opacity 0.7, color `dotIdle`.

Sizing presets:

| size | base px | range px | gap px | container h |
|------|---------|----------|--------|-------------|
| lg   | 3       | 8        | 10     | 56          |
| md   | 2.5     | 6        | 8      | 40          |
| sm   | 2       | 3.5      | 6      | 24          |

The committed waveform style is **dots**. The prototype's `bars` and `blob` variants are exploratory — don't ship them unless explicitly requested.

### `<RecordButton>`

Props: `theme, active, onClick, size = 72`.

Circle button. Inner shape morphs:
- Idle: circle, ~32% of button size
- Active: rounded square (3px radius), ~28% of button size

Halo (active): `0 0 0 8px ${dotIdle}` ring + drop shadow.
Hover (idle only): translateY -1px, larger shadow.

### `<SmallRecordButton>` — `<RecordButton size={44}>` for the editor footer.

### `<IconButton>` — 28×28, radius 6, ghost. Used in toolbars and modal headers.

### Icons

All defined in `qw-tokens.jsx` as inline SVGs at 16×16 viewbox, stroke-only, stroke-width 1.1–1.5, `currentColor`. The set:

- **Sidebar** — rectangle with vertical divider
- **Settings** — proper 8-tooth gear with hollow hub (recently fixed from a sun-like sketch)
- **Sun / Moon** — theme toggle
- **Plus** — new note
- **Trash** — delete (12px in sidebar)
- **Copy** — two overlapping rounded rects
- **Close** — ✕
- **Check** — ✓ (post-copy confirmation)
- **Chevron** — generic dropdown indicator

### Sidebar (`Sidebar`, `SidebarItem`, `groupByDate`)

`groupByDate(snippets)` partitions by `createdAt` against today/yesterday/last-7-days boundaries. See `qw-sidebar.jsx`.

### Settings modal (`SettingsModal`, `SettingGroup`, `ModelRow`, `SelectRow`, `ToggleRow`, `Toggle`)

See `qw-sidebar.jsx`.

---

## Data model

A snippet:

```ts
type Snippet = {
  id: string;            // 'n' + Date.now() in the prototype; UUID in production
  title: string;         // first sentence (≤50 chars), user-editable
  text: string;          // full transcript, user-editable
  createdAt: number;     // unix ms
  durationSec: number;   // seconds of audio
};
```

Settings:

```ts
type Settings = {
  model: 'tiny' | 'base' | 'small' | 'medium' | 'voxtral'; // default 'small'
  language: 'en-US';                                       // fixed for v1
  autoPunct: boolean;                                      // default true
  dark: boolean;                                           // default false
};
```

**Persistence:** all of this should live in a local SQLite database (or Core Data, or a simple JSON file in `~/Library/Application Support/QuietWhisper/`). **No remote sync, no telemetry.**

Audio is **not** kept around in v1 — only the transcript. (We dropped "audio playback" from the feature list during scoping.)

The prototype uses `localStorage` for `qw-dark` and `qw-sidebar` only; snippets are seed data in memory.

---

## Interactions / state machine

### Recording state

```
idle ──[click record / press space]──> recording
recording ──[click stop / release space]──> transcribing
transcribing ──[engine returns text]──> idle (with new snippet selected)
```

### Hold-space-to-talk

- Listen for `keydown` with `code === 'Space'`, no repeat
- Ignore when the target is an input, textarea, or contenteditable
- Ignore when settings modal is open
- On press while idle → start recording, mark "held" flag
- On release → if held flag is set and currently recording, stop

This means **press-and-hold** for "press to talk" *and* a quick-tap-while-idle would record (until you release space). If you also want **toggle** (tap once to start, tap again to stop), wire the click on the big button — both modes coexist in the prototype.

### Mic permission

In the prototype, `useMicAmplitude` calls `getUserMedia({ audio: true })` and falls back to a simulated amplitude wave if the user denies. **In production, never silently fall back** — show a calm "Microphone access needed" message with a button to open System Settings. Until permission is granted, the record button is disabled.

### Waveform amplitude

```
analyser.fftSize = 512
analyser.smoothingTimeConstant = 0.75
rms = sqrt(mean((data - 128)²) / 128²)    // time-domain RMS, 0..~0.3 typically
amp = clamp(0, 1, rms × 4.5)              // boost so normal speech reads ~0.5
smoothed += (amp - smoothed) × 0.35       // exponential smoothing per frame
```

If you change the boost or smoothing, also revisit the waveform formula above.

### Sidebar

- Closed by default on first launch
- Last state persists across launches (`qw-sidebar` in localStorage equivalent)
- Width animates 0 ↔ 260px in 260ms

### Editor

- Title and body are independently editable
- Both autosave 300ms after last keypress
- Title field is single-line auto-growing — pressing Enter does *not* break to body (acceptable for v1)
- Body uses `text-wrap: pretty` and `spellcheck=true`

### Sidebar delete confirm

Two-click delete pattern. First click of the trash icon arms (2s window, button turns red). Second click commits. Mouse-out cancels. No native confirm dialog, no undo toast — keep it quiet.

---

## Copy

Exact strings used; preserve them.

- Window title: **Quiet Whisper**
- Hero (empty): **A quiet place to think out loud.**
- Hero subhead: **Press and hold space, or click the button. Take your time — there's no rush.**
- Recording eyebrow: **listening** (with pulsing dot)
- Recording subhead: **Take your time.**
- Recording footer hint: **release space to stop**
- Transcribing: **Transcribing…**
- Sidebar empty state: **Nothing here yet.** / **Press the button to start.**
- Sidebar heading: **Notes**
- Settings title: **Settings**
- Settings — model hint: **All models run locally. Nothing leaves this device.**
- Settings — language hint: **More languages coming soon.**
- Settings — auto-punct hint: **Adds commas, periods, and capitals from speech patterns.**
- Settings — dark mode hint: **Inverted paper — warm near-black with ivory ink.**
- Editor footer meta: **{N} words · saved**

---

## Build notes / acceptance

The product is "boring" by design. A few things to actively *not* do:

- ❌ **No menubar item.** The user said this explicitly. The app is launched normally and only does work when its window is visible and the user has pressed record.
- ❌ **No global hotkey.** Hold-space only works when the window has focus. Adding a system-wide hotkey is a different feature and was not asked for.
- ❌ **No upload, no analytics, no crash reporting that ships audio or transcripts.** If you need crash reporting, scrub everything user-typed.
- ❌ **No "smart" features for v1** — no summarization, no AI rewrite, no tags. The dictation surface is the whole product.
- ❌ **No emoji, no decorative icons.** The icons in the chrome are functional only.
- ❌ **No gradients, glows, or glassmorphism.** Solid surfaces only. (The settings modal uses backdrop-blur for the *backdrop*, which is fine — it's a modal scrim, not decoration.)

What "done" looks like for v1:

- [ ] App launches to empty state (or last opened snippet, if any)
- [ ] Click record OR hold space → live waveform → release → transcript appears in 1–3s for ≤1 min audio
- [ ] Transcript is editable in place; edits persist immediately
- [ ] Sidebar lists notes grouped by Today / Yesterday / This week / Earlier
- [ ] Sidebar item delete works with the 2-click confirm
- [ ] Settings modal lets you pick a model and toggle auto-punct + dark mode
- [ ] Light/dark theme swap is animated and smooth
- [ ] No network calls happen during normal operation (verify with Little Snitch or equivalent)

---

## Tech notes for implementation

If you go SwiftUI, suggested architecture:

- `App` (the entry) — owns the model store
- `WindowGroup { ContentView() }` — single window, no menubar item
- `ContentView` — `NavigationSplitView` for the sidebar/main split, customized to match (or `HStack` with manual collapse if `NavigationSplitView`'s animation feels wrong)
- `MainView` — switches on `RecordingState` enum (`.idle(snippet?)`, `.recording`, `.transcribing`)
- `WaveformView` — Canvas-based, reads from a published amplitude on the recorder
- `Recorder` — `AVAudioEngine` tap → RMS → published amplitude; on stop, hands the buffer to:
- `Transcriber` — wraps WhisperKit / whisper.cpp; loads the chosen model lazily
- `SnippetStore` — SQLite or `@Observable` store backed by a JSON file, autosaves on edit

Keyboard:
- `keyDown` for `49` (space) on the main window — the same press-and-hold rules as in the prototype.

Mic permission UX: when first attempting to record, request permission. If denied, show a calm in-window state with one button: **"Open Microphone Settings"**.

Models:
- Bundle Whisper Small as the default
- Allow user to download other sizes from the Settings modal (add a download button beside non-installed models — out of scope for the prototype, in scope for production)

---

## Open questions for the dev / PM

These came up during design and were left for v2:

1. **Markdown mode.** User mentioned "plain text with option to switch to markdown" might come later. Out of scope for v1; if you're adding it, the editor's body would render markdown in a read-mode toggle.
2. **Multi-language.** v1 is English-only. The Language row in Settings is a placeholder.
3. **Audio retention.** Currently we keep no audio. If the user wants to re-listen later (some users will), this becomes a setting.
4. **Streaming transcription.** v1 is batch (transcript appears after stop). Streaming would change the recording UI substantially.
5. **Pause/resume mid-recording.** Considered, dropped from scope. Easy to add: a pause button replaces the stop button when held briefly.
