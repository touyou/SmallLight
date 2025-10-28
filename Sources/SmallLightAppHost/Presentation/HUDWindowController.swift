import AppKit
import SmallLightUI
import SwiftUI

enum HUDPositioningMode {
    case followCursor
    case fixedTopLeft
}

@MainActor
protocol HUDWindowControlling: AnyObject {
    var isVisible: Bool { get }
    func show()
    func hide()
    func focus()
    func updatePosition(nearestTo point: CGPoint?)
    func setPositioningMode(_ mode: HUDPositioningMode)
}

/// Manages the floating HUD window that displays resolved Finder paths.
@MainActor
final class HUDWindowController {
    private let window: NSWindow
    private let hostingController: NSHostingController<HUDView>
    private let minimumSize = CGSize(width: 600, height: 360)
    private let edgeInsets = NSEdgeInsets(top: 48, left: 32, bottom: 48, right: 32)
    private var positioningMode: HUDPositioningMode = .followCursor

    init(viewModel: HUDViewModel, copyHandler: @escaping (HUDEntry) -> Void) {
        let hudView = HUDView(viewModel: viewModel, copyHandler: copyHandler)
        hostingController = NSHostingController(rootView: hudView)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: minimumSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = hostingController
        updatePosition(nearestTo: NSEvent.mouseLocation)
    }

    func show() {
        updatePosition(nearestTo: NSEvent.mouseLocation)
        window.orderFrontRegardless()
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
        updatePosition(nearestTo: NSEvent.mouseLocation)
        show()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
    }

    func updatePosition(nearestTo point: CGPoint?) {
        hostingController.view.layoutSubtreeIfNeeded()
        let desiredSize = CGSize(
            width: max(hostingController.view.fittingSize.width, minimumSize.width),
            height: max(hostingController.view.fittingSize.height, minimumSize.height)
        )
        window.setContentSize(desiredSize)

        let targetScreen: NSScreen?
        switch positioningMode {
        case .followCursor:
            let globalPoint = point ?? NSEvent.mouseLocation
            targetScreen =
                NSScreen.screens.first { $0.frame.contains(globalPoint) }
                ?? window.screen
                ?? NSScreen.main
            guard let screen = targetScreen else { return }

            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: desiredSize))
            let visible = screen.visibleFrame

            let minX = visible.minX + edgeInsets.left
            let maxX = visible.maxX - edgeInsets.right - frame.width
            let centeredX = globalPoint.x - frame.width / 2
            frame.origin.x = min(max(centeredX, minX), maxX)

            let minY = visible.minY + edgeInsets.bottom
            let maxY = visible.maxY - edgeInsets.top - frame.height
            let centeredY = globalPoint.y - frame.height / 2
            frame.origin.y = min(max(centeredY, minY), maxY)

            window.setFrame(frame, display: false)
        case .fixedTopLeft:
            let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
            guard let screen else { return }
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: desiredSize))
            let visible = screen.visibleFrame
            frame.origin.x = visible.minX + edgeInsets.left
            frame.origin.y = visible.maxY - edgeInsets.top - frame.height
            window.setFrame(frame, display: false)
        }
    }

    func setPositioningMode(_ mode: HUDPositioningMode) {
        positioningMode = mode
        updatePosition(nearestTo: nil)
    }
}

extension HUDWindowController: HUDWindowControlling {}
