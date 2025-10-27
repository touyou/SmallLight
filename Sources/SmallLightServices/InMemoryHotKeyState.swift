import Foundation
import SmallLightDomain

public final class InMemoryHotKeyState: HotKeyStateProviding {
    public var isModifierChordActive: Bool

    public init(isModifierChordActive: Bool = false) {
        self.isModifierChordActive = isModifierChordActive
    }
}
