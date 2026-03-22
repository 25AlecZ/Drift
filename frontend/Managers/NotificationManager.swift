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

    func scheduleNudge(for nudge: Nudge, delay: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = "Stay in touch with \(nudge.contact_name)"
        content.body = nudge.talking_points.first ?? "It's been \(nudge.days_since_contact) days. Reach out!"
        content.sound = .default
        content.userInfo = ["nudgeId": nudge.id ?? "", "talkingPointIndex": 0]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: nudge.id ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWeeklyNudges(for nudges: [Nudge]) {
        // Cancel any previously scheduled weekly nudges
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: nudges.compactMap { "weekly-\($0.id ?? "")" }
        )

        // Spread nudges randomly across the next 7 days
        for nudge in nudges {
            let content = UNMutableNotificationContent()
            content.title = "Stay in touch with \(nudge.contact_name)"
            content.body = nudge.talking_points.first ?? "It's been \(nudge.days_since_contact) days. Reach out!"
            content.sound = .default
            content.userInfo = ["nudgeId": nudge.id ?? "", "talkingPointIndex": 0]

            // Random time within the next 7 days (between 1 and 7 days from now)
            let randomDelay = TimeInterval.random(in: 86400...604800)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: randomDelay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "weekly-\(nudge.id ?? UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // Called when notification is tapped
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let nudgeId = userInfo["nudgeId"] as? String ?? ""
        let talkingPointIndex = userInfo["talkingPointIndex"] as? Int ?? 0
        NotificationCenter.default.post(name: .didTapNudgeNotification, object: ["nudgeId": nudgeId, "talkingPointIndex": talkingPointIndex])
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
