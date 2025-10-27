import AppKit

@MainActor
protocol OverlayUpdating {
    func updateCursorPosition(_ point: CGPoint)
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
    }

    private var windows: [OverlayWindow] = []

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
            window.orderFrontRegardless()
            return window
        }
    }

    func updateCursorPosition(_ point: CGPoint) {
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
}

extension OverlayWindowManager: OverlayUpdating {}
