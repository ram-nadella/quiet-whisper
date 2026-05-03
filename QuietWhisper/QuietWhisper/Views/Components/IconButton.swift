// IconButton.swift
// 28x28 ghost button with hover/press feedback.

import SwiftUI

struct IconButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @Environment(\.paperTheme) private var theme
    @State private var hover = false
    @State private var pressed = false

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(pressed ? theme.active : (hover ? theme.hover : Color.clear))
                label()
                    .foregroundStyle(theme.inkSoft)
            }
            .frame(width: 28, height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .animation(.easeInOut(duration: 0.12), value: hover)
            .animation(.easeInOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}
