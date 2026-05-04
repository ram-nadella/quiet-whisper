// RecordButton.swift
// Big round record button. Inner shape morphs circle ↔ rounded square
// when active. Halo + drop shadow. Ported from
// design_handoff_quiet_whisper/prototype/qw-wave.jsx lines 127–167.

import SwiftUI

struct RecordButton: View {
    let active: Bool
    let action: () -> Void
    var size: CGFloat = 72

    @Environment(\.paperTheme) private var theme
    @State private var hover = false

    var body: some View {
        let inner = active ? size * 0.28 : size * 0.32
        let isDark = theme.mode == .dark
        let baseShadow: Color = isDark ? Color.black.opacity(0.25) : Color(hex: 0x1A1815, opacity: 0.08)
        let hoverShadow: Color = isDark ? Color.black.opacity(0.30) : Color(hex: 0x1A1815, opacity: 0.12)
        let activeShadow: Color = isDark ? Color.black.opacity(0.40) : Color(hex: 0x1A1815, opacity: 0.15)

        Button(action: action) {
            ZStack {
                // Active halo: 8pt ring of dotIdle outside the button.
                if active {
                    Circle()
                        .stroke(theme.dotIdle, lineWidth: 8)
                        .frame(width: size + 8, height: size + 8)
                }
                Circle()
                    .fill(theme.recordBg)
                    .frame(width: size, height: size)

                Group {
                    if active {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.recordFg)
                    } else {
                        Circle()
                            .fill(theme.recordFg)
                    }
                }
                .frame(width: inner, height: inner)
                .animation(.easeInOut(duration: 0.18), value: active)
            }
            // Reserve halo room only when active. When inactive the outer
            // frame matches the visible circle so the button sits flush
            // inside parent layouts (e.g. the editor footer pill, which was
            // rendering a 16-pt gap on either side of the inactive button).
            .frame(width: active ? size + 16 : size, height: active ? size + 16 : size)
            .contentShape(Circle())
            .shadow(
                color: active ? activeShadow : (hover ? hoverShadow : baseShadow),
                radius: active ? 32 : (hover ? 20 : 12),
                x: 0,
                y: active ? 8 : (hover ? 4 : 2)
            )
            .animation(.easeInOut(duration: 0.22), value: hover)
            .animation(.easeInOut(duration: 0.22), value: active)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(active ? "Stop recording" : "Start recording")
    }
}

struct SmallRecordButton: View {
    let active: Bool
    let action: () -> Void
    var body: some View {
        RecordButton(active: active, action: action, size: 44)
    }
}
