// ToggleRow.swift
// Label + optional hint + PaperToggle. Whole row taps toggle the value.
// Ported from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx (ToggleRow, lines 409–426).

import SwiftUI

struct ToggleRow: View {
    let label: String
    let hint: String?
    @Binding var value: Bool

    @Environment(\.paperTheme) private var theme

    init(label: String, hint: String? = nil, value: Binding<Bool>) {
        self.label = label
        self.hint = hint
        self._value = value
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.paperSettingsRowLabel)
                    .foregroundStyle(theme.ink)
                if let hint {
                    Text(hint)
                        .font(.paperMetaMono)
                        .foregroundStyle(theme.mute)
                        .lineSpacing(10.5 * (1.4 - 1.0))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            PaperToggle(value: $value)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            value.toggle()
        }
    }
}
