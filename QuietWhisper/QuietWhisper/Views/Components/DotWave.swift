// DotWave.swift
// 21-dot soft pulsing waveform. Math ported verbatim from
// design_handoff_quiet_whisper/prototype/qw-wave.jsx (lines 38–52).
// Uses Canvas + TimelineView for a single-pass GPU draw.

import SwiftUI

enum WaveSize {
    case lg, md, sm

    // From qw-wave.jsx lines 31–35.
    var base: CGFloat   { switch self { case .lg: 3;   case .md: 2.5; case .sm: 2 } }
    var range: CGFloat  { switch self { case .lg: 8;   case .md: 6;   case .sm: 3.5 } }
    var gap: CGFloat    { switch self { case .lg: 10;  case .md: 8;   case .sm: 6 } }
    var height: CGFloat { switch self { case .lg: 56;  case .md: 40;  case .sm: 24 } }
}

struct DotWave: View {
    let active: Bool
    let amplitude: Double
    let count: Int
    let size: WaveSize

    @Environment(\.paperTheme) private var theme

    init(active: Bool, amplitude: Double = 0, count: Int = 21, size: WaveSize) {
        self.active = active
        self.amplitude = amplitude
        self.count = count
        self.size = size
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0, paused: false)) { context in
            let tick = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, canvasSize in
                let centerY = canvasSize.height / 2
                let totalWidth = CGFloat(count - 1) * size.gap
                let startX = (canvasSize.width - totalWidth) / 2
                let dotIdle = theme.dotIdle
                let dotActive = theme.dotActive

                for i in 0..<count {
                    let amp = amplitudeFor(i: i, tick: tick)
                    let s = size.base + CGFloat(amp) * size.range
                    let opacity = active ? (0.35 + amp * 0.6) : 0.7
                    let color = (active ? dotActive : dotIdle).opacity(opacity)
                    let x = startX + CGFloat(i) * size.gap
                    let rect = CGRect(x: x - s/2, y: centerY - s/2, width: s, height: s)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            .frame(height: size.height)
        }
    }

    /// Per-dot amplitude. Matches qw-wave.jsx exactly: idle uses a slow drift; active
    /// uses a centered bell envelope multiplied by a fast phase plus a higher-frequency jitter.
    private func amplitudeFor(i: Int, tick: TimeInterval) -> Double {
        if !active {
            let drift = (sin(tick * 0.6 + Double(i) * 0.4) + 1) * 0.04
            return 0.08 + drift
        }
        let amp = min(1.0, amplitude)
        let center = Double(count) / 2.0
        let d = abs(Double(i) - center) / center
        let env = 1 - d * d * 0.45
        let phase = sin(tick * 3.2 + Double(i) * 0.5) * 0.5 + 0.5
        let jitter = sin(tick * 5.1 + Double(i) * 1.7) * 0.15
        return max(0.12, min(1.0, amp * env * (0.55 + phase * 0.55) + jitter))
    }
}
