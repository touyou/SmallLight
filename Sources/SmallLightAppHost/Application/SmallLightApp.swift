import AppKit
import SmallLightServices
import SmallLightUI
import SwiftUI

@main
struct SmallLightApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        let settings = AppSettings()
        let coordinator = AppCoordinator(
            settings: settings,
            overlayManager: OverlayWindowManager(),
            pasteboard: .general,
            dedupStore: nil,
            hoverMonitorFactory: HoverMonitor.init,
            hudWindowFactory: { viewModel, copyHandler in
                HUDWindowController(viewModel: viewModel, copyHandler: copyHandler)
            },
            resolver: FinderItemResolver(),
            zipHandler: ZipHandler(),
            hotKeyCenter: HotKeyCenter(),
            auditLogger: FileAuditLogger(),
            undoManager: FileUndoStagingManager()
        )
        coordinator.start()
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        MenuBarExtra("SmallLight", systemImage: "lightbulb") {
            MenuContent(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuContent: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: monitoringBinding) {
                Text(UILocalized.string("menu.monitoring"))
            }
            Button(action: coordinator.toggleHUDVisibility) {
                Text(coordinator.hudVisible ? UILocalized.string("menu.hide.hud") : UILocalized.string("menu.show.hud"))
            }
            Button(action: coordinator.focusHUD) {
                Text(UILocalized.string("menu.focus.hud"))
            }
            Divider()
            Button(action: coordinator.revealStagingFolder) {
                Text(UILocalized.string("menu.reveal.staging"))
            }
            Button(action: coordinator.revealAuditLog) {
                Text(UILocalized.string("menu.reveal.logs"))
            }
            Divider()
            Button {
                NSApp.terminate(nil)
            } label: {
                Text(UILocalized.string("menu.quit"))
            }
        }
        .padding(16)
        .frame(minWidth: 220)
    }

    private var monitoringBinding: Binding<Bool> {
        Binding(
            get: { coordinator.isRunning },
            set: { newValue in
                if newValue {
                    coordinator.start()
                } else {
                    coordinator.stop()
                }
            }
        )
    }
}
