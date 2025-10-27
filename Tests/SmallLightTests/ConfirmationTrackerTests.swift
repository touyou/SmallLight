import XCTest
@testable import SmallLightDomain
@testable import SmallLightServices

final class ConfirmationTrackerTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        defaultsSuiteName = "io.smalllight.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        if let suiteName = defaultsSuiteName {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
    }

    func testNeedsConfirmationIsTrueUntilMarked() {
        let tracker = UserDefaultsConfirmationTracker(userDefaults: defaults)
        let url = URL(fileURLWithPath: "/tmp/sample")

        XCTAssertTrue(tracker.needsConfirmation(for: url))

        tracker.markConfirmed(for: url)

        XCTAssertFalse(tracker.needsConfirmation(for: url))
    }

    func testPersistenceAcrossInstances() {
        let url = URL(fileURLWithPath: "/tmp/sample")

        let trackerA = UserDefaultsConfirmationTracker(userDefaults: defaults)
        trackerA.markConfirmed(for: url)

        let trackerB = UserDefaultsConfirmationTracker(userDefaults: defaults)
        XCTAssertFalse(trackerB.needsConfirmation(for: url))
    }

    func testResetAllowsReconfirmation() {
        let tracker = UserDefaultsConfirmationTracker(userDefaults: defaults)
        let url = URL(fileURLWithPath: "/tmp/sample")

        tracker.markConfirmed(for: url)
        XCTAssertFalse(tracker.needsConfirmation(for: url))

        tracker.resetConfirmation(for: url)
        XCTAssertTrue(tracker.needsConfirmation(for: url))
    }
}
