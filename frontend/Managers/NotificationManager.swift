import UserNotifications
import Foundation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleNudge(for nudge: Nudge) {
        let content = UNMutableNotificationContent()
        content.title = "Stay in touch with \(nudge.contact_name)"
        content.body = nudge.talking_points.first ?? "It's been \(nudge.days_since_contact) days. Reach out!"
        content.sound = .default
        content.userInfo = ["nudgeId": nudge.id ?? ""]

        // Fire after 5 seconds for testing; swap for a real trigger in production
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: nudge.id ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Called when notification is tapped
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let nudgeId = response.notification.request.content.userInfo["nudgeId"] as? String ?? ""
        NotificationCenter.default.post(name: .didTapNudgeNotification, object: nudgeId)
        completionHandler()
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let didTapNudgeNotification = Notification.Name("didTapNudgeNotification")
}
