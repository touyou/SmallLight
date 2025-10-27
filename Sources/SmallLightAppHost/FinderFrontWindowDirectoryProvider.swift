import AppKit
import Foundation

/// Provides the base Finder directory by querying the frontmost Finder window via AppleScript.
protocol FinderBaseDirectoryProviding {
    func activeDirectoryPath() throws -> String?
}

/// Executes AppleScript snippets, returning the resulting string when available.
protocol AppleScriptExecuting {
    func run(script: String) throws -> String?
}

enum AppleScriptError: Error {
    case compilationFailed
    case executionFailed(message: String)
}

enum FinderAppleScript {
    /// AppleScript that resolves the POSIX path of the front Finder window target or the desktop.
    static let baseDirectory: String = """
    tell application "Finder"
        if (count of Finder windows) is greater than 0 then
            set targetPath to POSIX path of (target of front Finder window as alias)
        else
            set targetPath to POSIX path of (desktop as alias)
        end if
    end tell
    return targetPath
    """
}

/// Default executor backed by `NSAppleScript`.
final class AppleScriptExecutor: AppleScriptExecuting {
    func run(script: String) throws -> String? {
        guard let appleScript = NSAppleScript(source: script) else {
            throw AppleScriptError.compilationFailed
        }

        var errorDict: NSDictionary?
        let descriptor = appleScript.executeAndReturnError(&errorDict)

        if let errorDict = errorDict as? [String: Any], !errorDict.isEmpty {
            let message = errorDict[NSAppleScript.errorBriefMessage] as? String
                ?? errorDict[NSAppleScript.errorMessage] as? String
                ?? "Unknown AppleScript error"
            throw AppleScriptError.executionFailed(message: message)
        }

        return descriptor.stringValue
    }
}

/// Fetches the active Finder directory path, trimming whitespace for downstream composition.
struct FinderFrontWindowDirectoryProvider: FinderBaseDirectoryProviding {
    private let executor: AppleScriptExecuting

    init(executor: AppleScriptExecuting = AppleScriptExecutor()) {
        self.executor = executor
    }

    func activeDirectoryPath() throws -> String? {
        guard let result = try executor.run(script: FinderAppleScript.baseDirectory) else {
            return nil
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Helper building absolute paths from base directory and Finder item metadata.
enum FinderPathBuilder {
    static func buildPath(baseDirectory: String, itemName: String) -> String {
        let baseURL = URL(fileURLWithPath: baseDirectory, isDirectory: true)
        let itemURL = baseURL.appendingPathComponent(itemName)
        return itemURL.standardizedFileURL.path
    }
}
