import Foundation

public protocol FinderTargetingService {
    func itemUnderCursor() throws -> FinderItem?
}

public protocol HotKeyStateProviding {
    var isModifierChordActive: Bool { get }
}

public protocol CompressionService {
    func compress(item: FinderItem, destinationDirectory: URL) throws -> URL
    func decompress(item: FinderItem, destinationDirectory: URL) throws -> URL
}

public protocol AuditLogging {
    func record(action: SmallLightAction, item: FinderItem, destination: URL) throws
}

public protocol UndoStagingManaging {
    func stagingURL(for item: FinderItem, action: SmallLightAction) throws -> URL
    func stageOriginal(at url: URL) throws -> URL
    func restore(from stagingURL: URL, to destinationURL: URL) throws
}

public protocol ActionOrchestrating {
    func evaluatePendingAction() throws -> ActionDecision?
    func perform(decision: ActionDecision) throws -> URL
    func undoLastAction(for item: FinderItem) throws
}
