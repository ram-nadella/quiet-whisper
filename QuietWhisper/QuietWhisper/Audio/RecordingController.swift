import Foundation
import Observation

private let log = QWLog.state

/// Plain-data result of a completed take. The view layer wraps this in a
/// `Snippet` and inserts into the model context — keeping the controller free
/// of SwiftData lets us test the state machine without spinning up a
/// `ModelContainer`.
struct TakeResult: Equatable {
    var text: String
    var durationSec: Int
    var transcriberError: String?
}

/// State machine for the record → transcribe loop. Owns the recorder and
/// transcriber and exposes a single `toggle(...)` entry point that mirrors
/// what `ContentView` was doing inline. Tests drive this directly with
/// `PreviewRecorder` and a stub transcriber.
@MainActor
@Observable
final class RecordingController {
    private(set) var state: RecordingState = .idle
    private(set) var permissionDenied: Bool = false
    /// Mirrored from the recorder via push callback so the SwiftUI view layer
    /// can observe a stored property on a known concrete type. Reading
    /// `recorder.amplitude` directly through `any RecorderProtocol` doesn't
    /// reliably trigger SwiftUI re-renders even though the protocol inherits
    /// from `Observable`.
    private(set) var amplitude: Double = 0
    /// Non-nil when the recorder failed to start for a reason other than
    /// permission (e.g. AVAudioEngine couldn't start, the temp file couldn't
    /// be opened). The view should surface this so the user knows why the
    /// big record button did nothing.
    private(set) var startError: String?

    let recorder: any RecorderProtocol
    let transcriber: any TranscriberProtocol

    /// Called on the main actor with the result of every completed take.
    var onTakeCompleted: (@MainActor (TakeResult) -> Void)?

    init(recorder: any RecorderProtocol, transcriber: any TranscriberProtocol) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.recorder.onAmplitudeUpdate = { [weak self] amp in
            self?.amplitude = amp
        }
    }

    func toggle(model: WhisperModelKind, autoPunct: Bool) {
        log.debug("controller: toggle from state=\(String(describing: self.state), privacy: .public)")
        switch state {
        case .idle:
            Task { await start() }
        case .recording:
            Task { await stop(model: model, autoPunct: autoPunct) }
        case .transcribing:
            // Releasing the button while we're already transcribing is a
            // double-fire — usually a click landing right after a hold-space
            // release. Drop it on the floor; the transcriber owns the lifecycle.
            log.notice("controller: toggle ignored — already transcribing")
            return
        }
    }

    func start() async {
        log.notice("controller: start invoked — recorder.permission=\(String(describing: self.recorder.permission), privacy: .public)")
        let perm = recorder.permission == .unknown
            ? await recorder.requestPermission()
            : recorder.permission
        guard perm == .granted else {
            log.error("controller: start aborted — permission=\(String(describing: perm), privacy: .public)")
            permissionDenied = true
            return
        }
        permissionDenied = false
        startError = nil
        do {
            try await recorder.start()
            amplitude = 0
            state = .recording(startedAt: Date())
            log.notice("controller: state → recording")
        } catch RecorderError.permissionDenied {
            log.error("controller: recorder.start threw permissionDenied")
            permissionDenied = true
            state = .idle
        } catch {
            log.error("controller: recorder.start threw \(String(describing: error), privacy: .public) — surfacing as startError")
            startError = "Couldn't start the microphone. \(error.localizedDescription)"
            state = .idle
        }
    }

    func clearStartError() {
        log.debug("controller: startError cleared by user")
        startError = nil
    }

    func stop(model: WhisperModelKind, autoPunct: Bool) async {
        guard case .recording(let started) = state else {
            log.debug("controller: stop ignored — not in .recording state")
            return
        }
        let durationSec = max(1, Int(Date().timeIntervalSince(started).rounded()))
        let buffersAtStop = recorder.buffersReceived
        state = .transcribing
        amplitude = 0
        log.notice("controller: state → transcribing (durationSec=\(durationSec, privacy: .public), buffers=\(buffersAtStop, privacy: .public))")

        let wavURL: URL?
        do { wavURL = try await recorder.stop() } catch {
            log.error("controller: recorder.stop threw \(String(describing: error), privacy: .public)")
            wavURL = nil
        }

        var result = TakeResult(text: "", durationSec: durationSec, transcriberError: nil)

        // Detect "engine started but no buffers ever arrived". Skip the
        // pointless transcribe pass and surface a useful error. Sandbox
        // blocks on macOS land here — the audio engine accepts our setup
        // but no data flows from the input device.
        if buffersAtStop == 0 {
            log.error("controller: take had 0 buffers — skipping transcribe, surfacing no-audio error")
            result.transcriberError = "Microphone is open but no audio reached the app. Check System Settings → Privacy & Security → Microphone, or try a different input device."
            if let wavURL { try? FileManager.default.removeItem(at: wavURL) }
            onTakeCompleted?(result)
            state = .idle
            log.notice("controller: state → idle (no-audio take)")
            return
        }

        if let wavURL {
            do {
                try await transcriber.load(model)
                result.text = try await transcriber.transcribe(wavURL, autoPunct: autoPunct)
                log.notice("controller: transcribe succeeded — \(result.text.count, privacy: .public) chars")
            } catch {
                log.error("controller: transcribe failed — \(String(describing: error), privacy: .public)")
                result.transcriberError = error.localizedDescription
                result.text = ""
            }
            try? FileManager.default.removeItem(at: wavURL)
        } else {
            log.error("controller: no wav URL after recorder.stop — treating as failed take")
        }

        onTakeCompleted?(result)
        state = .idle
        log.notice("controller: state → idle")
    }

}
