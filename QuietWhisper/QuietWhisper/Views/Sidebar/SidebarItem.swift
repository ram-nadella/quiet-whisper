// SidebarItem.swift
// One snippet row in the sidebar. Ported from
// design_handoff_quiet_whisper/prototype/qw-sidebar.jsx lines 39–106.
// Two-click delete confirm: first click arms (red, 2s window),
// second click within window deletes, mouse-out resets.

import SwiftUI

struct SidebarItem: View {
    let title: String
    let createdAt: Date
    let durationSec: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @Environment(\.paperTheme) private var theme
    @State private var hover = false
    @State private var deleteState: DeleteState = .idle
    @State private var armTask: Task<Void, Never>?

    private enum DeleteState { case idle, armed }

    private var background: Color {
        if isSelected { return theme.selected }
        if hover      { return theme.hover }
        return Color.clear
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Row content (clickable area for select)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.paperSidebarItemTitle)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, hover ? 22 : 0)
                    .animation(.easeInOut(duration: 0.12), value: hover)

                HStack(spacing: 8) {
                    Text(formatTime(createdAt))
                    Text("·").opacity(0.5)
                    Text(formatDuration(durationSec))
                }
                .font(.paperMetaMono)
                .foregroundStyle(theme.mute)
                .tracking(0.4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            // Delete button — only visible on hover. Lives in ZStack so its
            // own tap handler beats the row's onTapGesture (no propagation).
            if hover {
                Button {
                    handleDeleteTap()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(deleteState == .armed ? theme.danger : Color.clear)
                        PaperIcon.Trash(size: 12)
                            .foregroundStyle(deleteState == .armed ? theme.recordFg : theme.mute)
                    }
                    .frame(width: 20, height: 20)
                    .contentShape(RoundedRectangle(cornerRadius: 4))
                    .animation(.easeInOut(duration: 0.12), value: deleteState)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
                .padding(.trailing, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6).fill(background)
        )
        .animation(.easeInOut(duration: 0.12), value: background)
        .padding(.bottom, 1) // 1pt gap between items
        .onHover { hovering in
            hover = hovering
            if !hovering {
                // mouse-out cancels any armed confirm
                armTask?.cancel()
                armTask = nil
                deleteState = .idle
            }
        }
    }

    private func handleDeleteTap() {
        switch deleteState {
        case .armed:
            armTask?.cancel()
            armTask = nil
            onDelete()
        case .idle:
            deleteState = .armed
            armTask?.cancel()
            armTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run { deleteState = .idle }
                }
            }
        }
    }
}
