import AppKit
import Combine
import Foundation
import SmallLightDomain
import SmallLightServices
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
    private let overlayManager: OverlayUpdating
    private let pasteboard: NSPasteboard
    private let hoverMonitorFactory: (AppSettings.Trigger, @escaping HoverMonitor.Handler) -> HoverMonitor
    private let hudWindowFactory: @MainActor (HUDViewModel, @escaping (HUDEntry) -> Void) -> HUDWindowControlling
    private let dedupStore: DeduplicationStore
    private let resolver: FinderItemResolving
    private let zipHandler: ZipHandling
    private let hotKeyCenter: HotKeyRegistering
    private let auditLoggerBox: SendableBox<any AuditLogging>
    private let undoManagerBox: SendableBox<any UndoStagingManaging>
    private var didWarnAccessibility = false

    private lazy var hoverMonitor: HoverMonitor = hoverMonitorFactory(settings.trigger) { [weak self] event in
        self?.handleHoverEvent(event)
    }
    private lazy var hudWindowController: HUDWindowControlling = hudWindowFactory(hudViewModel) { [weak self] entry in
        self?.copyToClipboard(entry)
    }
    private let hudViewModel: HUDViewModel
    private let resolutionQueue = DispatchQueue(label: "io.smalllight.finder-resolution", qos: .userInitiated)

    init(
        settings: AppSettings = AppSettings(),
        overlayManager: OverlayUpdating = OverlayWindowManager(),
        pasteboard: NSPasteboard = .general,
        dedupStore: DeduplicationStore? = nil,
        hoverMonitorFactory: @escaping (AppSettings.Trigger, @escaping HoverMonitor.Handler) -> HoverMonitor = HoverMonitor.init,
        hudWindowFactory: @MainActor @escaping (HUDViewModel, @escaping (HUDEntry) -> Void) -> HUDWindowControlling = { viewModel, copyHandler in
            HUDWindowController(viewModel: viewModel, copyHandler: copyHandler)
        },
        resolver: FinderItemResolving = FinderItemResolver(),
        zipHandler: ZipHandling,
        hotKeyCenter: HotKeyRegistering,
        auditLogger: AuditLogging,
        undoManager: UndoStagingManaging
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
        self.auditLoggerBox = SendableBox(auditLogger)
        self.undoManagerBox = SendableBox(undoManager)
    }

    private var auditLogger: any AuditLogging { auditLoggerBox.value }
    private var undoManager: any UndoStagingManaging { undoManagerBox.value }

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
            let message = contextMessage(for: resolution)
            present(path: resolution.path, message: message)
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
        let auditLoggerBox = self.auditLoggerBox
        let undoManagerBox = self.undoManagerBox
        resolutionQueue.async { [weak self] in
            do {
                let itemURL = URL(fileURLWithPath: resolution.path)
                let finderItem = FinderItem(
                    url: itemURL,
                    isDirectory: resolution.isDirectory,
                    isArchive: resolution.isArchive
                )
                let undoManager = undoManagerBox.value
                _ = try undoManager.stagingURL(for: finderItem, action: .decompress)
                _ = try undoManager.stageOriginal(at: itemURL)
                let destination = try zipHandler.extract(zipPath: resolution.path)
                do {
                    try auditLoggerBox.value.record(action: .decompress, item: finderItem, destination: destination)
                } catch {
                    NSLog("[FinderOverlayDebugger] Failed to record audit entry: \(error)")
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let message = UILocalized.formatted("hud.zip.success", destination.path)
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
                        self?.manualResolve()
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

    func manualResolve() {
        let location = NSEvent.mouseLocation
        overlayManager.updateCursorPosition(location)
        resolve(at: location, bypassDedup: true)
    }

    /// Opens Finder pointing at the undo staging directory so users can inspect or restore staged originals manually.
    func revealStagingFolder() {
        let url = FileUndoStagingManager.defaultRootDirectory()
        ensureDirectoryExists(at: url)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens Finder pointing at the audit log (or its directory when the log has not been created yet).
    func revealAuditLog() {
        let directory = AppSupportPaths.auditLogDirectory
        ensureDirectoryExists(at: directory)
        let logFile = directory.appendingPathComponent("actions.log")
        if FileManager.default.fileExists(atPath: logFile.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logFile])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([directory])
        }
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

    /// Creates the contextual HUD message for regular files and folders, surfacing the parent location.
    private func contextMessage(for resolution: FinderItemResolution) -> String? {
        let url = URL(fileURLWithPath: resolution.path)
        let parent = url.deletingLastPathComponent().path
        if resolution.isDirectory {
            return UILocalized.formatted("hud.info.folder", parent)
        } else {
            return UILocalized.formatted("hud.info.file", parent)
        }
    }

    /// Ensures the provided directory exists before we attempt to reveal it in Finder. Errors are intentionally ignored
    /// because failing to create the directory should not crash the coordinator – Finder will simply open the parent.
    private func ensureDirectoryExists(at url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private struct AppSupportPaths {
    static var baseDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    }

    static var auditLogDirectory: URL {
        baseDirectory.appendingPathComponent("SmallLight/logs", isDirectory: true)
    }
}

/// A lightweight wrapper used to treat non-Sendable protocol conformers as sendable when hopping across queues.
/// The coordinator guarantees main-actor usage, so boxing is safe in practice.
private final class SendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
