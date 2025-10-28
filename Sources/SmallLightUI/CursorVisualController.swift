import AppKit
import Combine
import Foundation

@MainActor
public protocol CursorVisualControlling {
    func update(listening: Bool)
    func reset()
}

@MainActor
public final class CursorVisualController: CursorVisualControlling {
    private let assetLoader: CursorAssetLoading
    private lazy var assets = assetLoader.loadAssets()
    private lazy var idleCursor = NSCursor(
        image: assets.idleImage,
        hotSpot: NSPoint(x: assets.idleImage.size.width / 2, y: assets.idleImage.size.height / 2))
    private lazy var listeningCursor = NSCursor(
        image: assets.listeningImage,
        hotSpot: NSPoint(
            x: assets.listeningImage.size.width / 2, y: assets.listeningImage.size.height / 2))
    private var isListening = false
    private var didSetCursor = false

    public init(assetLoader: CursorAssetLoading = CursorAssetLoader()) {
        self.assetLoader = assetLoader
    }

    public func update(listening: Bool) {
        let stateChanged = listening != isListening
        if !stateChanged, didSetCursor {
            return
        }
        isListening = listening
        let cursor = listening ? listeningCursor : idleCursor
        cursor.set()
        didSetCursor = true
    }

    public func reset() {
        isListening = false
        didSetCursor = false
        NSCursor.arrow.set()
    }
}
