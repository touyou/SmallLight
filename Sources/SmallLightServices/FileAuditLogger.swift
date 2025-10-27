import Foundation
import SmallLightDomain

public final class FileAuditLogger: AuditLogging {
    private let directoryURL: URL
    private let fileManager: FileManager
    private let dateProvider: () -> Date
    private let encoder: JSONEncoder
    private let queue = DispatchQueue(label: "io.smalllight.audit-logger", qos: .utility)

    public init(
        baseDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"),
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.directoryURL = baseDirectory.appendingPathComponent("SmallLight/logs", isDirectory: true)
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func record(action: SmallLightAction, item: FinderItem, destination: URL) throws {
        let entry = AuditEntry(
            timestamp: dateProvider(),
            action: action,
            sourcePath: item.url.path,
            destinationPath: destination.path
        )

        try queue.sync {
            try prepareLogDirectory()
            let data = try encoder.encode(entry)
            try appendLogLine(data: data)
        }
    }

    private func prepareLogDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func appendLogLine(data: Data) throws {
        let logURL = directoryURL.appendingPathComponent("actions.log")
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: logURL) else {
            throw SmallLightError.auditFailed(reason: "Unable to open audit log for writing.")
        }
        defer { try? handle.close() }
        try handle.seekToEnd()
        handle.write(data)
        handle.write(Data("\n".utf8))
    }

    private struct AuditEntry: Encodable {
        let timestamp: Date
        let action: SmallLightAction
        let sourcePath: String
        let destinationPath: String
    }
}
