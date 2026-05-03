// SidebarView.swift
// 260pt sidebar — heading, new/close buttons, scrollable grouped history list.
// Ported from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx lines 111–182.
// Purely presentational: parent passes snippets in; no @Query here.

import SwiftUI

struct SidebarView: View {
    let snippets: [Snippet]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onNew: () -> Void
    let onClose: () -> Void

    @Environment(\.paperTheme) private var theme

    private var groups: [(SidebarGroup, [Snippet])] {
        DateGrouping.group(snippets, by: { $0.createdAt })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top region — leaves room for traffic lights on the left.
            HStack(spacing: 0) {
                Text("Notes")
                    .font(.paperSidebarHeading)
                    .foregroundStyle(theme.ink)
                    .tracking(0.1)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    IconButton(action: onNew) { PaperIcon.Plus() }
                    IconButton(action: onClose) { PaperIcon.Sidebar() }
                }
            }
            .padding(.leading, 82)
            .padding(.trailing, 12)
            .frame(height: 44)

            // Scrollable list
            ScrollView {
                if groups.isEmpty {
                    VStack(spacing: 0) {
                        Text("Nothing here yet.\nPress the button to start.")
                            .font(.paperSidebarEmpty)
                            .foregroundStyle(theme.mute)
                            .multilineTextAlignment(.center)
                            .lineSpacing(13 * 0.5) // line-height 1.5 over 13pt
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 14)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groups, id: \.0) { group, items in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.rawValue.uppercased())
                                    .font(.paperGroupHeaderMono)
                                    .foregroundStyle(theme.mute)
                                    .tracking(1.2)
                                    .padding(.top, 10)
                                    .padding(.leading, 14)
                                    .padding(.bottom, 6)

                                ForEach(items, id: \.id) { snippet in
                                    SidebarItem(
                                        title: snippet.title,
                                        createdAt: snippet.createdAt,
                                        durationSec: snippet.durationSec,
                                        isSelected: snippet.id == selectedID,
                                        onSelect: { onSelect(snippet.id) },
                                        onDelete: { onDelete(snippet.id) }
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(theme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.line)
                .frame(width: 1)
        }
    }
}
