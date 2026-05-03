// DateGrouping.swift
// Pure helpers for sidebar date partitioning + meta formatting.
// Ported verbatim from design_handoff_quiet_whisper/prototype/qw-sidebar.jsx
// lines 4–34.

import Foundation

struct DatedSnippet {
    let id: UUID
    let title: String
    let createdAt: Date
    let durationSec: Int
}

enum DateGrouping {
    /// Partition `items` into Today / Yesterday / This week / Earlier groups,
    /// preserving the source order within each group. Empty groups are dropped,
    /// non-empty groups are returned in fixed order.
    static func group<T>(
        _ items: [T],
        by date: (T) -> Date,
        now: Date = Date()
    ) -> [(SidebarGroup, [T])] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = startOfToday.addingTimeInterval(-24 * 3600)
        let startOfWeek = startOfToday.addingTimeInterval(-7 * 24 * 3600)

        var today: [T] = []
        var yesterday: [T] = []
        var thisWeek: [T] = []
        var earlier: [T] = []

        for item in items {
            let d = date(item)
            if d >= startOfToday {
                today.append(item)
            } else if d >= startOfYesterday {
                yesterday.append(item)
            } else if d >= startOfWeek {
                thisWeek.append(item)
            } else {
                earlier.append(item)
            }
        }

        var result: [(SidebarGroup, [T])] = []
        if !today.isEmpty     { result.append((.today, today)) }
        if !yesterday.isEmpty { result.append((.yesterday, yesterday)) }
        if !thisWeek.isEmpty  { result.append((.thisWeek, thisWeek)) }
        if !earlier.isEmpty   { result.append((.earlier, earlier)) }
        return result
    }
}

/// "11:24 am" — 12-hour clock, lowercased am/pm to match the prototype.
func formatTime(_ date: Date) -> String {
    let calendar = Calendar.current
    let hour24 = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let ampm = hour24 >= 12 ? "pm" : "am"
    let h12 = (hour24 % 12 == 0) ? 12 : (hour24 % 12)
    return String(format: "%d:%02d %@", h12, minute, ampm)
}

/// "0:42" if >= 60s, "42s" otherwise. Mirrors `formatDuration` in the prototype.
func formatDuration(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)s"
}
