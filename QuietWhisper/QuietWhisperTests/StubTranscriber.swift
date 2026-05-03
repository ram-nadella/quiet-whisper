import Foundation
@testable import QuietWhisper

/// Test-side stub that lets us choose between "load + transcribe both succeed
/// with a canned string", "load throws", and "transcribe throws". Records every
/// call so tests can assert ordering.
@MainActor
final class StubTranscriber: TranscriberProtocol {
    enum Outcome {
        case ok(String)
        case loadThrows(Error)
        case transcribeThrows(Error)
    }

    enum Call: Equatable {
        case load(WhisperModelKind)
        case transcribe(URL, autoPunct: Bool)
    }

    var outcome: Outcome
    private(set) var calls: [Call] = []

    init(outcome: Outcome = .ok("hello world")) {
        self.outcome = outcome
    }

    func load(_ model: WhisperModelKind) async throws {
        calls.append(.load(model))
        if case .loadThrows(let err) = outcome { throw err }
    }

    func transcribe(_ wav: URL, autoPunct: Bool) async throws -> String {
        calls.append(.transcribe(wav, autoPunct: autoPunct))
        switch outcome {
        case .ok(let text): return text
        case .loadThrows: return ""
        case .transcribeThrows(let err): throw err
        }
    }
}

enum StubError: LocalizedError, Equatable {
    case canned(String)
    var errorDescription: String? {
        switch self { case .canned(let s): return s }
    }
}
