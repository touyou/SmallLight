import SmallLightDomain
import SmallLightServices
import SmallLightUI
import SwiftUI

@main
struct SmallLightApp: App {
    @StateObject private var viewModel: AppViewModel
    @StateObject private var coordinator: AppCoordinator
    private let preferencesStore: PreferencesStore

    init() {
        let bootstrap = Self.bootstrap()
        _viewModel = StateObject(wrappedValue: bootstrap.viewModel)
        _coordinator = StateObject(wrappedValue: bootstrap.coordinator)
        preferencesStore = bootstrap.preferences
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
        SettingsView(viewModel: PreferencesViewModel(store: preferencesStore, launchAgentManager: LaunchAgentManager()))
        }
    }

    private static func bootstrap() -> (viewModel: AppViewModel, coordinator: AppCoordinator, preferences: PreferencesStore) {
        let finder = AccessibilityFinderTargetingService()
        let hotKeyState = InMemoryHotKeyState()
        let compression = FileCompressionService()
        let logger = FileAuditLogger()
        let preferences = PreferencesStore.shared
        let undoManager = FileUndoStagingManager(retentionInterval: preferences.undoRetentionInterval)
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
        let coordinator = AppCoordinator(
            viewModel: viewModel,
            hotKeyManager: hotKeyManager,
            chord: preferences.preferredHotKey,
            undoManager: undoManager,
            preferences: preferences
        )
        return (viewModel, coordinator, preferences)
    }
}
