import SmallLightDomain
import SwiftUI

public struct MenuBarView: View {
    @ObservedObject private var viewModel: AppViewModel
    @Binding private var monitoringEnabled: Bool
    private let onAppearAction: () -> Void
    private let onDisappearAction: () -> Void

    public init(viewModel: AppViewModel, monitoringEnabled: Binding<Bool>, onAppear: @escaping () -> Void = {}, onDisappear: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        _monitoringEnabled = monitoringEnabled
        self.onAppearAction = onAppear
        self.onDisappearAction = onDisappear
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(UILocalized.string("menu.section.title"))
                    .font(.headline)
                Text(viewModel.statusText)
                    .font(.subheadline)
                if viewModel.isListening {
                    Text(UILocalized.string("menu.listening"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let actionLabel = viewModel.pendingActionLabel {
                Text(UILocalized.formatted("menu.action.label", actionLabel))
                    .font(.footnote)
            }

            if viewModel.isAwaitingConfirmation {
                Button(UILocalized.string("menu.button.confirm")) {
                    viewModel.confirmPendingAction()
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.canExecuteAction {
                Button(UILocalized.string("menu.button.run")) {
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
                Button(UILocalized.string("menu.button.undo")) {
                    viewModel.undoLastAction()
                }
                .buttonStyle(.link)
            }

            Button(UILocalized.string(monitoringEnabled ? "menu.button.pause" : "menu.button.resume")) {
                monitoringEnabled.toggle()
            }
            .buttonStyle(.bordered)

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
    MenuBarView(viewModel: viewModel, monitoringEnabled: .constant(true))
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
