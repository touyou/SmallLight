import XCTest
@testable import SmallLightDomain
@testable import SmallLightServices
@testable import SmallLightUI

final class MenuBarViewModelTests: XCTestCase {
    @MainActor
    func testRefreshStateReflectsListeningStatus() {
        let item = FinderItem(url: URL(fileURLWithPath: "/tmp/folder"), isDirectory: true, isArchive: false)
        let finder = StubFinderTargetingService(initialItem: item)
        let hotKey = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = StubCompressionService()
        let logger = NoopAuditLogger()
        let undo = StubUndoStagingManager()
        let confirmation = UITestConfirmationTracker()
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo,
            confirmationTracker: confirmation
        )
        let viewModel = AppViewModel(orchestrator: orchestrator)

        viewModel.refreshState()
        XCTAssertTrue(viewModel.isListening)
        XCTAssertEqual(viewModel.statusText, "Compress ready")
    }
}

private final class UITestConfirmationTracker: ConfirmationTracking {
    func needsConfirmation(for url: URL) -> Bool {
        true
    }

    func markConfirmed(for url: URL) {
        // no-op
    }

    func resetConfirmation(for url: URL) {
        // no-op
    }
}
