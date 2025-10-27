@testable import SmallLightUI
import XCTest

@MainActor
final class HUDViewModelTests: XCTestCase {
    func testAppendsPrependLatestEntry() {
        let model = HUDViewModel(historyLimit: 3, autoCopyEnabled: false)

        model.append(HUDEntry(path: "/tmp/a.txt"))
        model.append(HUDEntry(path: "/tmp/b.txt"))

        XCTAssertEqual(model.history.map(\.path), ["/tmp/b.txt", "/tmp/a.txt"])
    }

    func testHistoryIsTrimmedToLimit() {
        let model = HUDViewModel(historyLimit: 2, autoCopyEnabled: false)

        model.append(HUDEntry(path: "first"))
        model.append(HUDEntry(path: "second"))
        model.append(HUDEntry(path: "third"))

        XCTAssertEqual(model.history.count, 2)
        XCTAssertEqual(model.history.map(\.path), ["third", "second"])
    }
}
