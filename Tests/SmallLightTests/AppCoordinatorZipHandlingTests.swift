@testable import SmallLightAppHost
import AppKit
import SmallLightDomain
import SmallLightServices
import SmallLightUI
import XCTest

@MainActor
final class AppCoordinatorZipHandlingTests: XCTestCase {
    func testZipExtractionSuccessRecordsAuditAndHud() {
        let fixture = makeCoordinator(zipResult: .success(URL(fileURLWithPath: "/tmp/archive_unpacked")))

    fixture.overlay.setIndicatorState(.listening)
        fixture.overlay.updateCursorPosition(.zero)
        fixture.instance.manualResolve()

        wait(for: fixture.overlay.updateExpectation, fixture.resolver.expectation, fixture.zipExpectation)
        waitForHUDHistory(of: fixture.instance)

        XCTAssertEqual(fixture.zipHandler.recordedZipPath, "/tmp/archive.zip")
        XCTAssertEqual(fixture.auditLogger.records.first?.action, .decompress)
        XCTAssertEqual(fixture.auditLogger.records.first?.destination.path, "/tmp/archive_unpacked")
        XCTAssertEqual(fixture.instance.hudModel.history.first?.path, "/tmp/archive_unpacked")
        XCTAssertEqual(fixture.instance.hudModel.history.first?.message, UILocalized.formatted("hud.zip.success", "/tmp/archive_unpacked"))
        XCTAssertEqual(fixture.undoManager.stagedOriginals.count, 1)
    XCTAssertTrue(fixture.overlay.recordedStates.contains(.listening))
    }

    func testZipExtractionFailureClearsDedupAndShowsError() {
        let error = ZipHandlerError.dittoFailed(code: 1, message: "ditto failed")
        let fixture = makeCoordinator(zipResult: .failure(error))

    fixture.overlay.setIndicatorState(.listening)
        fixture.overlay.updateCursorPosition(.zero)
        fixture.instance.manualResolve()

        wait(for: fixture.overlay.updateExpectation, fixture.resolver.expectation, fixture.zipExpectation)
        waitForHUDHistory(of: fixture.instance)

        let dedupKey = "/tmp/archive.zip::resolve"
        XCTAssertFalse(fixture.dedup.isDuplicate(dedupKey))
        XCTAssertTrue(fixture.auditLogger.records.isEmpty)
        XCTAssertEqual(fixture.instance.hudModel.history.first?.path, "/tmp/archive.zip")
        XCTAssertEqual(fixture.instance.hudModel.history.first?.message, UILocalized.formatted("hud.zip.error", "ditto failed"))
        XCTAssertTrue(fixture.compression.compressRequests.isEmpty)
    }

    func testCompressionSuccessRecordsAuditAndHud() {
        let compressedURL = URL(fileURLWithPath: "/tmp/folder.zip")
        let fixture = makeCompressionCoordinator(compressResult: .success(compressedURL))

        let compressionExpectation = expectation(description: "compression invoked")
        fixture.compression.expectation = compressionExpectation

    fixture.overlay.setIndicatorState(.listening)
        fixture.overlay.updateCursorPosition(.zero)
        fixture.instance.manualResolve()

        wait(for: fixture.overlay.updateExpectation, fixture.resolver.expectation, compressionExpectation)
        waitForHUDHistory(of: fixture.instance)

        XCTAssertEqual(fixture.compression.compressRequests.count, 1)
        XCTAssertEqual(fixture.compression.compressRequests.first?.item.url.path, "/tmp/folder")
        XCTAssertEqual(fixture.compression.compressRequests.first?.destinationDirectory.path, "/tmp")
        XCTAssertEqual(fixture.auditLogger.records.first?.action, .compress)
        XCTAssertEqual(fixture.auditLogger.records.first?.destination.path, compressedURL.path)
        XCTAssertEqual(fixture.undoManager.stagedOriginals, [URL(fileURLWithPath: "/tmp/folder")])
        XCTAssertEqual(fixture.instance.hudModel.history.first?.path, compressedURL.path)
        XCTAssertEqual(fixture.instance.hudModel.history.first?.message, UILocalized.formatted("hud.compress.success", compressedURL.path))
    }

    private func wait(for expectations: XCTestExpectation...) {
        wait(for: expectations, timeout: 1.0)
    }

    private func waitForHUDHistory(of coordinator: AppCoordinator) {
        let expectation = expectation(description: "hud history updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func makeCoordinator(zipResult: Result<URL, Error>) -> TestFixture {
        let settings = AppSettings()
        let overlay = OverlayStub()
        let hud = HUDStub()
        let resolver = ResolverStub(result: FinderItemResolution(path: "/tmp/archive.zip", isDirectory: false, isArchive: true))
        let zipHandler = ZipHandlerStub(result: zipResult)
        let hotKeys = HotKeyCenterStub()
        let dedup = DeduplicationStore(ttl: 10, capacity: 8)
        let auditLogger = AuditLoggerStub()
        let undoManager = UndoManagerStub()
        let cursor = CursorControllerStub()
        let compression = RecordingCompressionService()

        let coordinator = AppCoordinator(
            settings: settings,
            overlayManager: overlay,
            pasteboard: .general,
            dedupStore: dedup,
            hoverMonitorFactory: { triggerSettings, dwellHandler, _, modifier in
                modifier?(true)
                return HoverMonitor(settings: triggerSettings, handler: dwellHandler)
            },
            hudWindowFactory: { _, _ in hud },
            resolver: resolver,
            compressionService: compression,
            zipHandler: zipHandler,
            hotKeyCenter: hotKeys,
            auditLogger: auditLogger,
            undoManager: undoManager,
            cursorController: cursor
        )

        return TestFixture(
            instance: coordinator,
            overlay: overlay,
            resolver: resolver,
            zipHandler: zipHandler,
            auditLogger: auditLogger,
            undoManager: undoManager,
            dedup: dedup,
            zipExpectation: zipHandler.expectation,
            compression: compression
        )
    }

    private func makeCompressionCoordinator(compressResult: Result<URL, Error>) -> CompressionFixture {
        var settings = AppSettings()
        settings.zip.behaviour = .auto
        let overlay = OverlayStub()
        let hud = HUDStub()
        let resolver = ResolverStub(result: FinderItemResolution(path: "/tmp/folder", isDirectory: true, isArchive: false))
        let compression = RecordingCompressionService(result: compressResult)
        let zipHandler = ZipHandlerStub(result: .success(URL(fileURLWithPath: "/tmp/archive_unpacked")))
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
            hoverMonitorFactory: { triggerSettings, dwellHandler, _, modifier in
                modifier?(true)
                return HoverMonitor(settings: triggerSettings, handler: dwellHandler)
            },
            hudWindowFactory: { _, _ in hud },
            resolver: resolver,
            compressionService: compression,
            zipHandler: zipHandler,
            hotKeyCenter: hotKeys,
            auditLogger: auditLogger,
            undoManager: undoManager,
            cursorController: cursor
        )

        return CompressionFixture(
            instance: coordinator,
            overlay: overlay,
            resolver: resolver,
            compression: compression,
            auditLogger: auditLogger,
            undoManager: undoManager
        )
    }

    private struct TestFixture {
        let instance: AppCoordinator
        let overlay: OverlayStub
        let resolver: ResolverStub
        let zipHandler: ZipHandlerStub
        let auditLogger: AuditLoggerStub
        let undoManager: UndoManagerStub
        let dedup: DeduplicationStore
        let zipExpectation: XCTestExpectation
        let compression: RecordingCompressionService
    }

    private struct CompressionFixture {
        let instance: AppCoordinator
        let overlay: OverlayStub
        let resolver: ResolverStub
        let compression: RecordingCompressionService
        let auditLogger: AuditLoggerStub
        let undoManager: UndoManagerStub
    }
}

// MARK: - Test Doubles

private final class RecordingCompressionService: CompressionService, @unchecked Sendable {
    struct Request: Equatable {
        let item: FinderItem
        let destinationDirectory: URL
    }

    private(set) var compressRequests: [Request] = []
    var compressResult: Result<URL, Error>
    var expectation: XCTestExpectation?

    init(result: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/compressed.zip"))) {
        self.compressResult = result
    }

    func compress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        compressRequests.append(Request(item: item, destinationDirectory: destinationDirectory))
        expectation?.fulfill()
        switch compressResult {
        case let .success(url):
            return url
        case let .failure(error):
            throw error
        }
    }

    func decompress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        destinationDirectory
    }
}

@MainActor
private final class OverlayStub: OverlayUpdating {
    let updateExpectation = XCTestExpectation(description: "overlay updated")
    private(set) var recordedStates: [OverlayIndicatorState] = []

    func updateCursorPosition(_ point: CGPoint) {
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

private final class ZipHandlerStub: ZipHandling, @unchecked Sendable {
    private let result: Result<URL, Error>
    private(set) var recordedZipPath: String?
    let expectation = XCTestExpectation(description: "zip handler invoked")

    init(result: Result<URL, Error>) {
        self.result = result
    }

    func extract(zipPath: String) throws -> URL {
        recordedZipPath = zipPath
        expectation.fulfill()
        switch result {
        case let .success(url):
            return url
        case let .failure(error):
            throw error
        }
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

private final class CursorControllerStub: CursorVisualControlling {
    func update(listening: Bool) {}
    func reset() {}
}
