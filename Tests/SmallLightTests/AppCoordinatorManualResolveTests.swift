@testable import SmallLightAppHost
import AppKit
import SmallLightDomain
import SmallLightServices
import SmallLightUI
import XCTest

@MainActor
final class AppCoordinatorManualResolveTests: XCTestCase {
    func testManualResolveBypassesDedup() throws {
        let settings = AppSettings()
        let overlay = OverlayStub()
        let hud = HUDStub()
        let resolver = ResolverStub(result: FinderItemResolution(path: "/tmp/manual.txt", isDirectory: false, isArchive: false))
        let zip = ZipHandlerStub()
        let compression = StubCompressionService()
        let hotKeys = HotKeyCenterStub()
        let dedup = DeduplicationStore(ttl: 10, capacity: 8)
        let auditLogger = AuditLoggerStub()
        let undoManager = UndoManagerStub()
        let cursor = CursorControllerStub()

        let coordinator = AppCoordinator(
            settings: settings,
            overlayManager: overlay,
            pasteboard: .general,
            dedupStore: dedup,
            hoverMonitorFactory: { triggerSettings, dwellHandler, _, _ in
                HoverMonitor(settings: triggerSettings, handler: dwellHandler)
            },
            hudWindowFactory: { _, _ in hud },
            resolver: resolver,
            compressionService: compression,
            zipHandler: zip,
            hotKeyCenter: hotKeys,
            auditLogger: auditLogger,
            undoManager: undoManager,
            cursorController: cursor
        )

        let key = "/tmp/manual.txt::resolve"
        dedup.record(key)

        coordinator.manualResolve()

        wait(for: [overlay.updateExpectation, resolver.expectation], timeout: 1.0)
        waitForHUDHistory(of: coordinator)

        XCTAssertEqual(resolver.callCount, 1, "Manual resolve should invoke resolver even when dedup contains the key")
        XCTAssertEqual(coordinator.hudModel.history.first?.path, "/tmp/manual.txt")
        let expectedMessage = UILocalized.formatted("hud.info.file", "/tmp")
        XCTAssertEqual(coordinator.hudModel.history.first?.message, expectedMessage)
        XCTAssertTrue(overlay.receivedUpdate, "Manual resolve should update overlay position")
    }

    func testModifierToggleUpdatesOverlayAndCursorStates() {
        let settings = AppSettings()
        let overlay = OverlayStub()
        let hud = HUDStub()
        let resolver = ResolverStub(result: nil)
        let zip = ZipHandlerStub()
        let compression = StubCompressionService()
        let hotKeys = HotKeyCenterStub()
        let dedup = DeduplicationStore(ttl: 10, capacity: 8)
        let auditLogger = AuditLoggerStub()
        let undoManager = UndoManagerStub()
        let cursor = CursorControllerStub()

        var capturedModifier: HoverMonitor.ModifierHandler?

        let coordinator = AppCoordinator(
            settings: settings,
            overlayManager: overlay,
            pasteboard: .general,
            dedupStore: dedup,
            hoverMonitorFactory: { triggerSettings, dwellHandler, movementHandler, modifier in
                capturedModifier = modifier
                return HoverMonitor(settings: triggerSettings, handler: dwellHandler, movementHandler: movementHandler, modifierHandler: modifier)
            },
            hudWindowFactory: { _, _ in hud },
            resolver: resolver,
            compressionService: compression,
            zipHandler: zip,
            hotKeyCenter: hotKeys,
            auditLogger: auditLogger,
            undoManager: undoManager,
            cursorController: cursor
        )

    coordinator.start()
    defer { coordinator.stop() }

        XCTAssertNotNil(capturedModifier)

        capturedModifier?(true)
        capturedModifier?(false)

        XCTAssertEqual(overlay.recordedStates, [.idle, .listening, .idle])
        XCTAssertEqual(cursor.listeningStates, [false, true, false])
        XCTAssertFalse(hud.isVisible)
        XCTAssertFalse(coordinator.hudVisible)
    }

    private func waitForHUDHistory(of coordinator: AppCoordinator) {
        let expectation = expectation(description: "hud history updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Test Doubles

@MainActor
private final class OverlayStub: OverlayUpdating {
    let updateExpectation = XCTestExpectation(description: "overlay updated")
    private(set) var receivedUpdate = false
    private(set) var recordedStates: [OverlayIndicatorState] = []

    func updateCursorPosition(_ point: CGPoint) {
        receivedUpdate = true
        updateExpectation.fulfill()
    }

    func setIndicatorState(_ state: OverlayIndicatorState) {
        recordedStates.append(state)
    }

    func reset() {
        recordedStates.append(.hidden)
    }
}

@MainActor
private final class HUDStub: HUDWindowControlling {
    var isVisible = false

    func show() {
        isVisible = true
    }

    func hide() {
        isVisible = false
    }

    func focus() {
        isVisible = true
    }

    func updatePosition(nearestTo point: CGPoint?) {}

    func setPositioningMode(_ mode: HUDPositioningMode) {}
}

private final class ResolverStub: FinderItemResolving, @unchecked Sendable {
    private let result: FinderItemResolution?
    private let lock = NSLock()
    private var callCountStorage = 0
    let expectation = XCTestExpectation(description: "resolver invoked")

    init(result: FinderItemResolution?) {
        self.result = result
    }

    func resolveItem(at screenPoint: CGPoint) throws -> FinderItemResolution? {
        lock.lock()
        callCountStorage += 1
        lock.unlock()
        expectation.fulfill()
        return result
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return callCountStorage
    }
}

private final class ZipHandlerStub: ZipHandling, @unchecked Sendable {
    func extract(zipPath: String) throws -> URL {
        XCTFail("Zip extraction should not be invoked for non-archive manual resolve")
        return URL(fileURLWithPath: "/tmp/unused")
    }
}

@MainActor
private final class HotKeyCenterStub: HotKeyRegistering {
    func register(_ entries: [(HotKeyChord, () -> Void)]) throws {}
    func unregisterAll() {}
}

private final class AuditLoggerStub: AuditLogging, @unchecked Sendable {
    private(set) var records: [(SmallLightAction, FinderItem, URL)] = []

    func record(action: SmallLightAction, item: FinderItem, destination: URL) throws {
        records.append((action, item, destination))
    }
}

private final class UndoManagerStub: UndoStagingManaging, @unchecked Sendable {
    func stagingURL(for item: FinderItem, action: SmallLightAction) throws -> URL {
        URL(fileURLWithPath: "/tmp/staging/\(UUID().uuidString)")
    }

    func stageOriginal(at url: URL) throws -> URL {
        URL(fileURLWithPath: "/tmp/staging/original-\(UUID().uuidString)")
    }

    func restore(from stagingURL: URL, to destinationURL: URL) throws {}
}

private final class CursorControllerStub: CursorVisualControlling {
    private(set) var listeningStates: [Bool] = []

    func update(listening: Bool) {
        listeningStates.append(listening)
    }

    func reset() {
        listeningStates.append(false)
    }
}
