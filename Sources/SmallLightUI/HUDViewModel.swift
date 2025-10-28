import Foundation

/// Represents a HUD entry containing the resolved path and metadata for display.
public struct HUDEntry: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let path: String
    public let message: String?

    public init(path: String, message: String? = nil, timestamp: Date = Date()) {
        self.path = path
        self.message = message
        self.timestamp = timestamp
    }
}

/// Observable view model powering the HUD.
@MainActor
public final class HUDViewModel: ObservableObject {
    @Published public private(set) var history: [HUDEntry] = []
    @Published public var autoCopyEnabled: Bool
    @Published public private(set) var accessibilityGranted: Bool

    private let historyLimit: Int

    public init(historyLimit: Int, autoCopyEnabled: Bool, accessibilityGranted: Bool = true) {
        self.historyLimit = historyLimit
        self.autoCopyEnabled = autoCopyEnabled
        self.accessibilityGranted = accessibilityGranted
    }

    /// Appends a new entry and trims history to the configured limit.
    public func append(_ entry: HUDEntry) {
        history.insert(entry, at: 0)
        if history.count > historyLimit {
            history = Array(history.prefix(historyLimit))
        }
    }

    public func updateAccessibility(granted: Bool) {
        accessibilityGranted = granted
    }
}
