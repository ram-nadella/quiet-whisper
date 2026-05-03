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
    @State private var selectedID: UUID?
    @State private var settingsOpen = false
    @State private var lastError: String?
    /// When non-nil at the moment the user clicks record, the resulting take
    /// is appended to that snippet instead of opening a new one. Captured at
    /// `start` time so a sidebar selection change mid-take can't redirect
    /// the append.
    @State private var appendTargetID: UUID?

    @State private var controller: RecordingController
    @State private var spaceMonitor: SpaceKeyMonitor?

    @MainActor
    init() {
        self.init(recorder: AudioRecorder(), transcriber: WhisperTranscriber())
    }

    @MainActor
    init(recorder: any RecorderProtocol, transcriber: any TranscriberProtocol) {
        _controller = State(initialValue: RecordingController(recorder: recorder, transcriber: transcriber))
    }

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
        .onAppear {
            QWLog.ui.notice("view: ContentView appeared — wiring controller + space monitor")
            controller.onTakeCompleted = { [self] result in handleTake(result) }
            installSpaceMonitor()
        }
        .onDisappear {
            QWLog.ui.notice("view: ContentView disappeared — stopping space monitor")
            spaceMonitor?.stop()
        }
    }

    // MARK: - Stage selection

    @ViewBuilder
    private var stageView: some View {
        switch controller.state {
        case .idle:
            if let snippet = selectedSnippet {
                EditorStage(
                    snippet: snippet,
                    density: settings.density,
                    isRecording: false,
                    amplitude: 0,
                    onUpdate: { title, text in
                        snippet.title = title
                        snippet.text = text
                        try? ctx.save()
                    },
                    onRecord: toggleRecord
                )
            } else if controller.permissionDenied {
                MicPermissionPanel()
            } else if let startError = controller.startError {
                TranscriberErrorPanel(message: startError, onDismiss: { controller.clearStartError() }, onRetry: toggleRecord)
            } else if let lastError {
                TranscriberErrorPanel(message: lastError, onDismiss: { self.lastError = nil }, onRetry: toggleRecord)
            } else {
                EmptyStage(onRecord: toggleRecord)
            }
        case .recording(let startedAt):
            // If the user invoked record from inside an existing note, stay
            // on the editor so they keep their context. Otherwise show the
            // full-window recording stage for a fresh take.
            if let snippet = appendTargetSnippet {
                EditorStage(
                    snippet: snippet,
                    density: settings.density,
                    isRecording: true,
                    amplitude: controller.amplitude,
                    onUpdate: { title, text in
                        snippet.title = title
                        snippet.text = text
                        try? ctx.save()
                    },
                    onRecord: toggleRecord
                )
            } else {
                RecordingStage(
                    amplitude: controller.amplitude,
                    startedAt: startedAt,
                    onStop: toggleRecord
                )
            }
        case .transcribing:
            // During transcribe of an append, also keep the editor visible —
            // jumping to the full-screen "Transcribing…" panel would lose the
            // user's context for what they were dictating into.
            if let snippet = appendTargetSnippet {
                EditorStage(
                    snippet: snippet,
                    density: settings.density,
                    isRecording: false,
                    amplitude: 0,
                    onUpdate: { title, text in
                        snippet.title = title
                        snippet.text = text
                        try? ctx.save()
                    },
                    onRecord: toggleRecord
                )
            } else {
                TranscribingStage()
            }
        }
    }

    private var appendTargetSnippet: Snippet? {
        guard let id = appendTargetID else { return nil }
        return snippets.first { $0.id == id }
    }

    // MARK: - Actions

    private func toggleRecord() {
        lastError = nil
        // Capture append target on the leading edge: if we're idle and the
        // user has a snippet open, this take should grow that note. Capture
        // it now (not at handleTake time) so a sidebar click during the
        // recording can't redirect us mid-take.
        if case .idle = controller.state {
            appendTargetID = selectedID
        }
        controller.toggle(model: settings.model, autoPunct: settings.autoPunct)
    }

    private func handleTake(_ result: TakeResult) {
        // Snapshot + clear the append target — even on error we don't want
        // it lingering for the next take.
        let appendTo = appendTargetID.flatMap { id in snippets.first { $0.id == id } }
        appendTargetID = nil

        if let err = result.transcriberError {
            QWLog.ui.error("view: take failed — \(err, privacy: .public)")
            // Don't clear selection if we were appending — the editor stays
            // open, the user just sees the error panel-style state next time
            // they leave/return. For new-note takes, clear so we don't
            // strand the user in a stale editor.
            if appendTo == nil { selectedID = nil }
            lastError = err
            return
        }

        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            QWLog.ui.notice("view: take produced empty text — surfacing no-speech panel")
            if appendTo == nil { selectedID = nil }
            lastError = "No speech detected. Try again, a little closer to the mic."
            return
        }

        if let appendTo {
            appendTo.append(transcribedText: trimmed, durationSec: result.durationSec)
            do {
                try ctx.save()
                QWLog.ui.notice("view: appended \(trimmed.count, privacy: .public) chars (+\(result.durationSec, privacy: .public)s) to snippet \(appendTo.id, privacy: .public)")
            } catch {
                QWLog.ui.error("view: ctx.save after append failed: \(String(describing: error), privacy: .public)")
            }
            // Keep selectedID where it was — we're still on this snippet.
            return
        }

        let snippet = Snippet(
            title: Snippet.makeTitle(from: trimmed),
            text: trimmed,
            createdAt: Date(),
            durationSec: result.durationSec
        )
        ctx.insert(snippet)
        do {
            try ctx.save()
            QWLog.ui.notice("view: snippet inserted (id=\(snippet.id, privacy: .public), \(trimmed.count, privacy: .public) chars, \(result.durationSec, privacy: .public)s)")
        } catch {
            QWLog.ui.error("view: ctx.save after insert failed: \(String(describing: error), privacy: .public)")
        }
        selectedID = snippet.id
    }

    private func deleteSnippet(_ id: UUID) {
        guard let s = snippets.first(where: { $0.id == id }) else {
            QWLog.ui.notice("view: delete called with unknown id \(id, privacy: .public)")
            return
        }
        ctx.delete(s)
        do {
            try ctx.save()
            QWLog.ui.notice("view: snippet deleted (id=\(id, privacy: .public))")
        } catch {
            QWLog.ui.error("view: ctx.save after delete failed: \(String(describing: error), privacy: .public)")
        }
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
                if case .idle = controller.state { toggleRecord() }
            },
            onReleaseUp: {
                if case .recording = controller.state { toggleRecord() }
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

// MARK: - Transcriber error panel

private struct TranscriberErrorPanel: View {
    let message: String
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            Text("Something went wrong")
                .font(.paperHero)
                .foregroundStyle(theme.ink)
                .tracking(-0.4)
            Text(message)
                .font(.paperHeroSubhead)
                .foregroundStyle(theme.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)
            HStack(spacing: 12) {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .tint(theme.ink)
                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.ink)
            }
            .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
