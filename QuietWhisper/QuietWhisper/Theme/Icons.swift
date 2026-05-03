// Icons.swift
// Stroke icons in a 16x16 viewBox, ported verbatim from
// design_handoff_quiet_whisper/prototype/qw-tokens.jsx (lines 64–125).
// Round caps + joins, no fills. Color via .foregroundStyle (currentColor).

import SwiftUI

// MARK: - Style helpers

private struct StrokeStyleSpec {
    let lineWidth: CGFloat
    let lineCap: CGLineCap
    let lineJoin: CGLineJoin
}

private extension Path {
    /// Wrap a path with the given stroke spec into a view, scaled from a 16x16 source canvas.
    func strokedAsView(_ spec: StrokeStyleSpec, size: CGFloat) -> some View {
        GeometryReader { _ in
            self.stroke(style: StrokeStyle(
                lineWidth: spec.lineWidth,
                lineCap: spec.lineCap,
                lineJoin: spec.lineJoin
            ))
        }
        .frame(width: size, height: size)
    }
}

/// Apply uniform scale from a 16x16 source canvas to the rendered size.
private func scale(_ p: CGFloat, _ size: CGFloat) -> CGFloat { p * size / 16.0 }

// MARK: - PaperIcon namespace

enum PaperIcon {

    // Sidebar — rect 2,3 12x10 r2 + vertical line at x=6.5
    struct Sidebar: View {
        var size: CGFloat = 16
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                let rect = CGRect(x: 2*s, y: 3*s, width: 12*s, height: 10*s)
                let rounded = Path(roundedRect: rect, cornerRadius: 2*s)
                ctx.stroke(rounded, with: .color(.primary), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                var line = Path()
                line.move(to: CGPoint(x: 6.5*s, y: 3.5*s))
                line.addLine(to: CGPoint(x: 6.5*s, y: 12.5*s))
                ctx.stroke(line, with: .color(.primary), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Settings — proper 8-tooth gear, hollow hub
    struct Settings: View {
        var size: CGFloat = 16
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x*s, y: y*s) }
                var gear = Path()
                gear.move(to: P(8, 1.4))
                gear.addLine(to: P(9.05, 1.9))   // l 1.05 .5
                gear.addLine(to: P(9.6, 3.45))   // l .55 1.55
                gear.addLine(to: P(11.2, 3.75))  // l 1.6 .3
                gear.addLine(to: P(12.35, 2.6)) // l 1.15 -1.15
                gear.addLine(to: P(13.4, 3.65)) // l 1.05 1.05
                gear.addLine(to: P(12.25, 4.8)) // l -1.15 1.15
                gear.addLine(to: P(12.55, 6.4)) // l .3 1.6
                gear.addLine(to: P(14.1, 6.95)) // l 1.55 .55
                gear.addLine(to: P(14.6, 8))    // l .5 1.05
                gear.addLine(to: P(14.1, 9.05)) // l -.5 1.05
                gear.addLine(to: P(12.55, 9.6)) // l -1.55 .55
                gear.addLine(to: P(12.25, 11.2))// l -.3 1.6
                gear.addLine(to: P(13.4, 12.35))// l 1.15 1.15
                gear.addLine(to: P(12.35, 13.4))// l -1.05 1.05
                gear.addLine(to: P(11.2, 12.25))// l -1.15 -1.15
                gear.addLine(to: P(9.6, 12.55)) // l -1.6 .3
                gear.addLine(to: P(9.05, 14.1)) // l -.55 1.55
                gear.addLine(to: P(8, 14.6))    // L 8 14.6
                gear.addLine(to: P(6.95, 14.1)) // l -1.05 -.5
                gear.addLine(to: P(6.4, 12.55)) // l -.55 -1.55
                gear.addLine(to: P(4.8, 12.25)) // l -1.6 -.3
                gear.addLine(to: P(3.65, 13.4)) // l -1.15 1.15
                gear.addLine(to: P(2.6, 12.35)) // l -1.05 -1.05
                gear.addLine(to: P(3.75, 11.2)) // l 1.15 -1.15
                gear.addLine(to: P(3.45, 9.6))  // l -.3 -1.6
                gear.addLine(to: P(1.9, 9.05))  // L 1.9 9.05
                gear.addLine(to: P(1.4, 8))     // L 1.4 8
                gear.addLine(to: P(1.9, 6.95))  // l .5 -1.05
                gear.addLine(to: P(3.45, 6.4))  // l 1.55 -.55
                gear.addLine(to: P(3.75, 4.8))  // l .3 -1.6
                gear.addLine(to: P(2.6, 3.65))  // L 2.6 3.65
                gear.addLine(to: P(3.65, 2.6))  // l 1.05 -1.05
                gear.addLine(to: P(4.8, 3.75))  // L 4.8 3.75
                gear.addLine(to: P(6.4, 3.45))  // l 1.6 -.3
                gear.addLine(to: P(6.95, 1.9))  // l .55 -1.55
                gear.closeSubpath()
                ctx.stroke(gear, with: .color(.primary), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))

                let hub = Path(ellipseIn: CGRect(x: (8-2.1)*s, y: (8-2.1)*s, width: 4.2*s, height: 4.2*s))
                ctx.stroke(hub, with: .color(.primary), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Sun — circle r=3 + 8 short rays
    struct Sun: View {
        var size: CGFloat = 16
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                let circle = Path(ellipseIn: CGRect(x: 5*s, y: 5*s, width: 6*s, height: 6*s))
                ctx.stroke(circle, with: .color(.primary), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                // rays
                let rays: [(CGPoint, CGPoint)] = [
                    (CGPoint(x: 8, y: 1.5), CGPoint(x: 8, y: 3)),
                    (CGPoint(x: 8, y: 13),  CGPoint(x: 8, y: 14.5)),
                    (CGPoint(x: 14.5, y: 8), CGPoint(x: 13, y: 8)),
                    (CGPoint(x: 3, y: 8),   CGPoint(x: 1.5, y: 8)),
                    (CGPoint(x: 12.6, y: 3.4), CGPoint(x: 11.6, y: 4.4)),
                    (CGPoint(x: 4.4, y: 11.6), CGPoint(x: 3.4, y: 12.6)),
                    (CGPoint(x: 12.6, y: 12.6), CGPoint(x: 11.6, y: 11.6)),
                    (CGPoint(x: 4.4, y: 4.4), CGPoint(x: 3.4, y: 3.4)),
                ]
                var p = Path()
                for (a, b) in rays {
                    p.move(to: CGPoint(x: a.x*s, y: a.y*s))
                    p.addLine(to: CGPoint(x: b.x*s, y: b.y*s))
                }
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Moon — single arc-like path
    struct Moon: View {
        var size: CGFloat = 16
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                // Approximate the SVG arc with two cubic curves; faithful enough at icon scale.
                var p = Path()
                p.move(to: CGPoint(x: 13*s, y: 9.5*s))
                // First arc: A 5.5,5.5 0 0 1 6.5,3
                p.addArc(tangent1End: CGPoint(x: 6.5*s, y: 9.5*s),
                         tangent2End: CGPoint(x: 6.5*s, y: 3*s),
                         radius: 5.5*s)
                // c0-.5 .1-1 .2-1.5  → control point relative
                p.addLine(to: CGPoint(x: 6.7*s, y: 1.5*s))
                // A 6 6 0 1 0 14.5,9.3
                p.addArc(tangent1End: CGPoint(x: 14.5*s, y: 1.5*s),
                         tangent2End: CGPoint(x: 14.5*s, y: 9.3*s),
                         radius: 6*s)
                p.addLine(to: CGPoint(x: 13*s, y: 9.5*s))
                p.closeSubpath()
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Plus — vertical + horizontal stroke
    struct Plus: View {
        var size: CGFloat = 16
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                var p = Path()
                p.move(to: CGPoint(x: 8*s, y: 3*s)); p.addLine(to: CGPoint(x: 8*s, y: 13*s))
                p.move(to: CGPoint(x: 3*s, y: 8*s)); p.addLine(to: CGPoint(x: 13*s, y: 8*s))
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Trash
    struct Trash: View {
        var size: CGFloat = 14
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                var p = Path()
                // top bar: M3 4.5h10
                p.move(to: CGPoint(x: 3*s, y: 4.5*s)); p.addLine(to: CGPoint(x: 13*s, y: 4.5*s))
                // lid handle: M6.5 4.5V3 a1 1 0 0 1 1-1 h1 a1 1 0 0 1 1 1 V4.5
                p.move(to: CGPoint(x: 6.5*s, y: 4.5*s))
                p.addLine(to: CGPoint(x: 6.5*s, y: 3*s))
                p.addQuadCurve(to: CGPoint(x: 7.5*s, y: 2*s), control: CGPoint(x: 6.5*s, y: 2*s))
                p.addLine(to: CGPoint(x: 8.5*s, y: 2*s))
                p.addQuadCurve(to: CGPoint(x: 9.5*s, y: 3*s), control: CGPoint(x: 9.5*s, y: 2*s))
                p.addLine(to: CGPoint(x: 9.5*s, y: 4.5*s))
                // bin: M4.5 4.5l.5 8 a1 1 0 0 0 1 1 h4 a1 1 0 0 0 1-1 l.5-8
                p.move(to: CGPoint(x: 4.5*s, y: 4.5*s))
                p.addLine(to: CGPoint(x: 5*s, y: 12.5*s))
                p.addQuadCurve(to: CGPoint(x: 6*s, y: 13.5*s), control: CGPoint(x: 5*s, y: 13.5*s))
                p.addLine(to: CGPoint(x: 10*s, y: 13.5*s))
                p.addQuadCurve(to: CGPoint(x: 11*s, y: 12.5*s), control: CGPoint(x: 11*s, y: 13.5*s))
                p.addLine(to: CGPoint(x: 11.5*s, y: 4.5*s))
                // ribs: M7 7v4 M9 7v4
                p.move(to: CGPoint(x: 7*s, y: 7*s)); p.addLine(to: CGPoint(x: 7*s, y: 11*s))
                p.move(to: CGPoint(x: 9*s, y: 7*s)); p.addLine(to: CGPoint(x: 9*s, y: 11*s))
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Copy — front rect + back tab line
    struct Copy: View {
        var size: CGFloat = 14
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                let rect = CGRect(x: 5*s, y: 5*s, width: 8*s, height: 9*s)
                let rounded = Path(roundedRect: rect, cornerRadius: 1.5*s)
                ctx.stroke(rounded, with: .color(.primary), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                // M3 11 V3.5 A1.5 1.5 0 0 1 4.5 2 H10
                var p = Path()
                p.move(to: CGPoint(x: 3*s, y: 11*s))
                p.addLine(to: CGPoint(x: 3*s, y: 3.5*s))
                p.addQuadCurve(to: CGPoint(x: 4.5*s, y: 2*s), control: CGPoint(x: 3*s, y: 2*s))
                p.addLine(to: CGPoint(x: 10*s, y: 2*s))
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Close — X
    struct Close: View {
        var size: CGFloat = 14
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                var p = Path()
                p.move(to: CGPoint(x: 4*s, y: 4*s));  p.addLine(to: CGPoint(x: 12*s, y: 12*s))
                p.move(to: CGPoint(x: 12*s, y: 4*s)); p.addLine(to: CGPoint(x: 4*s,  y: 12*s))
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Check — M3.5 8.5l3 3 6-7
    struct Check: View {
        var size: CGFloat = 14
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                var p = Path()
                p.move(to: CGPoint(x: 3.5*s, y: 8.5*s))
                p.addLine(to: CGPoint(x: 6.5*s, y: 11.5*s))
                p.addLine(to: CGPoint(x: 12.5*s, y: 4.5*s))
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // Chevron — M4 6l4 4 4-4, rotated by `dir`
    enum ChevronDirection { case down, up, left, right
        var degrees: Double {
            switch self {
            case .down: 0; case .up: 180; case .left: 90; case .right: -90
            }
        }
    }
    struct Chevron: View {
        var size: CGFloat = 12
        var dir: ChevronDirection = .down
        var body: some View {
            Canvas { ctx, sz in
                let s = sz.width / 16.0
                var p = Path()
                p.move(to: CGPoint(x: 4*s, y: 6*s))
                p.addLine(to: CGPoint(x: 8*s, y: 10*s))
                p.addLine(to: CGPoint(x: 12*s, y: 6*s))
                ctx.stroke(p, with: .color(.primary), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(dir.degrees))
        }
    }
}
