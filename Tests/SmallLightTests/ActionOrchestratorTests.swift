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
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo
        )

        XCTAssertNil(try orchestrator.evaluatePendingAction())
    }

    func testEvaluatePendingActionReturnsCompressForDirectory() throws {
        let finder = StubFinderTargetingService(initialItem: FinderItem(
            url: URL(fileURLWithPath: "/tmp/folder"),
            isDirectory: true,
            isArchive: false
        ))
        let hotKey = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo
        )

        let decision = try XCTUnwrap(orchestrator.evaluatePendingAction())
        XCTAssertEqual(decision.intendedAction, .compress)
    }

    func testEvaluatePendingActionReturnsDecompressForArchive() throws {
        let finder = StubFinderTargetingService(initialItem: FinderItem(
            url: URL(fileURLWithPath: "/tmp/archive.zip"),
            isDirectory: false,
            isArchive: true
        ))
        let hotKey = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo
        )

        let decision = try XCTUnwrap(orchestrator.evaluatePendingAction())
        XCTAssertEqual(decision.intendedAction, .decompress)
    }
}
