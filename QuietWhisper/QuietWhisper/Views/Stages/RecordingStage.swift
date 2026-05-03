// RecordingStage.swift
// Live recording view — pulsing eyebrow, "Take your time.", waveform,
// timer with muted decisecond, stop button, release-space hint.
// Ported from design_handoff_quiet_whisper/prototype/qw-app.jsx lines 337–386.

import SwiftUI

struct RecordingStage: View {
    let amplitude: Double
    let elapsed: TimeInterval
    let onStop: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            eyebrow
                .padding(.bottom, 14)

            Text("Take your time.")
                .font(.paperRecordingSubhead)
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 44)

            DotWave(active: true, amplitude: amplitude, size: .lg)

            Spacer().frame(height: 36)

            timer
                .padding(.bottom, 28)

            RecordButton(active: true, action: onStop)

            Spacer().frame(height: 24)

            Text("release space to stop")
                .font(.paperReleaseHint)
                .tracking(0.8)
                .foregroundStyle(theme.mute)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // Mono uppercase eyebrow with a 6pt dot pulsing 0.3↔0.9 / 1↔1.25 over 1.4s.
    private var eyebrow: some View {
        TimelineView(.animation) { context in
            // 1.4s ease-in-out infinite. Triangle phase → eased via cosine.
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * (.pi * 2 / 1.4) - .pi / 2) + 1) / 2  // 0..1 eased
            let opacity = 0.3 + phase * 0.6
            let scale = 1.0 + phase * 0.25

            HStack(spacing: 8) {
                Circle()
                    .fill(theme.ink)
                    .frame(width: 6, height: 6)
                    .opacity(opacity)
                    .scaleEffect(scale)
                Text("listening")
                    .font(.paperEyebrowMono)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.mute)
            }
        }
    }

    // MM:SS.t — minutes/seconds in ink, decisecond in mute. Tabular digits.
    private var timer: some View {
        let totalMs = Int(elapsed * 1000)
        let sec = totalMs / 1000
        let mm = String(format: "%02d", sec / 60)
        let ss = String(format: "%02d", sec % 60)
        let ds = (totalMs % 1000) / 100

        return HStack(spacing: 0) {
            Text("\(mm):\(ss)")
                .font(.paperRecordingTimer)
                .tracking(0.5)
                .foregroundStyle(theme.ink)
            Text(".\(ds)")
                .font(.paperRecordingTimer)
                .tracking(0.5)
                .foregroundStyle(theme.mute)
        }
        .monospacedDigit()
    }
}
