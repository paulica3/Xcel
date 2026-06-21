import Foundation
import FoundationModels

// One recurring task and how often it actually got done across the period.
struct TaskStruggle: Identifiable {
    let id = UUID()
    let title: String
    let done: Int
    let total: Int
    var rate: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

// The monthly "verdict against life" plus the patterns behind it.
struct MonthlyInsights {
    var periodLabel: String
    var gamesPlayed: Int
    var wins: Int
    var losses: Int
    var wonAgainstLife: Bool
    var headline: String
    var summary: String
    var successPatterns: [String]
    var blockers: [String]
    var suggestions: [String]
    var struggles: [TaskStruggle]   // recurring tasks you keep dropping
    var bright: [TaskStruggle]      // recurring tasks you reliably nail
    var hasEnoughData: Bool

    static let empty = MonthlyInsights(
        periodLabel: "Last 30 days", gamesPlayed: 0, wins: 0, losses: 0,
        wonAgainstLife: false, headline: "", summary: "",
        successPatterns: [], blockers: [], suggestions: [],
        struggles: [], bright: [], hasEnoughData: false
    )
}

enum InsightsService {
    private static let windowDays = 30
    private static let minGames = 3   // below this, there's nothing meaningful to analyze

    static func compute(from allSeries: [Series]) async -> MonthlyInsights {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -windowDays, to: Date()) ?? .distantPast

        // Judged games in the window (warm-ups still count as lived days here —
        // they're real effort, just not a real series).
        let games = allSeries
            .flatMap { $0.games }
            .filter { $0.verdict != .pending && $0.date >= cutoff }
            .sorted { $0.date < $1.date }

        let wins = games.filter { $0.verdict == .win }.count
        let losses = games.filter { $0.verdict == .loss }.count

        let (struggles, bright) = taskBreakdown(games)

        var insights = MonthlyInsights.empty
        insights.periodLabel = "Last 30 days"
        insights.gamesPlayed = games.count
        insights.wins = wins
        insights.losses = losses
        insights.struggles = struggles
        insights.bright = bright
        insights.hasEnoughData = games.count >= minGames

        guard insights.hasEnoughData else { return insights }

        // Try the on-device model; fall back to a deterministic read of the data.
        if let ai = try? await analyzeWithAI(games: games, struggles: struggles,
                                             bright: bright, wins: wins, losses: losses) {
            insights.wonAgainstLife = ai.wonAgainstLife
            insights.headline = ai.headline
            insights.summary = ai.summary
            insights.successPatterns = ai.successPatterns
            insights.blockers = ai.blockers
            insights.suggestions = ai.suggestions
        } else {
            applyHeuristic(to: &insights)
        }
        return insights
    }

    // MARK: - Deterministic task breakdown

    private static func taskBreakdown(_ games: [Game]) -> (struggles: [TaskStruggle], bright: [TaskStruggle]) {
        struct Tally { var title: String; var done = 0; var total = 0 }
        var tallies: [String: Tally] = [:]

        for game in games {
            for item in game.checklist {
                let key = normalize(item.title)
                guard !key.isEmpty else { continue }
                var t = tallies[key] ?? Tally(title: item.title)
                t.total += 1
                if item.isDone { t.done += 1 }
                tallies[key] = t
            }
        }

        let recurring = tallies.values.filter { $0.total >= 2 }
        let struggles = recurring
            .filter { Double($0.done) / Double($0.total) < 0.6 }
            .map { TaskStruggle(title: $0.title, done: $0.done, total: $0.total) }
            .sorted { $0.rate != $1.rate ? $0.rate < $1.rate : $0.total > $1.total }
            .prefix(5)
        let bright = recurring
            .filter { Double($0.done) / Double($0.total) >= 0.75 }
            .map { TaskStruggle(title: $0.title, done: $0.done, total: $0.total) }
            .sorted { $0.rate != $1.rate ? $0.rate > $1.rate : $0.total > $1.total }
            .prefix(3)
        return (Array(struggles), Array(bright))
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    // MARK: - AI analysis

    private struct AIInsights {
        var wonAgainstLife: Bool
        var headline: String
        var summary: String
        var successPatterns: [String]
        var blockers: [String]
        var suggestions: [String]
    }

    private static func analyzeWithAI(games: [Game], struggles: [TaskStruggle],
                                      bright: [TaskStruggle], wins: Int, losses: Int) async throws -> AIInsights {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw JudgeError.modelUnavailable }

        let instructions = """
        You are a performance analyst reviewing someone's last month of daily self-discipline "games".
        Each day they set a plan of tasks, then logged what they did or didn't do, and got a Win or Loss.
        Your job: find the REAL patterns — what drives their wins, and what keeps tripping them up — and
        deliver a straight, motivating monthly verdict on whether they won against life this month.

        Rules:
        - Be specific and grounded in the data you're given. Reference actual task themes and behaviors.
        - No empty platitudes. Every point must be something they could act on or recognize.
        - Honest but constructive. Name the blockers plainly; frame them as fixable.

        Respond ONLY with valid JSON, nothing else:
        {"wonAgainstLife":true,"headline":"short punchy verdict line","summary":"2-3 sentence overview","successPatterns":["...","..."],"blockers":["...","..."],"suggestions":["...","..."]}
        """

        var prompt = "Month record: \(wins) wins, \(losses) losses across \(games.count) days.\n\n"
        prompt += "Recurring tasks they KEEP DROPPING (done/total):\n"
        if struggles.isEmpty { prompt += "  (none stand out)\n" }
        for s in struggles { prompt += "  - \(s.title): \(s.done)/\(s.total)\n" }
        prompt += "\nRecurring tasks they RELIABLY DO (done/total):\n"
        if bright.isEmpty { prompt += "  (none stand out)\n" }
        for b in bright { prompt += "  - \(b.title): \(b.done)/\(b.total)\n" }

        prompt += "\nDay-by-day:\n"
        let df = DateFormatter(); df.dateFormat = "EEE MMM d"
        for game in games.suffix(28) {
            let mark = game.verdict == .win ? "W" : "L"
            let doneCount = game.checklist.filter { $0.isDone }.count
            prompt += "\(df.string(from: game.date)) [\(mark)] \(doneCount)/\(game.checklist.count) done"
            let missed = game.checklist.filter { !$0.isDone }.map { $0.title }
            if !missed.isEmpty { prompt += " — missed: \(missed.joined(separator: ", "))" }
            prompt += "\n"
        }

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return try parse(response.content)
    }

    private static func parse(_ raw: String) throws -> AIInsights {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JudgeError.parseFailure(raw)
        }
        func strings(_ key: String) -> [String] {
            (json[key] as? [Any])?.compactMap { $0 as? String } ?? []
        }
        return AIInsights(
            wonAgainstLife: (json["wonAgainstLife"] as? Bool) ?? false,
            headline: (json["headline"] as? String) ?? "",
            summary: (json["summary"] as? String) ?? "",
            successPatterns: strings("successPatterns"),
            blockers: strings("blockers"),
            suggestions: strings("suggestions")
        )
    }

    // MARK: - Heuristic fallback (no AI on device)

    private static func applyHeuristic(to insights: inout MonthlyInsights) {
        let total = max(insights.gamesPlayed, 1)
        let winRate = Double(insights.wins) / Double(total)
        insights.wonAgainstLife = winRate >= 0.5

        let pct = Int((winRate * 100).rounded())
        insights.headline = insights.wonAgainstLife
            ? "You won the month — \(insights.wins)–\(insights.losses)."
            : "Life took this month — \(insights.wins)–\(insights.losses). Not the next one."
        insights.summary = "You played \(insights.gamesPlayed) games and won \(pct)% of them. "
            + (insights.wonAgainstLife
               ? "More wins than losses — the habit is taking hold."
               : "The losses outweighed the wins. The plan is there; the follow-through is the gap.")

        insights.successPatterns = insights.bright.map {
            "You almost never skip “\($0.title)” (\($0.done)/\($0.total)) — that's an anchor habit."
        }
        if insights.successPatterns.isEmpty && insights.wins > 0 {
            insights.successPatterns = ["Your wins line up with days you finished most of your plan — completion is your edge."]
        }

        insights.blockers = insights.struggles.prefix(3).map {
            "“\($0.title)” keeps slipping — only \($0.done) of \($0.total) days done."
        }
        if insights.blockers.isEmpty {
            insights.blockers = ["No single task is dragging you down — the misses are scattered, which usually means inconsistent days, not one bad habit."]
        }

        insights.suggestions = insights.struggles.prefix(2).map {
            "Shrink “\($0.title)” to the smallest version you'll actually do, and put it first."
        }
        insights.suggestions.append(insights.wonAgainstLife
            ? "Raise the bar next month: add one harder task you'd be proud to win."
            : "Aim for one clean, fully-completed day to start — momentum beats intensity.")
    }
}
