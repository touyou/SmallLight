import AppKit

@MainActor
protocol OverlayUpdating {
    func updateCursorPosition(_ point: CGPoint)
    func setActive(_ isActive: Bool)
}

/// Draws circular cursor indicators on transparent windows across all displays.
@MainActor
final class OverlayWindowManager {
    private final class OverlayWindow: NSWindow {
        private let indicatorLayer = CAShapeLayer()

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

            indicatorLayer.fillColor = NSColor.labelColor.cgColor
            indicatorLayer.opacity = 0.85
            contentView?.wantsLayer = true
            contentView?.layer?.addSublayer(indicatorLayer)
        }

        func updateIndicator(to point: CGPoint) {
            let diameter: CGFloat = 16
            let rect = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)
            indicatorLayer.path = CGPath(ellipseIn: rect, transform: nil)
        }

        func clearIndicator() {
            indicatorLayer.path = nil
        }
    }

    private var windows: [OverlayWindow] = []
    private var isActive: Bool = false

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
        guard isActive else { return }
        for window in windows {
            guard let screen = window.screen else { continue }
            if screen.frame.contains(point) {
                window.orderFrontRegardless()
                let localPoint = CGPoint(
                    x: point.x - screen.frame.origin.x,
                    y: point.y - screen.frame.origin.y
                )
                window.updateIndicator(to: localPoint)
            }
        }
    }

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        applyVisibility()
        if isActive {
            updateCursorPosition(NSEvent.mouseLocation)
        }
    }

    private func applyVisibility() {
        for window in windows {
            if isActive {
                window.orderFrontRegardless()
            } else {
                window.clearIndicator()
                window.orderOut(nil)
            }
        }
    }
}

extension OverlayWindowManager: OverlayUpdating {}
