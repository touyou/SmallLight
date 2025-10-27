import XCTest
@testable import SmallLightDomain
@testable import SmallLightServices

final class CompressionFlowAcceptanceTests: XCTestCase {
    func testCompressionFlowTriggeredByModifierChord() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let folderURL = tempDirectory.appendingPathComponent("SampleFolder", isDirectory: true)
        let archiveURL = tempDirectory.appendingPathComponent("SampleFolder.zip")

        let finder = StubFinderTargetingService(initialItem: FinderItem(
            url: folderURL,
            isDirectory: true,
            isArchive: false
        ))
        let hotKeyState = InMemoryHotKeyState(isModifierChordActive: true)
        let compression = RecordingCompressionService(expectedDestination: archiveURL)
        let auditLogger = RecordingAuditLogger()
        let undoManager = RecordingUndoManager(stagingRoot: tempDirectory.appendingPathComponent("staging"))
        let confirmationTracker = RecordingConfirmationTracker()

        let orchestrator = DefaultActionOrchestrator(
            finderService: finder,
            hotKeyState: hotKeyState,
            compressionService: compression,
            auditLogger: auditLogger,
            undoManager: undoManager,
            confirmationTracker: confirmationTracker
        )

        let decision = try XCTUnwrap(orchestrator.evaluatePendingAction())
        XCTAssertTrue(decision.requiresConfirmation)
        XCTAssertEqual(decision.intendedAction, .compress)

        orchestrator.acknowledgeConfirmation(for: decision.item)
        let destination = try orchestrator.perform(decision: decision)
        XCTAssertEqual(destination, archiveURL)

        XCTAssertEqual(auditLogger.records.count, 1)
        XCTAssertEqual(auditLogger.records.first?.action, .compress)
        XCTAssertEqual(auditLogger.records.first?.item, decision.item)
        XCTAssertEqual(auditLogger.records.first?.destination, archiveURL)

        XCTAssertEqual(compression.capturedRequests.count, 1)
        XCTAssertEqual(compression.capturedRequests.first?.source, decision.item)
        XCTAssertEqual(compression.capturedRequests.first?.destinationDirectory, decision.item.url.deletingLastPathComponent())
        XCTAssertEqual(undoManager.stageRequests.count, 1)
        XCTAssertEqual(confirmationTracker.markedURLs, [decision.item.url])
    }
}

private final class RecordingCompressionService: CompressionService {
    struct Request: Equatable {
        let source: FinderItem
        let destinationDirectory: URL
    }

    private let expectedDestination: URL
    private(set) var capturedRequests: [Request] = []

    init(expectedDestination: URL) {
        self.expectedDestination = expectedDestination
    }

    func compress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        capturedRequests.append(Request(source: item, destinationDirectory: destinationDirectory))
        return expectedDestination
    }

    func decompress(item: FinderItem, destinationDirectory: URL) throws -> URL {
        capturedRequests.append(Request(source: item, destinationDirectory: destinationDirectory))
        return expectedDestination.deletingPathExtension()
    }
}

private final class RecordingAuditLogger: AuditLogging {
    struct Record: Equatable {
        let action: SmallLightAction
        let item: FinderItem
        let destination: URL
    }

    private(set) var records: [Record] = []

    func record(action: SmallLightAction, item: FinderItem, destination: URL) throws {
        records.append(Record(action: action, item: item, destination: destination))
    }
}

private final class RecordingUndoManager: UndoStagingManaging {
    private let stagingRoot: URL
    private(set) var stageRequests: [FinderItem] = []

    init(stagingRoot: URL) {
        self.stagingRoot = stagingRoot
    }

    func stagingURL(for item: FinderItem, action: SmallLightAction) throws -> URL {
        stageRequests.append(item)
        return stagingRoot.appendingPathComponent(item.url.lastPathComponent)
    }

    func stageOriginal(at url: URL) throws -> URL {
        stagingRoot.appendingPathComponent(url.lastPathComponent)
    }

    func restore(from stagingURL: URL, to destinationURL: URL) throws {
        // no-op for acceptance stub
    }
}

private final class RecordingConfirmationTracker: ConfirmationTracking {
    private(set) var markedURLs: [URL] = []

    func needsConfirmation(for url: URL) -> Bool {
        !markedURLs.contains(url)
    }

    func markConfirmed(for url: URL) {
        if !markedURLs.contains(url) {
            markedURLs.append(url)
        }
    }

    func resetConfirmation(for url: URL) {
        markedURLs.removeAll { $0 == url }
    }
}
