// SettingGroup.swift
// Vertical group with mono uppercase eyebrow + optional italic-serif hint + content rows.
// Ported from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx (SettingGroup, lines 316–337).

import SwiftUI

struct SettingGroup<Content: View>: View {
    let label: String
    let hint: String?
    let isLast: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.paperTheme) private var theme

    init(
        label: String,
        hint: String? = nil,
        isLast: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.hint = hint
        self.isLast = isLast
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.paperEyebrowSettings)
                .tracking(1.2)
                .foregroundStyle(theme.mute)
                .padding(.bottom, 8)

            if let hint {
                Text(hint)
                    .font(.paperSettingHint)
                    .foregroundStyle(theme.inkSoft)
                    .lineSpacing(12.5 * (1.45 - 1.0))
                    .padding(.bottom, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, isLast ? 0 : 22)
    }
}
