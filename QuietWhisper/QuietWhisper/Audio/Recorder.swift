import Foundation
import AVFoundation
import Observation

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

    // AVFoundation plumbing — only touched on MainActor or inside the tap
    // callback (which is on a real-time audio thread).
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var outputFile: AVAudioFile?
    private var outputURL: URL?

    /// 16kHz mono Float32 — our internal "after-conversion" buffer format.
    private let processingFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: 16_000,
                      channels: 1,
                      interleaved: false)!
    }()

    /// 16kHz mono int16 PCM — what we write to disk for Whisper.
    private let fileFormatSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]

    init() {
        // Initial permission state from the system, so UI doesn't have to wait
        // for requestPermission() to render the right prompt.
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: permission = .granted
        case .denied, .restricted: permission = .denied
        case .notDetermined: permission = .unknown
        @unknown default: permission = .unknown
        }
    }

    func requestPermission() async -> MicPermission {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        let result: MicPermission = granted ? .granted : .denied
        permission = result
        return result
    }

    func start() async throws {
        if permission == .unknown {
            _ = await requestPermission()
        }
        guard permission == .granted else {
            throw RecorderError.permissionDenied
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        // macOS doesn't auto-resample input, so we capture at the device's
        // native format and then convert each tapped buffer to 16kHz mono.
        guard let conv = AVAudioConverter(from: inputFormat, to: processingFormat) else {
            throw RecorderError.engineFailure
        }
        converter = conv

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        outputURL = url

        do {
            outputFile = try AVAudioFile(forWriting: url,
                                         settings: fileFormatSettings,
                                         commonFormat: .pcmFormatFloat32,
                                         interleaved: false)
        } catch {
            throw RecorderError.fileSetupFailed
        }

        // Tap on the inputNode's native format. The tap fires off the main
        // thread; we do the math there and bounce just the smoothed amplitude
        // update back to MainActor.
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handleInputBuffer(buffer)
        }

        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailure
        }

        isRecording = true
    }

    func stop() async throws -> URL? {
        guard isRecording else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // Releasing the file flushes pending writes.
        outputFile = nil
        converter = nil
        isRecording = false
        amplitude = 0

        let url = outputURL
        outputURL = nil
        return url
    }

    // MARK: - Tap handling (off main thread)

    private nonisolated func handleInputBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        // Capture references on the audio thread without crossing actors —
        // these are only mutated on MainActor between start() and stop().
        guard let converter = MainActor.assumeIsolated({ self.converter }),
              let outputFile = MainActor.assumeIsolated({ self.outputFile })
        else { return }

        // Estimate the converted frame count: ratio of target to source rate.
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

        // Write 16kHz mono PCM to disk. AVAudioFile transparently encodes the
        // Float32 buffer to int16 because that's what we set in the file
        // settings.
        try? outputFile.write(from: outBuffer)

        // Time-domain RMS over Float channelData[0]. Speech RMS sits around
        // 0.05–0.15; the 4.5x boost normalises it to a 0–1 range that reads
        // around 0.5 for normal speech in the waveform UI.
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
        }
    }
}
