import XCTest

@testable import SmallLightUI

final class CursorAssetLoaderTests: XCTestCase {
    func testLoadsDefaultAssetsWhenCustomMissing() {
        let loader = CursorAssetLoader(
            fileManager: .default,
            customAssetsDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString))
        let assets = loader.loadAssets()
        XCTAssertGreaterThan(assets.idleImage.size.width, 0)
        XCTAssertGreaterThan(assets.listeningImage.size.width, 0)
    }
}
