// EmptyStage.swift
// First screen — quiet hero copy, idle dot wave, big record button.
// Ported from design_handoff_quiet_whisper/prototype/qw-app.jsx lines 290–319.

import SwiftUI

struct EmptyStage: View {
    let onRecord: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text("A quiet place to think out loud.")
                .font(.paperHero)
                .tracking(-0.8)
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
                .padding(.bottom, 14)

            // Subhead: italic serif with inline KeyCap. Use a wrapping HStack so the
            // cap sits inline; the surrounding text is split before/after.
            subhead
                .frame(maxWidth: 420)

            Spacer().frame(height: 56)

            DotWave(active: false, size: .lg)

            Spacer().frame(height: 40)

            RecordButton(active: false, action: onRecord)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // Italic serif paragraph with an inline KeyCap. SwiftUI's Text doesn't allow
    // arbitrary view embedding mid-string, so we lay out three pieces in an HStack
    // and let the Text on the right wrap to the second line if needed.
    private var subhead: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Press and hold")
                .font(.paperHeroSubhead)
                .foregroundStyle(theme.mute)
            KeyCap("space")
            Text(", or click the button. Take your time — there's no rush.")
                .font(.paperHeroSubhead)
                .foregroundStyle(theme.mute)
                .lineSpacing((1.55 - 1) * 15)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
