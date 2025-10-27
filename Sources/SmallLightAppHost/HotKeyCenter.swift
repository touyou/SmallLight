import Foundation
import SmallLightDomain
import SmallLightServices

@MainActor
protocol HotKeyRegistering {
    func register(_ entries: [(HotKeyChord, () -> Void)]) throws
    func unregisterAll()
}

/// Manages global hotkey registrations and dispatches pressed events to callbacks.
final class HotKeyCenter {
    private struct Registration {
        let registrar: HotKeyRegistrar
        let token: HotKeyRegistrationToken
    }

    private var registrations: [Registration] = []
    private let registrarFactory: () -> HotKeyRegistrar

    init(registrarFactory: @escaping () -> HotKeyRegistrar = { CarbonHotKeyRegistrar() }) {
        self.registrarFactory = registrarFactory
    }

    func register(_ entries: [(HotKeyChord, () -> Void)]) throws {
        unregisterAll()
        do {
            for (chord, handler) in entries {
                let registrar = registrarFactory()
                let token = try registrar.register(chord: chord) { event in
                    guard event.kind == .pressed else { return }
                    handler()
                }
                registrations.append(Registration(registrar: registrar, token: token))
            }
        } catch {
            unregisterAll()
            throw error
        }
    }

    func unregisterAll() {
        registrations.forEach { $0.token.unregister() }
        registrations.removeAll()
    }
}

extension HotKeyCenter: HotKeyRegistering {}
