// ContentView.swift
// Top-level layout + recording state machine.
// Sidebar | (TopBar / Stages) with a Settings overlay.

import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]

    @State private var settings = AppSettings()
    @State private var recState: RecordingState = .idle
    @State private var selectedID: UUID?
    @State private var settingsOpen = false
    @State private var elapsed: TimeInterval = 0

    @State private var recorder = AudioRecorder()
    @State private var transcriber = WhisperTranscriber()
    @State private var spaceMonitor: SpaceKeyMonitor?

    @State private var permissionDenied = false

    private var theme: PaperTheme { .of(mode: settings.dark ? .dark : .light) }

    private var selectedSnippet: Snippet? {
        guard let id = selectedID else { return nil }
        return snippets.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Sidebar — width animates 0 ↔ 260 on toggle.
                if settings.sidebarOpen {
                    SidebarView(
                        snippets: snippets,
                        selectedID: selectedID,
                        onSelect: { id in selectedID = id },
                        onDelete: deleteSnippet,
                        onNew: newNote,
                        onClose: { settings.sidebarOpen = false }
                    )
                    .frame(width: 260)
                    .transition(.move(edge: .leading))
                }

                VStack(spacing: 0) {
                    TopBar(
                        sidebarOpen: settings.sidebarOpen,
                        dark: settings.dark,
                        onToggleSidebar: { settings.sidebarOpen.toggle() },
                        onToggleDark: { settings.dark.toggle() },
                        onOpenSettings: { settingsOpen = true }
                    )

                    stageView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.easeInOut(duration: 0.26), value: settings.sidebarOpen)
            .animation(.easeInOut(duration: 0.24), value: settings.dark)
            .background(theme.bg.ignoresSafeArea())

            if settingsOpen {
                SettingsModal(
                    model: Binding(get: { settings.model }, set: { settings.model = $0 }),
                    autoPunct: Binding(get: { settings.autoPunct }, set: { settings.autoPunct = $0 }),
                    dark: Binding(get: { settings.dark }, set: { settings.dark = $0 }),
                    onClose: { settingsOpen = false }
                )
                .transition(.opacity)
            }
        }
        .environment(\.paperTheme, theme)
        .preferredColorScheme(settings.dark ? .dark : .light)
        .onAppear { installSpaceMonitor() }
        .onDisappear { spaceMonitor?.stop() }
    }

    // MARK: - Stage selection

    @ViewBuilder
    private var stageView: some View {
        switch recState {
        case .idle:
            if let snippet = selectedSnippet {
                EditorStage(
                    snippet: snippet,
                    density: settings.density,
                    onUpdate: { title, text in
                        snippet.title = title
                        snippet.text = text
                        try? ctx.save()
                    },
                    onRecord: toggleRecord
                )
            } else if permissionDenied {
                MicPermissionPanel()
            } else {
                EmptyStage(onRecord: toggleRecord)
            }
        case .recording:
            RecordingStage(
                amplitude: recorder.amplitude,
                elapsed: elapsed,
                onStop: toggleRecord
            )
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                if case .recording(let started) = recState {
                    elapsed = Date().timeIntervalSince(started)
                }
            }
        case .transcribing:
            TranscribingStage()
        }
    }

    // MARK: - Actions

    private func toggleRecord() {
        switch recState {
        case .idle:        Task { await startRecording() }
        case .recording:   Task { await stopRecording() }
        case .transcribing: break
        }
    }

    private func startRecording() async {
        let perm = recorder.permission == .unknown
            ? await recorder.requestPermission()
            : recorder.permission
        guard perm == .granted else {
            permissionDenied = true
            return
        }
        permissionDenied = false
        do {
            try await recorder.start()
            elapsed = 0
            recState = .recording(startedAt: Date())
            selectedID = nil
        } catch {
            permissionDenied = (recorder.permission == .denied)
        }
    }

    private func stopRecording() async {
        guard case .recording(let started) = recState else { return }
        let durationSec = max(1, Int(Date().timeIntervalSince(started).rounded()))
        recState = .transcribing
        let wavURL: URL?
        do { wavURL = try await recorder.stop() } catch { wavURL = nil }

        let text: String
        if let wavURL {
            do {
                try await transcriber.load(settings.model)
                text = try await transcriber.transcribe(wavURL, autoPunct: settings.autoPunct)
            } catch {
                text = "[Transcription failed: \(error.localizedDescription)]"
            }
            try? FileManager.default.removeItem(at: wavURL)
        } else {
            text = ""
        }

        let snippet = Snippet(
            title: Snippet.makeTitle(from: text),
            text: text,
            createdAt: Date(),
            durationSec: durationSec
        )
        ctx.insert(snippet)
        try? ctx.save()
        selectedID = snippet.id
        recState = .idle
    }

    private func deleteSnippet(_ id: UUID) {
        guard let s = snippets.first(where: { $0.id == id }) else { return }
        ctx.delete(s)
        try? ctx.save()
        if selectedID == id { selectedID = nil }
    }

    private func newNote() {
        selectedID = nil
        if !settings.sidebarOpen { settings.sidebarOpen = true }
    }

    // MARK: - Hold-space

    private func installSpaceMonitor() {
        let monitor = SpaceKeyMonitor(
            onPressDown: {
                if case .idle = recState { Task { await startRecording() } }
            },
            onReleaseUp: {
                if case .recording = recState { Task { await stopRecording() } }
            },
            isEnabled: { !settingsOpen }
        )
        monitor.start()
        spaceMonitor = monitor
    }

}

// MARK: - Mic permission panel

private struct MicPermissionPanel: View {
    @Environment(\.paperTheme) private var theme
    var body: some View {
        VStack(spacing: 18) {
            Text("Microphone access needed")
                .font(.paperHero)
                .foregroundStyle(theme.ink)
                .tracking(-0.4)
            Text("Quiet Whisper transcribes audio on this device.\nNothing leaves your Mac.")
                .font(.paperHeroSubhead)
                .foregroundStyle(theme.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Button("Open Microphone Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.ink)
            .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
