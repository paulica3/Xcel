import Foundation
import UserNotifications

// Schedules repeating daily local notifications. Calendar triggers fire at the
// given wall-clock time in the device's CURRENT time zone, and iOS reschedules
// them automatically if the user travels. Times are driven by AppSettings.
enum NotificationManager {
    private enum Id {
        // Daily ritual reminders are scheduled per-day (not repeating) so today's
        // can be skipped once the user has already done that step.
        static let morningPrefix = "xcel.morning."
        static let lockWarnPrefix = "xcel.lockwarning."
        static let loggingOpenPrefix = "xcel.loggingopen."
        static let eveningPrefix = "xcel.evening."
        // The 4pm check-up is scheduled per-day so it can carry the live score.
        static let checkupPrefix = "xcel.checkup."
        static let stakes = "xcel.stakes"
    }

    // How many days ahead the daily reminders are kept topped up.
    private static let dailyHorizon = 7

    // The series situation that warrants a high-stakes alert.
    enum Stakes {
        case none, elimination, comeback

        static func forSeries(wins: Int, losses: Int) -> Stakes {
            if losses == 3 && wins < 4 { return .elimination }
            if losses - wins >= 2 { return .comeback }
            return .none
        }
    }

    private static let stakesHour = 17
    private static let stakesMinute = 30

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

    // Daily ritual reminders, scheduled per-day over the next week so they can be
    // state-aware: if the user already set today's plan, today's morning + lock
    // nudges are skipped; if they already logged tonight's result, today's
    // logging-open + evening nudges are skipped. Future days are always scheduled
    // (we don't know their state yet); they're refreshed on each app open.
    static func reschedule(enabled: Bool,
                           morning: (hour: Int, minute: Int),
                           evening: (hour: Int, minute: Int),
                           skipTodayMorning: Bool = false,
                           skipTodayEvening: Bool = false) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<dailyHorizon).flatMap { off in
            ["\(Id.morningPrefix)\(off)", "\(Id.lockWarnPrefix)\(off)",
             "\(Id.loggingOpenPrefix)\(off)", "\(Id.eveningPrefix)\(off)"]
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled else { return }

        for offset in 0..<dailyHorizon {
            let isToday = offset == 0
            if !(isToday && skipTodayMorning) {
                addDaily(id: "\(Id.morningPrefix)\(offset)", dayOffset: offset,
                         hour: morning.hour, minute: morning.minute,
                         title: "Set your game plan",
                         body: "Game day. Lock in your plan before tip-off - it locks at noon.")
                addDaily(id: "\(Id.lockWarnPrefix)\(offset)", dayOffset: offset,
                         hour: lockWarnHour, minute: lockWarnMinute,
                         title: "Last call to edit",
                         body: "Your game plan locks at 12:00. Make your changes now - no edits after noon.")
            }
            if !(isToday && skipTodayEvening) {
                addDaily(id: "\(Id.loggingOpenPrefix)\(offset)", dayOffset: offset,
                         hour: Game.loggingOpenHour, minute: 0,
                         title: "Logging is open",
                         body: "The night shift is on. Log your day now - the window closes at 11:59 PM.")
                addDaily(id: "\(Id.eveningPrefix)\(offset)", dayOffset: offset,
                         hour: evening.hour, minute: evening.minute,
                         title: "How'd it go?",
                         body: "The judge is waiting. Log your day before the buzzer.")
            }
        }
    }

    // Reminders are only recalculated when the app is next opened - so if the
    // user acts on today's step without reopening the app afterward (e.g. logs
    // the evening result and never relaunches), the notifications already
    // scheduled earlier that day just sit there and fire anyway. These cancel
    // today's now-irrelevant ones the instant the matching action happens.
    static func cancelTodayMorning() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["\(Id.morningPrefix)0", "\(Id.lockWarnPrefix)0"])
    }

    static func cancelTodayEvening() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["\(Id.loggingOpenPrefix)0", "\(Id.eveningPrefix)0",
                              "\(Id.checkupPrefix)0", Id.stakes])
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

    // High-stakes alert for today when the series is on the line. Cleared and
    // re-evaluated on each app open.
    static func scheduleStakes(enabled: Bool, wins: Int, losses: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Id.stakes])
        guard enabled else { return }

        let stakes = Stakes.forSeries(wins: wins, losses: losses)
        let title: String, body: String
        switch stakes {
        case .none: return
        case .elimination:
            title = "Elimination game tonight"
            body = "Down \(wins)–\(losses). Win tonight or the series is over. Leave it all out there."
        case .comeback:
            title = "The comeback's alive"
            body = "Down \(wins)–\(losses), but not out. Stack the wins and steal this series."
        }

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = stakesHour
        comps.minute = stakesMinute
        guard let fire = cal.date(from: comps), fire > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: Id.stakes, content: content, trigger: trigger))
    }

    private static func checkupBody(wins: Int, losses: Int) -> String {
        let score = "\(wins)–\(losses)"
        let push: String
        if losses > wins {
            push = "You're down. Today you need to really push."
        } else if wins > losses {
            push = "You're ahead - don't let up. Close it out."
        } else {
            push = "It's tied. This one swings the series."
        }
        return "Series is \(score). \(push)"
    }

    // Schedule a one-shot notification on the given day (0 = today) at a wall-clock
    // time. Skips it entirely if that moment has already passed.
    private static func addDaily(id: String, dayOffset: Int, hour: Int, minute: Int, title: String, body: String) {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        guard let fire = cal.date(from: comps), fire > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
