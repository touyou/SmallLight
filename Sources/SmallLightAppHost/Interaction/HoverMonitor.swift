import CoreGraphics
import Foundation

/// Monitors global hover activity and emits dwell events while the configured modifier chord is held.
final class HoverMonitor {
    struct Event {
        let location: CGPoint
        let modifiers: CGEventFlags
    }

    typealias Handler = (Event) -> Void

    private let handler: Handler
    private let dwellThreshold: TimeInterval
    private let debounceInterval: TimeInterval
    private let processingQueue = DispatchQueue(label: "io.smalllight.hover-monitor", qos: .userInteractive)
    private var stateMachine: HoverStateMachine

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var dwellTimer: DispatchSourceTimer?

    init(settings: AppSettings.Trigger, handler: @escaping Handler) {
        self.handler = handler
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
            (1 << CGEventType.mouseMoved.rawValue) |
                (1 << CGEventType.flagsChanged.rawValue)
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
        let location = event.location

        processingQueue.async { [weak self] in
            guard let self else { return }
            switch type {
            case .mouseMoved:
                let action = self.stateMachine.handleMouseMove(
                    location: location,
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
            let event = Event(location: result.location, modifiers: result.modifiers)
            handler(event)
        } else {
            // Timer fired but state machine not ready; keep waiting if still armed.
            if stateMachine.dwellIsActive {
                scheduleDwellTimer()
            }
        }
    }
}

struct HoverStateMachine {
    enum Action: Equatable {
        case startDwell
        case cancelDwell
        case none
    }

    private let dwellThreshold: TimeInterval
    private let debounceInterval: TimeInterval
    private let requiredFlags: CGEventFlags
    private let movementTolerance: CGFloat

    private(set) var lastLocation: CGPoint?
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

    mutating func handleMouseMove(location: CGPoint, flags: CGEventFlags, timestamp: TimeInterval) -> Action {
        let filteredFlags = flags.filtered
        let previousLocation = lastLocation
        lastLocation = location
        lastMovementTime = timestamp
        currentFlags = filteredFlags
        isHeld = filteredFlags.containsAll(requiredFlags)

        guard isHeld else {
            dwellArmed = false
            return .cancelDwell
        }

        if dwellArmed, let previousLocation, previousLocation.distance(to: location) <= movementTolerance {
            return .none
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

        if lastLocation != nil, !dwellArmed {
            dwellArmed = true
            return .startDwell
        }

        return .none
    }

    mutating func handleDwellTimer(timestamp: TimeInterval) -> (location: CGPoint, modifiers: CGEventFlags)? {
        guard dwellArmed, isHeld, let lastMovementTime, let location = lastLocation else {
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
        return (location, currentFlags)
    }

    var dwellIsActive: Bool {
        dwellArmed
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

private extension CGEvent {
    var timestampSeconds: TimeInterval {
        TimeInterval(timestamp) / 1_000_000_000
    }

    var normalizedFlags: CGEventFlags {
        flags.filtered
    }
}

private extension CGEventFlags {
    static let monitoredModifiers: CGEventFlags = [
        .maskAlternate,
        .maskControl,
        .maskShift,
        .maskCommand,
    ]

    var filtered: CGEventFlags {
        CGEventFlags(rawValue: rawValue & CGEventFlags.monitoredModifiers.rawValue)
    }

    func containsAll(_ required: CGEventFlags) -> Bool {
        (rawValue & required.rawValue) == required.rawValue
    }
}

extension HoverMonitor: @unchecked Sendable {}
