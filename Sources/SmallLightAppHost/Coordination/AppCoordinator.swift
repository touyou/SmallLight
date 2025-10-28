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
    private let hoverMonitorFactory: (AppSettings.Trigger, @escaping HoverMonitor.DwellHandler, HoverMonitor.MovementHandler?, HoverMonitor.ModifierHandler?) -> HoverMonitor
    private let hudWindowFactory: @MainActor (HUDViewModel, @escaping (HUDEntry) -> Void) -> HUDWindowControlling
    private let dedupStore: DeduplicationStore
    private let resolver: FinderItemResolving
    private let compressionServiceBox: SendableBox<any CompressionService>
    private let zipHandler: ZipHandling
    private let hotKeyCenter: HotKeyRegistering
    private let auditLoggerBox: SendableBox<any AuditLogging>
    private let undoManagerBox: SendableBox<any UndoStagingManaging>
    private let cursorController: CursorVisualControlling
    private let accessibilityPromptController = AccessibilityPromptController()
    private var didWarnAccessibility = false

    private lazy var hoverMonitor: HoverMonitor = hoverMonitorFactory(
        settings.trigger,
        { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleHoverEvent(event)
            }
        },
        { [weak self] event in
            guard let self else { return }
            self.overlayManager.updateCursorPosition(event.location)
        },
        { [weak self] isHeld in
            guard let self else { return }
            overlayManager.setActive(isHeld)
            cursorController.update(listening: isHeld)
        }
    )
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
        hoverMonitorFactory: @escaping (AppSettings.Trigger, @escaping HoverMonitor.DwellHandler, HoverMonitor.MovementHandler?, HoverMonitor.ModifierHandler?) -> HoverMonitor = HoverMonitor.init,
        hudWindowFactory: @MainActor @escaping (HUDViewModel, @escaping (HUDEntry) -> Void) -> HUDWindowControlling = { viewModel, copyHandler in
            HUDWindowController(viewModel: viewModel, copyHandler: copyHandler)
        },
        resolver: FinderItemResolving = FinderItemResolver(),
    compressionService: CompressionService,
        zipHandler: ZipHandling,
        hotKeyCenter: HotKeyRegistering,
        auditLogger: AuditLogging,
        undoManager: UndoStagingManaging,
        cursorController: CursorVisualControlling = CursorVisualController()
    ) {
        self.settings = settings
        self.overlayManager = overlayManager
        self.pasteboard = pasteboard
        self.hoverMonitorFactory = hoverMonitorFactory
        self.hudWindowFactory = hudWindowFactory
        self.hudViewModel = HUDViewModel(
            historyLimit: settings.hud.historyLimit,
            autoCopyEnabled: settings.hud.autoCopyEnabled,
            accessibilityGranted: AXIsProcessTrusted()
        )
        self.dedupStore = dedupStore ?? DeduplicationStore(ttl: settings.dedup.ttl, capacity: settings.dedup.capacity)
        self.resolver = resolver
    self.compressionServiceBox = SendableBox(compressionService)
        self.zipHandler = zipHandler
        self.hotKeyCenter = hotKeyCenter
        self.auditLoggerBox = SendableBox(auditLogger)
        self.undoManagerBox = SendableBox(undoManager)
        self.cursorController = cursorController
    }

    private var auditLogger: any AuditLogging { auditLoggerBox.value }
    private var undoManager: any UndoStagingManaging { undoManagerBox.value }

    func start() {
        guard mode == .idle else { return }
        hoverMonitor.start()
        overlayManager.setActive(false)
        cursorController.update(listening: false)
        hudWindowController.show()
        hudVisible = true
        mode = .watching
        registerHotKeys()
        verifyAccessibilityPermissions()
    }

    func stop() {
        guard mode == .watching else { return }
        hoverMonitor.stop()
        overlayManager.setActive(false)
        cursorController.reset()
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
        hudWindowController.updatePosition(nearestTo: event.location)
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
        } else if resolution.isDirectory {
            handleCompression(for: resolution, dedupKey: dedupKey)
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
        showAccessibilityAlert()
        hudViewModel.updateAccessibility(granted: false)
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
                let stagingURL = try undoManager.stagingURL(for: finderItem, action: .decompress)
                let stagedOriginal = try undoManager.stageOriginal(at: itemURL)
                let destination = try zipHandler.extract(zipPath: resolution.path)
                do {
                    try auditLoggerBox.value.record(action: .decompress, item: finderItem, destination: destination)
                } catch {
                    NSLog("[FinderOverlayDebugger] Failed to record audit entry: \(error)")
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.present(path: stagingURL.path, message: UILocalized.formatted("hud.zip.staging", stagingURL.path))
                    self.present(path: stagedOriginal.path, message: UILocalized.formatted("hud.zip.staged", stagedOriginal.path))
                    self.present(path: destination.path, message: UILocalized.formatted("hud.zip.success", destination.path))
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

    private func handleCompression(for resolution: FinderItemResolution, dedupKey: String) {
        let compressionServiceBox = self.compressionServiceBox
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
                let stagingURL = try undoManager.stagingURL(for: finderItem, action: .compress)
                let stagedOriginal = try undoManager.stageOriginal(at: itemURL)
                let destinationDirectory = itemURL.deletingLastPathComponent()
                let destination = try compressionServiceBox.value.compress(item: finderItem, destinationDirectory: destinationDirectory)
                do {
                    try auditLoggerBox.value.record(action: .compress, item: finderItem, destination: destination)
                } catch {
                    NSLog("[FinderOverlayDebugger] Failed to record audit entry: \(error)")
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.present(path: stagingURL.path, message: UILocalized.formatted("hud.zip.staging", stagingURL.path))
                    self.present(path: stagedOriginal.path, message: UILocalized.formatted("hud.zip.staged", stagedOriginal.path))
                    self.present(path: destination.path, message: UILocalized.formatted("hud.compress.success", destination.path))
                }
            } catch {
                dedupStore.remove(dedupKey)
                NSLog("[FinderOverlayDebugger] Compression failed: \(error)")
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let message = UILocalized.formatted("hud.compress.error", error.localizedDescription)
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
        hudWindowController.updatePosition(nearestTo: location)
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

    @MainActor
    private func verifyAccessibilityPermissions() {
        if AXIsProcessTrusted() {
            accessibilityPromptController.reset()
            hudViewModel.updateAccessibility(granted: true)
            return
        }
        guard accessibilityPromptController.shouldPrompt else { return }
        showAccessibilityAlert()
        hudViewModel.updateAccessibility(granted: false)
    }

    @MainActor
    private func showAccessibilityAlert() {
        accessibilityPromptController.recordPrompt()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = UILocalized.string("accessibility.alert.title")
        alert.informativeText = UILocalized.string("accessibility.alert.message")
        alert.addButton(withTitle: UILocalized.string("accessibility.alert.open"))
        alert.addButton(withTitle: UILocalized.string("accessibility.alert.cancel"))
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.openAccessibilityPreferences()
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openAccessibilityPreferences()
            }
        }
    }

    @MainActor
    private func openAccessibilityPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.didWarnAccessibility = false
            self?.verifyAccessibilityPermissions()
        }
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

private final class AccessibilityPromptController {
    private let defaults: UserDefaults
    private let lastPromptKey = "io.smalllight.accessibility.lastPrompt"
    private let suppressionInterval: TimeInterval = 60 * 60 // one hour

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldPrompt: Bool {
        guard !AXIsProcessTrusted() else {
            reset()
            return false
        }
        let last = defaults.double(forKey: lastPromptKey)
        guard last > 0 else { return true }
        let elapsed = Date().timeIntervalSince1970 - last
        return elapsed > suppressionInterval
    }

    func recordPrompt() {
        defaults.set(Date().timeIntervalSince1970, forKey: lastPromptKey)
    }

    func reset() {
        defaults.removeObject(forKey: lastPromptKey)
    }
}
