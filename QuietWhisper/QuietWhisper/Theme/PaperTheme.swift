// PaperTheme.swift
// Color tokens for light + dark "paper" themes. Ported verbatim from
// design_handoff_quiet_whisper/prototype/qw-tokens.jsx — same hex, same opacities.
// No pure black. No pure white.

import SwiftUI

struct PaperTheme: PaperThemeProtocol, Equatable {
    let mode: PaperMode

    let bg: Color
    let panel: Color
    let panelSoft: Color
    let sidebar: Color
    let ink: Color
    let inkSoft: Color
    let mute: Color
    let muteSoft: Color
    let line: Color
    let lineSoft: Color
    let hover: Color
    let active: Color
    let selected: Color
    let recordBg: Color
    let recordFg: Color
    let dotIdle: Color
    let dotActive: Color
    let danger: Color
    let shadowSmall: ShadowSpec
    let shadowLarge: ShadowSpec

    static let light = PaperTheme(
        mode: .light,
        bg:        Color(hex: 0xF6F4EF),
        panel:     Color(hex: 0xFFFFFF),
        panelSoft: Color(hex: 0xFAF8F3),
        sidebar:   Color(hex: 0xEFECE5),
        ink:       Color(hex: 0x1A1815),
        inkSoft:   Color(hex: 0x3A352D),
        mute:      Color(hex: 0x8A857B),
        muteSoft:  Color(hex: 0xB5B0A4),
        line:      Color(hex: 0x1A1815, opacity: 0.08),
        lineSoft:  Color(hex: 0x1A1815, opacity: 0.04),
        hover:     Color(hex: 0x1A1815, opacity: 0.04),
        active:    Color(hex: 0x1A1815, opacity: 0.08),
        selected:  Color(hex: 0x1A1815, opacity: 0.07),
        recordBg:  Color(hex: 0x1A1815),
        recordFg:  Color(hex: 0xF6F4EF),
        dotIdle:   Color(hex: 0x1A1815, opacity: 0.18),
        dotActive: Color(hex: 0x1A1815, opacity: 0.78),
        danger:    Color(hex: 0xA8443A),
        shadowSmall: ShadowSpec(color: Color(hex: 0x1A1815, opacity: 0.04),
                                radius: 1, x: 0, y: 1),
        shadowLarge: ShadowSpec(color: Color(hex: 0x1A1815, opacity: 0.06),
                                radius: 16, x: 0, y: 8)
    )

    static let dark = PaperTheme(
        mode: .dark,
        bg:        Color(hex: 0x17150F),
        panel:     Color(hex: 0x1E1B15),
        panelSoft: Color(hex: 0x1A1812),
        sidebar:   Color(hex: 0x141209),
        ink:       Color(hex: 0xF0EBE0),
        inkSoft:   Color(hex: 0xC9C3B6),
        mute:      Color(hex: 0x7A756B),
        muteSoft:  Color(hex: 0x5A554C),
        line:      Color(hex: 0xF0EBE0, opacity: 0.08),
        lineSoft:  Color(hex: 0xF0EBE0, opacity: 0.04),
        hover:     Color(hex: 0xF0EBE0, opacity: 0.04),
        active:    Color(hex: 0xF0EBE0, opacity: 0.08),
        selected:  Color(hex: 0xF0EBE0, opacity: 0.07),
        recordBg:  Color(hex: 0xF0EBE0),
        recordFg:  Color(hex: 0x17150F),
        dotIdle:   Color(hex: 0xF0EBE0, opacity: 0.18),
        dotActive: Color(hex: 0xF0EBE0, opacity: 0.82),
        danger:    Color(hex: 0xD87268),
        shadowSmall: ShadowSpec(color: Color.black.opacity(0.2),
                                radius: 1, x: 0, y: 1),
        shadowLarge: ShadowSpec(color: Color.black.opacity(0.4),
                                radius: 16, x: 0, y: 8)
    )

    static func of(mode: PaperMode) -> PaperTheme {
        mode == .dark ? .dark : .light
    }
}

// MARK: - Environment

private struct PaperThemeKey: EnvironmentKey {
    static let defaultValue: PaperTheme = .light
}

extension EnvironmentValues {
    var paperTheme: PaperTheme {
        get { self[PaperThemeKey.self] }
        set { self[PaperThemeKey.self] = newValue }
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Shadow modifier

extension View {
    func paperShadow(_ spec: ShadowSpec) -> some View {
        self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
    func paperLargeShadow(_ theme: PaperTheme) -> some View {
        self
            .shadow(color: theme.shadowSmall.color,
                    radius: theme.shadowSmall.radius,
                    x: theme.shadowSmall.x, y: theme.shadowSmall.y)
            .shadow(color: theme.shadowLarge.color,
                    radius: theme.shadowLarge.radius,
                    x: theme.shadowLarge.x, y: theme.shadowLarge.y)
    }
}
