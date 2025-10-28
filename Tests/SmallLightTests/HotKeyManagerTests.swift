import XCTest

@testable import SmallLightDomain
@testable import SmallLightServices

final class HotKeyManagerTests: XCTestCase {
    func testHotKeyEventsToggleState() throws {
        let registrar = RecordingHotKeyRegistrar()
        let state = InMemoryHotKeyState()
        let manager = DefaultHotKeyManager(registrar: registrar, state: state)
        let chord = HotKeyChord(keyCode: 0, modifiers: [.command, .shift])

        try manager.register(chord: chord)

        XCTAssertEqual(registrar.registeredChord, chord)

        registrar.simulate(event: .init(kind: .pressed))
        XCTAssertTrue(state.isModifierChordActive)

        registrar.simulate(event: .init(kind: .released))
        XCTAssertFalse(state.isModifierChordActive)
    }

    func testUnregisterResetsState() throws {
        let registrar = RecordingHotKeyRegistrar()
        let state = InMemoryHotKeyState()
        let manager = DefaultHotKeyManager(registrar: registrar, state: state)

        try manager.register(chord: HotKeyChord(keyCode: 1, modifiers: [.option]))
        registrar.simulate(event: .init(kind: .pressed))
        XCTAssertTrue(state.isModifierChordActive)

        manager.unregister()
        XCTAssertFalse(state.isModifierChordActive)
        XCTAssertTrue(registrar.didUnregister)
    }
}

private final class RecordingHotKeyRegistrar: HotKeyRegistrar {
    private final class Token: HotKeyRegistrationToken {
        private let onUnregister: () -> Void
        private(set) var isUnregistered = false

        init(onUnregister: @escaping () -> Void) {
            self.onUnregister = onUnregister
        }

        func unregister() {
            guard !isUnregistered else { return }
            isUnregistered = true
            onUnregister()
        }
    }

    private(set) var handler: ((HotKeyEvent) -> Void)?
    private(set) var registeredChord: HotKeyChord?
    private(set) var didUnregister = false

    func register(
        chord: HotKeyChord,
        handler: @escaping (HotKeyEvent) -> Void
    ) throws -> HotKeyRegistrationToken {
        registeredChord = chord
        self.handler = handler
        return Token { [weak self] in
            self?.didUnregister = true
            self?.handler = nil
            self?.registeredChord = nil
        }
    }

    func simulate(event: HotKeyEvent) {
        handler?(event)
    }
}
