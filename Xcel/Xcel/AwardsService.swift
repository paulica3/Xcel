import Foundation
import SwiftUI

// The end-of-month hardware. Each award is earned from real data for a calendar
// month - wins and box-score quality - so it can't be faked.
enum Award: String, CaseIterable, Identifiable {
    case mvp        // best all-round month
    case mip        // biggest jump vs the month before
    case dpoy       // discipline / lock-in
    case sixthMan   // spark off the bench: going beyond the plan

    var id: String { rawValue }

    var abbrev: String {
        switch self {
        case .mvp: return "MVP"
        case .mip: return "MIP"
        case .dpoy: return "DPOY"
        case .sixthMan: return "6MOY"
        }
    }

    var title: String {
        switch self {
        case .mvp: return "Most Valuable Player"
        case .mip: return "Most Improved Player"
        case .dpoy: return "Defensive Player of the Year"
        case .sixthMan: return "Sixth Man of the Year"
        }
    }

    var icon: String {
        switch self {
        case .mvp: return "crown.fill"
        case .mip: return "chart.line.uptrend.xyaxis"
        case .dpoy: return "shield.lefthalf.filled"
        case .sixthMan: return "bolt.fill"
        }
    }

    func blurb(for m: MonthlyAwards) -> String {
        switch self {
        case .mvp:
            return "You carried the month - \(m.wins)–\(m.losses) with a \(fmt(m.avgBox)) box score. Elite, top-to-bottom."
        case .mip:
            return "Biggest jump in the league. You climbed \(plus(m.boxDelta)) on the box score over last month - the work is showing."
        case .dpoy:
            return "Lockdown discipline - a \(fmt(m.avgDiscipline)) on the glass. You stuck to the plan and shut the excuses down."
        case .sixthMan:
            return "Instant offense off the bench - you went beyond the plan on \(m.extraDays) day\(m.extraDays == 1 ? "" : "s"). Always bringing more."
        }
    }

    private func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
    private func plus(_ v: Double) -> String { String(format: "+%.1f", max(0, v)) }
}

// A single calendar month of play and the awards it earned.
struct MonthlyAwards: Identifiable {
    let id = UUID()
    var monthLabel: String      // "June 2026"
    var sortKey: Int            // year*12 + month, for ordering
    var games: Int
    var wins: Int
    var losses: Int
    var avgBox: Double
    var avgDiscipline: Double
    var extraDays: Int
    var boxDelta: Double        // vs previous month's avg box
    var awards: [Award]

    var winRate: Double { games == 0 ? 0 : Double(wins) / Double(games) }
    var hasHardware: Bool { !awards.isEmpty }
}

enum AwardsService {
    // A month needs a real sample before any award is on the table.
    static let minGames = 5

    static func compute(from allSeries: [Series]) -> [MonthlyAwards] {
        let cal = Calendar.current
        let judged = allSeries
            .flatMap { $0.games }
            .filter { $0.verdict != .pending }

        // Group judged games by calendar month.
        var byMonth: [Int: [Game]] = [:]
        for game in judged {
            let c = cal.dateComponents([.year, .month], from: game.date)
            guard let y = c.year, let mo = c.month else { continue }
            byMonth[y * 12 + mo, default: []].append(game)
        }

        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"

        var months: [MonthlyAwards] = []
        for (key, games) in byMonth.sorted(by: { $0.key < $1.key }) {
            let wins = games.filter { $0.verdict == .win }.count
            let losses = games.filter { $0.verdict == .loss }.count
            let box = BoxScoreAverages.compute(from: games)
            let extraDays = games.filter { !$0.extraNotes.isEmpty }.count

            let prevBox = byMonth[key - 1].map { BoxScoreAverages.compute(from: $0).overall }
            let boxDelta = prevBox.map { box.overall - $0 } ?? 0

            // Label from any game in the month.
            let label = games.first.map { df.string(from: $0.date) } ?? "—"

            var m = MonthlyAwards(
                monthLabel: label, sortKey: key, games: games.count,
                wins: wins, losses: losses,
                avgBox: box.overall, avgDiscipline: box.discipline,
                extraDays: extraDays, boxDelta: boxDelta, awards: []
            )
            m.awards = decideAwards(for: m, hasPrev: prevBox != nil)
            months.append(m)
        }

        // Most recent month first.
        return months.sorted { $0.sortKey > $1.sortKey }
    }

    private static func decideAwards(for m: MonthlyAwards, hasPrev: Bool) -> [Award] {
        guard m.games >= minGames else { return [] }
        var earned: [Award] = []

        // MVP - a genuinely dominant month, top and bottom line.
        if m.winRate >= 0.65 && m.avgBox >= 7.5 { earned.append(.mvp) }

        // MIP - a clear step up from the month before.
        if hasPrev && m.boxDelta >= 1.0 { earned.append(.mip) }

        // DPOY - discipline is the defense; reward locking in.
        if m.avgDiscipline >= 7.8 { earned.append(.dpoy) }

        // 6th Man - consistently doing more than the plan asked.
        if m.extraDays >= 4 { earned.append(.sixthMan) }

        return earned
    }
}
