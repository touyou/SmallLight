import Foundation

public enum SmallLightError: Error, Equatable {
    case finderAccessDenied
    case itemUnavailable
    case compressionFailed(reason: String)
    case decompressionFailed(reason: String)
    case confirmationPending
    case undoUnavailable
}
