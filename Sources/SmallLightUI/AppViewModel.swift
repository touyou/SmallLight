import Combine
import Foundation
import SmallLightDomain
import SmallLightServices

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var statusText: String = "Idle"
    @Published public private(set) var isListening: Bool = false

    private let orchestrator: ActionOrchestrating

    public init(orchestrator: ActionOrchestrating) {
        self.orchestrator = orchestrator
    }

    public func refreshState() {
        do {
            if let decision = try orchestrator.evaluatePendingAction() {
                isListening = true
                switch decision.intendedAction {
                case .compress:
                    statusText = "Compress ready"
                case .decompress:
                    statusText = "Decompress ready"
                case .none:
                    statusText = "Watching"
                }
            } else {
                isListening = false
                statusText = "Idle"
            }
        } catch {
            isListening = false
            statusText = "Error"
        }
    }
}
