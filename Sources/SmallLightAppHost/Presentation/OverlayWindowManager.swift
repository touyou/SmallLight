import AppKit

enum OverlayIndicatorState {
    case hidden
    case idle
    case listening
}

@MainActor
protocol OverlayUpdating {
    func updateCursorPosition(_ point: CGPoint)
    func setIndicatorState(_ state: OverlayIndicatorState)
    func reset()
}

/// Draws circular cursor indicators on transparent windows across all displays.
@MainActor
final class OverlayWindowManager {
    private final class OverlayWindow: NSWindow {
        private let idleLayer = CAShapeLayer()
        private let listeningLayer = CAShapeLayer()
        private var currentState: OverlayIndicatorState = .hidden
        private let indicatorDiameter: CGFloat = 16

        init(screen: NSScreen) {
            super.init(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            setFrame(screen.frame, display: false)
            isOpaque = false
            backgroundColor = .clear
            ignoresMouseEvents = true
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            level = .screenSaver
            hasShadow = false

            contentView?.wantsLayer = true
            if let layer = contentView?.layer {
                idleLayer.fillColor = NSColor.systemGray.withAlphaComponent(0.5).cgColor
                idleLayer.opacity = 1.0
                listeningLayer.fillColor = NSColor.systemYellow.withAlphaComponent(0.85).cgColor
                listeningLayer.opacity = 1.0
                idleLayer.contentsScale = screen.backingScaleFactor
                listeningLayer.contentsScale = screen.backingScaleFactor
                let indicatorBounds = CGRect(origin: .zero, size: CGSize(width: indicatorDiameter, height: indicatorDiameter))
                let indicatorPath = CGPath(ellipseIn: indicatorBounds, transform: nil)
                idleLayer.bounds = indicatorBounds
                idleLayer.path = indicatorPath
                idleLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                listeningLayer.bounds = indicatorBounds
                listeningLayer.path = indicatorPath
                listeningLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                layer.addSublayer(idleLayer)
                layer.addSublayer(listeningLayer)
                layer.masksToBounds = false
            }
            apply(state: .hidden)
        }

        func updateIndicator(globalPoint point: CGPoint) {
            guard let contentView else { return }
            let windowPoint = convertPoint(fromScreen: point)
            let converted = contentView.convert(windowPoint, from: nil)
            idleLayer.position = converted
            listeningLayer.position = converted
        }

        func clearIndicator() {
            idleLayer.isHidden = true
            listeningLayer.isHidden = true
        }

        func apply(state: OverlayIndicatorState) {
            currentState = state
            switch state {
            case .hidden:
                clearIndicator()
            case .idle:
                idleLayer.isHidden = false
                listeningLayer.isHidden = true
                if idleLayer.path == nil {
                    let indicatorBounds = CGRect(origin: .zero, size: CGSize(width: indicatorDiameter, height: indicatorDiameter))
                    idleLayer.bounds = indicatorBounds
                    idleLayer.path = CGPath(ellipseIn: indicatorBounds, transform: nil)
                }
            case .listening:
                idleLayer.isHidden = true
                listeningLayer.isHidden = false
                if listeningLayer.path == nil {
                    let indicatorBounds = CGRect(origin: .zero, size: CGSize(width: indicatorDiameter, height: indicatorDiameter))
                    listeningLayer.bounds = indicatorBounds
                    listeningLayer.path = CGPath(ellipseIn: indicatorBounds, transform: nil)
                }
            }
        }
    }

    private var windows: [OverlayWindow] = []
    private var state: OverlayIndicatorState = .hidden

    init() {
        rebuildWindows()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            return window
        }
        applyVisibility()
    }

    func updateCursorPosition(_ point: CGPoint) {
        guard state != .hidden else { return }
        for window in windows {
            guard let screen = window.screen else { continue }
            if screen.frame.contains(point) {
                window.orderFrontRegardless()
                window.updateIndicator(globalPoint: point)
            }
        }
    }

    func setIndicatorState(_ state: OverlayIndicatorState) {
        self.state = state
        applyVisibility()
        if state != .hidden {
            updateCursorPosition(NSEvent.mouseLocation)
        }
    }

    func reset() {
        windows.forEach { $0.clearIndicator() }
        setIndicatorState(.hidden)
    }

    private func applyVisibility() {
        for window in windows {
            switch state {
            case .hidden:
                window.clearIndicator()
                window.orderOut(nil)
                window.apply(state: .hidden)
            case .idle:
                window.apply(state: .idle)
                window.orderFrontRegardless()
            case .listening:
                window.apply(state: .listening)
                window.orderFrontRegardless()
            }
        }
    }
}

extension OverlayWindowManager: OverlayUpdating {}
