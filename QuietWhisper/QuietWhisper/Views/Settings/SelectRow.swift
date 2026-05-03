// SelectRow.swift
// Read-only select-style row used for Language. No tap handling.
// Ported from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx (SelectRow, lines 392–407).

import SwiftUI

struct SelectRow: View {
    let value: String
    let hint: String?

    @Environment(\.paperTheme) private var theme

    init(value: String, hint: String? = nil) {
        self.value = value
        self.hint = hint
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.paperSettingsRowLabel)
                    .foregroundStyle(theme.ink)
                if let hint {
                    Text(hint)
                        .font(.paperMetaMono)
                        .foregroundStyle(theme.mute)
                }
            }

            Spacer(minLength: 0)

            PaperIcon.Chevron(size: 12)
                .foregroundStyle(theme.inkSoft)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.panelSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.line, lineWidth: 1)
        )
    }
}
