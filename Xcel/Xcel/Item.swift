import SwiftData
import Foundation

@Model
final class Series {
    var id: UUID
    var weekStart: Date
    @Relationship(deleteRule: .cascade, inverse: \Game.series) var games: [Game]

    init(weekStart: Date) {
        self.id = UUID()
        self.weekStart = weekStart
        self.games = []
    }

    var wins: Int { games.filter { $0.verdict == .win }.count }
    var losses: Int { games.filter { $0.verdict == .loss }.count }
    var judgedCount: Int { games.filter { $0.verdict != .pending }.count }

    var seriesResult: SeriesResult {
        if wins >= 4 { return .won }
        if losses >= 4 { return .lost }
        return .inProgress
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

@Model
final class Game {
    var id: UUID
    var date: Date
    var gameNumber: Int
    var morningIntention: String
    var eveningEntry: String
    var verdict: GameVerdict
    var verdictOneLiner: String
    var series: Series?

    init(date: Date, gameNumber: Int) {
        self.id = UUID()
        self.date = date
        self.gameNumber = gameNumber
        self.morningIntention = ""
        self.eveningEntry = ""
        self.verdict = .pending
        self.verdictOneLiner = ""
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    var isMissed: Bool {
        verdict == .pending && date < Calendar.current.startOfDay(for: Date())
    }
}

enum GameVerdict: String, Codable {
    case pending, win, loss
}
