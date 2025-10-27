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
        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKey,
            compressionService: compression,
            auditLogger: logger,
            undoManager: undo
        )
        let viewModel = AppViewModel(orchestrator: orchestrator)

        viewModel.refreshState()
        XCTAssertTrue(viewModel.isListening)
        XCTAssertEqual(viewModel.statusText, "Compress ready")
    }
}
