// TranscribingStage.swift
// Brief interstitial — italic "Transcribing…" with a 3-dot cycling spinner.
// Ported from design_handoff_quiet_whisper/prototype/qw-app.jsx lines 391–427.

import SwiftUI

struct TranscribingStage: View {
    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text("Transcribing…")
                .font(.paperTranscribing)
                .foregroundStyle(theme.inkSoft)
                .padding(.bottom, 32)

            spinner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // Three 6pt ink dots, gap 10. Active index advances every 180ms.
    private var spinner: some View {
        TimelineView(.animation) { context in
            let tick = Int(context.date.timeIntervalSince1970 * (1000.0 / 180.0))
            let active = ((tick % 3) + 3) % 3

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(theme.ink)
                        .frame(width: 6, height: 6)
                        .opacity(i == active ? 0.9 : 0.25)
                }
            }
        }
    }
}
