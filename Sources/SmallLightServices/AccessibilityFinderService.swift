import ApplicationServices
import AppKit
import Foundation
import SmallLightDomain

public final class AccessibilityFinderTargetingService: FinderTargetingService {
    private let systemWideElement = AXUIElementCreateSystemWide()
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func itemUnderCursor() throws -> FinderItem? {
        let cursorLocation = NSEvent.mouseLocation
        var axElement: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(cursorLocation.x),
            Float(cursorLocation.y),
            &axElement
        )

        guard result == .success, let element = axElement else {
            return nil
        }

        if let url = resolveURL(from: element) ?? ascendForURL(from: element) {
            return try makeFinderItem(from: url)
        }

        return nil
    }

    private func makeFinderItem(from url: URL) throws -> FinderItem? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        let isArchive = url.pathExtension.lowercased() == "zip"
        return FinderItem(url: url, isDirectory: isDirectory.boolValue, isArchive: isArchive)
    }

    private func resolveURL(from element: AXUIElement) -> URL? {
        if let value: CFTypeRef = try? copyAttribute(element: element, attribute: kAXURLAttribute as CFString),
           CFGetTypeID(value) == CFURLGetTypeID(),
           let url = value as? URL {
            return url
        }

        if let value: CFTypeRef = try? copyAttribute(element: element, attribute: kAXFilenameAttribute as CFString),
           CFGetTypeID(value) == CFStringGetTypeID(),
           let path = value as? String {
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    private func ascendForURL(from element: AXUIElement) -> URL? {
        var current = element

        while true {
            if let url = resolveURL(from: current) {
                return url
            }

            guard let parentValue = try? copyAttribute(element: current, attribute: kAXParentAttribute as CFString) else {
                return nil
            }

            guard CFGetTypeID(parentValue) == AXUIElementGetTypeID() else {
                return nil
            }

            current = unsafeDowncast(parentValue as AnyObject, to: AXUIElement.self)
        }
    }

    private func copyAttribute(element: AXUIElement, attribute: CFString) throws -> CFTypeRef? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else {
            throw AXErrorWrapper(error: error)
        }
        return value
    }
}

private struct AXErrorWrapper: Error {
    let error: AXError
}
