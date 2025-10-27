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
        XCTAssertTrue(viewModel.isAwaitingConfirmation)
        XCTAssertEqual(viewModel.statusText, String(format: NSLocalizedString("status.confirmation", bundle: .main, comment: ""), NSLocalizedString("status.compress.ready", bundle: .main, comment: "")))

        viewModel.confirmPendingAction()
        XCTAssertFalse(viewModel.isAwaitingConfirmation)
        XCTAssertTrue(viewModel.canExecuteAction)
        XCTAssertEqual(viewModel.statusText, NSLocalizedString("status.compress.ready", bundle: .main, comment: ""))

        viewModel.performPendingAction()
        XCTAssertNotNil(viewModel.lastActionDescription)
        XCTAssertNotNil(viewModel.lastAction)
        viewModel.undoLastAction()
    }
}

private final class UITestConfirmationTracker: ConfirmationTracking {
    private var confirmed: Set<URL> = []

    func needsConfirmation(for url: URL) -> Bool {
        !confirmed.contains(url)
    }

    func markConfirmed(for url: URL) {
        confirmed.insert(url)
    }

    func resetConfirmation(for url: URL) {
        confirmed.remove(url)
    }
}
