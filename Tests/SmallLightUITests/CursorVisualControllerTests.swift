import AppKit
import XCTest

@testable import SmallLightUI

@MainActor
final class CursorVisualControllerTests: XCTestCase {
    func testInitialUpdateAppliesIdleCursor() {
        let idleImage = NSImage(size: NSSize(width: 8, height: 8))
        idleImage.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        idleImage.unlockFocus()

        let listeningImage = NSImage(size: NSSize(width: 8, height: 8))
        listeningImage.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        listeningImage.unlockFocus()

        let loader = StubLoader(idle: idleImage, listening: listeningImage)
        let controller = CursorVisualController(assetLoader: loader)

        NSCursor.arrow.set()
        controller.update(listening: false)

        XCTAssertTrue(NSCursor.current.image === idleImage)

        controller.reset()
    }
}

private final class StubLoader: CursorAssetLoading {
    private let idle: NSImage
    private let listening: NSImage

    init(idle: NSImage, listening: NSImage) {
        self.idle = idle
        self.listening = listening
    }

    func loadAssets() -> CursorAssets {
        CursorAssets(idleImage: idle, listeningImage: listening)
    }
}
