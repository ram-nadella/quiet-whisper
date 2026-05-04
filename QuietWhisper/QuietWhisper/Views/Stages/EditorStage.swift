// EditorStage.swift
// Main writing surface: meta line, editable title + body, footer pill.
// Autosaves 300ms after last keystroke. Ported from
// design_handoff_quiet_whisper/prototype/qw-app.jsx lines 433–593.

import SwiftUI

struct EditorStage: View {
    let snippet: Snippet
    let density: EditorDensity
    let isRecording: Bool
    let amplitudeProvider: () -> Double
    let onUpdate: (String, String) -> Void
    let onRecord: () -> Void
    let onNewNote: (() -> Void)?

    init(
        snippet: Snippet,
        density: EditorDensity,
        isRecording: Bool = false,
        amplitude: @escaping () -> Double = { 0 },
        onUpdate: @escaping (String, String) -> Void,
        onRecord: @escaping () -> Void,
        onNewNote: (() -> Void)? = nil
    ) {
        self.snippet = snippet
        self.density = density
        self.isRecording = isRecording
        self.amplitudeProvider = amplitude
        self.onUpdate = onUpdate
        self.onRecord = onRecord
        self.onNewNote = onNewNote
    }

    @Environment(\.paperTheme) private var theme

    @State private var title: String = ""
    @State private var text: String = ""
    @State private var loaded = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    metaLine
                        .padding(.bottom, 14)

                    titleField
                        .padding(.bottom, 22)

                    bodyField

                    footerMeta
                        .padding(.top, 32)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 48)
                .padding(.horizontal, 64)
                .padding(.bottom, 160)
            }

            EditorFooterPill(
                text: text,
                isRecordingActive: isRecording,
                amplitude: amplitudeProvider,
                onRecord: onRecord,
                onNewNote: onNewNote
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            QWLog.ui.notice("EditorStage: appeared for snippet id=\(snippet.id, privacy: .public) title.count=\(snippet.title.count, privacy: .public) text.count=\(snippet.text.count, privacy: .public) durationSec=\(snippet.durationSec, privacy: .public)")
            syncFromSnippet()
        }
        .onChange(of: snippet.id) { _, _ in syncFromSnippet() }
        // External update (e.g. append after a take) — re-sync local fields so
        // the new text actually shows in the body.
        .onChange(of: snippet.text) { _, newText in
            if newText != text { syncFromSnippet() }
        }
        .onChange(of: snippet.title) { _, newTitle in
            if newTitle != title { syncFromSnippet() }
        }
        .onChange(of: title) { _, _ in scheduleSave() }
        .onChange(of: text)  { _, _ in scheduleSave() }
    }

    // MARK: - Pieces

    private var metaLine: some View {
        HStack(spacing: 10) {
            Text(EditorMeta.formatDate(snippet.createdAt).uppercased())
            Text("·").opacity(0.5)
            Text(EditorMeta.formatTime(snippet.createdAt).uppercased())
            Text("·").opacity(0.5)
            Text(EditorMeta.formatDuration(snippet.durationSec).uppercased())
        }
        .font(.paperMetaMono)
        .tracking(1.2)
        .foregroundStyle(theme.mute)
    }

    private var titleField: some View {
        TextField("", text: $title)
            .textFieldStyle(.plain)
            .font(.paperEditorTitle)
            .tracking(-0.6)
            .foregroundStyle(theme.ink)
    }

    private var bodyField: some View {
        // Per-density line spacing. SwiftUI .lineSpacing is *additional* leading
        // beyond the font's intrinsic height; (multiplier - 1) * 18 approximates
        // the prototype's CSS line-height multiplier on 18pt body.
        let extra = (density.lineSpacingMultiplier - 1.0) * 18.0

        return TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .font(.paperEditorBody)
            .tracking(0.1)
            .lineSpacing(extra)
            .foregroundStyle(theme.ink)
            .frame(minHeight: 200)
    }

    private var footerMeta: some View {
        HStack(spacing: 10) {
            Text("\(wordCount) words")
            Text("·").opacity(0.5)
            Text("saved")
        }
        .font(.paperMetaMono)
        .tracking(0.4)
        .foregroundStyle(theme.mute)
    }

    // MARK: - Logic

    private var wordCount: Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.split(whereSeparator: { $0.isWhitespace }).count
    }

    private func syncFromSnippet() {
        title = snippet.title
        text = snippet.text
        loaded = true
        saveTask?.cancel()
    }

    // 300ms debounce — cancel + replace pending task.
    private func scheduleSave() {
        guard loaded else { return }
        saveTask?.cancel()
        let snap = (title, text)
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            if snap.0 != snippet.title || snap.1 != snippet.text {
                onUpdate(snap.0, snap.1)
            }
        }
    }
}

// MARK: - Date / duration formatters
// Local to this file so the stage compiles standalone. Mirrors qw-sidebar.jsx
// `formatTime`/`formatDuration` and qw-app.jsx `formatDate` (lines 586–593).

enum EditorMeta {
    static func formatDate(_ ts: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(ts) { return "Today" }
        if cal.isDateInYesterday(ts) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: ts)
    }

    static func formatTime(_ ts: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: ts)
        let m = cal.component(.minute, from: ts)
        let ampm = h >= 12 ? "pm" : "am"
        let h12 = (h % 12 == 0) ? 12 : (h % 12)
        return String(format: "%d:%02d %@", h12, m, ampm)
    }

    static func formatDuration(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)s"
    }
}
