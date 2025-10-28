import AppKit
import Foundation
import SmallLightDomain
import SmallLightServices
import SmallLightUI

@MainActor
extension AppCoordinator {
    func start() {
        guard mode == .idle else { return }
        hoverMonitor.start()
        overlayManager.setIndicatorState(.idle)
        cursorController.update(listening: false)
        hudWindowController.setPositioningMode(.fixedTopLeft)
        hudWindowController.hide()
        hudVisible = false
        mode = .watching
        registerHotKeys()
        verifyAccessibilityPermissions()
    }

    func stop() {
        guard mode == .watching else { return }
        hoverMonitor.stop()
        overlayManager.setIndicatorState(.hidden)
        cursorController.reset()
        hudWindowController.hide()
        hotKeyCenter.unregisterAll()
        mode = .idle
    }

    func toggleHUDVisibility() {
        if hudWindowController.isVisible {
            hudWindowController.hide()
            hudVisible = false
        } else {
            hudWindowController.show()
            hudVisible = true
        }
    }

    func focusHUD() {
        hudWindowController.focus()
        hudVisible = true
    }

    func present(path: String, message: String? = nil) {
        let entry = HUDEntry(path: path, message: message)
        hudViewModel.append(entry)
        if hudViewModel.autoCopyEnabled {
            copyToClipboard(entry)
        }
    }

    func manualResolve() {
        let displayLocation = NSEvent.mouseLocation
        let hitTestLocation = CGEvent(source: nil)?.location ?? displayLocation
        overlayManager.updateCursorPosition(displayLocation)
        resolve(at: hitTestLocation, bypassDedup: true)
    }

    /// Opens Finder pointing at the undo staging directory so users can inspect or restore staged
    /// originals manually.
    func revealStagingFolder() {
        let url = FileUndoStagingManager.defaultRootDirectory()
        ensureDirectoryExists(at: url)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens Finder pointing at the audit log (or its directory when the log has not been created
    /// yet).
    func revealAuditLog() {
        let directory = AppSupportPaths.auditLogDirectory
        ensureDirectoryExists(at: directory)
        let logFile = directory.appendingPathComponent("actions.log")
        if FileManager.default.fileExists(atPath: logFile.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logFile])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([directory])
        }
    }
}

@MainActor
extension AppCoordinator {
    func clearDedupKey(for path: String, action: String) {
        let key = "\(path)::\(action)"
        dedupStore.remove(key)
    }

    func registerHotKeys() {
        do {
            try hotKeyCenter.register([
                (
                    settings.focusHotKey,
                    { [weak self] in
                        Task { @MainActor in
                            self?.focusHUD()
                        }
                    }
                ),
                (
                    settings.manualResolveHotKey,
                    { [weak self] in
                        Task { @MainActor in
                            self?.manualResolve()
                        }
                    }
                ),
                (
                    settings.toggleHUDHotKey,
                    { [weak self] in
                        Task { @MainActor in
                            self?.toggleHUDVisibility()
                        }
                    }
                ),
            ])
        } catch {
            NSLog("[FinderOverlayDebugger] Failed to register hot keys: \(error)")
        }
    }
}

@MainActor
extension AppCoordinator {
    func clearAccessibilityWarning() {
        didWarnAccessibility = false
    }
}

@MainActor
extension AppCoordinator {
    func handleHoverEvent(_ event: HoverMonitor.Event) {
        overlayManager.updateCursorPosition(event.displayLocation)
        resolve(at: event.hitTestLocation, bypassDedup: false)
    }

    func copyToClipboard(_ entry: HUDEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.path, forType: .string)
    }

    func handleResolvedItem(_ resolution: FinderItemResolution, dedupKey: String) {
        if resolution.isArchive, settings.zip.behaviour == .auto {
            handleZipExtraction(for: resolution, dedupKey: dedupKey)
        } else if resolution.isDirectory {
            handleCompression(for: resolution, dedupKey: dedupKey)
        } else {
            let message = contextMessage(for: resolution)
            present(path: resolution.path, message: message)
        }
    }

    func handleAccessibilityWarning() {
        guard !didWarnAccessibility else { return }
        didWarnAccessibility = true
        let message =
            "[FinderOverlayDebugger] Accessibility permission required to resolve "
            + "Finder items."
        NSLog(message)
        showAccessibilityAlert()
        hudViewModel.updateAccessibility(granted: false)
    }

    func handleResolverError(_ error: Error) {
        NSLog("[FinderOverlayDebugger] Failed to resolve Finder item: \(error)")
    }
}

@MainActor
extension AppCoordinator {
    func handleZipExtraction(for resolution: FinderItemResolution, dedupKey: String) {
        let zipHandler = self.zipHandler
        let dedupStore = self.dedupStore
        let auditLoggerBox = self.auditLoggerBox
        let undoManagerBox = self.undoManagerBox
        resolutionQueue.async { [weak self] in
            do {
                let (finderItem, itemURL) = AppCoordinator.makeFinderItem(for: resolution)
                let undoManager = undoManagerBox.value
                let stagingURL = try undoManager.stagingURL(
                    for: finderItem,
                    action: .decompress
                )
                let stagedOriginal = try undoManager.stageOriginal(at: itemURL)
                let destination = try zipHandler.extract(zipPath: resolution.path)
                do {
                    try auditLoggerBox.value.record(
                        action: .decompress, item: finderItem, destination: destination)
                } catch {
                    NSLog("[FinderOverlayDebugger] Failed to record audit entry: \(error)")
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.presentOperationSuccess(
                        stagingURL: stagingURL,
                        stagedOriginal: stagedOriginal,
                        destination: destination,
                        successKey: "hud.zip.success"
                    )
                }
            } catch {
                dedupStore.remove(dedupKey)
                NSLog("[FinderOverlayDebugger] Zip extraction failed: \(error)")
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.presentOperationFailure(
                        path: resolution.path,
                        errorKey: "hud.zip.error",
                        errorDescription: error.localizedDescription
                    )
                }
            }
        }
    }

    func handleCompression(for resolution: FinderItemResolution, dedupKey: String) {
        let compressionServiceBox = self.compressionServiceBox
        let dedupStore = self.dedupStore
        let auditLoggerBox = self.auditLoggerBox
        let undoManagerBox = self.undoManagerBox
        resolutionQueue.async { [weak self] in
            do {
                let (finderItem, itemURL) = AppCoordinator.makeFinderItem(for: resolution)
                let undoManager = undoManagerBox.value
                let stagingURL = try undoManager.stagingURL(
                    for: finderItem,
                    action: .compress
                )
                let stagedOriginal = try undoManager.stageOriginal(at: itemURL)
                let destinationDirectory = itemURL.deletingLastPathComponent()
                let destination = try compressionServiceBox.value.compress(
                    item: finderItem,
                    destinationDirectory: destinationDirectory
                )
                do {
                    try auditLoggerBox.value.record(
                        action: .compress, item: finderItem, destination: destination)
                } catch {
                    NSLog("[FinderOverlayDebugger] Failed to record audit entry: \(error)")
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.presentOperationSuccess(
                        stagingURL: stagingURL,
                        stagedOriginal: stagedOriginal,
                        destination: destination,
                        successKey: "hud.compress.success"
                    )
                }
            } catch {
                dedupStore.remove(dedupKey)
                NSLog("[FinderOverlayDebugger] Compression failed: \(error)")
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.presentOperationFailure(
                        path: resolution.path,
                        errorKey: "hud.compress.error",
                        errorDescription: error.localizedDescription
                    )
                }
            }
        }
    }
}

@MainActor
extension AppCoordinator {
    func resolve(at location: CGPoint, bypassDedup: Bool) {
        let resolver = self.resolver
        let dedupStore = self.dedupStore

        resolutionQueue.async { [weak self] in
            do {
                guard let resolution = try resolver.resolveItem(at: location) else { return }
                let key = "\(resolution.path)::\(DedupAction.resolve)"
                if !bypassDedup && dedupStore.isDuplicate(key) {
                    return
                }
                dedupStore.record(key)
                Task { @MainActor [weak self] in
                    self?.handleResolvedItem(resolution, dedupKey: key)
                }
            } catch FinderItemResolverError.accessibilityPermissionRequired {
                Task { @MainActor [weak self] in
                    self?.handleAccessibilityWarning()
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.handleResolverError(error)
                }
            }
        }
    }

    func contextMessage(for resolution: FinderItemResolution) -> String? {
        let url = URL(fileURLWithPath: resolution.path)
        let parent = url.deletingLastPathComponent().path
        if resolution.isDirectory {
            return UILocalized.formatted("hud.info.folder", parent)
        } else {
            return UILocalized.formatted("hud.info.file", parent)
        }
    }

    func ensureDirectoryExists(at url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

@MainActor
extension AppCoordinator {
    func verifyAccessibilityPermissions() {
        if AXIsProcessTrusted() {
            accessibilityPromptController.reset()
            hudViewModel.updateAccessibility(granted: true)
            return
        }
        guard accessibilityPromptController.shouldPrompt else { return }
        showAccessibilityAlert()
        hudViewModel.updateAccessibility(granted: false)
    }

    func showAccessibilityAlert() {
        accessibilityPromptController.recordPrompt()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = UILocalized.string("accessibility.alert.title")
        alert.informativeText = UILocalized.string("accessibility.alert.message")
        alert.addButton(withTitle: UILocalized.string("accessibility.alert.open"))
        alert.addButton(withTitle: UILocalized.string("accessibility.alert.cancel"))
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.openAccessibilityPreferences()
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openAccessibilityPreferences()
            }
        }
    }

    func openAccessibilityPreferences() {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.clearAccessibilityWarning()
            self?.verifyAccessibilityPermissions()
        }
    }
}

@MainActor
extension AppCoordinator {
    func presentOperationSuccess(
        stagingURL: URL,
        stagedOriginal: URL,
        destination: URL,
        successKey: String
    ) {
        present(
            path: stagingURL.path,
            message: UILocalized.formatted("hud.zip.staging", stagingURL.path)
        )
        present(
            path: stagedOriginal.path,
            message: UILocalized.formatted("hud.zip.staged", stagedOriginal.path)
        )
        present(
            path: destination.path,
            message: UILocalized.formatted(successKey, destination.path)
        )
    }

    func presentOperationFailure(path: String, errorKey: String, errorDescription: String) {
        let message = UILocalized.formatted(errorKey, errorDescription)
        present(path: path, message: message)
    }

    nonisolated static func makeFinderItem(
        for resolution: FinderItemResolution
    ) -> (FinderItem, URL) {
        let itemURL = URL(fileURLWithPath: resolution.path)
        let finderItem = FinderItem(
            url: itemURL,
            isDirectory: resolution.isDirectory,
            isArchive: resolution.isArchive
        )
        return (finderItem, itemURL)
    }
}
