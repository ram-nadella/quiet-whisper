# Whisper Dictation — macOS Speech-to-Text App

## Implementation Plan

A minimal, local-only speech-to-text macOS app built with Swift (no Xcode project), powered by whisper.cpp. The user holds a button to record, and transcribed text appears in real time. Inspired by iA Writer's clean, distraction-free aesthetic.

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  SwiftUI App                     │
│                                                  │
│  ┌───────────────┐  ┌────────────────────────┐  │
│  │  Record Button │  │  Transcription TextView │  │
│  │  (hold to talk)│  │  (scrollable, copyable) │  │
│  └───────┬───────┘  └────────────▲───────────┘  │
│          │                       │               │
│          ▼                       │               │
│  ┌───────────────┐  ┌───────────┴───────────┐  │
│  │ AudioCapture   │  │  WhisperBridge         │  │
│  │ (AVAudioEngine)│──│  (C interop to         │  │
│  │ 16kHz mono PCM │  │   whisper.cpp)          │  │
│  └───────────────┘  └───────────────────────┘  │
│                              │                   │
│                     ┌────────▼────────┐         │
│                     │  ggml .bin model │         │
│                     │  (on disk)       │         │
│                     └─────────────────┘         │
└─────────────────────────────────────────────────┘
```

**Data flow:**
1. User presses and holds the record button.
2. `AVAudioEngine` captures microphone audio, resampling to 16kHz mono Float32 PCM.
3. Audio buffers accumulate. On button release (or at intervals for streaming), the buffer is sent to whisper.cpp via a C bridge.
4. whisper.cpp processes the audio and returns transcribed text segments.
5. Text is appended to the transcript view.
6. User can copy the full transcript or clear it.

---

## 2. Project Structure

```
whisper-dictation/
├── Package.swift
├── Sources/
│   └── WhisperDictation/
│       ├── main.swift              # App entry point
│       ├── App.swift               # SwiftUI App definition
│       ├── ContentView.swift       # Main UI
│       ├── AudioCapture.swift      # Microphone recording via AVAudioEngine
│       ├── WhisperBridge.swift     # Swift wrapper around whisper.cpp C API
│       └── ModelManager.swift      # Model download/selection
├── CWhisper/
│   ├── include/
│   │   └── whisper_bridge.h        # C header exposing whisper.cpp to Swift
│   └── whisper_bridge.c            # Thin C wrapper (if needed)
├── Resources/
│   └── models/                     # Downloaded .bin files go here
├── scripts/
│   ├── build.sh                    # Build script
│   ├── run.sh                      # Run script
│   ├── download-model.sh           # Model download helper
│   └── bundle-app.sh              # Creates .app bundle
└── Info.plist                      # App metadata & permissions
```

---

## 3. Build System — Swift Package Manager (No Xcode)

### Prerequisites

- macOS with Xcode Command Line Tools installed: `xcode-select --install`
- An editor (VS Code with Swift extension, Cursor, etc.)
- cmake (install via `brew install cmake`)

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperDictation",
    platforms: [.macOS(.v14)],
    targets: [
        // C target wrapping whisper.cpp
        .systemLibrary(
            name: "CWhisper",
            pkgConfig: nil,
            providers: []
        ),
        .executableTarget(
            name: "WhisperDictation",
            dependencies: ["CWhisper"],
            path: "Sources/WhisperDictation",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedLibrary("whisper"),  // links libwhisper from whisper.cpp build
            ]
        )
    ]
)
```

**Important note on whisper.cpp integration:** There are two viable approaches. Choose one:

**Approach A — Build whisper.cpp as a static library, link it:**
1. Clone and build whisper.cpp with cmake.
2. Produce `libwhisper.a` and the `whisper.h` header.
3. Reference the library in `Package.swift` linker settings.
4. Create a `CWhisper` system module that points to the header.

**Approach B — Use the `whisper-cpp-kit` Swift package (if available):**
Check for a maintained Swift Package that wraps whisper.cpp. If one exists and is up-to-date, add it as a dependency instead. This is simpler but adds a third-party dependency.

**Recommendation:** Use Approach A for full control. The steps:

```bash
# Clone whisper.cpp
git clone https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp

# Build as shared/static library with Metal support (Apple Silicon)
cmake -B build \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_METAL=ON \
  -DWHISPER_COREML=OFF \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build -j --config Release

# The outputs you need:
#   build/src/libwhisper.a        (static library)
#   build/ggml/src/libggml*.a     (ggml static libraries)
#   include/whisper.h             (public C header)
```

Then set up the CWhisper module to find these artifacts. The `module.modulemap` in `CWhisper/include/`:

```
module CWhisper {
    header "whisper.h"
    link "whisper"
    export *
}
```

### Build & Run

```bash
# From project root
swift build -c release

# Run
.build/release/WhisperDictation
```

---

## 4. Models — Download & Management

### Supported Models

| Model ID | File | Size | Use Case |
|----------|------|------|----------|
| `medium.en` | `ggml-medium.en.bin` | ~1.5 GB | High accuracy, good speed on M-series |
| `large-v3-turbo` | `ggml-large-v3-turbo.bin` | ~1.6 GB | Near-best accuracy, optimized speed |

Both models are English-capable. The `medium.en` is English-only (slightly better for English). The `large-v3-turbo` is multilingual but we use it for English only.

### Download Source

All models are hosted on Hugging Face with no authentication required:

```
https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin
https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

### download-model.sh

```bash
#!/bin/bash
MODEL_DIR="$HOME/Library/Application Support/WhisperDictation/models"
mkdir -p "$MODEL_DIR"

BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

download_model() {
    local model_name=$1
    local filename="ggml-${model_name}.bin"
    local filepath="${MODEL_DIR}/${filename}"

    if [ -f "$filepath" ]; then
        echo "Model $model_name already exists at $filepath"
        return 0
    fi

    echo "Downloading $model_name (~1.5GB)..."
    curl -L --progress-bar -o "$filepath" "${BASE_URL}/${filename}"
    echo "Downloaded to $filepath"
}

case "${1:-medium.en}" in
    medium.en)
        download_model "medium.en"
        ;;
    large-v3-turbo)
        download_model "large-v3-turbo"
        ;;
    all)
        download_model "medium.en"
        download_model "large-v3-turbo"
        ;;
    *)
        echo "Usage: $0 [medium.en|large-v3-turbo|all]"
        exit 1
        ;;
esac
```

### ModelManager.swift

```swift
import Foundation

enum WhisperModel: String, CaseIterable {
    case mediumEn = "medium.en"
    case largeTurbo = "large-v3-turbo"

    var filename: String {
        "ggml-\(rawValue).bin"
    }

    var displayName: String {
        switch self {
        case .mediumEn: return "Medium (English)"
        case .largeTurbo: return "Large Turbo"
        }
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }
}

class ModelManager: ObservableObject {
    @Published var availableModels: [WhisperModel] = []
    @Published var selectedModel: WhisperModel = .mediumEn
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false

    let modelsDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("WhisperDictation/models")
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        refreshAvailableModels()
    }

    func modelPath(for model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.filename)
    }

    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: model).path)
    }

    func refreshAvailableModels() {
        availableModels = WhisperModel.allCases.filter { isModelDownloaded($0) }
    }

    func downloadModel(_ model: WhisperModel) async throws {
        // Use URLSession to download with progress tracking
        // Update downloadProgress on main thread
        // Save to modelsDirectory
        // Call refreshAvailableModels() on completion
    }
}
```

---

## 5. Audio Capture — AVAudioEngine

### AudioCapture.swift

Whisper requires **16kHz, mono, Float32 PCM** audio.

```swift
import AVFoundation

class AudioCapture: ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0  // for optional visual feedback

    /// Start capturing microphone audio
    func startRecording() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Target format: 16kHz mono Float32 (what Whisper expects)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatError
        }

        // Install a tap that converts to 16kHz mono
        // If the hardware sample rate differs, use AVAudioConverter
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, time in
            guard let self = self else { return }

            // Convert to 16kHz mono
            let convertedBuffer = self.convert(buffer: buffer, converter: converter, targetFormat: targetFormat)
            if let samples = convertedBuffer {
                self.bufferLock.lock()
                self.audioBuffer.append(contentsOf: samples)
                self.bufferLock.unlock()
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    /// Stop recording and return accumulated audio samples
    func stopRecording() -> [Float] {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        return samples
    }

    private func convert(buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, targetFormat: AVAudioFormat) -> [Float]? {
        // If formats match, extract directly
        // Otherwise, use converter to resample
        // Return [Float] array of samples
        // ...implementation detail...
        return nil // placeholder
    }
}

enum AudioCaptureError: Error {
    case formatError
    case permissionDenied
}
```

**Key implementation notes:**
- Always check/request microphone permission first via `AVCaptureDevice.requestAccess(for: .audio)`.
- The hardware mic is typically 44.1kHz or 48kHz stereo; you MUST resample to 16kHz mono.
- Use `AVAudioConverter` for resampling — do NOT do naive sample dropping.
- For the hold-to-record UX, `startRecording()` is called on button press, `stopRecording()` on release.

---

## 6. Whisper Integration — C Bridge to Swift

### WhisperBridge.swift

This wraps the whisper.cpp C API for use in Swift.

```swift
import Foundation
import CWhisper  // The C module wrapping whisper.h

class WhisperBridge {
    private var context: OpaquePointer?  // whisper_context*

    /// Load a model from disk
    func loadModel(path: String) throws {
        // Call: whisper_init_from_file(path)
        // Store the returned context pointer
        // Throw if nil (model failed to load)
        context = whisper_init_from_file(path)
        guard context != nil else {
            throw WhisperError.modelLoadFailed
        }
    }

    /// Transcribe a buffer of Float32 PCM samples at 16kHz
    func transcribe(samples: [Float]) -> String {
        guard let ctx = context else { return "" }

        // Set up whisper_full_params
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.language = "en".withCString { strdup($0) }
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 2))
        params.no_context = true
        params.single_segment = false
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false

        // Run inference
        // whisper_full(ctx, params, samples_pointer, sample_count)
        let result = samples.withUnsafeBufferPointer { bufferPtr in
            whisper_full(ctx, params, bufferPtr.baseAddress, Int32(samples.count))
        }

        guard result == 0 else { return "" }

        // Extract text from segments
        var text = ""
        let nSegments = whisper_full_n_segments(ctx)
        for i in 0..<nSegments {
            if let cStr = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: cStr)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Free the model
    func unloadModel() {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
    }

    deinit {
        unloadModel()
    }
}

enum WhisperError: Error {
    case modelLoadFailed
    case transcriptionFailed
}
```

**Key whisper_full_params settings:**
- `language = "en"` — forces English, skips language detection overhead.
- `n_threads` — use physical core count minus 2 to keep the system responsive.
- `no_context = true` — each transcription is independent (no cross-segment context).
- Greedy sampling is faster than beam search; use `WHISPER_SAMPLING_GREEDY`.

**Threading:** `whisper_full()` is blocking and CPU-intensive. Always call it on a background thread (Swift `Task` / `DispatchQueue.global()`), never on the main thread.

---

## 7. UI — SwiftUI (iA Writer-Inspired)

### Design Principles

- **Monospace or serif font** for the transcript (iA Writer uses a custom mono font; use `SF Mono` or `New York` as system alternatives).
- **Maximum whitespace.** Large margins, no chrome.
- **Muted colors.** Near-white background (#FAFAFA), dark gray text (#1A1A1A), subtle accents.
- **Single window.** No tabs, no sidebar, no toolbar clutter.
- **Focus mode.** The text area dominates the window. Controls are minimal and secondary.

### ContentView.swift

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var audioCapture = AudioCapture()
    @StateObject private var modelManager = ModelManager()
    @State private var whisperBridge = WhisperBridge()
    @State private var transcript = ""
    @State private var isTranscribing = false
    @State private var isModelLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Transcript Area ──
            // Scrollable text view, selectable & copyable
            // Large monospace font, generous padding
            // Placeholder text when empty: "Hold the button and speak..."
            ScrollView {
                Text(transcript.isEmpty ? "Hold the button and speak..." : transcript)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(transcript.isEmpty ? Color.gray.opacity(0.5) : Color(hex: "1A1A1A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(40)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "FAFAFA"))

            Divider()

            // ── Bottom Bar ──
            // Record button (center), Copy + Clear (trailing), Model picker (leading)
            HStack(spacing: 16) {
                // Model picker — small, unobtrusive
                Picker("Model", selection: $modelManager.selectedModel) {
                    ForEach(modelManager.availableModels, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)

                Spacer()

                // Record button — hold to record
                RecordButton(isRecording: audioCapture.isRecording) {
                    // on press
                    startRecording()
                } onRelease: {
                    // on release
                    stopAndTranscribe()
                }

                Spacer()

                // Copy button
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcript, forType: .string)
                }
                .disabled(transcript.isEmpty)

                // Clear button
                Button("Clear") {
                    transcript = ""
                }
                .disabled(transcript.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "F5F5F5"))
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadDefaultModel()
        }
    }

    private func startRecording() {
        try? audioCapture.startRecording()
    }

    private func stopAndTranscribe() {
        let samples = audioCapture.stopRecording()
        guard !samples.isEmpty else { return }

        isTranscribing = true
        Task.detached(priority: .userInitiated) {
            let text = whisperBridge.transcribe(samples: samples)
            await MainActor.run {
                if !text.isEmpty {
                    if !transcript.isEmpty {
                        transcript += "\n"
                    }
                    transcript += text
                }
                isTranscribing = false
            }
        }
    }

    private func loadDefaultModel() {
        // Load the selected model on a background thread
        // Update isModelLoaded on completion
    }
}
```

### RecordButton (Custom Component)

```swift
struct RecordButton: View {
    let isRecording: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        // A circular button that responds to press-and-hold
        // Visual states:
        //   - Idle: subtle gray circle with mic icon
        //   - Recording: red/pulsing circle with mic icon
        //   - Processing: spinner
        //
        // Use .simultaneousGesture(DragGesture(minimumDistance: 0)) to detect
        // press (onChanged) and release (onEnded) without requiring drag.
        Circle()
            .fill(isRecording ? Color.red.opacity(0.8) : Color.gray.opacity(0.15))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "mic.fill")
                    .foregroundColor(isRecording ? .white : .gray)
                    .font(.system(size: 22))
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording { onPress() }
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}
```

### Window Configuration

```swift
// In App.swift
@main
struct WhisperDictationApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 700, height: 500)
    }
}
```

**Design tokens (iA Writer inspired):**
- Background: `#FAFAFA`
- Text: `#1A1A1A`
- Placeholder text: `#CCCCCC`
- Bottom bar background: `#F5F5F5`
- Font: `SF Mono` at 15pt for transcript, system font for UI controls
- Padding: 40pt on transcript area
- No borders on text area, no visible scrollbar unless scrolling
- Window: no toolbar, title bar only

---

## 8. Permissions

### Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Whisper Dictation</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.whisper-dictation</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>WhisperDictation</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Whisper Dictation needs microphone access to transcribe your speech.</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

**Note:** The `NSMicrophoneUsageDescription` key is required. Without it, the app will crash when trying to access the microphone. The app must be bundled as a `.app` for the system permission dialog to appear properly.

---

## 9. App Bundle Script

For the permission dialogs and proper macOS behavior, the app needs to be a `.app` bundle:

### bundle-app.sh

```bash
#!/bin/bash
set -e

APP_NAME="Whisper Dictation"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS="${BUNDLE_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Build release binary
swift build -c release

# Create bundle structure
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp .build/release/WhisperDictation "$MACOS/WhisperDictation"

# Copy Info.plist
cp Info.plist "$CONTENTS/Info.plist"

# Copy whisper.cpp shared libraries if dynamically linked
# cp /path/to/libwhisper.dylib "$MACOS/"
# cp /path/to/libggml*.dylib "$MACOS/"

echo "Built: $BUNDLE_DIR"
echo "Run with: open \"$BUNDLE_DIR\""
```

---

## 10. Implementation Phases

### Phase 1 — Whisper.cpp integration (start here)

1. Clone and build whisper.cpp as a static library with Metal support.
2. Download `ggml-medium.en.bin` using the download script.
3. Create the Swift Package project structure.
4. Implement `CWhisper` module map pointing to whisper.h and the static library.
5. Implement `WhisperBridge.swift` — load model, transcribe a hardcoded test wav.
6. Verify transcription works from a CLI test: load model → read wav → print text.

### Phase 2 — Audio capture

1. Implement `AudioCapture.swift` with AVAudioEngine.
2. Handle mic permission request.
3. Verify audio format: 16kHz mono Float32.
4. Test: record 5 seconds → pass to WhisperBridge → print transcription.

### Phase 3 — UI

1. Implement the SwiftUI window with ContentView.
2. Implement the hold-to-record button using `DragGesture(minimumDistance: 0)`.
3. Wire up: press → startRecording, release → stopRecording → transcribe → display.
4. Add Copy and Clear buttons.
5. Style with iA Writer-inspired design tokens.

### Phase 4 — Model management

1. Implement `ModelManager` with download progress.
2. Add model picker in the bottom bar.
3. Support switching between `medium.en` and `large-v3-turbo`.
4. Show download UI if no models are present on first launch.

### Phase 5 — Bundle & polish

1. Create the `.app` bundle using `bundle-app.sh`.
2. Test microphone permission dialog.
3. Add a loading/processing indicator while whisper is transcribing.
4. Handle edge cases: empty recording, very short recording, model not loaded.

---

## 11. Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Build system | Swift Package Manager, no .xcodeproj | Lightweight, CLI-friendly, no Xcode dependency |
| Whisper integration | whisper.cpp static library via C interop | Full control, no third-party Swift wrapper needed |
| Audio format | 16kHz mono Float32 via AVAudioConverter | Required by whisper.cpp |
| Transcription mode | Batch (on button release) | Simpler than streaming for v1; avoids partial-segment complexity |
| UI framework | SwiftUI | Modern, minimal boilerplate, good enough for this UI |
| Model storage | ~/Library/Application Support/WhisperDictation/models/ | Standard macOS app data location |
| Threading | `Task.detached` for transcription | Keeps UI responsive during inference |
| Metal acceleration | Enabled via whisper.cpp cmake flag | Major speed boost on Apple Silicon |

---

## 12. Dependencies & Versions

| Dependency | Version | Source |
|------------|---------|--------|
| whisper.cpp | Latest from `main` branch | https://github.com/ggml-org/whisper.cpp |
| macOS SDK | 14.0+ (Sonoma) | Xcode Command Line Tools |
| Swift | 5.9+ | Bundled with Command Line Tools |
| cmake | 3.20+ | `brew install cmake` |

No npm, no pip, no package managers beyond SPM and Homebrew for cmake.

---

## 13. Gotchas & Warnings

- **Microphone permission requires .app bundle.** Running the bare binary from `.build/` may not trigger the permission dialog correctly. Always test with the bundled `.app`.
- **First whisper.cpp inference is slow** due to Metal shader compilation. Subsequent calls are fast. Consider a "warming up model..." state on first use.
- **whisper_full() blocks the calling thread.** Never call on main thread.
- **Audio buffer memory.** A 60-second recording at 16kHz Float32 is ~3.8MB. This is fine, but clear the buffer after transcription.
- **Large models need RAM.** `medium.en` uses ~1.5GB RAM, `large-v3-turbo` uses ~3GB. Warn the user if system memory is low.
- **Static linking whisper.cpp:** You'll need to link all ggml sub-libraries too (`libggml.a`, `libggml-base.a`, `libggml-metal.a`, `libggml-cpu.a`). Check the cmake build output for the full list.
- **Metal shaders:** whisper.cpp's Metal backend may need the `.metal` shader file at runtime. Either embed it or ensure it's in the bundle's Resources.
