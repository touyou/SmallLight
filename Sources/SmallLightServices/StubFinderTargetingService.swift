import Foundation
import SmallLightDomain

public final class StubFinderTargetingService: FinderTargetingService {
    private var nextItem: FinderItem?

    public init(initialItem: FinderItem? = nil) {
        self.nextItem = initialItem
    }

    public func itemUnderCursor() throws -> FinderItem? {
        return nextItem
    }

    public func update(item: FinderItem?) {
        nextItem = item
    }
}
