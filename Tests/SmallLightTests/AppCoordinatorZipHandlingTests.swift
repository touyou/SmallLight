@testable import SmallLightAppHost
import AppKit
import SmallLightDomain
import SmallLightServices
import SmallLightUI
import XCTest

@MainActor
final class AppCoordinatorZipHandlingTests: XCTestCase {
    func testZipExtractionSuccessRecordsAuditAndHud() {
        let settings = AppSettings()
        let overlay = OverlayStub()
        let hud = HUDStub()
        let resolver = ResolverStub(result: FinderItemResolution(path: "/tmp/archive.zip", isDirectory: false, isArchive: true))
        let zipHandler = ZipHandlerStubSuccess(destination: URL(fileURLWithPath: "/tmp/archive_unpacked"))
        let hotKeys = HotKeyCenterStub()
        let dedup = DeduplicationStore(ttl: 10, capacity: 8)
        let auditLogger = AuditLoggerStub()
        let undoManager = UndoManagerStub()

        let coordinator = AppCoordinator(
            settings: settings,
            overlayManager: overlay,
            pasteboard: .general,
            dedupStore: dedup,
            hoverMonitorFactory: { triggerSettings, handler in
                HoverMonitor(settings: triggerSettings, handler: handler)
            },
            hudWindowFactory: { _, _ in hud },
            resolver: resolver,
            zipHandler: zipHandler,
            hotKeyCenter: hotKeys,
            auditLogger: auditLogger,
            undoManager: undoManager
        )

        coordinator.manualResolve()

        wait(for: [overlay.updateExpectation, resolver.expectation, zipHandler.expectation], timeout: 1.0)
        waitForHUDHistory(of: coordinator)

        XCTAssertEqual(zipHandler.recordedZipPath, "/tmp/archive.zip")
        XCTAssertEqual(auditLogger.records.first?.action, .decompress)
        XCTAssertEqual(auditLogger.records.first?.destination.path, "/tmp/archive_unpacked")
        XCTAssertEqual(coordinator.hudModel.history.first?.path, "/tmp/archive_unpacked")
        XCTAssertEqual(coordinator.hudModel.history.first?.message, UILocalized.formatted("hud.zip.success", "/tmp/archive_unpacked"))
        XCTAssertEqual(undoManager.stagedOriginals.count, 1)
    }

    func testZipExtractionFailureClearsDedupAndShowsError() {
        let settings = AppSettings()
        let overlay = OverlayStub()
        let hud = HUDStub()
        let resolver = ResolverStub(result: FinderItemResolution(path: "/tmp/archive.zip", isDirectory: false, isArchive: true))
        let zipHandler = ZipHandlerStubFailure(error: ZipHandlerError.dittoFailed(code: 1, message: "ditto failed"))
        let hotKeys = HotKeyCenterStub()
        let dedup = DeduplicationStore(ttl: 10, capacity: 8)
        let auditLogger = AuditLoggerStub()
        let undoManager = UndoManagerStub()

        let coordinator = AppCoordinator(
            settings: settings,
            overlayManager: overlay,
            pasteboard: .general,
            dedupStore: dedup,
            hoverMonitorFactory: { triggerSettings, handler in
                HoverMonitor(settings: triggerSettings, handler: handler)
            },
            hudWindowFactory: { _, _ in hud },
            resolver: resolver,
            zipHandler: zipHandler,
            hotKeyCenter: hotKeys,
            auditLogger: auditLogger,
            undoManager: undoManager
        )

        coordinator.manualResolve()

        wait(for: [overlay.updateExpectation, resolver.expectation, zipHandler.expectation], timeout: 1.0)
        waitForHUDHistory(of: coordinator)

        let dedupKey = "/tmp/archive.zip::resolve"
        XCTAssertFalse(dedup.isDuplicate(dedupKey))
        XCTAssertTrue(auditLogger.records.isEmpty)
        XCTAssertEqual(coordinator.hudModel.history.first?.path, "/tmp/archive.zip")
        XCTAssertEqual(coordinator.hudModel.history.first?.message, UILocalized.formatted("hud.zip.error", "ditto failed"))
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

    func updateCursorPosition(_ point: CGPoint) {
        updateExpectation.fulfill()
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
}

private final class ResolverStub: FinderItemResolving, @unchecked Sendable {
    private let result: FinderItemResolution?
    let expectation = XCTestExpectation(description: "resolver invoked")

    init(result: FinderItemResolution?) {
        self.result = result
    }

    func resolveItem(at screenPoint: CGPoint) throws -> FinderItemResolution? {
        expectation.fulfill()
        return result
    }
}

private final class ZipHandlerStubSuccess: ZipHandling, @unchecked Sendable {
    let destination: URL
    private(set) var recordedZipPath: String?
    let expectation = XCTestExpectation(description: "zip handler invoked")

    init(destination: URL) {
        self.destination = destination
    }

    func extract(zipPath: String) throws -> URL {
        recordedZipPath = zipPath
        expectation.fulfill()
        return destination
    }
}

private final class ZipHandlerStubFailure: ZipHandling, @unchecked Sendable {
    let error: Error
    let expectation = XCTestExpectation(description: "zip handler invoked")

    init(error: Error) {
        self.error = error
    }

    func extract(zipPath: String) throws -> URL {
        expectation.fulfill()
        throw error
    }
}

@MainActor
private final class HotKeyCenterStub: HotKeyRegistering {
    func register(_ entries: [(HotKeyChord, () -> Void)]) throws {}
    func unregisterAll() {}
}

private final class AuditLoggerStub: AuditLogging, @unchecked Sendable {
    struct Record {
        let action: SmallLightAction
        let destination: URL
    }

    private(set) var records: [Record] = []

    func record(action: SmallLightAction, item: FinderItem, destination: URL) throws {
        records.append(Record(action: action, destination: destination))
    }
}

private final class UndoManagerStub: UndoStagingManaging, @unchecked Sendable {
    private(set) var stagedOriginals: [URL] = []

    func stagingURL(for item: FinderItem, action: SmallLightAction) throws -> URL {
        URL(fileURLWithPath: "/tmp/staging/\(UUID().uuidString)")
    }

    func stageOriginal(at url: URL) throws -> URL {
        stagedOriginals.append(url)
        return URL(fileURLWithPath: "/tmp/staging/original-\(UUID().uuidString)")
    }

    func restore(from stagingURL: URL, to destinationURL: URL) throws {}
}
