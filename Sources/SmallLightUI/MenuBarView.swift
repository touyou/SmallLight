import SmallLightDomain
import SwiftUI

public struct MenuBarView: View {
    @ObservedObject private var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SmallLight")
                .font(.headline)
            Text(viewModel.statusText)
                .font(.subheadline)
            if viewModel.isListening {
                Text("Listening…")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .frame(minWidth: 180)
    }
}

#Preview {
    MenuBarView(viewModel: AppViewModel(orchestrator: PreviewOrchestrator()))
}

private final class PreviewOrchestrator: ActionOrchestrating {
    func evaluatePendingAction() throws -> ActionDecision? {
        let item = FinderItem(url: URL(fileURLWithPath: "/tmp"), isDirectory: true, isArchive: false)
        return ActionDecision(item: item, intendedAction: .compress, requiresConfirmation: false)
    }

    func perform(decision: ActionDecision) throws -> URL {
        decision.item.url
    }

    func undoLastAction(for item: FinderItem) throws {}

    func acknowledgeConfirmation(for item: FinderItem) {}
}
