import Foundation
import SwiftData

@Model
final class Snippet {
    @Attribute(.unique) var id: UUID
    var title: String
    var text: String
    var createdAt: Date
    var durationSec: Int

    init(id: UUID = UUID(), title: String, text: String, createdAt: Date = Date(), durationSec: Int) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.durationSec = durationSec
    }
}

extension Snippet {
    static func makeTitle(from text: String) -> String {
        let firstSentence = text.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? text
        return String(firstSentence.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty("Untitled")
    }

    /// Append the result of a follow-up take to this snippet. Inserts a blank
    /// line as a separator (so dictated paragraphs are visually distinct),
    /// extends `durationSec`, and refreshes the auto-title only if the user
    /// hadn't customized it. Returns true if anything was actually appended.
    @discardableResult
    func append(transcribedText newText: String, durationSec extraDuration: Int) -> Bool {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let priorText = self.text
        let separator = priorText.isEmpty ? "" : "\n\n"
        self.text = priorText + separator + trimmed

        let priorAutoTitle = Snippet.makeTitle(from: priorText)
        if self.title == priorAutoTitle || self.title.isEmpty || self.title == "Untitled" {
            self.title = Snippet.makeTitle(from: self.text)
        }
        self.durationSec += extraDuration
        return true
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
