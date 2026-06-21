import SwiftData
import Foundation

@Model
final class Series {
    var id: UUID
    var weekStart: Date
    var createdAt: Date
    // A warm-up is the user's first week when they joined mid-week: full 4 wins
    // is impossible, so it's reps-only — judged for practice, not counted as a
    // real series. The first real best-of-7 starts the following Monday.
    var isWarmup: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Game.series) var games: [Game]

    init(weekStart: Date, isWarmup: Bool = false) {
        self.id = UUID()
        self.weekStart = weekStart
        self.createdAt = Date()
        self.isWarmup = isWarmup
        self.games = []
    }

    var wins: Int { games.filter { $0.verdict == .win }.count }
    var losses: Int { games.filter { $0.verdict == .loss }.count }
    var judgedCount: Int { games.filter { $0.verdict != .pending }.count }

    // Games the user can still play: today + future days this week that are
    // unjudged. Excludes days before the user started (they're void, not losses).
    var gamesRemaining: Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return games.filter {
            $0.verdict == .pending && Calendar.current.startOfDay(for: $0.date) >= todayStart
        }.count
    }

    var seriesResult: SeriesResult {
        // A warm-up never clinches — it stays "in progress" so it's never
        // framed as a won or lost series.
        if isWarmup { return .inProgress }
        if wins >= 4 { return .won }
        if losses >= 4 { return .lost }
        return .inProgress
    }

    // User must win or the series is over (down 1-3, 0-3, etc). Not in warm-up.
    var userFacingElimination: Bool { !isWarmup && losses == 3 && wins < 4 }

    // Won the series after trailing by 2+ games at some point — the marquee arc.
    var wasComeback: Bool {
        guard seriesResult == .won else { return false }
        var w = 0, l = 0, trailedBy2 = false
        for game in games.sorted(by: { $0.gameNumber < $1.gameNumber }) {
            switch game.verdict {
            case .win: w += 1
            case .loss: l += 1
            case .pending: break
            }
            if l - w >= 2 { trailedBy2 = true }
        }
        return trailedBy2
    }

    static func mondayOf(_ date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}

enum SeriesResult: String, Codable {
    case won, lost, inProgress
}

// One task the user committed to in the morning, reviewed at night.
struct ChecklistItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var isDone: Bool
    var note: String   // proof of how it was done, or the reason it wasn't

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.note = ""
    }
}

@Model
final class Game {
    var id: UUID
    var date: Date
    var gameNumber: Int
    var checklist: [ChecklistItem]
    var extraNotes: String   // anything done beyond the plan
    var verdict: GameVerdict
    var verdictOneLiner: String
    var verdictFeedback: String
    var series: Series?

    init(date: Date, gameNumber: Int) {
        self.id = UUID()
        self.date = date
        self.gameNumber = gameNumber
        self.checklist = []
        self.extraNotes = ""
        self.verdict = .pending
        self.verdictOneLiner = ""
        self.verdictFeedback = ""
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    var morningCompleted: Bool { !checklist.isEmpty }

    // Past, unjudged, and the user had a chance to play it (series already existed).
    func isMissed(seriesCreatedAt: Date) -> Bool {
        guard verdict == .pending else { return false }
        let dayStart = Calendar.current.startOfDay(for: date)
        let todayStart = Calendar.current.startOfDay(for: Date())
        let createdStart = Calendar.current.startOfDay(for: seriesCreatedAt)
        return dayStart < todayStart && dayStart >= createdStart
    }
}

enum GameVerdict: String, Codable {
    case pending, win, loss
}

// All-time identity shown on the Home page: record, current win streak, and
// the biggest series comeback ever pulled off.
struct CareerStats {
    var wins: Int
    var losses: Int
    var currentStreak: Int        // consecutive game wins ending at the latest judged game
    var bestComebackDeficit: Int  // largest game deficit erased in a won series (0 = none)

    var hasHistory: Bool { wins + losses > 0 }

    static func compute(from allSeries: [Series]) -> CareerStats {
        var wins = 0, losses = 0
        var judged: [Game] = []

        // Warm-up weeks are practice — they don't count toward the career record.
        for series in allSeries where !series.isWarmup {
            for game in series.games {
                switch game.verdict {
                case .win: wins += 1; judged.append(game)
                case .loss: losses += 1; judged.append(game)
                case .pending: break
                }
            }
        }

        // Current streak: walk backwards through judged games by date.
        var streak = 0
        for game in judged.sorted(by: { $0.date > $1.date }) {
            if game.verdict == .win { streak += 1 } else { break }
        }

        // Best comeback: deepest hole climbed out of in any series the user won.
        var bestDeficit = 0
        for series in allSeries where !series.isWarmup && series.seriesResult == .won {
            var w = 0, l = 0, maxDeficit = 0
            for game in series.games.sorted(by: { $0.gameNumber < $1.gameNumber }) {
                switch game.verdict {
                case .win: w += 1
                case .loss: l += 1
                case .pending: break
                }
                maxDeficit = max(maxDeficit, l - w)
            }
            bestDeficit = max(bestDeficit, maxDeficit)
        }

        return CareerStats(wins: wins, losses: losses,
                           currentStreak: streak, bestComebackDeficit: bestDeficit)
    }
}
