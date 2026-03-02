import Foundation
import CWhisper

// WhisperBridge is NOT Sendable — it must only be used from one thread at a time.
// The app uses Task.detached to call transcribe on a background thread,
// but ensures no concurrent access.
class WhisperBridge: @unchecked Sendable {
    static let shared = WhisperBridge()

    private var context: OpaquePointer? // whisper_context*

    var isModelLoaded: Bool { context != nil }

    func loadModel(path: String) throws {
        unloadModel()
        var cparams = whisper_context_default_params()
        cparams.use_gpu = true
        cparams.flash_attn = true
        context = whisper_init_from_file_with_params(path, cparams)
        guard context != nil else {
            throw WhisperError.modelLoadFailed
        }
    }

    func transcribe(samples: [Float]) -> String {
        guard let ctx = context else { return "" }
        guard !samples.isEmpty else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 2))
        params.no_context = true
        params.single_segment = false
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.translate = false

        let langStr = "en"
        let result = langStr.withCString { langPtr in
            params.language = UnsafePointer(langPtr)
            return samples.withUnsafeBufferPointer { bufferPtr in
                whisper_full(ctx, params, bufferPtr.baseAddress, Int32(samples.count))
            }
        }

        guard result == 0 else { return "" }

        var text = ""
        let nSegments = whisper_full_n_segments(ctx)
        for i in 0..<nSegments {
            if let cStr = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: cStr)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func unloadModel() {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
    }

}

enum WhisperError: LocalizedError {
    case modelLoadFailed

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed: return "Failed to load whisper model"
        }
    }
}
