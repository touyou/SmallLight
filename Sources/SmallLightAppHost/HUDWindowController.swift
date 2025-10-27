import AppKit
import SwiftUI
import SmallLightUI

/// Manages the floating HUD window that displays resolved Finder paths.
@MainActor
final class HUDWindowController {
    private let window: NSWindow
    private let hostingController: NSHostingController<HUDView>

    init(viewModel: HUDViewModel, copyHandler: @escaping (HUDEntry) -> Void) {
        let hudView = HUDView(viewModel: viewModel, copyHandler: copyHandler)
        hostingController = NSHostingController(rootView: hudView)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 220),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.contentViewController = hostingController
        positionWindow()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
    }

    func toggle() {
        if window.isVisible {
            hide()
        } else {
            show()
        }
    }

    var isVisible: Bool {
        window.isVisible
    }

    func focus() {
        show()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 20
        let size = window.frame.size
        let origin = CGPoint(
            x: screen.visibleFrame.maxX - size.width - margin,
            y: screen.visibleFrame.minY + margin
        )
        window.setFrameOrigin(origin)
    }
}
