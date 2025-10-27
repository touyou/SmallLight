import Foundation
import SmallLightDomain

public final class DefaultActionOrchestrator: ActionOrchestrating {
    private let finderService: FinderTargetingService
    private let hotKeyState: HotKeyStateProviding
    private let compressionService: CompressionService
    private let auditLogger: AuditLogging
    private let undoManager: UndoStagingManaging

    public init(
        finderService: FinderTargetingService,
        hotKeyState: HotKeyStateProviding,
        compressionService: CompressionService,
        auditLogger: AuditLogging,
        undoManager: UndoStagingManaging
    ) {
        self.finderService = finderService
        self.hotKeyState = hotKeyState
        self.compressionService = compressionService
        self.auditLogger = auditLogger
        self.undoManager = undoManager
    }

    public func evaluatePendingAction() throws -> ActionDecision? {
        guard hotKeyState.isModifierChordActive else {
            return nil
        }

        guard let item = try finderService.itemUnderCursor() else {
            return nil
        }

        let action: SmallLightAction
        if item.isDirectory {
            action = .compress
        } else if item.isArchive {
            action = .decompress
        } else {
            action = .none
        }

        let requiresConfirmation = action != .none
        return ActionDecision(item: item, intendedAction: action, requiresConfirmation: requiresConfirmation)
    }

    public func perform(decision: ActionDecision) throws -> URL {
        switch decision.intendedAction {
        case .compress:
            _ = try undoManager.stagingURL(for: decision.item, action: decision.intendedAction)
            let _ = try undoManager.stageOriginal(at: decision.item.url)
            let destinationDirectory = decision.item.url.deletingLastPathComponent()
            let destination = try compressionService.compress(item: decision.item, destinationDirectory: destinationDirectory)
            try auditLogger.record(action: .compress, item: decision.item, destination: destination)
            return destination
        case .decompress:
            _ = try undoManager.stagingURL(for: decision.item, action: decision.intendedAction)
            let _ = try undoManager.stageOriginal(at: decision.item.url)
            let destinationDirectory = decision.item.url.deletingLastPathComponent()
            let destination = try compressionService.decompress(item: decision.item, destinationDirectory: destinationDirectory)
            try auditLogger.record(action: .decompress, item: decision.item, destination: destination)
            return destination
        case .none:
            throw SmallLightError.confirmationPending
        }
    }

    public func undoLastAction(for item: FinderItem) throws {
        let stagingURL = try undoManager.stagingURL(for: item, action: .compress)
        try undoManager.restore(from: stagingURL, to: item.url)
    }
}
