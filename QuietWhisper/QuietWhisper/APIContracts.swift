// APIContracts.swift
// Shared interfaces every other file codes against. Defined here so parallel
// implementation agents don't have to guess at signatures and so the project
// compiles even when only some files are populated.
//
// IMPORTANT: This file is the source of truth for the v1 surface. If you need
// a new shared type, add it here and announce it; do not duplicate.

import Foundation
import SwiftUI

// MARK: - Recording state machine

enum RecordingState: Equatable {
    case idle
    case recording(startedAt: Date)
    case transcribing
}

// MARK: - Whisper model selection

enum WhisperModelKind: String, CaseIterable, Identifiable, Codable {
    case tiny, base, small, medium, voxtral
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: "Whisper Tiny"
        case .base: "Whisper Base"
        case .small: "Whisper Small"
        case .medium: "Whisper Medium"
        case .voxtral: "Voxtral Mini"
        }
    }

    var meta: String {
        switch self {
        case .tiny: "39M · fastest · lowest accuracy"
        case .base: "74M · fast"
        case .small: "244M · balanced"
        case .medium: "769M · accurate · slower"
        case .voxtral: "Mistral · 1B · experimental"
        }
    }

    var isRecommended: Bool { self == .small }

    /// Voxtral has no shippable local runtime today — render the row but disable it.
    var isAvailable: Bool { self != .voxtral }

    /// WhisperKit model identifier. nil for `voxtral` (handled by a separate engine).
    var whisperKitModelName: String? {
        switch self {
        case .tiny: "openai_whisper-tiny"
        case .base: "openai_whisper-base"
        case .small: "openai_whisper-small"
        case .medium: "openai_whisper-medium"
        case .voxtral: nil
        }
    }
}

// MARK: - Microphone permission

enum MicPermission: Equatable {
    case unknown
    case granted
    case denied
}

// MARK: - Recorder protocol
//
// The concrete type is `AudioRecorder` in Audio/Recorder.swift. Views observe
// `amplitude` for the live waveform; `start()` returns a temp WAV URL on stop
// (see `stop()`). This protocol exists so views can be previewed with a fake.

@MainActor
protocol RecorderProtocol: AnyObject, Observable {
    var amplitude: Double { get }              // 0...1, smoothed
    var isRecording: Bool { get }
    var permission: MicPermission { get }
    /// Number of audio buffers the tap has actually delivered during the
    /// current/last take. Zero after a `start()` that "succeeded" but never
    /// produced audio — sandbox blocks, format negotiation failures, muted
    /// device, etc.
    var buffersReceived: Int { get }
    /// Push channel for the live amplitude. The view layer observes the
    /// controller's mirrored `amplitude` instead of reading through an
    /// existential `any RecorderProtocol`, because SwiftUI's observation
    /// tracker doesn't reliably register reads through type-erased
    /// `@Observable` chains.
    var onAmplitudeUpdate: (@MainActor (Double) -> Void)? { get set }

    func requestPermission() async -> MicPermission
    func start() async throws
    /// Returns the temp WAV URL of the captured audio. Caller deletes it.
    func stop() async throws -> URL?
}

// MARK: - Transcriber protocol

@MainActor
protocol TranscriberProtocol: AnyObject {
    /// Lazily load the chosen model. Idempotent.
    func load(_ model: WhisperModelKind) async throws
    /// Transcribe a 16kHz mono WAV file. Returns plain UTF-8 text.
    func transcribe(_ wav: URL, autoPunct: Bool) async throws -> String
}

// MARK: - Theme contract
//
// Concrete type lives in Theme/PaperTheme.swift. We declare just enough here
// for the @Environment key to compile; the full token list is on the struct.

protocol PaperThemeProtocol {
    var mode: PaperMode { get }
    // Color tokens
    var bg: Color { get }
    var panel: Color { get }
    var panelSoft: Color { get }
    var sidebar: Color { get }
    var ink: Color { get }
    var inkSoft: Color { get }
    var mute: Color { get }
    var muteSoft: Color { get }
    var line: Color { get }
    var lineSoft: Color { get }
    var hover: Color { get }
    var active: Color { get }
    var selected: Color { get }
    var recordBg: Color { get }
    var recordFg: Color { get }
    var dotIdle: Color { get }
    var dotActive: Color { get }
    var danger: Color { get }
    // Shadow params
    var shadowSmall: ShadowSpec { get }
    var shadowLarge: ShadowSpec { get }
}

enum PaperMode: String, Codable { case light, dark }

struct ShadowSpec: Equatable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Density (editor body line-height)

enum EditorDensity: String, CaseIterable, Codable {
    case compact, regular, comfy
    var lineSpacingMultiplier: CGFloat {
        switch self {
        case .compact: 1.45
        case .regular: 1.65
        case .comfy:   1.85
        }
    }
}

// MARK: - Date grouping (sidebar)

enum SidebarGroup: String, CaseIterable {
    case today      = "Today"
    case yesterday  = "Yesterday"
    case thisWeek   = "This week"
    case earlier    = "Earlier"
}
