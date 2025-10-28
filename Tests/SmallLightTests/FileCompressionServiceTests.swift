import XCTest

@testable import SmallLightDomain
@testable import SmallLightServices

final class FileCompressionServiceTests: XCTestCase {
    private let fileManager = FileManager.default

    func testCompressCreatesZipArchive() throws {
        let tempRoot = try temporaryDirectory()
        let sourceDirectory = tempRoot.appendingPathComponent("Folder", isDirectory: true)
        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try "data"
            .write(
                to: sourceDirectory.appendingPathComponent("file.txt"), atomically: true,
                encoding: .utf8)

        let destinationDirectory = sourceDirectory.deletingLastPathComponent()
        let item = FinderItem(url: sourceDirectory, isDirectory: true, isArchive: false)
        let service = FileCompressionService(fileManager: fileManager)

        let destination = try service.compress(
            item: item, destinationDirectory: destinationDirectory)

        XCTAssertTrue(fileManager.fileExists(atPath: destination.path))
        XCTAssertEqual(destination.pathExtension, "zip")
    }

    func testDecompressExpandsArchiveIntoDirectory() throws {
        let tempRoot = try temporaryDirectory()
        let archiveSource = tempRoot.appendingPathComponent("SourceDir", isDirectory: true)
        try fileManager.createDirectory(at: archiveSource, withIntermediateDirectories: true)
        try "hello"
            .write(
                to: archiveSource.appendingPathComponent("file.txt"), atomically: true,
                encoding: .utf8)

        let service = FileCompressionService(fileManager: fileManager)
        let destinationDirectory = archiveSource.deletingLastPathComponent()
        let archiveURL = try service.compress(
            item: FinderItem(url: archiveSource, isDirectory: true, isArchive: false),
            destinationDirectory: destinationDirectory
        )

        let item = FinderItem(url: archiveURL, isDirectory: false, isArchive: true)
        let extractionDirectory = tempRoot.appendingPathComponent("extraction", isDirectory: true)
        try fileManager.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)

        let destination = try service.decompress(
            item: item, destinationDirectory: extractionDirectory)

        XCTAssertTrue(fileManager.fileExists(atPath: destination.path))
        XCTAssertTrue(
            fileManager.fileExists(atPath: destination.appendingPathComponent("file.txt").path))
    }

    private func temporaryDirectory() throws -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
