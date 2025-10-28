import XCTest

@testable import SmallLightDomain
@testable import SmallLightServices

final class ActionOrchestratorTests: XCTestCase {
    func testEvaluatePendingActionReturnsNilWhenHotKeyNotActive() throws {
        let finder = StubFinderTargetingService()
        let hotKey = InMemoryHotKeyState(isModifierChordActive: false)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let confirmation = TestConfirmationTracker()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo,
            confirmationTracker: confirmation
        )

        XCTAssertNil(try orchestrator.evaluatePendingAction())
    }

    func testEvaluatePendingActionReturnsCompressForDirectory() throws {
        let finder = StubFinderTargetingService(
            initialItem: FinderItem(
                url: URL(fileURLWithPath: "/tmp/folder"),
                isDirectory: true,
                isArchive: false
            ))
        let hotKey = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let confirmation = TestConfirmationTracker()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo,
            confirmationTracker: confirmation
        )

        let decision = try XCTUnwrap(orchestrator.evaluatePendingAction())
        XCTAssertEqual(decision.intendedAction, .compress)
        XCTAssertTrue(decision.requiresConfirmation)
    }

    func testEvaluatePendingActionReturnsDecompressForArchive() throws {
        let finder = StubFinderTargetingService(
            initialItem: FinderItem(
                url: URL(fileURLWithPath: "/tmp/archive.zip"),
                isDirectory: false,
                isArchive: true
            ))
        let hotKey = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let confirmation = TestConfirmationTracker()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo,
            confirmationTracker: confirmation
        )

        let decision = try XCTUnwrap(orchestrator.evaluatePendingAction())
        XCTAssertEqual(decision.intendedAction, .decompress)
        XCTAssertTrue(decision.requiresConfirmation)
    }

    func testPerformThrowsWhenConfirmationNotAcknowledged() throws {
        let item = FinderItem(
            url: URL(fileURLWithPath: "/tmp/folder"),
            isDirectory: true,
            isArchive: false
        )
        let finder = StubFinderTargetingService(initialItem: item)
        let hotKey = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let confirmation = TestConfirmationTracker()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo,
            confirmationTracker: confirmation
        )

        let decision = try XCTUnwrap(orchestrator.evaluatePendingAction())
        XCTAssertThrowsError(try orchestrator.perform(decision: decision)) { error in
            XCTAssertEqual(error as? SmallLightError, .confirmationPending)
        }
    }

    func testPerformSucceedsAfterConfirmationAcknowledged() throws {
        let item = FinderItem(
            url: URL(fileURLWithPath: "/tmp/folder"),
            isDirectory: true,
            isArchive: false
        )
        let finder = StubFinderTargetingService(initialItem: item)
        let hotKey = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let confirmation = TestConfirmationTracker()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo,
            confirmationTracker: confirmation
        )

        let decision = try XCTUnwrap(orchestrator.evaluatePendingAction())
        orchestrator.acknowledgeConfirmation(for: decision.item)
        let destination = try orchestrator.perform(decision: decision)

        XCTAssertEqual(destination, item.url)
        XCTAssertEqual(confirmation.markedURLs, [item.url])
    }
}

private final class TestConfirmationTracker: ConfirmationTracking {
    var needsConfirmationReturn: Bool = true
    private(set) var markedURLs: [URL] = []

    func needsConfirmation(for url: URL) -> Bool {
        needsConfirmationReturn
    }

    func markConfirmed(for url: URL) {
        needsConfirmationReturn = false
        if !markedURLs.contains(url) {
            markedURLs.append(url)
        }
    }

    func resetConfirmation(for url: URL) {
        needsConfirmationReturn = true
    }
}
