import AppKit
import Combine
import Foundation
import SmallLightDomain
import SmallLightServices
import SmallLightUI

/// Coordinates FinderOverlayDebugger subsystems such as the overlay, hover detection, HUD, and
/// clipboard integration.
@MainActor
final class AppCoordinator: ObservableObject {
    enum Mode {
        case idle
        case watching
    }

    enum DedupAction {
        static let resolve = "resolve"
    }

    @Published var mode: Mode = .idle
    @Published var hudVisible: Bool = false

    var isRunning: Bool { mode == .watching }

    var hudModel: HUDViewModel { hudViewModel }

    let settings: AppSettings
    let overlayManager: OverlayUpdating
    let pasteboard: NSPasteboard
    private let hoverMonitorFactory:
        (
            AppSettings.Trigger,
            @escaping HoverMonitor.DwellHandler,
            HoverMonitor.MovementHandler?,
            HoverMonitor.ModifierHandler?
        ) -> HoverMonitor
    private let hudWindowFactory:
        @MainActor (
            HUDViewModel,
            @escaping (HUDEntry) -> Void
        ) -> HUDWindowControlling
    let dedupStore: DeduplicationStore
    let resolver: FinderItemResolving
    let compressionServiceBox: SendableBox<any CompressionService>
    let zipHandler: ZipHandling
    let hotKeyCenter: HotKeyRegistering
    let auditLoggerBox: SendableBox<any AuditLogging>
    let undoManagerBox: SendableBox<any UndoStagingManaging>
    let cursorController: CursorVisualControlling
    let accessibilityPromptController = AccessibilityPromptController()
    var didWarnAccessibility = false

    lazy var hoverMonitor: HoverMonitor = hoverMonitorFactory(
        settings.trigger,
        { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleHoverEvent(event)
            }
        },
        { [weak self] event in
            guard let self else { return }
            self.overlayManager.updateCursorPosition(event.displayLocation)
        },
        { [weak self] isHeld in
            guard let self else { return }
            overlayManager.setIndicatorState(isHeld ? .listening : .idle)
            cursorController.update(listening: isHeld)
        }
    )
    lazy var hudWindowController: HUDWindowControlling = {
        hudWindowFactory(hudViewModel) { [weak self] entry in
            self?.copyToClipboard(entry)
        }
    }()
    let hudViewModel: HUDViewModel
    let resolutionQueue = DispatchQueue(
        label: "io.smalllight.finder-resolution", qos: .userInitiated)

    init(
        settings: AppSettings = AppSettings(),
        overlayManager: OverlayUpdating = OverlayWindowManager(),
        pasteboard: NSPasteboard = .general,
        dedupStore: DeduplicationStore? = nil,
        hoverMonitorFactory:
            @escaping (
                AppSettings.Trigger,
                @escaping HoverMonitor.DwellHandler,
                HoverMonitor.MovementHandler?,
                HoverMonitor.ModifierHandler?
            ) -> HoverMonitor = HoverMonitor.init,
        hudWindowFactory:
            @MainActor @escaping (
                HUDViewModel,
                @escaping (HUDEntry) -> Void
            ) -> HUDWindowControlling = { viewModel, copyHandler in
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
        self.dedupStore =
            dedupStore
            ?? DeduplicationStore(ttl: settings.dedup.ttl, capacity: settings.dedup.capacity)
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
}

struct AppSupportPaths {
    static var baseDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support")
    }

    static var auditLogDirectory: URL {
        baseDirectory.appendingPathComponent("SmallLight/logs", isDirectory: true)
    }
}

/// A lightweight wrapper used to treat non-Sendable protocol conformers as sendable when
/// hopping across queues.
/// The coordinator guarantees main-actor usage, so boxing is safe in practice.
final class SendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

final class AccessibilityPromptController {
    private let defaults: UserDefaults
    private let lastPromptKey = "io.smalllight.accessibility.lastPrompt"
    private let suppressionInterval: TimeInterval = 60 * 60  // one hour

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
