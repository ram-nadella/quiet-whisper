import Foundation
@preconcurrency import AVFoundation
import Observation

private let log = QWLog.audio

enum RecorderError: Error {
    case permissionDenied
    case engineFailure
    case fileSetupFailed
}

@MainActor
@Observable
final class AudioRecorder: RecorderProtocol {
    private(set) var amplitude: Double = 0
    private(set) var isRecording: Bool = false
    private(set) var permission: MicPermission = .unknown
    /// Total audio buffers the tap has handed us during the current/last
    /// take. Used by the controller to detect the "engine started but
    /// nothing is flowing" failure mode (sandboxed audio quirks, muted
    /// device, plugged-in mic with denied access, etc.).
    private(set) var buffersReceived: Int = 0
    var onAmplitudeUpdate: (@MainActor (Double) -> Void)?

    private let engine = AVAudioEngine()
    private var outputURL: URL?

    /// State the audio render thread reaches for inside the tap callback.
    /// Reads/writes are serialized by `TapStateBox` so install/uninstall on
    /// the main actor can't tear it down mid-callback. We never reach back to
    /// the main actor from the tap synchronously — bouncing to `MainActor`
    /// from there is what crashed the original implementation
    /// (`MainActor.assumeIsolated` traps when invoked off the main actor).
    nonisolated private let tapState = TapStateBox()

    /// 16kHz mono Float32 — our internal "after-conversion" buffer format.
    nonisolated private let processingFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: 16_000,
                      channels: 1,
                      interleaved: false)!
    }()

    /// 16kHz mono int16 PCM — what we write to disk for Whisper.
    nonisolated private let fileFormatSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]

    init() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: permission = .granted
        case .denied, .restricted: permission = .denied
        case .notDetermined: permission = .unknown
        @unknown default: permission = .unknown
        }
        log.debug("recorder: init permission=\(String(describing: self.permission), privacy: .public)")
    }

    func requestPermission() async -> MicPermission {
        log.notice("recorder: requesting mic permission")
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        let result: MicPermission = granted ? .granted : .denied
        permission = result
        log.notice("recorder: mic permission \(granted ? "granted" : "denied", privacy: .public)")
        return result
    }

    func start() async throws {
        log.notice("recorder: start invoked, permission=\(String(describing: self.permission), privacy: .public)")
        if permission == .unknown {
            _ = await requestPermission()
        }
        guard permission == .granted else {
            log.error("recorder: start aborted — permission=\(String(describing: self.permission), privacy: .public)")
            throw RecorderError.permissionDenied
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        log.info("recorder: input format sampleRate=\(inputFormat.sampleRate, privacy: .public) channels=\(inputFormat.channelCount, privacy: .public) commonFormat=\(String(describing: inputFormat.commonFormat), privacy: .public)")

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            log.error("recorder: input node reports degenerate format (sr=\(inputFormat.sampleRate, privacy: .public), ch=\(inputFormat.channelCount, privacy: .public)) — engine cannot capture")
            throw RecorderError.engineFailure
        }

        guard let conv = AVAudioConverter(from: inputFormat, to: processingFormat) else {
            log.error("recorder: AVAudioConverter init failed for \(inputFormat, privacy: .public) → \(self.processingFormat, privacy: .public)")
            throw RecorderError.engineFailure
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        outputURL = url

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: url,
                                   settings: fileFormatSettings,
                                   commonFormat: .pcmFormatFloat32,
                                   interleaved: false)
        } catch {
            log.error("recorder: AVAudioFile creation failed at \(url.path, privacy: .public): \(String(describing: error), privacy: .public)")
            throw RecorderError.fileSetupFailed
        }
        log.debug("recorder: opened output WAV at \(url.path, privacy: .public)")

        installTapState(converter: conv, outputFile: file)
        buffersReceived = 0

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handleInputBuffer(buffer)
        }
        log.debug("recorder: tap installed on input bus 0")

        engine.prepare()
        do {
            try engine.start()
        } catch {
            log.error("recorder: engine.start failed: \(String(describing: error), privacy: .public)")
            input.removeTap(onBus: 0)
            uninstallTapState()
            throw RecorderError.engineFailure
        }
        log.notice("recorder: started — engine.isRunning=\(self.engine.isRunning, privacy: .public)")
        if !engine.isRunning {
            log.error("recorder: engine.start returned but isRunning is false — buffers will never arrive")
        }

        isRecording = true
    }

    func stop() async throws -> URL? {
        guard isRecording else {
            log.debug("recorder: stop called while not recording — no-op")
            return nil
        }
        if buffersReceived == 0 {
            log.error("recorder: stopping with 0 buffers received — engine started but never delivered audio")
        } else {
            log.notice("recorder: stop after \(self.buffersReceived, privacy: .public) buffers")
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // Drop the file reference under the lock so any tap callback already
        // mid-flight finishes against the live file, but the next one finds
        // nothing and returns. AVAudioFile flushes its trailing buffer on
        // dealloc, which happens here once the last strong reference drops.
        uninstallTapState()
        isRecording = false
        amplitude = 0

        let url = outputURL
        outputURL = nil
        if let url, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            log.debug("recorder: output WAV size=\(size, privacy: .public) bytes at \(url.path, privacy: .public)")
        }
        return url
    }

    // MARK: - Tap-state plumbing

    private func installTapState(converter: AVAudioConverter, outputFile: AVAudioFile) {
        tapState.set(converter: converter, outputFile: outputFile)
    }

    private func uninstallTapState() {
        tapState.clear()
    }

    // MARK: - Tap handling (off main thread)

    nonisolated func handleInputBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        let snapshot = tapState.snapshot()
        guard let converter = snapshot.converter, let outputFile = snapshot.outputFile else { return }

        let ratio = processingFormat.sampleRate / inputBuffer.format.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 16)

        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat,
                                               frameCapacity: max(targetCapacity, 1)) else {
            return
        }

        var supplied = false
        var convError: NSError?
        let status = converter.convert(to: outBuffer, error: &convError) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error, convError == nil, outBuffer.frameLength > 0 else { return }

        try? outputFile.write(from: outBuffer)

        guard let chans = outBuffer.floatChannelData else { return }
        let samples = chans[0]
        let n = Int(outBuffer.frameLength)
        var sumSq: Double = 0
        for i in 0..<n {
            let v = Double(samples[i])
            sumSq += v * v
        }
        let rms = (n > 0) ? (sumSq / Double(n)).squareRoot() : 0
        let boosted = min(1.0, rms * 4.5)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.amplitude += (boosted - self.amplitude) * 0.35
            self.buffersReceived &+= 1
            self.onAmplitudeUpdate?(self.amplitude)
        }
    }
}

/// Lock-protected box for the audio-tap-thread state. Lives outside the
/// MainActor-isolated `AudioRecorder` so the audio render thread can read
/// from it without crossing actors.
final class TapStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var outputFile: AVAudioFile?

    func set(converter: AVAudioConverter, outputFile: AVAudioFile) {
        lock.lock()
        self.converter = converter
        self.outputFile = outputFile
        lock.unlock()
    }

    func clear() {
        lock.lock()
        converter = nil
        outputFile = nil
        lock.unlock()
    }

    func snapshot() -> (converter: AVAudioConverter?, outputFile: AVAudioFile?) {
        lock.lock()
        defer { lock.unlock() }
        return (converter, outputFile)
    }
}

#if DEBUG
extension AudioRecorder {
    /// Test hook: install converter + output file without going through
    /// AVAudioEngine so unit tests can drive `handleInputBuffer` directly.
    func installTapStateForTesting(sourceFormat: AVAudioFormat, outputURL: URL) throws {
        guard let conv = AVAudioConverter(from: sourceFormat, to: processingFormat) else {
            throw RecorderError.engineFailure
        }
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: outputURL,
                                   settings: fileFormatSettings,
                                   commonFormat: .pcmFormatFloat32,
                                   interleaved: false)
        } catch {
            throw RecorderError.fileSetupFailed
        }
        installTapState(converter: conv, outputFile: file)
    }

    func uninstallTapStateForTesting() {
        uninstallTapState()
    }
}
#endif
