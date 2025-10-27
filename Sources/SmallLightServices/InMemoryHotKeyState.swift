import Foundation
import SmallLightDomain

public final class InMemoryHotKeyState: HotKeyStateMutating {
    private let queue = DispatchQueue(label: "io.smalllight.hotkey-state", qos: .userInitiated)
    private var active: Bool

    public init(isModifierChordActive: Bool = false) {
        self.active = isModifierChordActive
    }

    public var isModifierChordActive: Bool {
        queue.sync {
            active
        }
    }

    public func setModifierChordActive(_ isActive: Bool) {
        queue.sync {
            active = isActive
        }
    }
}
