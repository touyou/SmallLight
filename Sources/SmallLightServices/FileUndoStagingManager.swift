import Foundation
import SmallLightDomain

public final class FileUndoStagingManager: UndoStagingManaging {
    private let rootDirectory: URL
    private let fileManager: FileManager
    private let dateProvider: () -> Date
    private let isoFormatter: ISO8601DateFormatter

    public init(
        rootDirectory: URL = FileUndoStagingManager.defaultRootDirectory(),
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
    }

    public static func defaultRootDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("SmallLight", isDirectory: true)
            .appendingPathComponent("staging", isDirectory: true)
    }

    public func stagingURL(for item: FinderItem, action: SmallLightAction) throws -> URL {
        let timestamp = isoFormatter.string(from: dateProvider())
        let actionDirectory = rootDirectory
            .appendingPathComponent(action.folderName, isDirectory: true)
            .appendingPathComponent(timestamp, isDirectory: true)
        try fileManager.createDirectory(at: actionDirectory, withIntermediateDirectories: true)

        return actionDirectory.appendingPathComponent(item.url.lastPathComponent, isDirectory: item.isDirectory)
    }

    public func stageOriginal(at url: URL) throws -> URL {
        let originalsDirectory = rootDirectory.appendingPathComponent("originals", isDirectory: true)
        try fileManager.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)

        let uniqueName = "\(UUID().uuidString)-\(url.lastPathComponent)"
        let destination = originalsDirectory.appendingPathComponent(uniqueName, isDirectory: false)
        try safeCopyItem(at: url, to: destination)
        return destination
    }

    public func restore(from stagingURL: URL, to destinationURL: URL) throws {
        let parent = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: stagingURL, to: destinationURL)
    }

    private func safeCopyItem(at source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }
}

private extension SmallLightAction {
    var folderName: String {
        switch self {
        case .compress: "compress"
        case .decompress: "decompress"
        case .none: "noop"
        }
    }
}
