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
        private var isWindowVisible = false

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
                layer.contentsScale = screen.backingScaleFactor
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

        func presentIndicator(state: OverlayIndicatorState, at point: CGPoint) {
            if currentState != state {
                apply(state: state)
            }

            guard state != .hidden, let contentView else {
                dismissIndicator()
                return
            }

            // Convert from global screen space into the window's layer-backed coordinate space.
            let windowPoint = convertPoint(fromScreen: point)
            let converted = contentView.convert(windowPoint, from: nil)
            idleLayer.position = converted
            listeningLayer.position = converted
            if !isWindowVisible {
                orderFrontRegardless()
                isWindowVisible = true
            }
        }

        func dismissIndicator() {
            guard isWindowVisible || currentState != .hidden else { return }
            apply(state: .hidden)
            orderOut(nil)
            isWindowVisible = false
        }

        func apply(state: OverlayIndicatorState) {
            currentState = state
            switch state {
            case .hidden:
                idleLayer.isHidden = true
                listeningLayer.isHidden = true
            case .idle:
                idleLayer.isHidden = false
                listeningLayer.isHidden = true
            case .listening:
                idleLayer.isHidden = true
                listeningLayer.isHidden = false
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
        windows.forEach { $0.dismissIndicator() }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
        if state != .hidden {
            updateCursorPosition(NSEvent.mouseLocation)
        }
    }

    func updateCursorPosition(_ point: CGPoint) {
        guard state != .hidden else { return }
        // Only keep the overlay visible on the display that currently contains the cursor.
        for window in windows {
            guard let screen = window.screen else {
                window.dismissIndicator()
                continue
            }

            if screenFrame(screen, contains: point) {
                window.presentIndicator(state: state, at: point)
            } else {
                window.dismissIndicator()
            }
        }
    }

    func setIndicatorState(_ state: OverlayIndicatorState) {
        self.state = state
        if state == .hidden {
            windows.forEach { $0.dismissIndicator() }
        } else {
            updateCursorPosition(NSEvent.mouseLocation)
        }
    }

    func reset() {
        setIndicatorState(.hidden)
    }

    private func screenFrame(_ screen: NSScreen, contains point: CGPoint) -> Bool {
        // Expand the frame slightly so edges shared between displays still report true.
        let expandedFrame = screen.frame.insetBy(dx: -1, dy: -1)
        return expandedFrame.contains(point)
    }
}

extension OverlayWindowManager: OverlayUpdating {}
