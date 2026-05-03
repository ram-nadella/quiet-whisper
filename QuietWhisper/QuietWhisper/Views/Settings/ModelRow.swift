// ModelRow.swift
// One row in the Transcription model picker. Custom radio dot + label + meta + optional pill.
// Ported from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx (ModelRow, lines 339–390).

import SwiftUI

struct ModelRow: View {
    let model: WhisperModelKind
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.paperTheme) private var theme
    @State private var hover = false

    private var isDisabled: Bool { !model.isAvailable }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Custom radio dot — 14×14 circle with inner 7×7 fill when selected.
            ZStack {
                Circle()
                    .stroke(isSelected ? theme.ink : theme.muteSoft, lineWidth: 1.25)
                    .frame(width: 14, height: 14)
                if isSelected {
                    Circle()
                        .fill(theme.ink)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    Text(model.displayName)
                        .font(.paperSettingsRowLabelMedium)
                        .foregroundStyle(theme.ink)

                    if model.isRecommended {
                        Text("Recommended".uppercased())
                            .font(.paperRecommendedPill)
                            .tracking(1)
                            .foregroundStyle(theme.mute)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(theme.line, lineWidth: 1)
                            )
                    }
                }

                Text(model.meta)
                    .font(.paperMetaMono)
                    .tracking(0.3)
                    .foregroundStyle(theme.mute)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? theme.line : Color.clear, lineWidth: 1)
        )
        .opacity(isDisabled ? 0.5 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { h in
            guard !isDisabled else { return }
            hover = h
        }
        .onTapGesture {
            guard !isDisabled else { return }
            onSelect()
        }
        .animation(.easeInOut(duration: 0.12), value: hover)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    private var rowBackground: Color {
        if isSelected { return theme.selected }
        if hover { return theme.hover }
        return Color.clear
    }
}
