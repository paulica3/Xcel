import Foundation

// Loaded once from the bundled quotes.json; a fresh random one is shown each app open.
enum Quotes {
    static let all: [String] = load()

    static func random() -> String {
        all.randomElement() ?? "Show up. The rest is footwork."
    }

    private static func load() -> [String] {
        if let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let parsed = try? JSONDecoder().decode([String].self, from: data),
           !parsed.isEmpty {
            return parsed
        }
        return fallback
    }

    private static let fallback = [
        "You miss 100% of the days you don't log.",
        "Hard work beats talent when talent forgets to show up.",
        "Ball don't lie. Neither does the judge.",
        "Down 0-2? That's just a comeback you haven't finished yet.",
        "Win the morning, win the game.",
    ]
}
