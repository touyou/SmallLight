import Foundation
import SmallLightDomain

public final class FileCompressionService: CompressionService {
    private let fileManager: FileManager
    private let processLauncher: ProcessLaunching

    public init(
        fileManager: FileManager = .default,
        processLauncher: ProcessLaunching = DefaultProcessLauncher()
    ) {
        self.fileManager = fileManager
        self.processLauncher = processLauncher
    }

    public func compress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        let destinationURL = destinationDirectory.appendingPathComponent(
            item.url.lastPathComponent + ".zip"
        )

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try fileManager.removeItemIfExists(at: destinationURL)

        let arguments = [
            "ditto",
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            item.url.path,
            destinationURL.path
        ]

        do {
            try processLauncher.run(arguments: arguments)
        } catch {
            throw SmallLightError.compressionFailed(reason: error.localizedDescription)
        }

        return destinationURL
    }

    public func decompress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        let baseDirectory = destinationDirectory
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        let uniqueRootName = "\(item.url.deletingPathExtension().lastPathComponent)-\(UUID().uuidString)"
        let extractionRoot = baseDirectory.appendingPathComponent(uniqueRootName, isDirectory: true)

        if fileManager.fileExists(atPath: extractionRoot.path) {
            try fileManager.removeItem(at: extractionRoot)
        }
        try fileManager.createDirectory(at: extractionRoot, withIntermediateDirectories: true)

        let arguments = [
            "ditto",
            "-x",
            "-k",
            item.url.path,
            extractionRoot.path
        ]

        do {
            try processLauncher.run(arguments: arguments)
        } catch {
            throw SmallLightError.decompressionFailed(reason: error.localizedDescription)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: extractionRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        if contents.count == 1 {
            return contents[0]
        }

        return extractionRoot
    }
}

public protocol ProcessLaunching {
    func run(arguments: [String]) throws
}


public struct DefaultProcessLauncher: ProcessLaunching {
    public init() {}

    public func run(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ProcessLauncherError.commandFailed(exitCode: Int(process.terminationStatus))
        }
    }
}

public enum ProcessLauncherError: Error {
    case commandFailed(exitCode: Int)
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
