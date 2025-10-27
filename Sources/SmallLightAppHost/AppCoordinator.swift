import AppKit
import Combine
import Foundation
import SmallLightUI

/// Coordinates FinderOverlayDebugger subsystems such as the overlay, hover detection, HUD, and clipboard integration.
@MainActor
final class AppCoordinator: ObservableObject {
    enum Mode {
        case idle
        case watching
    }

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var hudVisible: Bool = false

    var isRunning: Bool { mode == .watching }

    var hudModel: HUDViewModel { hudViewModel }

    private let settings: AppSettings
    private let overlayManager: OverlayWindowManager
    private let pasteboard: NSPasteboard
    private let hoverMonitorFactory: (AppSettings.Trigger, @escaping HoverMonitor.Handler) -> HoverMonitor
    private let hudWindowFactory: @MainActor (HUDViewModel, @escaping (HUDEntry) -> Void) -> HUDWindowController
    private let dedupStore: DeduplicationStore

    private lazy var hoverMonitor: HoverMonitor = hoverMonitorFactory(settings.trigger) { [weak self] event in
        self?.handleHoverEvent(event)
    }
    private lazy var hudWindowController: HUDWindowController = hudWindowFactory(hudViewModel) { [weak self] entry in
        self?.copyToClipboard(entry)
    }
    private let hudViewModel: HUDViewModel

    init(
        settings: AppSettings = AppSettings(),
        overlayManager: OverlayWindowManager = OverlayWindowManager(),
        pasteboard: NSPasteboard = .general,
        dedupStore: DeduplicationStore? = nil,
        hoverMonitorFactory: @escaping (AppSettings.Trigger, @escaping HoverMonitor.Handler) -> HoverMonitor = HoverMonitor.init,
        hudWindowFactory: @MainActor @escaping (HUDViewModel, @escaping (HUDEntry) -> Void) -> HUDWindowController = { viewModel, copyHandler in
            HUDWindowController(viewModel: viewModel, copyHandler: copyHandler)
        }
    ) {
        self.settings = settings
        self.overlayManager = overlayManager
        self.pasteboard = pasteboard
        self.hoverMonitorFactory = hoverMonitorFactory
        self.hudWindowFactory = hudWindowFactory
        self.hudViewModel = HUDViewModel(historyLimit: settings.hud.historyLimit, autoCopyEnabled: settings.hud.autoCopyEnabled)
        self.dedupStore = dedupStore ?? DeduplicationStore(ttl: settings.dedup.ttl, capacity: settings.dedup.capacity)
    }

    func start() {
        guard mode == .idle else { return }
        hoverMonitor.start()
        hudWindowController.show()
        hudVisible = true
        mode = .watching
    }

    func stop() {
        guard mode == .watching else { return }
        hoverMonitor.stop()
        mode = .idle
    }

    func toggleHUDVisibility() {
        if hudWindowController.isVisible {
            hudWindowController.hide()
            hudVisible = false
        } else {
            hudWindowController.show()
            hudVisible = true
        }
    }

    func focusHUD() {
        hudWindowController.focus()
        hudVisible = true
    }

    func present(path: String, message: String? = nil) {
        let entry = HUDEntry(path: path, message: message)
        hudViewModel.append(entry)
        if hudViewModel.autoCopyEnabled {
            copyToClipboard(entry)
        }
    }

    func clearDedupKey(for path: String, action: String) {
        let key = dedupKey(for: path, action: action)
        dedupStore.remove(key)
    }

    private func handleHoverEvent(_ event: HoverMonitor.Event) {
        overlayManager.updateCursorPosition(event.location)
        // Finder resolution pipeline will be connected in Phase 3.
    }

    private func copyToClipboard(_ entry: HUDEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.path, forType: .string)
    }

    private func dedupKey(for path: String, action: String) -> String {
        "\(path)::\(action)"
    }
}
