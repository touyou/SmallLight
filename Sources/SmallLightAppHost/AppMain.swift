import SmallLightDomain
import SmallLightServices
import SmallLightUI
import SwiftUI

@main
struct SmallLightApp: App {
    @StateObject private var viewModel: AppViewModel
    @StateObject private var coordinator: AppCoordinator

    init() {
        let bootstrap = Self.bootstrap()
        _viewModel = StateObject(wrappedValue: bootstrap.viewModel)
        _coordinator = StateObject(wrappedValue: bootstrap.coordinator)
    }

    var body: some Scene {
        MenuBarExtra("SmallLight", systemImage: "lightbulb") {
            MenuBarView(
                viewModel: viewModel,
                onAppear: { coordinator.start() },
                onDisappear: { coordinator.stop() }
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private static func bootstrap() -> (viewModel: AppViewModel, coordinator: AppCoordinator) {
        let finder = AccessibilityFinderTargetingService()
        let hotKeyState = InMemoryHotKeyState()
        let compression = FileCompressionService()
        let logger = FileAuditLogger()
        let undoManager = FileUndoStagingManager()
        let confirmationTracker = UserDefaultsConfirmationTracker()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKeyState,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undoManager,
            confirmationTracker: confirmationTracker
        )
        let viewModel = AppViewModel(orchestrator: orchestrator)
        let hotKeyRegistrar = CarbonHotKeyRegistrar()
        let hotKeyManager = DefaultHotKeyManager(registrar: hotKeyRegistrar, state: hotKeyState)
        let coordinator = AppCoordinator(viewModel: viewModel, hotKeyManager: hotKeyManager, chord: .defaultActionChord)
        return (viewModel, coordinator)
    }
}

private struct SettingsView: View {
    var body: some View {
        Form {
            Text("Preferences coming soon.")
        }
        .padding()
        .frame(width: 320, height: 200)
    }
}
