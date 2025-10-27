import Foundation
import SmallLightDomain

public final class NoopAuditLogger: AuditLogging {
    public init() {}

    public func record(action: SmallLightAction, item: FinderItem, destination: URL) throws {
        // Intentionally left blank until persistent logging is implemented.
    }
}
