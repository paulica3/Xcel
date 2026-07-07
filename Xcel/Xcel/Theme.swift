import SwiftUI
import Combine

// The near-black arena backdrop is fixed; the accent is the user's pick.
extension Color {
    static let arenaBlack = Color(white: 0.04)
    static let neonGreen = AccentTheme.green.color
    static let eliminationRed = Color(red: 1.0, green: 0.23, blue: 0.19)
}

// Tracks whether the software keyboard is currently on screen, so sheets can
// tell "the user is dragging to lower the keyboard" apart from "the user is
// swiping the sheet away."
private final class KeyboardObserver: ObservableObject {
    @Published var isVisible = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in self?.isVisible = true }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in self?.isVisible = false }
            .store(in: &cancellables)
    }
}

// Multi-line text fields (`TextField(..., axis: .vertical)`) treat Return as
// "add a line," not "submit" - with no other affordance the keyboard has no
// way to close. Drag-down-to-dismiss (`.scrollDismissesKeyboard(.interactively)`)
// is the natural fix, same gesture as Messages/Mail, but on a sheet that same
// drag also satisfies the sheet's own swipe-to-dismiss, so a short scroll view
// can close the whole sheet instead of just lowering the keyboard. Disabling
// the sheet's interactive dismiss while the keyboard is actually up removes
// that conflict without adding any visible chrome.
private struct KeyboardDismissModifier: ViewModifier {
    @StateObject private var keyboard = KeyboardObserver()

    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(keyboard.isVisible)
    }
}

extension View {
    func dismissKeyboardOnScroll() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

// A top-down basketball court etched faintly into the arena floor. Used as the
// base layer on the main screens. Lines are only a touch lighter than the black
// backdrop so they read as court markings without lifting the dark aesthetic.
struct CourtBackground: View {
    @Environment(AppSettings.self) private var settings
    // An explicit theme override (used by previews); otherwise the user's pick.
    var theme: ArenaTheme? = nil
    var lineWidth: CGFloat = 1.5

    private var t: ArenaTheme { theme ?? settings.theme }

    var body: some View {
        ZStack {
            t.backdrop
            if t.showGlow {
                RadialGradient(
                    colors: [t.glowColor.opacity(0.55), .clear],
                    center: .center, startRadius: 4, endRadius: 460
                )
            }
            CourtLines()
                .stroke(t.line, lineWidth: lineWidth)

            // Center-court X, like an NBA team's midcourt logo. Accent-colored,
            // very faint, gently breathing in and out on a slow wave. No harsh
            // glow - just a soft ambient swell.
            WaveX(color: settings.accent.color)

            // A whisper of animated film grain over the whole field so the
            // court feels alive/broadcast, not flat. Deliberately gentle.
            GrainOverlay()
        }
        .ignoresSafeArea()
    }
}

// A large "X" wordmark in the accent color that gently breathes on a slow
// sine-like wave. Low opacity and a small soft edge - ambient, not a glow bomb.
private struct WaveX: View {
    var color: Color
    @State private var swell = false

    var body: some View {
        Text("X")
            .font(.system(size: 260, weight: .black))
            .foregroundStyle(color)
            .blur(radius: 6)
            .opacity(swell ? 0.15 : 0.08)
            .scaleEffect(swell ? 1.025 : 1.0)
            .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: swell)
            .onAppear { swell = true }
            .allowsHitTesting(false)
    }
}

// Gentle animated film grain: a sparse field of faint specks re-seeded a few
// times a second so it shimmers subtly without ever being noisy.
private struct GrainOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0)) { timeline in
            Canvas { ctx, size in
                let tick = UInt64(timeline.date.timeIntervalSinceReferenceDate * 10)
                var rng = SeededRNG(seed: tick)
                let count = 700
                for _ in 0..<count {
                    let x = Double.random(in: 0..<max(size.width, 1), using: &rng)
                    let y = Double.random(in: 0..<max(size.height, 1), using: &rng)
                    let a = Double.random(in: 0.0..<0.04, using: &rng)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                        with: .color(.white.opacity(a))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// Tiny deterministic xorshift RNG so each frame's grain is stable within the
// frame but shifts frame-to-frame.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// A bundled cosmetic "look" for the court/arena. Light touch by design: a theme
// swaps the backdrop, the court-line color, and an optional center glow - the
// user's accent color still layers on top of everything. Dark aesthetic always.
enum ArenaTheme: String, CaseIterable, Identifiable {
    case hardwood, blacktop, parquet, midnight, royal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hardwood: return "Hardwood"
        case .blacktop: return "Blacktop"
        case .parquet:  return "Parquet"
        case .midnight: return "Midnight"
        case .royal:    return "Royal"
        }
    }

    var tagline: String {
        switch self {
        case .hardwood: return "The classic. Polished maple."
        case .blacktop: return "Street ball. All grit, no frills."
        case .parquet:  return "Old-school championship wood."
        case .midnight: return "Primetime, under the lights."
        case .royal:    return "Purple-and-gold energy."
        }
    }

    var backdrop: Color {
        switch self {
        case .hardwood: return Color(white: 0.04)
        case .blacktop: return Color(white: 0.02)
        case .parquet:  return Color(red: 0.060, green: 0.048, blue: 0.034)
        case .midnight: return Color(red: 0.025, green: 0.030, blue: 0.055)
        case .royal:    return Color(red: 0.045, green: 0.030, blue: 0.060)
        }
    }

    var line: Color {
        switch self {
        case .hardwood: return Color(white: 0.09)
        case .blacktop: return Color(white: 0.075)
        case .parquet:  return Color(red: 0.20, green: 0.15, blue: 0.08)
        case .midnight: return Color(red: 0.11, green: 0.12, blue: 0.18)
        case .royal:    return Color(red: 0.16, green: 0.11, blue: 0.20)
        }
    }

    var showGlow: Bool {
        switch self {
        case .midnight, .royal: return true
        default: return false
        }
    }

    var glowColor: Color {
        switch self {
        case .midnight: return Color(red: 0.10, green: 0.16, blue: 0.38)
        case .royal:    return Color(red: 0.26, green: 0.12, blue: 0.36)
        default:        return .clear
        }
    }

    // A subtly tinted card surface to match the theme (kept very close to the
    // neutral dark so the light-touch promise holds).
    var surface: Color {
        switch self {
        case .hardwood: return Color(white: 0.07)
        case .blacktop: return Color(white: 0.06)
        case .parquet:  return Color(red: 0.095, green: 0.078, blue: 0.052)
        case .midnight: return Color(red: 0.060, green: 0.070, blue: 0.100)
        case .royal:    return Color(red: 0.080, green: 0.060, blue: 0.100)
        }
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
            let tpR = court.width * 0.52
            let cornerHalf = court.width * 0.42
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

// One approved Off Season (vacation) window. Deliberately UserDefaults-only,
// never synced to Supabase - the free-text description is exactly the kind of
// raw entry the Accounts & Sync design promises stays private to the author,
// which is also what makes the in-app privacy disclaimer literally true.
struct OffSeasonPeriod: Codable, Identifiable {
    var id: UUID
    var requestedAt: Date
    var startDate: Date
    var durationDays: Int
    var description: String
    var aiVerdict: String

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays - 1, to: startDate) ?? startDate
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
    // Set once the user has typed their own name (or explicitly cleared their
    // photo) - once true, a name/photo pulled from Sign in with Apple or the
    // synced account never overwrites it.
    var userNameIsCustom: Bool {
        didSet { UserDefaults.standard.set(userNameIsCustom, forKey: Keys.userNameIsCustom) }
    }
    var profileImageIsCustom: Bool {
        didSet { UserDefaults.standard.set(profileImageIsCustom, forKey: Keys.profileImageIsCustom) }
    }
    // The guide whose voice the judge speaks in.
    var guide: Guide {
        didSet { UserDefaults.standard.set(guide.rawValue, forKey: Keys.guide) }
    }
    // The cosmetic court/arena look. Independent of the accent color.
    var theme: ArenaTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }
    // Recurring daily tasks - pre-loaded into every new day's game plan so the
    // user doesn't re-type their staples (e.g. "20 pushups after waking up").
    var recurringTasks: [String] {
        didSet { UserDefaults.standard.set(recurringTasks, forKey: Keys.recurringTasks) }
    }
    // Approved Off Season vacation windows (max 2/year, enforced by OffSeasonService).
    var offSeasonPeriods: [OffSeasonPeriod] {
        didSet {
            let data = try? JSONEncoder().encode(offSeasonPeriods)
            UserDefaults.standard.set(data, forKey: Keys.offSeasonPeriods)
        }
    }

    // Stored as a file in Documents (too big for UserDefaults).
    var profileImageData: Data? {
        didSet { Self.writeAvatar(profileImageData) }
    }

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Keys.hasOnboarded) }
    }
    // Shown once, right after onboarding - a skippable pitch for Sign in with
    // Apple so the account option isn't buried three taps deep in Account.
    // Never re-shown once seen, even if the user skips without signing in.
    var hasSeenSignInPrompt: Bool {
        didSet { UserDefaults.standard.set(hasSeenSignInPrompt, forKey: Keys.hasSeenSignInPrompt) }
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
        static let userNameIsCustom = "userNameIsCustom"
        static let profileImageIsCustom = "profileImageIsCustom"
        static let guide = "guide"
        static let theme = "arenaTheme"
        static let recurringTasks = "recurringTasks"
        static let offSeasonPeriods = "offSeasonPeriods"
        static let hasOnboarded = "hasOnboarded"
        static let hasSeenSignInPrompt = "hasSeenSignInPrompt"
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
        self.userNameIsCustom = d.bool(forKey: Keys.userNameIsCustom)
        self.profileImageIsCustom = d.bool(forKey: Keys.profileImageIsCustom)
        self.guide = Guide(rawValue: d.string(forKey: Keys.guide) ?? "") ?? .king
        self.theme = ArenaTheme(rawValue: d.string(forKey: Keys.theme) ?? "") ?? .hardwood
        self.recurringTasks = d.stringArray(forKey: Keys.recurringTasks) ?? []
        self.offSeasonPeriods = (d.data(forKey: Keys.offSeasonPeriods)).flatMap {
            try? JSONDecoder().decode([OffSeasonPeriod].self, from: $0)
        } ?? []
        self.profileImageData = Self.readAvatar()
        self.hasOnboarded = d.bool(forKey: Keys.hasOnboarded)
        self.hasSeenSignInPrompt = d.bool(forKey: Keys.hasSeenSignInPrompt)
        self.notificationsEnabled = d.object(forKey: Keys.notifEnabled) as? Bool ?? true
        self.stakesNotificationsEnabled = d.object(forKey: Keys.stakesEnabled) as? Bool ?? true
        self.morningHour = d.object(forKey: Keys.morningHour) as? Int ?? 9
        self.morningMinute = d.object(forKey: Keys.morningMinute) as? Int ?? 0
        self.eveningHour = d.object(forKey: Keys.eveningHour) as? Int ?? 20
        self.eveningMinute = d.object(forKey: Keys.eveningMinute) as? Int ?? 0
    }

    // Pulled in from Sign in with Apple or the synced account - never applied
    // once the user has typed their own name/picked their own photo.
    func applyRemoteName(_ name: String) {
        guard !userNameIsCustom, !name.isEmpty, name != userName else { return }
        userName = name
    }
    func applyRemotePhoto(_ data: Data) {
        guard !profileImageIsCustom, data != profileImageData else { return }
        profileImageData = data
    }

    // Request permission once (on launch), then schedule with today's state so
    // already-completed steps don't nag. `suppressAll` mutes the whole week's
    // reminders without touching the user's actual `notificationsEnabled`
    // preference - used while an Off Season vacation is active.
    func setUpNotifications(skipTodayMorning: Bool = false, skipTodayEvening: Bool = false, suppressAll: Bool = false) {
        NotificationManager.requestAuthorization { _ in
            DispatchQueue.main.async {
                self.applySchedule(skipTodayMorning: skipTodayMorning, skipTodayEvening: skipTodayEvening, suppressAll: suppressAll)
            }
        }
    }

    // Settings-driven reschedule (no game state known): schedule the full week.
    func applySchedule() {
        applySchedule(skipTodayMorning: false, skipTodayEvening: false)
    }

    // State-aware reschedule from ContentView: drop today's morning/lock nudges if
    // the plan is set, and today's logging/evening nudges if the day is logged.
    func applySchedule(skipTodayMorning: Bool, skipTodayEvening: Bool, suppressAll: Bool = false) {
        NotificationManager.reschedule(
            enabled: notificationsEnabled && !suppressAll,
            morning: (morningHour, morningMinute),
            evening: (eveningHour, eveningMinute),
            skipTodayMorning: skipTodayMorning,
            skipTodayEvening: skipTodayEvening
        )
    }
}
