import Carbon
import Foundation
import SmallLightDomain

public enum CarbonHotKeyError: Error {
    case registrationFailed(OSStatus)
    case handlerInstallFailed(OSStatus)
}

public final class CarbonHotKeyRegistrar: HotKeyRegistrar {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handler: ((HotKeyEvent) -> Void)?

    public init() {}

    public func register(
        chord: HotKeyChord,
        handler: @escaping (HotKeyEvent) -> Void
    ) throws -> HotKeyRegistrationToken {
        unregisterInternal()

        self.handler = handler

        let signature: OSType = 0x534C_484B  // 'SLHK'
        let hotKeyID = EventHotKeyID(signature: signature, id: UInt32(1))
        var carbonHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(chord.keyCode),
            chord.modifiers.carbonFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &carbonHotKeyRef
        )

        guard status == noErr, let hotKeyRef = carbonHotKeyRef else {
            throw CarbonHotKeyError.registrationFailed(status)
        }

        self.hotKeyRef = hotKeyRef

        let eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let statusHandler: OSStatus = eventTypes.withUnsafeBufferPointer { buffer in
            InstallEventHandler(
                GetEventDispatcherTarget(),
                carbonHotKeyEventHandler,
                Int(buffer.count),
                buffer.baseAddress,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
        }

        guard statusHandler == noErr else {
            unregisterInternal()
            throw CarbonHotKeyError.handlerInstallFailed(statusHandler)
        }

        return Token(registrar: self)
    }

    fileprivate func handle(event: EventRef?) {
        guard let event else { return }
        let kind = GetEventKind(event)
        switch kind {
        case UInt32(kEventHotKeyPressed):
            handler?(HotKeyEvent(kind: .pressed))
        case UInt32(kEventHotKeyReleased):
            handler?(HotKeyEvent(kind: .released))
        default:
            break
        }
    }

    private func unregisterInternal() {
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        handler = nil
    }

    private final class Token: HotKeyRegistrationToken {
        private weak var registrar: CarbonHotKeyRegistrar?

        init(registrar: CarbonHotKeyRegistrar) {
            self.registrar = registrar
        }

        func unregister() {
            registrar?.unregisterInternal()
        }
    }
}

private func carbonHotKeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ eventRef: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    registrar.handle(event: eventRef)
    return noErr
}

extension HotKeyModifiers {
    fileprivate var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if contains(.option) {
            flags |= UInt32(optionKey)
        }
        if contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        if contains(.control) {
            flags |= UInt32(controlKey)
        }
        return flags
    }
}
