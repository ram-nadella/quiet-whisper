import XCTest
@preconcurrency import AVFoundation
@testable import QuietWhisper

/// These tests pin down the threading contract of `AudioRecorder.handleInputBuffer`.
/// AVAudioEngine input taps fire on the audio render thread, never on the main
/// actor, so the tap callback must tolerate being called from any thread.
///
/// Before the fix, `handleInputBuffer` reached for `MainActor.assumeIsolated`
/// while reading its converter/outputFile references — a precondition trap that
/// killed the process the moment a buffer arrived. The "off main" tests below
/// would crash the runner pre-fix.
@MainActor
final class RecorderTests: XCTestCase {

    // MARK: - The crash repro

    func testTapCallbackDoesNotTrapWhenInvokedOffMain() async {
        let recorder = AudioRecorder()
        let buffer = Self.makeSilentBuffer(seconds: 0.05, sampleRate: 48_000)

        // Without the fix, the call below traps the test runner the instant it
        // hits `MainActor.assumeIsolated` from a non-main queue.
        let done = expectation(description: "tap returned without trapping")
        DispatchQueue.global(qos: .userInitiated).async {
            recorder.handleInputBuffer(buffer)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 1.0)
    }

    func testRapidOffMainTapsAreSerializedSafely() async {
        // Many buffers, many threads, no shared state corruption or crash.
        let recorder = AudioRecorder()
        let buffer = Self.makeSilentBuffer(seconds: 0.02, sampleRate: 48_000)

        let group = DispatchGroup()
        for _ in 0..<200 {
            group.enter()
            DispatchQueue.global().async {
                recorder.handleInputBuffer(buffer)
                group.leave()
            }
        }
        let done = expectation(description: "all taps returned")
        group.notify(queue: .main) { done.fulfill() }
        await fulfillment(of: [done], timeout: 5.0)
    }

    // MARK: - Happy path: the tap actually writes audio when configured

    func testTapWritesAudioToOutputFileFromOffMain() async throws {
        let recorder = AudioRecorder()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("qw-test-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        // Inject the audio-thread state directly so we don't need a microphone.
        try recorder.installTapStateForTesting(
            sourceFormat: AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!,
            outputURL: url
        )

        let buffer = Self.makeSineBuffer(
            seconds: 0.1,
            sampleRate: 48_000,
            frequency: 440
        )
        let done = expectation(description: "tap returned")
        DispatchQueue.global().async {
            recorder.handleInputBuffer(buffer)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 1.0)

        // Drain the file (write-on-dealloc) by tearing down the tap state.
        recorder.uninstallTapStateForTesting()

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 44, "WAV file should contain at least the header plus some samples")
    }

    func testStoppingClearsTapStateSoLateBuffersAreIgnored() async throws {
        let recorder = AudioRecorder()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("qw-test-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try recorder.installTapStateForTesting(
            sourceFormat: AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!,
            outputURL: url
        )
        recorder.uninstallTapStateForTesting()

        // A late buffer arriving after teardown should be a no-op, not a crash.
        let buffer = Self.makeSilentBuffer(seconds: 0.05, sampleRate: 48_000)
        let done = expectation(description: "late tap was ignored")
        DispatchQueue.global().async {
            recorder.handleInputBuffer(buffer)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 1.0)
    }

    // MARK: - Permission state plumbing

    func testInitialPermissionStateMirrorsSystem() {
        let recorder = AudioRecorder()
        // We don't know the host's permission, but the value must be one of the
        // documented cases — never silently invalid.
        XCTAssertTrue([.unknown, .granted, .denied].contains(recorder.permission))
    }

    func testStoppingWithoutStartingReturnsNil() async throws {
        let recorder = AudioRecorder()
        let url = try await recorder.stop()
        XCTAssertNil(url, "stop() before start() must be a safe no-op")
        XCTAssertFalse(recorder.isRecording)
    }

    // MARK: - Buffer fixtures

    private static func makeSilentBuffer(seconds: Double, sampleRate: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        // memset to silence is the AVAudioPCMBuffer default; no need to zero.
        return buf
    }

    private static func makeSineBuffer(seconds: Double, sampleRate: Double, frequency: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let twoPi = 2.0 * .pi
        let chans = buf.floatChannelData!
        for i in 0..<Int(frames) {
            chans[0][i] = Float(sin(Double(i) * twoPi * frequency / sampleRate)) * 0.3
        }
        return buf
    }
}
