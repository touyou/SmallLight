import SmallLightDomain
import SmallLightServices
import SmallLightUI
import SwiftUI

@main
struct SmallLightApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        _viewModel = StateObject(wrappedValue: Self.makeViewModel())
    }

    var body: some Scene {
        MenuBarExtra("SmallLight", systemImage: "lightbulb") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private static func makeViewModel() -> AppViewModel {
        let finder = StubFinderTargetingService()
        let hotKeyState = InMemoryHotKeyState()
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undoManager = StubUndoStagingManager()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKeyState,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undoManager
        )
        return AppViewModel(orchestrator: orchestrator)
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
