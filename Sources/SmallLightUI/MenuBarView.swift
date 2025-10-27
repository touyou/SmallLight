import SmallLightDomain
import SwiftUI

public struct MenuBarView: View {
    @ObservedObject private var viewModel: AppViewModel
    private let onAppearAction: () -> Void
    private let onDisappearAction: () -> Void

    public init(viewModel: AppViewModel, onAppear: @escaping () -> Void = {}, onDisappear: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onAppearAction = onAppear
        self.onDisappearAction = onDisappear
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("menu.section.title"))
                    .font(.headline)
                Text(viewModel.statusText)
                    .font(.subheadline)
                if viewModel.isListening {
                    Text(LocalizedStringKey("menu.listening"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let actionLabel = viewModel.pendingActionLabel {
                Text(String(format: NSLocalizedString("menu.action.label", bundle: .main, comment: ""), actionLabel))
                    .font(.footnote)
            }

            if viewModel.isAwaitingConfirmation {
                Button(LocalizedStringKey("menu.button.confirm")) {
                    viewModel.confirmPendingAction()
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.canExecuteAction {
                Button(LocalizedStringKey("menu.button.run")) {
                    viewModel.performPendingAction()
                }
                .buttonStyle(.bordered)
            }

            if let lastAction = viewModel.lastActionDescription {
                Text(lastAction)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if viewModel.lastAction != nil {
                Button(LocalizedStringKey("menu.button.undo")) {
                    viewModel.undoLastAction()
                }
                .buttonStyle(.link)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
        .onAppear(perform: onAppearAction)
        .onDisappear(perform: onDisappearAction)
    }
}

#Preview {
    let viewModel: AppViewModel = {
        let previewOrchestrator = PreviewOrchestrator()
        let vm = AppViewModel(orchestrator: previewOrchestrator)
        vm.refreshState()
        return vm
    }()
    MenuBarView(viewModel: viewModel)
}

private final class PreviewOrchestrator: ActionOrchestrating {
    func evaluatePendingAction() throws -> ActionDecision? {
        let item = FinderItem(url: URL(fileURLWithPath: "/tmp"), isDirectory: true, isArchive: false)
        return ActionDecision(item: item, intendedAction: .compress, requiresConfirmation: true)
    }

    func perform(decision: ActionDecision) throws -> URL {
        decision.item.url.appendingPathExtension("zip")
    }

    func undoLastAction(for item: FinderItem) throws {}

    func acknowledgeConfirmation(for item: FinderItem) {}
}
