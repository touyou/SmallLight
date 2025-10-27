import XCTest
@testable import SmallLightDomain
@testable import SmallLightServices

final class UndoStagingManagerTests: XCTestCase {
    private let fileManager = FileManager.default

    func testStagingURLResidesWithinRootDirectory() throws {
        let tempRoot = try temporaryDirectory()
        let manager = FileUndoStagingManager(rootDirectory: tempRoot, fileManager: fileManager)
        let item = FinderItem(
            url: tempRoot.appendingPathComponent("Example"),
            isDirectory: true,
            isArchive: false
        )

        let stagingURL = try manager.stagingURL(for: item, action: .compress)

        XCTAssertTrue(stagingURL.path.hasPrefix(tempRoot.path))
        XCTAssertTrue(stagingURL.path.contains("compress"))
    }

    func testStageOriginalCopiesItemIntoStaging() throws {
        let tempRoot = try temporaryDirectory()
        let manager = FileUndoStagingManager(rootDirectory: tempRoot, fileManager: fileManager)
        let sourceFile = tempRoot.appendingPathComponent("source.txt")
        try "hello".write(to: sourceFile, atomically: true, encoding: .utf8)

        let stagedURL = try manager.stageOriginal(at: sourceFile)

        XCTAssertTrue(fileManager.fileExists(atPath: stagedURL.path))
        let stagedContents = try String(contentsOf: stagedURL)
        XCTAssertEqual(stagedContents, "hello")
    }

    func testRestoreMovesStagedFileBackToDestination() throws {
        let tempRoot = try temporaryDirectory()
        let manager = FileUndoStagingManager(rootDirectory: tempRoot, fileManager: fileManager)

        let destinationURL = tempRoot.appendingPathComponent("destination.txt")
        let stagedURL = tempRoot.appendingPathComponent("staged.txt")

        try "undo".write(to: stagedURL, atomically: true, encoding: .utf8)

        try manager.restore(from: stagedURL, to: destinationURL)

        XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        let restoredContents = try String(contentsOf: destinationURL)
        XCTAssertEqual(restoredContents, "undo")
    }

    private func temporaryDirectory() throws -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
