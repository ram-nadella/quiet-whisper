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
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
