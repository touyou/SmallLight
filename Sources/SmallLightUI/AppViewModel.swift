import Combine
import Foundation
import SmallLightDomain
import SmallLightServices

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var statusText: String = "Idle"
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var pendingDecision: ActionDecision?
    @Published public private(set) var lastActionDescription: String?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastAction: CompletedAction?

    private let orchestrator: ActionOrchestrating

    public init(orchestrator: ActionOrchestrating) {
        self.orchestrator = orchestrator
    }

    public func refreshState() {
        do {
            let decision = try orchestrator.evaluatePendingAction()
            pendingDecision = decision
            updateState(with: decision)
        } catch {
            isListening = false
            statusText = "Error"
            pendingDecision = nil
            errorMessage = error.localizedDescription
        }
    }

    public func confirmPendingAction() {
        guard let decision = pendingDecision else { return }
        orchestrator.acknowledgeConfirmation(for: decision.item)
        errorMessage = nil
        refreshState()
    }

    public func performPendingAction() {
        guard let decision = pendingDecision else { return }
        do {
            let destination = try orchestrator.perform(decision: decision)
            let completed = CompletedAction(item: decision.item, action: decision.intendedAction, destination: destination)
            lastAction = completed
            lastActionDescription = actionOutcomeDescription(for: completed.action, destination: completed.destination)
            errorMessage = nil
            refreshState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public var isAwaitingConfirmation: Bool {
        pendingDecision?.requiresConfirmation ?? false
    }

    public var canExecuteAction: Bool {
        guard let decision = pendingDecision else { return false }
        return !decision.requiresConfirmation && decision.intendedAction != .none
    }

    public var pendingActionLabel: String? {
        guard let decision = pendingDecision else { return nil }
        return actionLabel(for: decision.intendedAction)
    }

    public func undoLastAction() {
        guard let completed = lastAction else { return }
        do {
            try orchestrator.undoLastAction(for: completed.item)
            lastActionDescription = "Undo restored \(completed.item.url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateState(with decision: ActionDecision?) {
        guard let decision else {
            isListening = false
            statusText = "Idle"
            return
        }

        isListening = true

        switch decision.intendedAction {
        case .compress, .decompress:
            if decision.requiresConfirmation {
                statusText = "\(actionLabel(for: decision.intendedAction)) confirmation required"
            } else {
                statusText = "\(actionLabel(for: decision.intendedAction)) ready"
            }
        case .none:
            statusText = "Watching"
        }
    }

    private func actionLabel(for action: SmallLightAction) -> String {
        switch action {
        case .compress:
            return "Compress"
        case .decompress:
            return "Decompress"
        case .none:
            return "Observe"
        }
    }

    private func actionOutcomeDescription(for action: SmallLightAction, destination: URL) -> String {
        switch action {
        case .compress:
            return "Compressed to \(destination.lastPathComponent)"
        case .decompress:
            return "Decompressed to \(destination.lastPathComponent)"
        case .none:
            return "No action performed"
        }
    }
}

public struct CompletedAction: Equatable {
    public let item: FinderItem
    public let action: SmallLightAction
    public let destination: URL
}
