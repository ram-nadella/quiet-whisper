import XCTest
@testable import QuietWhisper

/// macOS 14+ requires sandboxed apps that touch AVAudioEngine input to declare
/// a mach-lookup exception for `com.apple.audioanalyticsd`. Without it the
/// engine prints a `PRECONDITION FAILURE` from CoreAudio, refuses to deliver
/// buffers, and silently produces an empty WAV — the exact symptom that drove
/// this branch. Pin the entitlements file so a future plist edit doesn't
/// regress us back into that state.
final class EntitlementsTests: XCTestCase {

    func testEntitlementsFileGrantsAudioInputAndAudioAnalyticsLookup() throws {
        let url = try Self.entitlementsURL()
        let plist = try Self.loadPlist(url)

        XCTAssertEqual(plist["com.apple.security.app-sandbox"] as? Bool, true,
                       "App sandbox should remain enabled")
        XCTAssertEqual(plist["com.apple.security.device.audio-input"] as? Bool, true,
                       "Mic entitlement is required to capture audio")

        let lookups = (plist["com.apple.security.temporary-exception.mach-lookup.global-name"] as? [String]) ?? []
        XCTAssertTrue(lookups.contains("com.apple.audioanalyticsd"),
                      "AVAudioEngine input on sandboxed macOS apps requires this lookup exception or the engine fails silently")
    }

    // MARK: - File discovery

    private static func entitlementsURL(file: StaticString = #filePath) throws -> URL {
        // #filePath points to this test source. The entitlements file is a
        // sibling of `QuietWhisperTests/` inside the source tree, so walking up
        // a couple of levels and into `QuietWhisper/` finds it. This works in
        // Xcode (DerivedData) and CI (checkout) alike because the path is the
        // compile-time source location, not the test bundle's runtime URL.
        let testFile = URL(fileURLWithPath: String(describing: file))
        let candidate = testFile
            .deletingLastPathComponent()                // QuietWhisperTests/
            .deletingLastPathComponent()                // QuietWhisper/ (the project dir)
            .appendingPathComponent("QuietWhisper")     // app source dir
            .appendingPathComponent("QuietWhisper.entitlements")
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw XCTSkip("Could not locate QuietWhisper.entitlements at \(candidate.path)")
        }
        return candidate
    }

    private static func loadPlist(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = parsed as? [String: Any] else {
            throw NSError(domain: "EntitlementsTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Entitlements plist is not a dictionary"])
        }
        return dict
    }
}
