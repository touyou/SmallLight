import Foundation
import SmallLightDomain

public final class UserDefaultsConfirmationTracker: ConfirmationTracking {
    private let defaults: UserDefaults
    private let storageKey = "io.smalllight.confirmed-paths"
    private let queue = DispatchQueue(label: "io.smalllight.confirmation-tracker", qos: .utility)
    private var cachedPaths: Set<String>

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        let stored = userDefaults.array(forKey: storageKey) as? [String] ?? []
        cachedPaths = Set(stored)
    }

    public func needsConfirmation(for url: URL) -> Bool {
        queue.sync {
            !cachedPaths.contains(storageKey(for: url))
        }
    }

    public func markConfirmed(for url: URL) {
        queue.sync {
            cachedPaths.insert(storageKey(for: url))
            persist()
        }
    }

    public func resetConfirmation(for url: URL) {
        queue.sync {
            cachedPaths.remove(storageKey(for: url))
            persist()
        }
    }

    private func storageKey(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func persist() {
        defaults.set(Array(cachedPaths), forKey: storageKey)
    }
}
