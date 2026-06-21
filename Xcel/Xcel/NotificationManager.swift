import Foundation
import UserNotifications

// Schedules repeating daily local notifications. Calendar triggers fire at the
// given wall-clock time in the device's CURRENT time zone, and iOS reschedules
// them automatically if the user travels. Times are driven by AppSettings.
enum NotificationManager {
    private enum Id {
        static let morning = "xcel.morning"
        static let lockWarning = "xcel.lockwarning"
        static let evening = "xcel.evening"
        // The 4pm check-up is scheduled per-day so it can carry the live score.
        static let checkupPrefix = "xcel.checkup."
    }

    // The morning plan locks at noon; the 4pm check-up fires mid-afternoon.
    static let lockHour = 12
    private static let lockWarnHour = 11
    private static let lockWarnMinute = 30
    private static let checkupHour = 16
    private static let checkupDays = 7   // how many days ahead to keep topped up

    static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                completion(granted)
            }
    }

    static func reschedule(enabled: Bool, morning: (hour: Int, minute: Int), evening: (hour: Int, minute: Int)) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Id.morning, Id.lockWarning, Id.evening])
        guard enabled else { return }

        addRepeating(id: Id.morning, hour: morning.hour, minute: morning.minute,
                     title: "Set your game plan",
                     body: "Game day. Lock in your plan before tip-off — it locks at noon.")

        addRepeating(id: Id.lockWarning, hour: lockWarnHour, minute: lockWarnMinute,
                     title: "Last call to edit",
                     body: "Your game plan locks at 12:00. Make your changes now — no edits after noon.")

        addRepeating(id: Id.evening, hour: evening.hour, minute: evening.minute,
                     title: "How'd it go?",
                     body: "The judge is waiting. Log your day before the buzzer.")
    }

    // The 4pm check-up carries the current series score, so it can't be a single
    // repeating notification. Re-scheduled on each app open for the next few days
    // (today gets the live score; later days refresh next time the app opens).
    static func scheduleCheckups(enabled: Bool, wins: Int, losses: Int) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<checkupDays).map { "\(Id.checkupPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled else { return }

        let cal = Calendar.current
        let body = checkupBody(wins: wins, losses: losses)

        for offset in 0..<checkupDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = checkupHour
            comps.minute = 0
            // Skip if today's 4pm has already passed.
            if let fire = cal.date(from: comps), fire <= Date() { continue }

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = "Halftime check"
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "\(Id.checkupPrefix)\(offset)",
                                             content: content, trigger: trigger))
        }
    }

    private static func checkupBody(wins: Int, losses: Int) -> String {
        let score = "\(wins)–\(losses)"
        let push: String
        if losses > wins {
            push = "You're down. Today you need to really push."
        } else if wins > losses {
            push = "You're ahead — don't let up. Close it out."
        } else {
            push = "It's tied. This one swings the series."
        }
        return "Series is \(score). \(push)"
    }

    private static func addRepeating(id: String, hour: Int, minute: Int, title: String, body: String) {
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
