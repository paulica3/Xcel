import Foundation
import UserNotifications

// Schedules repeating daily local notifications. Calendar triggers fire at the
// given wall-clock time in the device's CURRENT time zone, and iOS reschedules
// them automatically if the user travels. Times are driven by AppSettings.
enum NotificationManager {
    private enum Id {
        static let morning = "xcel.morning"
        static let evening = "xcel.evening"
    }

    static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                completion(granted)
            }
    }

    static func reschedule(enabled: Bool, morning: (hour: Int, minute: Int), evening: (hour: Int, minute: Int)) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Id.morning, Id.evening])
        guard enabled else { return }

        add(id: Id.morning, hour: morning.hour, minute: morning.minute,
            title: "Set your game plan",
            body: "Game day. Lock in your plan before tip-off.")

        add(id: Id.evening, hour: evening.hour, minute: evening.minute,
            title: "How'd it go?",
            body: "The judge is waiting. Log your day before the buzzer.")
    }

    private static func add(id: String, hour: Int, minute: Int, title: String, body: String) {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute   // no time zone set → uses the device's local time

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
