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

    private enum DedupAction {
        static let resolve = "resolve"
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
    private let resolver: FinderItemResolving
    private let zipHandler: ZipHandler
    private let hotKeyCenter: HotKeyCenter
    private var didWarnAccessibility = false

    private lazy var hoverMonitor: HoverMonitor = hoverMonitorFactory(settings.trigger) { [weak self] event in
        self?.handleHoverEvent(event)
    }
    private lazy var hudWindowController: HUDWindowController = hudWindowFactory(hudViewModel) { [weak self] entry in
        self?.copyToClipboard(entry)
    }
    private let hudViewModel: HUDViewModel
    private let resolutionQueue = DispatchQueue(label: "io.smalllight.finder-resolution", qos: .userInitiated)

    init(
        settings: AppSettings = AppSettings(),
        overlayManager: OverlayWindowManager = OverlayWindowManager(),
        pasteboard: NSPasteboard = .general,
        dedupStore: DeduplicationStore? = nil,
        hoverMonitorFactory: @escaping (AppSettings.Trigger, @escaping HoverMonitor.Handler) -> HoverMonitor = HoverMonitor.init,
        hudWindowFactory: @MainActor @escaping (HUDViewModel, @escaping (HUDEntry) -> Void) -> HUDWindowController = { viewModel, copyHandler in
            HUDWindowController(viewModel: viewModel, copyHandler: copyHandler)
        },
        resolver: FinderItemResolving = FinderItemResolver(),
        zipHandler: ZipHandler = ZipHandler(),
        hotKeyCenter: HotKeyCenter = HotKeyCenter()
    ) {
        self.settings = settings
        self.overlayManager = overlayManager
        self.pasteboard = pasteboard
        self.hoverMonitorFactory = hoverMonitorFactory
        self.hudWindowFactory = hudWindowFactory
        self.hudViewModel = HUDViewModel(historyLimit: settings.hud.historyLimit, autoCopyEnabled: settings.hud.autoCopyEnabled)
        self.dedupStore = dedupStore ?? DeduplicationStore(ttl: settings.dedup.ttl, capacity: settings.dedup.capacity)
        self.resolver = resolver
        self.zipHandler = zipHandler
        self.hotKeyCenter = hotKeyCenter
    }

    func start() {
        guard mode == .idle else { return }
        hoverMonitor.start()
        hudWindowController.show()
        hudVisible = true
        mode = .watching
        registerHotKeys()
    }

    func stop() {
        guard mode == .watching else { return }
        hoverMonitor.stop()
        hotKeyCenter.unregisterAll()
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

    private func handleHoverEvent(_ event: HoverMonitor.Event) {
        overlayManager.updateCursorPosition(event.location)
        resolve(at: event.location, bypassDedup: false)
    }

    private func copyToClipboard(_ entry: HUDEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.path, forType: .string)
    }

    @MainActor
    private func handleResolvedItem(_ resolution: FinderItemResolution, dedupKey: String) {
        if resolution.isArchive, settings.zip.behaviour == .auto {
            handleZipExtraction(for: resolution, dedupKey: dedupKey)
        } else {
            present(path: resolution.path)
        }
    }

    @MainActor
    private func handleAccessibilityWarning() {
        guard !didWarnAccessibility else { return }
        didWarnAccessibility = true
        NSLog("[FinderOverlayDebugger] Accessibility permission required to resolve Finder items.")
    }

    @MainActor
    private func handleResolverError(_ error: Error) {
        NSLog("[FinderOverlayDebugger] Failed to resolve Finder item: \(error)")
    }

    func clearDedupKey(for path: String, action: String) {
        let key = "\(path)::\(action)"
        dedupStore.remove(key)
    }

    private func handleZipExtraction(for resolution: FinderItemResolution, dedupKey: String) {
        let zipHandler = self.zipHandler
        let dedupStore = self.dedupStore
        resolutionQueue.async { [weak self] in
            do {
                let destination = try zipHandler.extract(zipPath: resolution.path)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let message = UILocalized.formatted("hud.zip.success", resolution.path)
                    self.present(path: destination.path, message: message)
                }
            } catch {
                dedupStore.remove(dedupKey)
                NSLog("[FinderOverlayDebugger] Zip extraction failed: \(error)")
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let message = UILocalized.formatted("hud.zip.error", error.localizedDescription)
                    self.present(path: resolution.path, message: message)
                }
            }
        }
    }

    private func registerHotKeys() {
        do {
            try hotKeyCenter.register([
                (settings.focusHotKey, { [weak self] in
                    Task { @MainActor in
                        self?.focusHUD()
                    }
                }),
                (settings.manualResolveHotKey, { [weak self] in
                    Task { @MainActor in
                        self?.handleManualResolve()
                    }
                }),
                (settings.toggleHUDHotKey, { [weak self] in
                    Task { @MainActor in
                        self?.toggleHUDVisibility()
                    }
                })
            ])
        } catch {
            NSLog("[FinderOverlayDebugger] Failed to register hot keys: \(error)")
        }
    }

    private func handleManualResolve() {
        let location = NSEvent.mouseLocation
        overlayManager.updateCursorPosition(location)
        resolve(at: location, bypassDedup: true)
    }

    private func resolve(at location: CGPoint, bypassDedup: Bool) {
        let resolver = self.resolver
        let dedupStore = self.dedupStore

        resolutionQueue.async { [weak self] in
            do {
                guard let resolution = try resolver.resolveItem(at: location) else { return }
                let key = "\(resolution.path)::\(DedupAction.resolve)"
                if !bypassDedup && dedupStore.isDuplicate(key) {
                    return
                }
                dedupStore.record(key)
                Task { @MainActor [weak self] in
                    self?.handleResolvedItem(resolution, dedupKey: key)
                }
            } catch FinderItemResolverError.accessibilityPermissionRequired {
                Task { @MainActor [weak self] in
                    self?.handleAccessibilityWarning()
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.handleResolverError(error)
                }
            }
        }
    }
}
