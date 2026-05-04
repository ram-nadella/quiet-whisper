// EditorFooterPill.swift
// Floating pill above the editor: copy, dot wave, record. Body fades into it
// via a vertical gradient.

import SwiftUI
import AppKit

struct EditorFooterPill: View {
    let text: String
    let isRecordingActive: Bool
    let amplitudeProvider: () -> Double
    let onRecord: () -> Void
    let onNewNote: (() -> Void)?

    init(
        text: String,
        isRecordingActive: Bool,
        amplitude: @escaping () -> Double = { 0 },
        onRecord: @escaping () -> Void,
        onNewNote: (() -> Void)? = nil
    ) {
        self.text = text
        self.isRecordingActive = isRecordingActive
        self.amplitudeProvider = amplitude
        self.onRecord = onRecord
        self.onNewNote = onNewNote
    }

    @Environment(\.paperTheme) private var theme
    @State private var copied = false
    @State private var copyResetTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [theme.bg.opacity(0), theme.bg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            HStack(spacing: 12) {
                if let onNewNote {
                    newNoteButton(action: onNewNote)
                    divider
                }
                copyButton
                divider
                DotWave(active: isRecordingActive, amplitude: amplitudeProvider, count: 15, size: .sm)
                    .frame(width: 130)
                divider
                SmallRecordButton(active: isRecordingActive, action: onRecord)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(theme.panel))
            .overlay(Capsule().strokeBorder(theme.line, lineWidth: 1))
            .paperLargeShadow(theme)
            // Pin the pill to its intrinsic size so the Capsule background
            // can't be stretched by the surrounding ZStack. This is the
            // load-bearing fix for the giant-pill bug.
            .fixedSize(horizontal: true, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: 80, alignment: .bottom)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.line)
            .frame(width: 1, height: 18)
    }

    private var copyButton: some View {
        Button {
            copyToPasteboard()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.clear)
                Group {
                    if copied {
                        PaperIcon.Check(size: 14)
                    } else {
                        PaperIcon.Copy(size: 14)
                    }
                }
                .foregroundStyle(theme.inkSoft)
            }
            .frame(width: 34, height: 34)
            .contentShape(Circle())
        }
        .buttonStyle(GhostCircleButtonStyle(theme: theme))
        .help(copied ? "Copied" : "Copy")
        .accessibilityLabel(copied ? "Copied" : "Copy")
    }

    private func newNoteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                PaperIcon.Plus(size: 14)
                    .foregroundStyle(theme.inkSoft)
            }
            .frame(width: 34, height: 34)
            .contentShape(Circle())
        }
        .buttonStyle(GhostCircleButtonStyle(theme: theme))
        .help("New note")
        .accessibilityLabel("New note")
    }

    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copied = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000) // 1600ms
            if !Task.isCancelled { copied = false }
        }
    }
}

// Hover/press background for the round copy button.
private struct GhostCircleButtonStyle: ButtonStyle {
    let theme: PaperTheme
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill(configuration.isPressed ? theme.active : (hover ? theme.hover : Color.clear))
            configuration.label
        }
        .animation(.easeInOut(duration: 0.12), value: hover)
        .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
        .onHover { hover = $0 }
    }
}
