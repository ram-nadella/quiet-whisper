// swift-tools-version: 5.9
import PackageDescription

let whisperBuild = "whisper.cpp/build"

let package = Package(
    name: "WhisperDictation",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CWhisper",
            path: "CWhisper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
        .executableTarget(
            name: "WhisperDictation",
            dependencies: ["CWhisper"],
            path: "Sources/WhisperDictation",
            swiftSettings: [
                .unsafeFlags([
                    "-I", "CWhisper/include",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(whisperBuild)/src",
                    "-L\(whisperBuild)/ggml/src",
                    "-L\(whisperBuild)/ggml/src/ggml-metal",
                    "-L\(whisperBuild)/ggml/src/ggml-blas",
                ]),
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-metal"),
                .linkedLibrary("ggml-blas"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Foundation"),
                .unsafeFlags(["-lc++"]),
            ]
        ),
    ]
)
