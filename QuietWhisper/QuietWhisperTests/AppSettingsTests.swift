import XCTest
@testable import QuietWhisper

final class AppSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "qw.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsWhenNothingPersisted() {
        let s = AppSettings(defaults: defaults)
        XCTAssertEqual(s.model, .small)
        XCTAssertTrue(s.autoPunct)
        XCTAssertFalse(s.dark)
        XCTAssertFalse(s.sidebarOpen)
        XCTAssertEqual(s.density, .regular)
    }

    func testRoundTripsMutations() {
        let s = AppSettings(defaults: defaults)
        s.model = .tiny
        s.autoPunct = false
        s.dark = true
        s.sidebarOpen = true
        s.density = .comfy

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.model, .tiny)
        XCTAssertFalse(reloaded.autoPunct)
        XCTAssertTrue(reloaded.dark)
        XCTAssertTrue(reloaded.sidebarOpen)
        XCTAssertEqual(reloaded.density, .comfy)
    }

    func testIgnoresGarbageInDefaults() {
        defaults.set("not-a-real-model", forKey: "qw.model")
        defaults.set("not-a-real-density", forKey: "qw.density")
        let s = AppSettings(defaults: defaults)
        XCTAssertEqual(s.model, .small)
        XCTAssertEqual(s.density, .regular)
    }

    func testExplicitFalseIsDistinguishedFromUnset() {
        defaults.set(false, forKey: "qw.autoPunct")
        let s = AppSettings(defaults: defaults)
        XCTAssertFalse(s.autoPunct, "explicit false must override the true default")
    }
}
