import Foundation
import SmallLightDomain
import SmallLightUI
import UserNotifications

@MainActor
public protocol NotificationControllerDelegate: AnyObject {
    func handleConfirmationRequest(forPath path: String)
    func handleUndoRequest(forPath path: String)
}

@MainActor
public final class NotificationController: NSObject {
    private enum Identifiers {
        static let confirmationCategory = "io.smalllight.confirmation"
        static let completionCategory = "io.smalllight.completion"
        static let confirmAction = "confirm"
        static let undoAction = "undo"
    }

    public weak var delegate: NotificationControllerDelegate?
    private var notificationCenter: UNUserNotificationCenter?

    public override init() {
        super.init()
    }

    func start() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            NSLog("[SmallLight] Skipping notification setup because executable is not part of an app bundle.")
            return
        }
        let center = UNUserNotificationCenter.current()
        notificationCenter = center
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("[SmallLight] Notification authorization error: \(error.localizedDescription)")
            } else if !granted {
                NSLog("[SmallLight] Notification authorization not granted")
            }
        }

        let confirmAction = UNNotificationAction(identifier: Identifiers.confirmAction, title: "Confirm", options: [.foreground])
        let confirmationCategory = UNNotificationCategory(
            identifier: Identifiers.confirmationCategory,
            actions: [confirmAction],
            intentIdentifiers: [],
            options: []
        )

        let undoAction = UNNotificationAction(identifier: Identifiers.undoAction, title: "Undo", options: [.foreground])
        let completionCategory = UNNotificationCategory(
            identifier: Identifiers.completionCategory,
            actions: [undoAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([confirmationCategory, completionCategory])
    }

    func presentConfirmation(for decision: ActionDecision) {
        guard let center = notificationCenter else { return }
        let content = UNMutableNotificationContent()
        content.title = "SmallLight Preview"
        content.body = "Prepare to \(decision.intendedAction == .compress ? "compress" : "decompress") \(decision.item.url.lastPathComponent)."
        content.categoryIdentifier = Identifiers.confirmationCategory
        content.userInfo = ["path": decision.item.url.path]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                NSLog("[SmallLight] Failed to schedule confirmation notification: \(error.localizedDescription)")
            }
        }
    }

    func presentCompletion(for action: SmallLightAction, item: FinderItem, destination: URL) {
        guard let center = notificationCenter else { return }
        let content = UNMutableNotificationContent()
        content.title = "SmallLight Completed"
        switch action {
        case .compress:
            content.body = "Created \(destination.lastPathComponent)"
        case .decompress:
            content.body = "Extracted to \(destination.lastPathComponent)"
        case .none:
            content.body = "Action finished"
        }
        content.categoryIdentifier = Identifiers.completionCategory
        content.userInfo = [
            "path": item.url.path
        ]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                NSLog("[SmallLight] Failed to schedule completion notification: \(error.localizedDescription)")
            }
        }
    }
}

extension NotificationController: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let path = response.notification.request.content.userInfo["path"] as? String
        let actionIdentifier = response.actionIdentifier
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            switch actionIdentifier {
            case Identifiers.confirmAction:
                if let path {
                    self.delegate?.handleConfirmationRequest(forPath: path)
                }
            case Identifiers.undoAction:
                if let path {
                    self.delegate?.handleUndoRequest(forPath: path)
                }
            default:
                break
            }
        }
        completionHandler()
    }
}
