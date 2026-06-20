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

    private enum Keys {
        static let accent = "accentTheme"
        static let userName = "userName"
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Keys.accent)
        self.accent = AccentTheme(rawValue: raw ?? "") ?? .green
        self.userName = UserDefaults.standard.string(forKey: Keys.userName) ?? "Champ"
    }
}
