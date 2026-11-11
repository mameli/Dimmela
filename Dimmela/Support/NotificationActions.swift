import UserNotifications

/// The buttons on Dimmela's notifications. *Reprocess* sits on "Post-processing failed":
/// once the provider is back, one click instead of the History submenu.
final class NotificationActions: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let postProcessingFailed = "postProcessingFailed"
    private static let postProcessAgain = "postProcessAgain"

    private let onPostProcessAgain: @MainActor () -> Void

    init(onPostProcessAgain: @escaping @MainActor () -> Void) {
        self.onPostProcessAgain = onPostProcessAgain
        super.init()
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.postProcessingFailed,
                actions: [UNNotificationAction(identifier: Self.postProcessAgain, title: "Reprocess")],
                intentIdentifiers: []
            ),
        ])
        center.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.postProcessAgain else { return }
        await onPostProcessAgain()
    }

    /// Shown also while Dimmela is the active app, as right after its menu was used: without a
    /// delegate macOS did so by itself.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
