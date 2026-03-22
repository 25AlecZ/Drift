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
        let talkingPointIndex = Int.random(in: 0..<max(1, nudge.talking_points.count))
        content.title = "Stay in touch with \(nudge.contact_name)"
        content.body = nudge.talking_points.indices.contains(talkingPointIndex) ? nudge.talking_points[talkingPointIndex] : "It's been \(nudge.days_since_contact) days. Reach out!"
        content.sound = .default
        content.userInfo = ["nudgeId": nudge.id ?? "", "talkingPointIndex": talkingPointIndex]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: nudge.id ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWeeklyNudges(for nudges: [Nudge]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: nudges.compactMap { "weekly-\($0.id ?? "")" }
        )

        for nudge in nudges {
            let content = UNMutableNotificationContent()
            let talkingPointIndex = Int.random(in: 0..<max(1, nudge.talking_points.count))
            content.title = "Stay in touch with \(nudge.contact_name)"
            content.body = nudge.talking_points.indices.contains(talkingPointIndex) ? nudge.talking_points[talkingPointIndex] : "It's been \(nudge.days_since_contact) days. Reach out!"
            content.sound = .default
            content.userInfo = ["nudgeId": nudge.id ?? "", "talkingPointIndex": talkingPointIndex]

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

    // Called when notification banner is tapped — remove from pending, open detail
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

    // Called when notification is delivered — add to bell icon list
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let nudgeId = notification.request.content.userInfo["nudgeId"] as? String ?? ""
        NotificationCenter.default.post(name: .didDeliverNudgeNotification, object: nudgeId)
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let didTapNudgeNotification    = Notification.Name("didTapNudgeNotification")
    static let didDeliverNudgeNotification = Notification.Name("didDeliverNudgeNotification")
    static let didSnoozeNudge             = Notification.Name("didSnoozeNudge")
}
