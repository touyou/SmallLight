import AppKit
import ApplicationServices
import Foundation

/// Resolution details for a Finder item discovered under the cursor.
struct FinderItemResolution: Equatable {
    let path: String
    let isDirectory: Bool
    let isArchive: Bool
}

/// Abstraction for resolving Finder items based on screen coordinates.
protocol FinderItemResolving: Sendable {
    func resolveItem(at screenPoint: CGPoint) throws -> FinderItemResolution?
}

enum FinderItemResolverError: Error {
    case accessibilityPermissionRequired
    case baseDirectoryUnavailable
}

/// Uses Accessibility hit testing and AppleScript fallbacks to map cursor locations to Finder items.
final class FinderItemResolver: FinderItemResolving {
    private let systemWideElement = AXUIElementCreateSystemWide()
    private let baseDirectoryProvider: FinderBaseDirectoryProviding
    private let fileManager: FileManager
    private let bundleIdentifier = "com.apple.finder"

    init(
        baseDirectoryProvider: FinderBaseDirectoryProviding = FinderFrontWindowDirectoryProvider(),
        fileManager: FileManager = .default
    ) {
        self.baseDirectoryProvider = baseDirectoryProvider
        self.fileManager = fileManager
    }

    func resolveItem(at screenPoint: CGPoint) throws -> FinderItemResolution? {
        guard AXIsProcessTrusted() else {
            throw FinderItemResolverError.accessibilityPermissionRequired
        }

        var axElement: AXUIElement?
        let axResult = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(screenPoint.x),
            Float(screenPoint.y),
            &axElement
        )

        guard axResult == .success, let element = axElement else {
            return nil
        }

        guard isFinderElement(element) else { return nil }

        if let url = resolveURL(from: element) {
            return try buildResolution(for: url)
        }

        if let name = resolveFilename(from: element) {
            guard let baseDirectory = try baseDirectoryProvider.activeDirectoryPath() else {
                throw FinderItemResolverError.baseDirectoryUnavailable
            }
            let path = FinderPathBuilder.buildPath(baseDirectory: baseDirectory, itemName: name)
            return try buildResolution(for: URL(fileURLWithPath: path))
        }

        return nil
    }

    private func resolveURL(from element: AXUIElement) -> URL? {
        var current: AXUIElement? = element
        while let target = current {
            if let url = attributeValue(for: target, attribute: kAXURLAttribute as CFString) as? URL {
                return url
            }

            if let filename = attributeValue(for: target, attribute: kAXFilenameAttribute as CFString) as? String {
                if filename.hasPrefix("/") {
                    return URL(fileURLWithPath: filename)
                } else {
                    return URL(fileURLWithPath: filename, isDirectory: false)
                }
            }

            current = parentElement(of: target)
        }
        return nil
    }

    private func resolveFilename(from element: AXUIElement) -> String? {
        var current: AXUIElement? = element
        while let target = current {
            if let name = attributeValue(for: target, attribute: kAXTitleAttribute as CFString) as? String, !name.isEmpty {
                return name
            }
            current = parentElement(of: target)
        }
        return nil
    }

    private func buildResolution(for url: URL) throws -> FinderItemResolution? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        let isArchive = url.pathExtension.lowercased() == "zip"
        return FinderItemResolution(
            path: url.standardizedFileURL.path,
            isDirectory: isDirectory.boolValue,
            isArchive: isArchive
        )
    }

    private func parentElement(of element: AXUIElement) -> AXUIElement? {
        guard let value = attributeValue(for: element, attribute: kAXParentAttribute as CFString) else { return nil }
        let cfValue = value as CFTypeRef
        guard CFGetTypeID(cfValue) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    private func attributeValue(for element: AXUIElement, attribute: CFString) -> AnyObject? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else { return nil }
        return value
    }

    private func isFinderElement(_ element: AXUIElement) -> Bool {
        guard let applicationElement = applicationElement(for: element) else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(applicationElement, &pid) == .success else { return false }
        guard let application = NSRunningApplication(processIdentifier: pid) else { return false }
        return application.bundleIdentifier == bundleIdentifier
    }

    private func applicationElement(for element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        while let target = current {
            if let role = attributeValue(for: target, attribute: kAXRoleAttribute as CFString) as? String,
               role == (kAXApplicationRole as String)
            {
                return target
            }
            current = parentElement(of: target)
        }
        return nil
    }
}

extension FinderItemResolver: @unchecked Sendable {}
