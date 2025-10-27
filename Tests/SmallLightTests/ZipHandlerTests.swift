@testable import SmallLightAppHost
import XCTest

final class ZipHandlerTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileManager: FileManager!

    override func setUpWithError() throws {
        fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? fileManager.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testExtractsZipIntoSiblingDirectory() throws {
        let sourceDir = tempDirectory.appendingPathComponent("SampleDir", isDirectory: true)
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: false)
        let filePath = sourceDir.appendingPathComponent("hello.txt")
        try "hello".data(using: .utf8)?.write(to: filePath)

        let zipURL = tempDirectory.appendingPathComponent("SampleDir.zip")
        try makeZip(from: sourceDir, to: zipURL)
        try fileManager.removeItem(at: sourceDir)

        let handler = ZipHandler()
        let destination = try handler.extract(zipPath: zipURL.path)

        XCTAssertTrue(fileManager.fileExists(atPath: destination.path, isDirectory: nil))
        let extractedFile = destination.appendingPathComponent("SampleDir/hello.txt")
        XCTAssertTrue(fileManager.fileExists(atPath: extractedFile.path))
    }

    func testAddsSuffixWhenDestinationConflicts() throws {
        let sourceDir = tempDirectory.appendingPathComponent("Projects", isDirectory: true)
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: false)
        try "data".data(using: .utf8)?.write(to: sourceDir.appendingPathComponent("file.txt"))

        let zipURL = tempDirectory.appendingPathComponent("Projects.zip")
        try makeZip(from: sourceDir, to: zipURL)
        try fileManager.removeItem(at: sourceDir)

        // Create conflicting directory.
        let conflicting = tempDirectory.appendingPathComponent("Projects", isDirectory: true)
        try fileManager.createDirectory(at: conflicting, withIntermediateDirectories: false)

        let handler = ZipHandler()
        let destination = try handler.extract(zipPath: zipURL.path)

        XCTAssertTrue(destination.lastPathComponent.hasPrefix("Projects_unpacked"))
        XCTAssertTrue(fileManager.fileExists(atPath: destination.path))
    }

    func testThrowsWhenArchiveInvalid() throws {
        let fakeZip = tempDirectory.appendingPathComponent("Invalid.zip")
        try "not a zip".data(using: .utf8)?.write(to: fakeZip)

        let handler = ZipHandler()
        XCTAssertThrowsError(try handler.extract(zipPath: fakeZip.path)) { error in
            guard case ZipHandlerError.dittoFailed = error else {
                XCTFail("Expected dittoFailed error, got \(error)")
                return
            }
        }
    }

    private func makeZip(from directory: URL, to zipURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", directory.path, zipURL.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "Failed to create zip fixture")
    }
}
