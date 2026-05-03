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
                IconButton(action: onToggleSidebar) { PaperIcon.Sidebar() }
            }
            Spacer()
            IconButton(action: onToggleDark) {
                if dark { PaperIcon.Sun() } else { PaperIcon.Moon() }
            }
            IconButton(action: onOpenSettings) { PaperIcon.Settings() }
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
        .overlay(
            // Centered italic title — pointer-events none.
            Text("Quiet Whisper")
                .font(.paperToolbarTitle)
                .foregroundStyle(theme.mute)
                .tracking(0.3)
                .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: 0.26), value: sidebarOpen)
    }
}
