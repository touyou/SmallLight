import Foundation
import SmallLightDomain

public final class StubUndoStagingManager: UndoStagingManaging {
    public init() {}

    public func stagingURL(for item: FinderItem, action: SmallLightAction) throws -> URL {
        return item.url.appendingPathExtension("staging")
    }

    public func stageOriginal(at url: URL) throws -> URL {
        return url.appendingPathExtension("staged")
    }

    public func restore(from stagingURL: URL, to destinationURL: URL) throws {
        // No-op in stub implementation; tests rely on staged state only.
    }
}
