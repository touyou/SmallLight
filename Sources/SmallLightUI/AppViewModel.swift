import Combine
import Foundation
import SmallLightDomain
import SmallLightServices

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var statusText: String = UILocalized.string("status.paused")
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var pendingDecision: ActionDecision?
    @Published public private(set) var lastActionDescription: String?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastAction: CompletedAction?

    private let orchestrator: ActionOrchestrating
    private var isMonitoringActive = false

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
            statusText = localized("status.error")
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

    public func setMonitoringActive(_ active: Bool) {
        isMonitoringActive = active
        if active {
            if pendingDecision == nil {
                statusText = localized("status.watch")
            }
        } else {
            isListening = false
            statusText = localized("status.paused")
        }
    }

    public func undoLastAction() {
        guard let completed = lastAction else { return }
        do {
            try orchestrator.undoLastAction(for: completed.item)
            lastActionDescription = String(format: localized("notification.undo.body"), completed.item.url.lastPathComponent)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateState(with decision: ActionDecision?) {
        guard let decision else {
            isListening = false
            statusText = isMonitoringActive ? localized("status.watch") : localized("status.paused")
            return
        }

        isListening = true

        switch decision.intendedAction {
        case .compress, .decompress:
            if decision.requiresConfirmation {
                statusText = String(format: localized("status.confirmation"), actionLabel(for: decision.intendedAction))
            } else {
                statusText = readyLabel(for: decision.intendedAction)
            }
        case .none:
            statusText = localized("status.watch")
        }
    }

    private func actionLabel(for action: SmallLightAction) -> String {
        switch action {
        case .compress:
            return localized("status.compress.ready")
        case .decompress:
            return localized("status.decompress.ready")
        case .none:
            return localized("status.watch")
        }
    }

    private func actionOutcomeDescription(for action: SmallLightAction, destination: URL) -> String {
        switch action {
        case .compress:
            return String(format: localized("notification.complete.body.compress"), destination.lastPathComponent)
        case .decompress:
            return String(format: localized("notification.complete.body.decompress"), destination.lastPathComponent)
        case .none:
            return localized("notification.complete.body.default")
        }
    }

    private func readyLabel(for action: SmallLightAction) -> String {
        switch action {
        case .compress:
            return localized("status.compress.ready")
        case .decompress:
            return localized("status.decompress.ready")
        case .none:
            return localized("status.watch")
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }
}

public struct CompletedAction: Equatable {
    public let item: FinderItem
    public let action: SmallLightAction
    public let destination: URL
}
