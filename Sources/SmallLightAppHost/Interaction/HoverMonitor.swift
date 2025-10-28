import AppKit
import CoreGraphics
import Foundation

/// Monitors global hover activity and emits dwell events while the configured modifier chord is
/// held.
final class HoverMonitor {
    struct Event {
        let displayLocation: CGPoint
        let hitTestLocation: CGPoint
        let modifiers: CGEventFlags

        var location: CGPoint { displayLocation }
    }

    typealias DwellHandler = (Event) -> Void
    typealias MovementHandler = (Event) -> Void
    typealias ModifierHandler = (Bool) -> Void

    private let dwellHandler: DwellHandler
    private let movementHandler: MovementHandler?
    private let modifierHandler: ModifierHandler?
    private let dwellThreshold: TimeInterval
    private let debounceInterval: TimeInterval
    private let processingQueue = DispatchQueue(
        label: "io.smalllight.hover-monitor", qos: .userInteractive)
    private var stateMachine: HoverStateMachine

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var dwellTimer: DispatchSourceTimer?

    private var lastModifierState: Bool = false

    init(
        settings: AppSettings.Trigger,
        handler: @escaping DwellHandler,
        movementHandler: MovementHandler? = nil,
        modifierHandler: ModifierHandler? = nil
    ) {
        dwellHandler = handler
        self.movementHandler = movementHandler
        self.modifierHandler = modifierHandler
        dwellThreshold = settings.dwellThreshold
        debounceInterval = settings.debounceInterval
        stateMachine = HoverStateMachine(
            dwellThreshold: settings.dwellThreshold,
            debounceInterval: settings.debounceInterval,
            requiredFlags: settings.heldKey.eventFlags
        )
    }

    deinit {
        stop()
    }

    func start() {
        guard eventTap == nil else { return }
        let mask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        )
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let info = userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HoverMonitor>.fromOpaque(info).takeUnretainedValue()
                monitor.handle(event: event, type: type)
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        cancelDwellTimer()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
    }

    private func handle(event: CGEvent, type: CGEventType) {
        let timestamp = event.timestampSeconds
        let flags = event.normalizedFlags
        let displayLocation = event.appKitLocation
        let hitTestLocation = event.location

        let isHeld = flags.containsAll(stateMachine.requiredFlags)
        notifyModifierIfNeeded(isHeld: isHeld)
        if type == .mouseMoved {
            if let movementHandler {
                Task { @MainActor in
                    movementHandler(
                        Event(
                            displayLocation: displayLocation, hitTestLocation: hitTestLocation,
                            modifiers: flags))
                }
            }
        }

        processingQueue.async { [weak self] in
            guard let self else { return }
            switch type {
            case .mouseMoved:
                let action = self.stateMachine.handleMouseMove(
                    displayLocation: displayLocation,
                    hitTestLocation: hitTestLocation,
                    flags: flags,
                    timestamp: timestamp
                )
                self.handle(action: action)
            case .flagsChanged:
                let action = self.stateMachine.handleFlagsChange(
                    flags: flags,
                    timestamp: timestamp
                )
                self.handle(action: action)
            default:
                break
            }
        }
    }

    private func handle(action: HoverStateMachine.Action) {
        switch action {
        case .startDwell:
            scheduleDwellTimer()
        case .cancelDwell:
            cancelDwellTimer()
        case .none:
            break
        }
    }

    private func scheduleDwellTimer() {
        cancelDwellTimer()
        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + dwellThreshold)
        timer.setEventHandler { [weak self] in
            self?.dwellTimerFired()
        }
        timer.resume()
        dwellTimer = timer
    }

    private func cancelDwellTimer() {
        dwellTimer?.cancel()
        dwellTimer = nil
    }

    private func dwellTimerFired() {
        let timestamp = ProcessInfo.processInfo.systemUptime
        if let result = stateMachine.handleDwellTimer(timestamp: timestamp) {
            let event = Event(
                displayLocation: result.displayLocation,
                hitTestLocation: result.hitTestLocation,
                modifiers: result.modifiers
            )
            dwellHandler(event)
        } else {
            // Timer fired but state machine not ready; keep waiting if still armed.
            if stateMachine.dwellIsActive {
                scheduleDwellTimer()
            }
        }
    }

    private func notifyModifierIfNeeded(isHeld: Bool) {
        guard let modifierHandler, isHeld != lastModifierState else { return }
        lastModifierState = isHeld
        Task { @MainActor in
            modifierHandler(isHeld)
        }
    }
}

struct HoverStateMachine {
    enum Action: Equatable {
        case startDwell
        case cancelDwell
        case none
    }

    struct DwellSnapshot: Equatable {
        let displayLocation: CGPoint
        let hitTestLocation: CGPoint
        let modifiers: CGEventFlags
    }

    private let dwellThreshold: TimeInterval
    private let debounceInterval: TimeInterval
    let requiredFlags: CGEventFlags
    private let movementTolerance: CGFloat

    private(set) var lastDisplayLocation: CGPoint?
    private(set) var lastHitTestLocation: CGPoint?
    private(set) var lastMovementTime: TimeInterval?
    private(set) var currentFlags: CGEventFlags = []
    private var lastTriggerTime: TimeInterval?
    private var dwellArmed = false
    private var isHeld = false

    init(
        dwellThreshold: TimeInterval,
        debounceInterval: TimeInterval,
        requiredFlags: CGEventFlags,
        movementTolerance: CGFloat = 4
    ) {
        self.dwellThreshold = dwellThreshold
        self.debounceInterval = debounceInterval
        self.requiredFlags = requiredFlags
        self.movementTolerance = movementTolerance
    }

    mutating func handleMouseMove(
        displayLocation: CGPoint, hitTestLocation: CGPoint, flags: CGEventFlags,
        timestamp: TimeInterval
    ) -> Action {
        let filteredFlags = flags.filtered
        let previousLocation = lastDisplayLocation
        lastDisplayLocation = displayLocation
        lastHitTestLocation = hitTestLocation
        lastMovementTime = timestamp
        currentFlags = filteredFlags
        isHeld = filteredFlags.containsAll(requiredFlags)

        guard isHeld else {
            dwellArmed = false
            return .cancelDwell
        }

        if dwellArmed, let previousLocation {
            let isStationary =
                previousLocation.distance(to: displayLocation) <= movementTolerance
            if isStationary {
                return .none
            }
        }

        dwellArmed = true
        return .startDwell
    }

    mutating func handleFlagsChange(flags: CGEventFlags, timestamp: TimeInterval) -> Action {
        let filteredFlags = flags.filtered
        currentFlags = filteredFlags
        isHeld = filteredFlags.containsAll(requiredFlags)

        guard isHeld else {
            dwellArmed = false
            return .cancelDwell
        }

        lastMovementTime = timestamp

        if lastDisplayLocation != nil, !dwellArmed {
            dwellArmed = true
            return .startDwell
        }

        return .none
    }

    mutating func handleDwellTimer(timestamp: TimeInterval) -> DwellSnapshot? {
        guard dwellArmed, isHeld, let lastMovementTime, let displayLocation = lastDisplayLocation,
            let hitTestLocation = lastHitTestLocation
        else {
            dwellArmed = false
            return nil
        }

        if let lastTriggerTime, timestamp - lastTriggerTime < debounceInterval {
            return nil
        }

        if timestamp - lastMovementTime + .ulpOfOne < dwellThreshold {
            return nil
        }

        dwellArmed = false
        lastTriggerTime = timestamp
        return DwellSnapshot(
            displayLocation: displayLocation,
            hitTestLocation: hitTestLocation,
            modifiers: currentFlags
        )
    }

    var dwellIsActive: Bool {
        dwellArmed
    }
}

extension CGPoint {
    fileprivate func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

extension CGEvent {
    fileprivate var timestampSeconds: TimeInterval {
        TimeInterval(timestamp) / 1_000_000_000
    }

    fileprivate var normalizedFlags: CGEventFlags {
        flags.filtered
    }

    fileprivate var appKitLocation: CGPoint {
        if let appKitEvent = NSEvent(cgEvent: self) {
            return appKitEvent.locationInWindow
        }
        return NSEvent.mouseLocation
    }
}

extension CGEventFlags {
    fileprivate static let monitoredModifiers: CGEventFlags = [
        .maskAlternate,
        .maskControl,
        .maskShift,
        .maskCommand,
    ]

    fileprivate var filtered: CGEventFlags {
        CGEventFlags(rawValue: rawValue & CGEventFlags.monitoredModifiers.rawValue)
    }

    fileprivate func containsAll(_ required: CGEventFlags) -> Bool {
        (rawValue & required.rawValue) == required.rawValue
    }
}

extension HoverMonitor: @unchecked Sendable {}
