import Foundation
import SmallLightDomain

public final class StubCompressionService: CompressionService {
    public init() {}

    public func compress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        return item.url
    }

    public func decompress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        return item.url
    }
}
