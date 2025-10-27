import AppKit
import Foundation

public struct CursorAssets {
    public let idleImage: NSImage
    public let listeningImage: NSImage

    public init(idleImage: NSImage, listeningImage: NSImage) {
        self.idleImage = idleImage
        self.listeningImage = listeningImage
    }
}

public protocol CursorAssetLoading {
    func loadAssets() -> CursorAssets
}

public final class CursorAssetLoader: CursorAssetLoading {
    private let fileManager: FileManager
    private let customAssetsURL: URL

    public init(
        fileManager: FileManager = .default,
        customAssetsDirectory: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SmallLight/Assets", isDirectory: true)
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/SmallLight/Assets")
    ) {
        self.fileManager = fileManager
        self.customAssetsURL = customAssetsDirectory
    }

    public func loadAssets() -> CursorAssets {
        if let custom = loadCustomAssets() {
            return custom
        }
        return CursorAssets(
            idleImage: Self.defaultCursor(color: NSColor.systemGray.withAlphaComponent(0.7)),
            listeningImage: Self.defaultCursor(color: NSColor.systemYellow.withAlphaComponent(0.9))
        )
    }

    private func loadCustomAssets() -> CursorAssets? {
        let idleURL = customAssetsURL.appendingPathComponent("cursor-idle.png")
        let listeningURL = customAssetsURL.appendingPathComponent("cursor-active.png")

        guard fileManager.fileExists(atPath: idleURL.path),
              fileManager.fileExists(atPath: listeningURL.path),
              let idle = NSImage(contentsOf: idleURL),
              let active = NSImage(contentsOf: listeningURL)
        else {
            return nil
        }

        return CursorAssets(idleImage: idle, listeningImage: active)
    }

    private static func defaultCursor(color: NSColor) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4))
        color.setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 2
        path.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
