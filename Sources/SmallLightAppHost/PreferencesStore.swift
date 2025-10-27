import Combine
import Foundation
import SmallLightDomain

@MainActor
protocol PreferencesStoring: AnyObject {
    var undoRetentionInterval: TimeInterval { get set }
    var assetPackPath: String? { get set }
    var launchAtLogin: Bool { get set }
    var preferredHotKey: HotKeyChord { get set }

    var preferencesDidChange: AnyPublisher<Void, Never> { get }
}

@MainActor
final class PreferencesStore: PreferencesStoring {
    static let shared = PreferencesStore()

    private enum Keys {
        static let undoRetention = "io.smalllight.preferences.undoRetention"
        static let assetPackPath = "io.smalllight.preferences.assetPackPath"
        static let launchAtLogin = "io.smalllight.preferences.launchAtLogin"
        static let hotKeyModifiers = "io.smalllight.preferences.hotKeyModifiers"
        static let hotKeyCode = "io.smalllight.preferences.hotKeyCode"
    }

    private let defaults: UserDefaults
    private let subject = PassthroughSubject<Void, Never>()

    var preferencesDidChange: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var undoRetentionInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: Keys.undoRetention)
            return stored > 0 ? stored : 60 * 60 * 24 * 7
        }
        set {
            defaults.set(newValue, forKey: Keys.undoRetention)
            subject.send()
        }
    }

    var assetPackPath: String? {
        get { defaults.string(forKey: Keys.assetPackPath) }
        set {
            defaults.set(newValue, forKey: Keys.assetPackPath)
            subject.send()
        }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            subject.send()
        }
    }

    var preferredHotKey: HotKeyChord {
        get {
            let code = defaults.object(forKey: Keys.hotKeyCode) as? UInt32 ?? HotKeyChord.defaultActionChord.keyCode
            let modifiersRaw = defaults.object(forKey: Keys.hotKeyModifiers) as? UInt32 ?? HotKeyChord.defaultActionChord.modifiers.rawValue
            return HotKeyChord(keyCode: code, modifiers: HotKeyModifiers(rawValue: modifiersRaw))
        }
        set {
            defaults.set(newValue.keyCode, forKey: Keys.hotKeyCode)
            defaults.set(newValue.modifiers.rawValue, forKey: Keys.hotKeyModifiers)
            subject.send()
        }
    }
}
