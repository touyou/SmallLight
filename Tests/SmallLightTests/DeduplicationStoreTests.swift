import XCTest

@testable import SmallLightAppHost

final class DeduplicationStoreTests: XCTestCase {
    func testDuplicateWithinTTLReturnsTrue() {
        let store = DeduplicationStore(ttl: 1.0, capacity: 4)
        let now = Date()
        store.record("abc", now: now)

        XCTAssertTrue(store.isDuplicate("abc", now: now.addingTimeInterval(0.5)))
    }

    func testExpiredEntriesArePurged() {
        let store = DeduplicationStore(ttl: 1.0, capacity: 4)
        let now = Date()
        store.record("abc", now: now)

        XCTAssertFalse(store.isDuplicate("abc", now: now.addingTimeInterval(1.5)))
    }

    func testRemovalAllowsImmediateRetry() {
        let store = DeduplicationStore(ttl: 1.0, capacity: 4)
        store.record("abc")
        XCTAssertTrue(store.isDuplicate("abc"))
        store.remove("abc")
        XCTAssertFalse(store.isDuplicate("abc"))
    }
}
