import CoreGraphics
import Foundation
import SmallLightDomain

/// Immutable configuration describing default behaviour for FinderOverlayDebugger.
struct AppSettings {
    /// Settings for the held-key trigger and dwell detection.
    struct Trigger {
        var heldKey: HeldKey = .option
        var dwellThreshold: TimeInterval = 0.200
        var debounceInterval: TimeInterval = 0.080
    }

    /// Preferences for the onscreen HUD presentation.
    struct HUD {
        var historyLimit: Int = 5
        var autoCopyEnabled: Bool = false
    }

    /// Parameters for in-memory deduplication of repeated events.
    struct Dedup {
        var ttl: TimeInterval = 3.0
        var capacity: Int = 256
    }

    /// Behaviour modifiers applied when a zip archive is encountered.
    struct ZipBehaviour {
        var behaviour: ZipMode = .auto
        var destination: ZipDestination = .sameDirectory
    }

    enum ZipMode {
        case auto
        case prompt
    }

    enum ZipDestination {
        case sameDirectory
    }

    /// Supported modifier key combinations for dwell detection.
    enum HeldKey {
        case option
        case control
        case shiftOption

        var eventFlags: CGEventFlags {
            switch self {
            case .option:
                return [.maskAlternate]
            case .control:
                return [.maskControl]
            case .shiftOption:
                return [.maskShift, .maskAlternate]
            }
        }
    }

    /// Trigger configuration controlling dwell detection and held-key selection.
    var trigger = Trigger()
    /// HUD presentation settings.
    var hud = HUD()
    /// Deduplication settings (TTL and store size).
    var dedup = Dedup()
    /// Zip handling defaults.
    var zip = ZipBehaviour()
    var focusHotKey = HotKeyChord(  // Ctrl+Option+Space
        keyCode: 49,
        modifiers: [.control, .option]
    )
    var manualResolveHotKey = HotKeyChord(  // Ctrl+Option+P
        keyCode: 35,
        modifiers: [.control, .option]
    )
    var toggleHUDHotKey = HotKeyChord(  // Cmd+Option+H
        keyCode: 4,
        modifiers: [.option, .command]
    )
}
