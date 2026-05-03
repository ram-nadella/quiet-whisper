import XCTest
@testable import QuietWhisper

final class WhisperModelKindTests: XCTestCase {

    func testWhisperKitNamesAreSetForEveryShippingModel() {
        for kind in WhisperModelKind.allCases where kind != .voxtral {
            XCTAssertNotNil(kind.whisperKitModelName, "expected whisperKitModelName for \(kind)")
            XCTAssertTrue(kind.whisperKitModelName!.hasPrefix("openai_whisper-"))
        }
    }

    func testVoxtralIsTheOnlyModelWithoutAWhisperKitName() {
        XCTAssertNil(WhisperModelKind.voxtral.whisperKitModelName)
    }

    func testVoxtralIsCurrentlyMarkedUnavailable() {
        XCTAssertFalse(WhisperModelKind.voxtral.isAvailable)
        for kind in WhisperModelKind.allCases where kind != .voxtral {
            XCTAssertTrue(kind.isAvailable, "\(kind) should be available")
        }
    }

    func testSmallIsTheRecommendedDefault() {
        XCTAssertTrue(WhisperModelKind.small.isRecommended)
        for kind in WhisperModelKind.allCases where kind != .small {
            XCTAssertFalse(kind.isRecommended)
        }
    }

    func testRawValuesAreStableForUserDefaultsPersistence() {
        // Treat these as load-bearing — UserDefaults entries written by past
        // builds need to keep deserializing.
        XCTAssertEqual(WhisperModelKind.tiny.rawValue, "tiny")
        XCTAssertEqual(WhisperModelKind.base.rawValue, "base")
        XCTAssertEqual(WhisperModelKind.small.rawValue, "small")
        XCTAssertEqual(WhisperModelKind.medium.rawValue, "medium")
        XCTAssertEqual(WhisperModelKind.voxtral.rawValue, "voxtral")
    }

    func testEditorDensityRawValuesStable() {
        XCTAssertEqual(EditorDensity.compact.rawValue, "compact")
        XCTAssertEqual(EditorDensity.regular.rawValue, "regular")
        XCTAssertEqual(EditorDensity.comfy.rawValue, "comfy")
    }
}
