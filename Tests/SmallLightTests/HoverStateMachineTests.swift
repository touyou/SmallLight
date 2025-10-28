import CoreGraphics
import XCTest

@testable import SmallLightAppHost

final class HoverStateMachineTests: XCTestCase {
    private let dwell: TimeInterval = 0.2
    private let debounce: TimeInterval = 0.08
    private let optionFlag: CGEventFlags = .maskAlternate

    func testDwellFiresAfterThreshold() {
        var machine = makeMachine()

        // Move without modifier to seed location.
        _ = machine.handleMouseMove(
            displayLocation: CGPoint(x: 100, y: 200), hitTestLocation: CGPoint(x: 100, y: 200),
            flags: [], timestamp: 0.0)
        // Modifier pressed starts dwell.
        let action = machine.handleFlagsChange(flags: optionFlag, timestamp: 0.05)
        XCTAssertEqual(action, .startDwell)

        // Timer before threshold should not trigger.
        XCTAssertNil(machine.handleDwellTimer(timestamp: 0.20))
        // After threshold dwell event emitted.
        let trigger = machine.handleDwellTimer(timestamp: 0.26)
        XCTAssertEqual(trigger?.displayLocation, CGPoint(x: 100, y: 200))
        XCTAssertEqual(trigger?.modifiers, optionFlag)
    }

    func testMovementResetsDwell() {
        var machine = makeMachine()

        _ = machine.handleFlagsChange(flags: optionFlag, timestamp: 0.0)
        var action = machine.handleMouseMove(
            displayLocation: CGPoint(x: 50, y: 50), hitTestLocation: CGPoint(x: 50, y: 50),
            flags: optionFlag, timestamp: 0.01)
        XCTAssertEqual(action, .startDwell)

        // Move significantly before dwell threshold; should restart.
        action = machine.handleMouseMove(
            displayLocation: CGPoint(x: 120, y: 120), hitTestLocation: CGPoint(x: 120, y: 120),
            flags: optionFlag, timestamp: 0.05)
        XCTAssertEqual(action, .startDwell)

        // Timer for old position should be ignored (< dwell threshold since restart).
        XCTAssertNil(machine.handleDwellTimer(timestamp: 0.19))

        // After dwell threshold from last move event, trigger occurs.
        let trigger = machine.handleDwellTimer(timestamp: 0.26)
        XCTAssertEqual(trigger?.displayLocation, CGPoint(x: 120, y: 120))
    }

    func testDebouncePreventsRapidRetrigger() {
        var machine = makeMachine()

        _ = machine.handleMouseMove(
            displayLocation: CGPoint(x: 10, y: 10), hitTestLocation: CGPoint(x: 10, y: 10),
            flags: optionFlag, timestamp: 0.0)
        _ = machine.handleFlagsChange(flags: optionFlag, timestamp: 0.0)
        XCTAssertNotNil(machine.handleDwellTimer(timestamp: 0.21))

        // Re-arm dwell at same spot.
        let action = machine.handleMouseMove(
            displayLocation: CGPoint(x: 10, y: 10), hitTestLocation: CGPoint(x: 10, y: 10),
            flags: optionFlag, timestamp: 0.22)
        XCTAssertEqual(action, .startDwell)

        // Firing before debounce interval should be ignored.
        XCTAssertNil(machine.handleDwellTimer(timestamp: 0.27))

        // After debounce period has elapsed, trigger allowed again.
        XCTAssertNil(machine.handleDwellTimer(timestamp: 0.31))
        let trigger = machine.handleDwellTimer(timestamp: 0.43)
        XCTAssertNotNil(trigger)
    }

    func testModifierReleaseCancelsDwell() {
        var machine = makeMachine()

        _ = machine.handleFlagsChange(flags: optionFlag, timestamp: 0.0)
        _ = machine.handleMouseMove(
            displayLocation: CGPoint(x: 5, y: 5), hitTestLocation: CGPoint(x: 5, y: 5),
            flags: optionFlag, timestamp: 0.01)
        XCTAssertEqual(
            machine.handleDwellTimer(timestamp: 0.22)?.displayLocation, CGPoint(x: 5, y: 5))

        // Re-arm dwell by moving slightly.
        var action = machine.handleMouseMove(
            displayLocation: CGPoint(x: 6, y: 5), hitTestLocation: CGPoint(x: 6, y: 5),
            flags: optionFlag, timestamp: 0.23)
        XCTAssertEqual(action, .startDwell)

        // Modifier lifted cancels dwell.
        action = machine.handleFlagsChange(flags: [], timestamp: 0.24)
        XCTAssertEqual(action, .cancelDwell)

        XCTAssertNil(machine.handleDwellTimer(timestamp: 0.40))
    }

    private func makeMachine() -> HoverStateMachine {
        HoverStateMachine(
            dwellThreshold: dwell,
            debounceInterval: debounce,
            requiredFlags: optionFlag
        )
    }
}
