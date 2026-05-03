// KeyCap.swift
// Inline kbd-style label.

import SwiftUI

struct KeyCap: View {
    let text: String

    @Environment(\.paperTheme) private var theme

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.paperKeyCap)
            .foregroundStyle(theme.inkSoft)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4).fill(theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.line, lineWidth: 1)
            )
    }
}
