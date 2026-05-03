// Typography.swift
// Type scale ported from design_handoff_quiet_whisper/README.md "Type scale".
//
// Per the README's macOS guidance, we substitute system fonts:
//   serif → New York   (Font.system .serif)
//   ui    → SF Pro     (Font.system default)
//   mono  → SF Mono    (Font.system .monospaced)
// Fraunces / Inter / JetBrains Mono can be bundled later if a closer match
// is desired; New York reads very close to Fraunces at body sizes.

import SwiftUI

extension Font {
    // Reading (serif → New York)
    static var paperEditorTitle: Font     { .system(size: 34, weight: .regular, design: .serif) }
    static var paperEditorBody: Font      { .system(size: 18, weight: .regular, design: .serif) }
    static var paperHero: Font            { .system(size: 38, weight: .regular, design: .serif) }
    static var paperHeroSubhead: Font     { .system(size: 15, weight: .regular, design: .serif).italic() }
    static var paperRecordingSubhead: Font { .system(size: 18, weight: .regular, design: .serif).italic() }
    static var paperTranscribing: Font    { .system(size: 22, weight: .regular, design: .serif).italic() }
    static var paperSettingsTitle: Font   { .system(size: 22, weight: .regular, design: .serif) }
    static var paperToolbarTitle: Font    { .system(size: 14, weight: .regular, design: .serif).italic() }
    static var paperSidebarHeading: Font  { .system(size: 15, weight: .regular, design: .serif).italic() }
    static var paperSidebarEmpty: Font    { .system(size: 13, weight: .regular, design: .serif).italic() }
    static var paperSettingHint: Font     { .system(size: 12.5, weight: .regular, design: .serif).italic() }

    // UI (sans → SF Pro)
    static var paperSidebarItemTitle: Font       { .system(size: 13, weight: .medium, design: .default) }
    static var paperSettingsRowLabel: Font       { .system(size: 13, weight: .regular, design: .default) }
    static var paperSettingsRowLabelMedium: Font { .system(size: 13, weight: .medium, design: .default) }

    // Mono / micro (mono → SF Mono)
    static var paperMetaMono: Font          { .system(size: 10.5, weight: .regular, design: .monospaced) }
    static var paperGroupHeaderMono: Font   { .system(size: 10, weight: .medium, design: .monospaced) }
    static var paperEyebrowMono: Font       { .system(size: 11, weight: .regular, design: .monospaced) }
    static var paperRecordingTimer: Font    { .system(size: 22, weight: .regular, design: .monospaced).monospacedDigit() }
    static var paperKeyCap: Font            { .system(size: 11, weight: .regular, design: .monospaced) }
    static var paperRecommendedPill: Font   { .system(size: 9, weight: .regular, design: .monospaced) }
    static var paperReleaseHint: Font       { .system(size: 10.5, weight: .regular, design: .monospaced) }
    static var paperEyebrowSettings: Font   { .system(size: 10.5, weight: .medium, design: .monospaced) }
}
