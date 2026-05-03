import Foundation
import WhisperKit

private let log = QWLog.transcribe

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
        if loadedModel == model, whisperKit != nil {
            log.debug("transcribe: load(\(model.rawValue, privacy: .public)) — already loaded, skipping")
            return
        }

        guard let modelName = model.whisperKitModelName else {
            log.error("transcribe: load(\(model.rawValue, privacy: .public)) — no WhisperKit name registered for this model")
            throw TranscriberError.modelUnavailable
        }

        log.notice("transcribe: loading model \(modelName, privacy: .public)")
        let started = Date()
        do {
            // FIXME(whisperkit-api): WhisperKitConfig initializer label/options
            // may differ across 0.10.x versions; adjust if compilation fails.
            let config = WhisperKitConfig(model: modelName)
            let kit = try await WhisperKit(config)
            self.whisperKit = kit
            self.loadedModel = model
            log.notice("transcribe: loaded \(modelName, privacy: .public) in \(Date().timeIntervalSince(started), privacy: .public)s")
        } catch {
            log.error("transcribe: load \(modelName, privacy: .public) failed after \(Date().timeIntervalSince(started), privacy: .public)s: \(String(describing: error), privacy: .public)")
            throw TranscriberError.engineError(String(describing: error))
        }
    }

    func transcribe(_ wav: URL, autoPunct: Bool) async throws -> String {
        guard let kit = whisperKit else {
            log.error("transcribe: transcribe called before load — no kit available")
            throw TranscriberError.notLoaded
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: wav.path)[.size] as? Int) ?? -1
        log.notice("transcribe: starting on \(wav.path, privacy: .public) size=\(size, privacy: .public) bytes autoPunct=\(autoPunct, privacy: .public)")
        let started = Date()

        let raw: String
        do {
            // FIXME(whisperkit-api): newer WhisperKit returns
            // [TranscriptionResult]; older releases returned a single result
            // or had a different label. Adjust the call/return shape if the
            // installed version exposes a different API.
            let results = try await kit.transcribe(audioPath: wav.path)
            raw = results.map(\.text).joined(separator: " ")
            log.notice("transcribe: completed in \(Date().timeIntervalSince(started), privacy: .public)s, \(results.count, privacy: .public) segments, \(raw.count, privacy: .public) chars")
        } catch {
            log.error("transcribe: failed after \(Date().timeIntervalSince(started), privacy: .public)s: \(String(describing: error), privacy: .public)")
            throw TranscriberError.engineError(String(describing: error))
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            log.notice("transcribe: result is empty after trim — caller will surface as no-speech")
        }
        // Whisper occasionally emits control chars / RTL marks / zero-width
        // joiners that confuse text rendering downstream. Strip them up front
        // so the editor never has to deal with them.
        let sanitized = Self.sanitize(trimmed)
        if sanitized != trimmed {
            log.notice("transcribe: stripped \(trimmed.count - sanitized.count, privacy: .public) control/format chars from result")
        }

        if !autoPunct {
            let lowered = sanitized.lowercased()
            return lowered.trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:"))
        }
        return sanitized
    }

    /// Strip C0/C1 control codes (except newline + tab) and Unicode formatting
    /// chars that have no visible glyph but mess with text-layout passes.
    private static func sanitize(_ s: String) -> String {
        var bad = CharacterSet.controlCharacters
        bad.remove(charactersIn: "\n\t")
        bad.formUnion(CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{2028}\u{2029}\u{FEFF}"))
        return s.unicodeScalars.filter { !bad.contains($0) }.reduce(into: "") { $0.append(Character($1)) }
    }
}
