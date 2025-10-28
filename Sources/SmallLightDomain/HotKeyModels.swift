import Foundation

public struct HotKeyChord: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: HotKeyModifiers

    public init(keyCode: UInt32, modifiers: HotKeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct HotKeyEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case pressed
        case released
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}

public struct HotKeyModifiers: OptionSet, Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = HotKeyModifiers(rawValue: 1 << 0)
    public static let option = HotKeyModifiers(rawValue: 1 << 1)
    public static let shift = HotKeyModifiers(rawValue: 1 << 2)
    public static let control = HotKeyModifiers(rawValue: 1 << 3)
}

extension HotKeyChord {
    public static let defaultActionChord = HotKeyChord(keyCode: 37, modifiers: [.option, .control])
}
