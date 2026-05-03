// PaperToggle.swift
// 32×19pt capsule toggle. Off: muteSoft background, On: ink background.
// 15×15pt thumb slides 13pt over 180ms cubic-bezier(.4,0,.2,1).
// Ported from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx (Toggle, lines 428–445).

import SwiftUI

struct PaperToggle: View {
    @Binding var value: Bool

    @Environment(\.paperTheme) private var theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(value ? theme.ink : theme.muteSoft)
                .frame(width: 32, height: 19)
                .animation(.easeInOut(duration: 0.18), value: value)

            Circle()
                .fill(theme.panel)
                .frame(width: 15, height: 15)
                .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                .offset(x: value ? 15 : 2, y: 2)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.18), value: value)
        }
        .frame(width: 32, height: 19)
        .contentShape(Capsule())
        .onTapGesture {
            value.toggle()
        }
    }
}
