import Foundation
import SmallLightDomain

public protocol HotKeyRegistrar {
    func register(chord: HotKeyChord, handler: @escaping (HotKeyEvent) -> Void) throws -> HotKeyRegistrationToken
}

public protocol HotKeyRegistrationToken {
    func unregister()
}

public final class DefaultHotKeyManager: HotKeyManaging {
    private let registrar: HotKeyRegistrar
    private let state: HotKeyStateMutating
    private var token: HotKeyRegistrationToken?

    public init(registrar: HotKeyRegistrar, state: HotKeyStateMutating) {
        self.registrar = registrar
        self.state = state
    }

    public func register(chord: HotKeyChord) throws {
        token?.unregister()
        token = try registrar.register(chord: chord) { [weak self] event in
            self?.handle(event: event)
        }
    }

    public func unregister() {
        token?.unregister()
        token = nil
        state.setModifierChordActive(false)
    }

    private func handle(event: HotKeyEvent) {
        switch event.kind {
        case .pressed:
            state.setModifierChordActive(true)
        case .released:
            state.setModifierChordActive(false)
        }
    }
}
