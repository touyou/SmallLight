import Foundation

protocol ZipHandling: Sendable {
    func extract(zipPath: String) throws -> URL
}

enum ZipHandlerError: LocalizedError {
    case notAZip
    case dittoFailed(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .notAZip:
            return "Selected item is not a zip archive."
        case .dittoFailed(let code, let message):
            if message.isEmpty {
                return "ditto failed with status \(code)."
            }
            return message
        }
    }
}

/// Handles extraction of `.zip` archives using `/usr/bin/ditto`.
final class ZipHandler {
    private let fileManager: FileManager
    private let dittoURL: URL
    private let processFactory: () -> Process

    init(
        fileManager: FileManager = .default,
        dittoURL: URL = URL(fileURLWithPath: "/usr/bin/ditto"),
        processFactory: @escaping () -> Process = Process.init
    ) {
        self.fileManager = fileManager
        self.dittoURL = dittoURL
        self.processFactory = processFactory
    }

    /// Extracts the archive located at `zipPath` into a sibling directory and returns its URL.
    func extract(zipPath: String) throws -> URL {
        let zipURL = URL(fileURLWithPath: zipPath)
        guard zipURL.pathExtension.lowercased() == "zip" else {
            throw ZipHandlerError.notAZip
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: zipURL.path, isDirectory: &isDirectory),
            !isDirectory.boolValue
        else {
            throw ZipHandlerError.notAZip
        }

        let destinationURL = try makeDestination(for: zipURL)
        try runDitto(zipURL: zipURL, destinationURL: destinationURL)
        return destinationURL
    }

    private func makeDestination(for zipURL: URL) throws -> URL {
        let parent = zipURL.deletingLastPathComponent()
        let baseName = zipURL.deletingPathExtension().lastPathComponent
        var candidate = parent.appendingPathComponent(baseName, isDirectory: true)

        if fileManager.fileExists(atPath: candidate.path) {
            var suffixIndex = 1
            repeat {
                let suffix = suffixIndex == 1 ? "_unpacked" : "_unpacked\(suffixIndex)"
                candidate = parent.appendingPathComponent("\(baseName)\(suffix)", isDirectory: true)
                suffixIndex += 1
            } while fileManager.fileExists(atPath: candidate.path)
        }

        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: false)
        return candidate
    }

    private func runDitto(zipURL: URL, destinationURL: URL) throws {
        let process = processFactory()
        process.executableURL = dittoURL
        process.arguments = ["-x", "-k", zipURL.path, destinationURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let messageData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message =
                String(data: messageData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            try? fileManager.removeItem(at: destinationURL)
            throw ZipHandlerError.dittoFailed(code: process.terminationStatus, message: message)
        }
    }
}

extension ZipHandler: ZipHandling {}
extension ZipHandler: @unchecked Sendable {}
