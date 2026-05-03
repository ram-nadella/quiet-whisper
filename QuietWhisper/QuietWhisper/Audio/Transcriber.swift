import Foundation
import WhisperKit

enum TranscriberError: Error {
    case notLoaded
    case modelUnavailable
    case engineError(String)
}

@MainActor
final class WhisperTranscriber: TranscriberProtocol {
    private var whisperKit: WhisperKit?
    private var loadedModel: WhisperModelKind?

    func load(_ model: WhisperModelKind) async throws {
        if loadedModel == model, whisperKit != nil { return }

        guard let modelName = model.whisperKitModelName else {
            throw TranscriberError.modelUnavailable
        }

        do {
            // FIXME(whisperkit-api): WhisperKitConfig initializer label/options
            // may differ across 0.10.x versions; adjust if compilation fails.
            let config = WhisperKitConfig(model: modelName)
            let kit = try await WhisperKit(config)
            self.whisperKit = kit
            self.loadedModel = model
        } catch {
            throw TranscriberError.engineError(String(describing: error))
        }
    }

    func transcribe(_ wav: URL, autoPunct: Bool) async throws -> String {
        guard let kit = whisperKit else { throw TranscriberError.notLoaded }

        let raw: String
        do {
            // FIXME(whisperkit-api): newer WhisperKit returns
            // [TranscriptionResult]; older releases returned a single result
            // or had a different label. Adjust the call/return shape if the
            // installed version exposes a different API.
            let results = try await kit.transcribe(audioPath: wav.path)
            raw = results.map(\.text).joined(separator: " ")
        } catch {
            throw TranscriberError.engineError(String(describing: error))
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !autoPunct {
            let lowered = trimmed.lowercased()
            return lowered.trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:"))
        }
        return trimmed
    }
}
