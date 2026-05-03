import XCTest
@testable import QuietWhisper

@MainActor
final class RecordingControllerTests: XCTestCase {

    // MARK: - Happy path

    func testFullRoundTripIdleRecordingTranscribingIdle() async throws {
        let recorder = TestRecorder()
        let transcriber = StubTranscriber(outcome: .ok("Hello there"))
        let controller = RecordingController(recorder: recorder, transcriber: transcriber)

        var takes: [TakeResult] = []
        controller.onTakeCompleted = { takes.append($0) }

        XCTAssertEqual(controller.state, .idle)

        await controller.start()
        if case .recording = controller.state {} else {
            return XCTFail("expected .recording, got \(controller.state)")
        }
        XCTAssertTrue(recorder.isRecording)

        await controller.stop(model: .small, autoPunct: true)

        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(takes.count, 1)
        XCTAssertEqual(takes.first?.text, "Hello there")
        XCTAssertNil(takes.first?.transcriberError)
        XCTAssertEqual(transcriber.calls.first, .load(.small))
    }

    // MARK: - Amplitude mirroring

    func testControllerMirrorsAmplitudeFromRecorderViaCallback() async throws {
        // The view layer reads `controller.amplitude`, not
        // `controller.recorder.amplitude` — protocol-typed reads don't trigger
        // SwiftUI re-renders. This pins the wiring: every recorder push
        // becomes a controller update.
        let recorder = TestRecorder()
        let controller = RecordingController(recorder: recorder, transcriber: StubTranscriber())

        XCTAssertEqual(controller.amplitude, 0)

        recorder.emitAmplitude(0.42)
        XCTAssertEqual(controller.amplitude, 0.42, accuracy: 0.0001)

        recorder.emitAmplitude(0.93)
        XCTAssertEqual(controller.amplitude, 0.93, accuracy: 0.0001)
    }

    func testAmplitudeResetsOnStartAndStop() async {
        let recorder = TestRecorder()
        let controller = RecordingController(recorder: recorder, transcriber: StubTranscriber())

        recorder.emitAmplitude(0.7)
        XCTAssertEqual(controller.amplitude, 0.7, accuracy: 0.0001)

        await controller.start()
        XCTAssertEqual(controller.amplitude, 0, "start clears stale amplitude")

        recorder.emitAmplitude(0.5)
        await controller.stop(model: .small, autoPunct: true)
        XCTAssertEqual(controller.amplitude, 0, "stop clears live amplitude")
    }

    // MARK: - Permission denial

    func testStartFlipsPermissionDeniedWhenRecorderRefuses() async {
        let recorder = AlwaysDenyingRecorder()
        let controller = RecordingController(recorder: recorder, transcriber: StubTranscriber())

        await controller.start()

        XCTAssertEqual(controller.state, .idle)
        XCTAssertTrue(controller.permissionDenied)
    }

    func testGrantedRecorderProducesCleanRecordingState() async {
        let recorder = PreviewRecorder()
        let controller = RecordingController(recorder: recorder, transcriber: StubTranscriber())
        await controller.start()
        XCTAssertFalse(controller.permissionDenied)
        if case .recording = controller.state {} else {
            XCTFail("expected .recording, got \(controller.state)")
        }
    }

    // MARK: - Error surfacing

    func testTranscribeFailureSurfacesErrorWithoutCrashing() async {
        let recorder = TestRecorder()
        let err = StubError.canned("model file missing")
        let transcriber = StubTranscriber(outcome: .transcribeThrows(err))
        let controller = RecordingController(recorder: recorder, transcriber: transcriber)

        var takes: [TakeResult] = []
        controller.onTakeCompleted = { takes.append($0) }

        await controller.start()
        await controller.stop(model: .small, autoPunct: true)

        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(takes.count, 1)
        XCTAssertEqual(takes.first?.text, "")
        XCTAssertEqual(takes.first?.transcriberError, "model file missing")
    }

    func testLoadFailureStillStopsTheRecorderAndSurfacesError() async {
        let recorder = TestRecorder()
        let err = StubError.canned("download failed")
        let transcriber = StubTranscriber(outcome: .loadThrows(err))
        let controller = RecordingController(recorder: recorder, transcriber: transcriber)

        var takes: [TakeResult] = []
        controller.onTakeCompleted = { takes.append($0) }

        await controller.start()
        await controller.stop(model: .small, autoPunct: true)

        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(takes.first?.transcriberError, "download failed")
    }

    func testNoBuffersReceivedSurfacesAsTranscriberErrorAndSkipsWhisperKit() async {
        // SilentRecorder mimics the real-world sandbox-blocked case: start
        // succeeds, the user sees the recording UI, the user releases — but
        // no audio data ever flows. We must not waste a transcription pass
        // on an empty WAV; we must surface a clear, actionable error.
        let recorder = SilentRecorder()
        let transcriber = StubTranscriber(outcome: .ok("should never be returned"))
        let controller = RecordingController(recorder: recorder, transcriber: transcriber)

        var takes: [TakeResult] = []
        controller.onTakeCompleted = { takes.append($0) }

        await controller.start()
        await controller.stop(model: .small, autoPunct: true)

        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(takes.count, 1)
        XCTAssertEqual(takes.first?.text, "")
        let err = takes.first?.transcriberError ?? ""
        XCTAssertTrue(err.contains("no audio reached"), "expected the no-audio diagnostic, got: \(err)")
        XCTAssertTrue(transcriber.calls.isEmpty, "no buffers means we shouldn't even call WhisperKit")
    }

    func testEngineFailureSurfacesStartErrorWithoutFlippingPermissionDenied() async {
        let recorder = AlwaysFailingRecorder()
        let controller = RecordingController(recorder: recorder, transcriber: StubTranscriber())

        await controller.start()

        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(controller.permissionDenied, "engine failures must not be misreported as permission denials")
        XCTAssertNotNil(controller.startError)
        XCTAssertTrue(controller.startError!.contains("Couldn't start"))

        controller.clearStartError()
        XCTAssertNil(controller.startError)
    }

    // MARK: - State machine guards

    func testStopWithoutRecordingIsANoOp() async {
        let controller = RecordingController(recorder: PreviewRecorder(), transcriber: StubTranscriber())
        await controller.stop(model: .small, autoPunct: true)
        XCTAssertEqual(controller.state, .idle)
    }

    func testToggleDuringTranscribingIsIgnored() async {
        let recorder = TestRecorder()
        let transcriber = SlowStubTranscriber(text: "later")
        let controller = RecordingController(recorder: recorder, transcriber: transcriber)

        var takes: [TakeResult] = []
        controller.onTakeCompleted = { takes.append($0) }

        await controller.start()
        let stopTask = Task { await controller.stop(model: .small, autoPunct: true) }
        // While the stub is sleeping inside `transcribe`, toggle should no-op.
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(controller.state, .transcribing)
        controller.toggle(model: .small, autoPunct: true)
        XCTAssertEqual(controller.state, .transcribing)

        await stopTask.value
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(takes.count, 1)
    }

    // MARK: - Duration rounding

    func testDurationIsAtLeastOneSecond() async {
        let recorder = TestRecorder()
        let controller = RecordingController(recorder: recorder, transcriber: StubTranscriber())
        var takes: [TakeResult] = []
        controller.onTakeCompleted = { takes.append($0) }

        await controller.start()
        // Synthetic instant stop — the rounded duration would be 0 without the floor.
        await controller.stop(model: .small, autoPunct: true)
        XCTAssertGreaterThanOrEqual(takes.first?.durationSec ?? 0, 1)
    }
}

// MARK: - Test fixtures

@MainActor
@Observable
final class AlwaysDenyingRecorder: RecorderProtocol {
    private(set) var amplitude: Double = 0
    private(set) var isRecording: Bool = false
    private(set) var permission: MicPermission = .denied
    private(set) var buffersReceived: Int = 0
    var onAmplitudeUpdate: (@MainActor (Double) -> Void)?

    func requestPermission() async -> MicPermission { .denied }
    func start() async throws { throw RecorderError.permissionDenied }
    func stop() async throws -> URL? { nil }
}

@MainActor
@Observable
final class AlwaysFailingRecorder: RecorderProtocol {
    private(set) var amplitude: Double = 0
    private(set) var isRecording: Bool = false
    private(set) var permission: MicPermission = .granted
    private(set) var buffersReceived: Int = 0
    var onAmplitudeUpdate: (@MainActor (Double) -> Void)?

    func requestPermission() async -> MicPermission { .granted }
    func start() async throws { throw RecorderError.engineFailure }
    func stop() async throws -> URL? { nil }
}

/// Mimics the macOS sandbox-blocked case: `start()` succeeds, `isRecording`
/// flips, but no audio buffers ever arrive.
@MainActor
@Observable
final class SilentRecorder: RecorderProtocol {
    private(set) var amplitude: Double = 0
    private(set) var isRecording: Bool = false
    private(set) var permission: MicPermission = .granted
    private(set) var buffersReceived: Int = 0
    var onAmplitudeUpdate: (@MainActor (Double) -> Void)?

    func requestPermission() async -> MicPermission { .granted }
    func start() async throws { isRecording = true }
    func stop() async throws -> URL? {
        isRecording = false
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("qw-silent-\(UUID().uuidString).wav")
        try? Data().write(to: url)
        return url
    }
}

/// In-memory recorder that mirrors the real recorder's contract: granted
/// permission, transitions in/out of `isRecording`, and synthesizes a real
/// temp WAV path on stop so the transcriber path actually runs.
@MainActor
@Observable
final class TestRecorder: RecorderProtocol {
    private(set) var amplitude: Double = 0
    private(set) var isRecording: Bool = false
    private(set) var permission: MicPermission = .granted
    /// Default to a non-zero count so happy-path controller tests don't trip
    /// the no-buffers guard. Use `SilentRecorder` to exercise that path.
    var buffersReceived: Int = 1
    var onAmplitudeUpdate: (@MainActor (Double) -> Void)?

    var producedURLs: [URL] = []

    func requestPermission() async -> MicPermission { .granted }

    func start() async throws { isRecording = true }

    func stop() async throws -> URL? {
        isRecording = false
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("qw-ctrl-test-\(UUID().uuidString).wav")
        try? Data().write(to: url)
        producedURLs.append(url)
        return url
    }

    /// Test hook: simulate a buffer arrival by pushing an amplitude update
    /// through the controller's wired-up callback.
    func emitAmplitude(_ value: Double) {
        amplitude = value
        buffersReceived &+= 1
        onAmplitudeUpdate?(value)
    }
}

@MainActor
@Observable
final class SlowStubTranscriber: TranscriberProtocol {
    let text: String
    init(text: String) { self.text = text }
    func load(_ model: WhisperModelKind) async throws {}
    func transcribe(_ wav: URL, autoPunct: Bool) async throws -> String {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return text
    }
}
