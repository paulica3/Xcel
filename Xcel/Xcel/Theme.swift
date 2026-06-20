import SwiftUI

// The near-black arena backdrop is fixed; the accent is the user's pick.
extension Color {
    static let arenaBlack = Color(white: 0.04)
    static let neonGreen = AccentTheme.green.color
}

enum AccentTheme: String, CaseIterable, Identifiable {
    case green, orange, blue, pink, purple, cyan, red, gold

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .green:  return Color(red: 0.224, green: 1.0,   blue: 0.078)
        case .orange: return Color(red: 1.0,   green: 0.42,  blue: 0.0)
        case .blue:   return Color(red: 0.0,   green: 0.70,  blue: 1.0)
        case .pink:   return Color(red: 1.0,   green: 0.18,  blue: 0.60)
        case .purple: return Color(red: 0.69,  green: 0.21,  blue: 1.0)
        case .cyan:   return Color(red: 0.0,   green: 1.0,   blue: 0.82)
        case .red:    return Color(red: 1.0,   green: 0.09,  blue: 0.27)
        case .gold:   return Color(red: 1.0,   green: 0.82,  blue: 0.0)
        }
    }

    var displayName: String {
        switch self {
        case .green:  return "Neon Green"
        case .orange: return "Inferno"
        case .blue:   return "Electric"
        case .pink:   return "Hot Pink"
        case .purple: return "Ultraviolet"
        case .cyan:   return "Ice"
        case .red:    return "Red Alert"
        case .gold:   return "Gold"
        }
    }
}

@Observable
final class AppSettings {
    var accent: AccentTheme {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: Keys.accent) }
    }
    var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: Keys.userName) }
    }

    // Stored as a file in Documents (too big for UserDefaults).
    var profileImageData: Data? {
        didSet { Self.writeAvatar(profileImageData) }
    }

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Keys.hasOnboarded) }
    }
    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifEnabled); applySchedule() }
    }
    var morningHour: Int { didSet { UserDefaults.standard.set(morningHour, forKey: Keys.morningHour); applySchedule() } }
    var morningMinute: Int { didSet { UserDefaults.standard.set(morningMinute, forKey: Keys.morningMinute); applySchedule() } }
    var eveningHour: Int { didSet { UserDefaults.standard.set(eveningHour, forKey: Keys.eveningHour); applySchedule() } }
    var eveningMinute: Int { didSet { UserDefaults.standard.set(eveningMinute, forKey: Keys.eveningMinute); applySchedule() } }

    // Date-of-day bindings for DatePicker; read/write the stored hour+minute.
    var morningTime: Date {
        get { Self.timeOfDay(morningHour, morningMinute) }
        set { let c = Calendar.current.dateComponents([.hour, .minute], from: newValue); morningHour = c.hour ?? 9; morningMinute = c.minute ?? 0 }
    }
    var eveningTime: Date {
        get { Self.timeOfDay(eveningHour, eveningMinute) }
        set { let c = Calendar.current.dateComponents([.hour, .minute], from: newValue); eveningHour = c.hour ?? 20; eveningMinute = c.minute ?? 0 }
    }

    private static func timeOfDay(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    private static var avatarURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatar.jpg")
    }
    private static func writeAvatar(_ data: Data?) {
        if let data { try? data.write(to: avatarURL) }
        else { try? FileManager.default.removeItem(at: avatarURL) }
    }
    private static func readAvatar() -> Data? { try? Data(contentsOf: avatarURL) }

    private enum Keys {
        static let accent = "accentTheme"
        static let userName = "userName"
        static let hasOnboarded = "hasOnboarded"
        static let notifEnabled = "notifEnabled"
        static let morningHour = "morningHour"
        static let morningMinute = "morningMinute"
        static let eveningHour = "eveningHour"
        static let eveningMinute = "eveningMinute"
    }

    init() {
        let d = UserDefaults.standard
        self.accent = AccentTheme(rawValue: d.string(forKey: Keys.accent) ?? "") ?? .green
        self.userName = d.string(forKey: Keys.userName) ?? "Champ"
        self.profileImageData = Self.readAvatar()
        self.hasOnboarded = d.bool(forKey: Keys.hasOnboarded)
        self.notificationsEnabled = d.object(forKey: Keys.notifEnabled) as? Bool ?? true
        self.morningHour = d.object(forKey: Keys.morningHour) as? Int ?? 9
        self.morningMinute = d.object(forKey: Keys.morningMinute) as? Int ?? 0
        self.eveningHour = d.object(forKey: Keys.eveningHour) as? Int ?? 20
        self.eveningMinute = d.object(forKey: Keys.eveningMinute) as? Int ?? 0
    }

    // Request permission once (on launch), then schedule.
    func setUpNotifications() {
        NotificationManager.requestAuthorization { _ in
            DispatchQueue.main.async { self.applySchedule() }
        }
    }

    func applySchedule() {
        NotificationManager.reschedule(
            enabled: notificationsEnabled,
            morning: (morningHour, morningMinute),
            evening: (eveningHour, eveningMinute)
        )
    }
}
