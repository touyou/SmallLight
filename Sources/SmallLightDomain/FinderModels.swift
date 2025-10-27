import Foundation

public enum SmallLightAction: Equatable, Codable {
    case compress
    case decompress
    case none
}

public struct FinderItem: Equatable {
    public let url: URL
    public let isDirectory: Bool
    public let isArchive: Bool

    public init(url: URL, isDirectory: Bool, isArchive: Bool) {
        self.url = url
        self.isDirectory = isDirectory
        self.isArchive = isArchive
    }
}

public struct ActionDecision: Equatable {
    public let item: FinderItem
    public let intendedAction: SmallLightAction
    public let requiresConfirmation: Bool

    public init(item: FinderItem, intendedAction: SmallLightAction, requiresConfirmation: Bool) {
        self.item = item
        self.intendedAction = intendedAction
        self.requiresConfirmation = requiresConfirmation
    }
}
