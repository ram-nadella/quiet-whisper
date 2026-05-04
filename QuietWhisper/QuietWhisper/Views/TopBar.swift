// TopBar.swift
// 44pt top bar — left padding clears the traffic lights when sidebar is closed.

import SwiftUI

struct TopBar: View {
    let sidebarOpen: Bool
    let dark: Bool
    let onToggleSidebar: () -> Void
    let onToggleDark: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            if !sidebarOpen {
                // Top-aligned to sit alongside the macOS traffic lights — when
                // centered in the 44pt bar the button reads as "floating" with
                // nothing to anchor it to. Matching the lights' y position
                // makes it feel like part of the window chrome.
                IconButton(action: onToggleSidebar) { PaperIcon.Sidebar() }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 4)
            }
            Spacer()
            IconButton(action: onToggleDark) {
                if dark { PaperIcon.Sun() } else { PaperIcon.Moon() }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 4)
            IconButton(action: onOpenSettings) { PaperIcon.Settings() }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
        }
        .padding(.leading, sidebarOpen ? 12 : 82)
        .padding(.trailing, 12)
        .frame(height: 44)
        .background(
            theme.bg
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.line).frame(height: 1)
                }
        )
        .overlay(alignment: .top) {
            // Centered italic title aligned to the top edge so it lines up
            // with the traffic lights and the toolbar buttons.
            Text("Quiet Whisper")
                .font(.paperToolbarTitle)
                .foregroundStyle(theme.mute)
                .tracking(0.3)
                .padding(.top, 10)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.26), value: sidebarOpen)
    }
}
