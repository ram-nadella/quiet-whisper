// SettingsModal.swift
// Full-overlay settings modal with blurred backdrop and animated card.
// Ported from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx (SettingsModal, lines 213–314).

import SwiftUI

struct SettingsModal: View {
    @Binding var model: WhisperModelKind
    @Binding var autoPunct: Bool
    @Binding var dark: Bool
    let onClose: () -> Void

    @Environment(\.paperTheme) private var theme
    @State private var didAppear = false
    @FocusState private var focused: Bool

    private var backdropColor: Color {
        theme.mode == .dark
            ? Color.black.opacity(0.5)
            : Color(hex: 0x1A1815, opacity: 0.25)
    }

    var body: some View {
        ZStack {
            // Backdrop — covers the whole window. Tap to close.
            backdropColor
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            // Modal card — width 480, capped at 90% of parent.
            modalCard
                .frame(maxWidth: 480)
                .padding(.horizontal, 16)
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 10)
        }
        .focusable()
        .focused($focused)
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .task {
            focused = true
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.2)) {
                didAppear = true
            }
        }
    }

    private var modalCard: some View {
        VStack(spacing: 0) {
            header
            body_
        }
        .frame(maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .paperLargeShadow(theme)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            // Stop click propagation to backdrop.
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Settings")
                .font(.paperSettingsTitle)
                .tracking(-0.2)
                .foregroundStyle(theme.ink)

            Spacer(minLength: 0)

            IconButton(action: onClose) {
                PaperIcon.Close()
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.lineSoft)
                .frame(height: 1)
        }
    }

    private var body_: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Transcription model
                SettingGroup(
                    label: "Transcription model",
                    hint: "All models run locally. Nothing leaves this device."
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(WhisperModelKind.allCases) { kind in
                            ModelRow(
                                model: kind,
                                isSelected: model == kind,
                                onSelect: { model = kind }
                            )
                        }
                    }
                }

                // 2. Language
                SettingGroup(label: "Language") {
                    SelectRow(
                        value: "English (US)",
                        hint: "More languages coming soon."
                    )
                }

                // 3. Transcription
                SettingGroup(label: "Transcription") {
                    ToggleRow(
                        label: "Auto-insert punctuation",
                        hint: "Adds commas, periods, and capitals from speech patterns.",
                        value: $autoPunct
                    )
                }

                // 4. Appearance
                SettingGroup(label: "Appearance", isLast: true) {
                    ToggleRow(
                        label: "Dark mode",
                        hint: "Inverted paper — warm near-black with ivory ink.",
                        value: $dark
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 440)
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}
