import Foundation

protocol LaunchAgentManaging {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

final class LaunchAgentManager: LaunchAgentManaging {
    private let fileManager: FileManager
    private let agentURL: URL
    private let bundleIdentifier: String

    init(
        fileManager: FileManager = .default,
        agentURL: URL? = nil,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "io.smalllight.app"
    ) {
        self.fileManager = fileManager
        if let agentURL {
            self.agentURL = agentURL
        } else {
            self.agentURL = LaunchAgentManager.defaultLaunchAgentURL()
        }
        self.bundleIdentifier = bundleIdentifier
    }

    static func defaultLaunchAgentURL() -> URL {
        let launchAgents = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        return launchAgents.appendingPathComponent("io.smalllight.app.plist")
    }

    func isEnabled() -> Bool {
        fileManager.fileExists(atPath: agentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try createLaunchAgent()
        } else {
            try disableLaunchAgent()
        }
    }

    private func createLaunchAgent() throws {
        let bundlePath = Bundle.main.bundlePath
        guard bundlePath.hasSuffix(".app") else {
            return
        }

        let plist: [String: Any] = [
            "Label": "io.smalllight.app",
            "Program": "\(bundlePath)/Contents/MacOS/SmallLight",
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        let parent = agentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        fileManager.createFile(atPath: agentURL.path, contents: data)
    }

    private func disableLaunchAgent() throws {
        guard fileManager.fileExists(atPath: agentURL.path) else { return }
        try fileManager.removeItem(at: agentURL)
    }
}
