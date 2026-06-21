import SwiftUI

// The near-black arena backdrop is fixed; the accent is the user's pick.
extension Color {
    static let arenaBlack = Color(white: 0.04)
    static let neonGreen = AccentTheme.green.color
    static let eliminationRed = Color(red: 1.0, green: 0.23, blue: 0.19)
}

// A top-down basketball court etched faintly into the arena floor. Used as the
// base layer on the main screens. Lines are only a touch lighter than the black
// backdrop so they read as court markings without lifting the dark aesthetic.
struct CourtBackground: View {
    var lineColor: Color = Color(white: 0.09)
    var lineWidth: CGFloat = 1.5

    var body: some View {
        ZStack {
            Color.arenaBlack
            CourtLines()
                .stroke(lineColor, lineWidth: lineWidth)
        }
        .ignoresSafeArea()
    }
}

// Vertical full-court markings drawn to fit any rect.
struct CourtLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let m = min(rect.width, rect.height) * 0.05
        let court = rect.insetBy(dx: m, dy: m)
        let midX = court.midX, midY = court.midY

        // Boundary + half-court line.
        p.addRoundedRect(in: court, cornerSize: CGSize(width: 10, height: 10))
        p.move(to: CGPoint(x: court.minX, y: midY))
        p.addLine(to: CGPoint(x: court.maxX, y: midY))

        // Center circle.
        let cc = court.width * 0.13
        p.addEllipse(in: CGRect(x: midX - cc, y: midY - cc, width: cc * 2, height: cc * 2))

        // Keys, free-throw circles, hoops, backboards, three-point arcs - both ends.
        let keyW = court.width * 0.34
        let keyH = court.height * 0.17
        let ftR = keyW * 0.5
        for top in [true, false] {
            let baseY = top ? court.minY : court.maxY
            let dir: CGFloat = top ? 1 : -1

            let keyRect = CGRect(x: midX - keyW / 2,
                                 y: top ? baseY : baseY - keyH,
                                 width: keyW, height: keyH)
            p.addRect(keyRect)

            let ftCenter = CGPoint(x: midX, y: baseY + dir * keyH)
            p.addEllipse(in: CGRect(x: ftCenter.x - ftR, y: ftCenter.y - ftR, width: ftR * 2, height: ftR * 2))

            let hoopY = baseY + dir * (court.height * 0.04)
            p.addEllipse(in: CGRect(x: midX - 4, y: hoopY - 4, width: 8, height: 8))

            let bbY = baseY + dir * (court.height * 0.022)
            p.move(to: CGPoint(x: midX - keyW * 0.32, y: bbY))
            p.addLine(to: CGPoint(x: midX + keyW * 0.32, y: bbY))

            // Three-point line: two straight corners running square off the
            // baseline, joined by an arc centered on the hoop. cornerHalf < tpR so
            // the corners sit on the circle and the arc meets them cleanly.
            let tpR = court.width * 0.46
            let cornerHalf = court.width * 0.40
            let off = (tpR * tpR - cornerHalf * cornerHalf).squareRoot()
            let jY = hoopY + dir * off

            p.move(to: CGPoint(x: midX - cornerHalf, y: baseY))
            p.addLine(to: CGPoint(x: midX - cornerHalf, y: jY))
            p.move(to: CGPoint(x: midX + cornerHalf, y: baseY))
            p.addLine(to: CGPoint(x: midX + cornerHalf, y: jY))

            let aR = atan2(Double(dir * off), Double(cornerHalf))
            let aL = atan2(Double(dir * off), Double(-cornerHalf))
            let steps = 40
            p.move(to: CGPoint(x: midX + cornerHalf, y: jY))
            for i in 1...steps {
                let a = aR + (aL - aR) * Double(i) / Double(steps)
                p.addLine(to: CGPoint(x: midX + tpR * CGFloat(cos(a)),
                                      y: hoopY + tpR * CGFloat(sin(a))))
            }
        }
        return p
    }
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
    // The guide whose voice the judge speaks in.
    var guide: Guide {
        didSet { UserDefaults.standard.set(guide.rawValue, forKey: Keys.guide) }
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
    // High-stakes elimination/comeback alerts (separate from the daily ritual).
    var stakesNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(stakesNotificationsEnabled, forKey: Keys.stakesEnabled)
            if !stakesNotificationsEnabled { NotificationManager.scheduleStakes(enabled: false, wins: 0, losses: 0) }
        }
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
        static let guide = "guide"
        static let hasOnboarded = "hasOnboarded"
        static let notifEnabled = "notifEnabled"
        static let stakesEnabled = "stakesEnabled"
        static let morningHour = "morningHour"
        static let morningMinute = "morningMinute"
        static let eveningHour = "eveningHour"
        static let eveningMinute = "eveningMinute"
    }

    init() {
        let d = UserDefaults.standard
        self.accent = AccentTheme(rawValue: d.string(forKey: Keys.accent) ?? "") ?? .green
        self.userName = d.string(forKey: Keys.userName) ?? "Champ"
        self.guide = Guide(rawValue: d.string(forKey: Keys.guide) ?? "") ?? .king
        self.profileImageData = Self.readAvatar()
        self.hasOnboarded = d.bool(forKey: Keys.hasOnboarded)
        self.notificationsEnabled = d.object(forKey: Keys.notifEnabled) as? Bool ?? true
        self.stakesNotificationsEnabled = d.object(forKey: Keys.stakesEnabled) as? Bool ?? true
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
