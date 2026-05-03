import Foundation
import Observation

/// Fake recorder for SwiftUI previews. Mirrors the smooth random walk in
/// qw-wave.jsx (lines 197–209): a new target every ~360ms, interpolated each
/// ~60ms tick toward the target.
@MainActor
@Observable
final class PreviewRecorder: RecorderProtocol {
    private(set) var amplitude: Double = 0
    private(set) var isRecording: Bool = false
    private(set) var permission: MicPermission = .granted
    private(set) var buffersReceived: Int = 0
    var onAmplitudeUpdate: (@MainActor (Double) -> Void)?

    private var timer: Timer?
    private var ticks: Int = 0
    private var target: Double = 0.4
    private var current: Double = 0.3

    func requestPermission() async -> MicPermission { .granted }

    func start() async throws {
        isRecording = true
        ticks = 0
        target = 0.4
        current = 0.3
        timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() async throws -> URL? {
        timer?.invalidate()
        timer = nil
        isRecording = false
        amplitude = 0
        return nil
    }

    private func tick() {
        ticks += 1
        if ticks % 6 == 0 {
            target = 0.15 + Double.random(in: 0...0.7)
        }
        current += (target - current) * 0.25
        amplitude = current
        buffersReceived &+= 1
        onAmplitudeUpdate?(amplitude)
    }
}
