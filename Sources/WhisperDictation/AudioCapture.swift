import AVFoundation

class AudioCapture: ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0

    func startRecording() throws {
        audioBuffer.removeAll()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatError
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.formatError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self = self else { return }

            if let samples = self.convert(buffer: buffer, converter: converter, targetFormat: targetFormat) {
                self.bufferLock.lock()
                self.audioBuffer.append(contentsOf: samples)
                self.bufferLock.unlock()

                // Update audio level on main thread for visual feedback
                let level = samples.reduce(0) { max($0, abs($1)) }
                DispatchQueue.main.async {
                    self.audioLevel = level
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    func stopRecording() -> [Float] {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0
        }

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        return samples
    }

    private func convert(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) -> [Float]? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if error != nil { return nil }

        guard let floatData = outputBuffer.floatChannelData else { return nil }
        let frameLength = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: floatData[0], count: frameLength))
    }
}

enum AudioCaptureError: LocalizedError {
    case formatError
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .formatError: return "Failed to set up audio format"
        case .permissionDenied: return "Microphone access denied"
        }
    }
}
