import XCTest

@testable import SmallLightDomain
@testable import SmallLightServices

final class FileAuditLoggerTests: XCTestCase {
    func testRecordAppendsLineToLog() throws {
        let tempDir = try temporaryDirectory()
        let logger = FileAuditLogger(baseDirectory: tempDir, fileManager: .default) {
            Date(timeIntervalSince1970: 0)
        }
        let item = FinderItem(
            url: tempDir.appendingPathComponent("Source"), isDirectory: true, isArchive: false)

        try logger.record(
            action: .compress, item: item, destination: tempDir.appendingPathComponent("Result.zip")
        )

        let logURL = tempDir.appendingPathComponent("SmallLight/logs/actions.log")
        let contents = try String(contentsOf: logURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(contents.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(LoggedEntry.self, from: data)
        XCTAssertEqual(entry.action, .compress)
        XCTAssertEqual(entry.sourcePath, item.url.path)
        XCTAssertEqual(entry.destinationPath, tempDir.appendingPathComponent("Result.zip").path)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private struct LoggedEntry: Decodable, Equatable {
        let timestamp: Date
        let action: SmallLightAction
        let sourcePath: String
        let destinationPath: String
    }
}
