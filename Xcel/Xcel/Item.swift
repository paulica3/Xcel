import SwiftData
import Foundation

@Model
final class Series {
    var id: UUID
    var weekStart: Date
    var createdAt: Date
    // A warm-up is the user's first week when they joined mid-week: full 4 wins
    // is impossible, so it's reps-only - judged for practice, not counted as a
    // real series. The first real best-of-7 starts the following Monday.
    var isWarmup: Bool = false
    // End-of-week broadcast recap, generated once when the series finishes.
    var recapHeadline: String = ""
    var recapBody: String = ""
    // Follow-through accountability: after a won Challenge Call, the NEXT series is
    // checked against the promise the player made. `followUpEvaluated` marks that
    // check as done; `followUpHonored` is whether they actually lived out the plan.
    // A dishonored follow-up locks the Challenge Call for the series after this one.
    var followUpEvaluated: Bool = false
    var followUpHonored: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Game.series) var games: [Game]

    var hasRecap: Bool { !recapBody.isEmpty }

    // A real (non-warm-up) series is recap-ready once it's clinched, or once
    // its week is fully in the past.
    var recapEligible: Bool {
        guard !isWarmup else { return false }
        if seriesResult != .inProgress { return true }
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return Date() >= weekEnd && judgedCount > 0
    }

    init(weekStart: Date, isWarmup: Bool = false) {
        self.id = UUID()
        self.weekStart = weekStart
        self.createdAt = Date()
        self.isWarmup = isWarmup
        self.games = []
    }

    var wins: Int { games.filter { $0.verdict == .win && !$0.excused }.count }
    var losses: Int { games.filter { $0.verdict == .loss && !$0.excused }.count }
    var judgedCount: Int { games.filter { $0.verdict != .pending }.count }

    // One Challenge Call per series (NBA coach's-challenge style): the user can
    // contest a single loss by making their case to the judge. Win or lose the
    // challenge, it's spent - so it's used on a game with a real reason, not as a
    // weekly free pass. A successful challenge flips the loss into a win (the call
    // is overturned in the player's favour, just like the NBA).
    var challengeUsed: Bool { games.contains { $0.challenged } }
    var canChallenge: Bool {
        !isWarmup && !challengeUsed && games.contains { $0.verdict == .loss && !$0.excused && !$0.challenged }
    }

    // The promise text from a won Challenge Call this series (if any) - the plan
    // the player will be held to next week by the follow-through check.
    var overturnedChallengePlan: String? {
        games.first { $0.challenged && $0.challengeOverturned }?.challengeStatement
    }

    // A real series is "complete" once it clinches or its calendar week has passed
    // - the point at which we can fairly judge whether a follow-through happened.
    var isComplete: Bool {
        guard !isWarmup else { return false }
        if seriesResult != .inProgress { return true }
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return Date() >= weekEnd
    }

    // Games the user can still play: today + future days this week that are
    // unjudged. Excludes days before the user started (they're void, not losses).
    var gamesRemaining: Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return games.filter {
            $0.verdict == .pending && Calendar.current.startOfDay(for: $0.date) >= todayStart
        }.count
    }

    // Every game has a final state (excused games carry verdict .loss but are
    // flagged excused). The week is settled once none are still pending.
    var allGamesSettled: Bool {
        !games.isEmpty && games.allSatisfy { $0.verdict != .pending }
    }

    var seriesResult: SeriesResult {
        // A warm-up never clinches - it stays "in progress" so it's never
        // framed as a won or lost series.
        if isWarmup { return .inProgress }
        if wins >= 4 { return .won }
        if losses >= 4 { return .lost }
        // Excused games (Injured Reserve / Timeout) void a slot, so the counting
        // games can be even and a week can end level - 3-3 with nobody at 4.
        // There are NO draws: once every game is settled, more wins takes it, and
        // a dead-even battle goes to the competitor who fought through the
        // adversity that earned the excuse.
        if allGamesSettled {
            return losses > wins ? .lost : .won
        }
        return .inProgress
    }

    // User must win or the series is over (down 1-3, 0-3, etc). Not in warm-up.
    var userFacingElimination: Bool { !isWarmup && losses == 3 && wins < 4 }

    // Won the series after trailing by 2+ games at some point - the marquee arc.
    var wasComeback: Bool {
        guard seriesResult == .won else { return false }
        var w = 0, l = 0, trailedBy2 = false
        for game in games.sorted(by: { $0.gameNumber < $1.gameNumber }) where !game.excused {
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
    // The one task that matters most today - the judge weights it heavier.
    var isGameBall: Bool
    // Optional photo proof: a downscaled JPEG thumbnail plus the on-device
    // verification result (same-day EXIF check + Vision label match).
    var photoData: Data?
    var photoVerified: Bool
    var photoNote: String

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.note = ""
        self.isGameBall = false
        self.photoData = nil
        self.photoVerified = false
        self.photoNote = ""
    }

    // Custom decode so checklists saved before newer fields existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.isDone = try c.decode(Bool.self, forKey: .isDone)
        self.note = try c.decode(String.self, forKey: .note)
        self.isGameBall = try c.decodeIfPresent(Bool.self, forKey: .isGameBall) ?? false
        self.photoData = try c.decodeIfPresent(Data.self, forKey: .photoData)
        self.photoVerified = try c.decodeIfPresent(Bool.self, forKey: .photoVerified) ?? false
        self.photoNote = try c.decodeIfPresent(String.self, forKey: .photoNote) ?? ""
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
    // Box score - the day rated 0-10 across four dimensions (premium breakdown).
    // 0 across the board means "not scored".
    var scoreEffort: Int = 0
    var scoreDiscipline: Int = 0
    var scoreMood: Int = 0
    var scoreProductivity: Int = 0
    // The loss is excused and no longer counts (via a successful Challenge Call
    // or a Timeout power-up).
    var excused: Bool = false
    // Challenge Call: the user contested this loss. `challenged` means the one
    // per-series challenge was spent here (win or lose); `challengeOverturned`
    // is whether the judge flipped the L into a W; `challengeRuling` is the call.
    var challenged: Bool = false
    var challengeOverturned: Bool = false
    var challengeStatement: String = ""
    var challengeRuling: String = ""
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

    var hasBoxScore: Bool {
        scoreEffort + scoreDiscipline + scoreMood + scoreProductivity > 0
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    var morningCompleted: Bool { !checklist.isEmpty }

    // The game plan can only be edited until noon on the game's day. After that
    // it's locked in - you can still log results at night, but no more changes.
    var editsLocked: Bool {
        let cal = Calendar.current
        guard let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) else { return true }
        return Date() >= noon
    }

    // Logging the day's result only opens at 6 PM local time and runs through end
    // of day - you can't grade a day you haven't finished living. Past days read
    // as open (their 6 PM is behind us); today gates until 18:00.
    static let loggingOpenHour = 18
    var isLoggingOpen: Bool {
        let cal = Calendar.current
        guard let open = cal.date(bySettingHour: Game.loggingOpenHour, minute: 0, second: 0, of: date) else { return true }
        return Date() >= open
    }

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

// Average box score across a set of games - the season-long "stat line".
// Each component is a 0-10 mean carried as a float (shown to one decimal).
struct BoxScoreAverages {
    var effort: Double
    var discipline: Double
    var mood: Double
    var productivity: Double
    var count: Int            // how many games actually carried a box score

    var hasData: Bool { count > 0 }
    var overall: Double {
        count == 0 ? 0 : (effort + discipline + mood + productivity) / 4
    }

    static let empty = BoxScoreAverages(effort: 0, discipline: 0, mood: 0, productivity: 0, count: 0)

    static func compute(from games: [Game]) -> BoxScoreAverages {
        let scored = games.filter { $0.hasBoxScore }
        guard !scored.isEmpty else { return .empty }
        let n = Double(scored.count)
        return BoxScoreAverages(
            effort: Double(scored.reduce(0) { $0 + $1.scoreEffort }) / n,
            discipline: Double(scored.reduce(0) { $0 + $1.scoreDiscipline }) / n,
            mood: Double(scored.reduce(0) { $0 + $1.scoreMood }) / n,
            productivity: Double(scored.reduce(0) { $0 + $1.scoreProductivity }) / n,
            count: scored.count
        )
    }
}

// Per-dimension box-score history (oldest → newest) for sparklines.
struct BoxScoreTrend {
    var effort: [Double]
    var discipline: [Double]
    var mood: [Double]
    var productivity: [Double]

    var hasData: Bool { effort.count >= 2 }
    static let empty = BoxScoreTrend(effort: [], discipline: [], mood: [], productivity: [])

    var series: [(String, [Double])] {
        [("EFFORT", effort), ("DISCIPLINE", discipline), ("MOOD", mood), ("PRODUCTIVITY", productivity)]
    }

    static func compute(from games: [Game], limit: Int = 10) -> BoxScoreTrend {
        let scored = games.filter { $0.hasBoxScore }.sorted { $0.date < $1.date }.suffix(limit)
        return BoxScoreTrend(
            effort: scored.map { Double($0.scoreEffort) },
            discipline: scored.map { Double($0.scoreDiscipline) },
            mood: scored.map { Double($0.scoreMood) },
            productivity: scored.map { Double($0.scoreProductivity) }
        )
    }
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

        // Warm-up weeks are practice - they don't count toward the career record.
        // Excused (Injured Reserve) days don't count either.
        for series in allSeries where !series.isWarmup {
            for game in series.games where !game.excused {
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
