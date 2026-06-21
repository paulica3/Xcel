import Foundation

// The judge's long-term memory of the player. Built from every prior series so a
// daily verdict can reference real, longitudinal patterns ("third Monday in a row
// you skipped the gym - that's your weak side") instead of judging each day cold.
//
// This is tone/personalization context only: it never changes how strictly the
// day is scored, exactly like the guide voice. Computed on-device from the same
// SwiftData the rest of the app reads - no network, no extra storage.
struct SeasonMemory {
    var record: (wins: Int, losses: Int)
    var currentStreak: Int          // consecutive game wins ending now
    var weakdayLabel: String?       // weekday the user historically drops, e.g. "Monday"
    var weakdayRecord: (w: Int, l: Int)?
    var droppedTask: String?        // recurring task most often left undone
    var droppedRate: (done: Int, total: Int)?

    var hasAnything: Bool {
        record.wins + record.losses > 0
    }

    // A compact, one-line-per-fact briefing handed to the judge prompt.
    var briefing: String {
        guard hasAnything else { return "" }
        var lines: [String] = []
        lines.append("Career record: \(record.wins)-\(record.losses).")
        if currentStreak >= 2 {
            lines.append("Riding a \(currentStreak)-game win streak right now - protecting it matters to them.")
        } else if currentStreak == 0 && record.losses > 0 {
            lines.append("Coming off a loss - looking to bounce back.")
        }
        if let day = weakdayLabel, let r = weakdayRecord {
            lines.append("Historically struggles on \(day)s (\(r.w)-\(r.l)). If today is a \(day), acknowledge the pattern.")
        }
        if let task = droppedTask, let r = droppedRate {
            lines.append("Keeps dropping \"\(task)\" (\(r.done)/\(r.total) days). A recurring weak spot.")
        }
        return lines.joined(separator: "\n")
    }

    // A subtle, user-facing nudge shown before they submit (one short sentence).
    var nudge: String? {
        if currentStreak >= 3 {
            return "GM's read: \(currentStreak)-game win streak on the line tonight."
        }
        let today = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
        if let day = weakdayLabel, day == today, let r = weakdayRecord {
            return "GM's read: \(day)s have been your weak side (\(r.w)-\(r.l)). Flip it."
        }
        if let task = droppedTask {
            return "GM's read: \"\(task)\" keeps slipping. Today's the day to nail it."
        }
        return nil
    }

    // Walks every real (non-warm-up) series to assemble the memory. Excludes a
    // series by id (the one currently being judged) so today's in-progress week
    // doesn't pollute the historical read.
    static func build(from allSeries: [Series], excluding excludeID: UUID? = nil) -> SeasonMemory {
        var wins = 0, losses = 0
        var judged: [Game] = []

        for series in allSeries where !series.isWarmup {
            for game in series.games where !game.excused {
                switch game.verdict {
                case .win:  wins += 1;  judged.append(game)
                case .loss: losses += 1; judged.append(game)
                case .pending: break
                }
            }
        }

        // Current streak: walk newest-first across all judged games.
        var streak = 0
        for game in judged.sorted(by: { $0.date > $1.date }) {
            if game.verdict == .win { streak += 1 } else { break }
        }

        // Weakest weekday: lowest win-rate weekday with a meaningful sample.
        var perDay: [Int: (w: Int, l: Int)] = [:]
        for game in judged {
            let wd = Calendar.current.component(.weekday, from: game.date)
            var t = perDay[wd] ?? (0, 0)
            if game.verdict == .win { t.w += 1 } else { t.l += 1 }
            perDay[wd] = t
        }
        var weakdayLabel: String?
        var weakdayRecord: (w: Int, l: Int)?
        var worstRate = 0.5   // only flag genuinely sub-.500 days
        for (wd, r) in perDay where r.w + r.l >= 3 {
            let rate = Double(r.w) / Double(r.w + r.l)
            if rate < worstRate {
                worstRate = rate
                weakdayLabel = Calendar.current.weekdaySymbols[wd - 1]
                weakdayRecord = r
            }
        }

        // Most-dropped recurring task across the history (excluding current week).
        struct Tally { var title: String; var done = 0; var total = 0 }
        var tallies: [String: Tally] = [:]
        for series in allSeries where !series.isWarmup && series.id != excludeID {
            for game in series.games where game.verdict != .pending {
                for item in game.checklist {
                    let key = item.title.lowercased().trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty else { continue }
                    var t = tallies[key] ?? Tally(title: item.title)
                    t.total += 1
                    if item.isDone { t.done += 1 }
                    tallies[key] = t
                }
            }
        }
        let dropped = tallies.values
            .filter { $0.total >= 3 && Double($0.done) / Double($0.total) < 0.5 }
            .min { (Double($0.done) / Double($0.total)) < (Double($1.done) / Double($1.total)) }

        return SeasonMemory(
            record: (wins, losses),
            currentStreak: streak,
            weakdayLabel: weakdayLabel,
            weakdayRecord: weakdayRecord,
            droppedTask: dropped?.title,
            droppedRate: dropped.map { ($0.done, $0.total) }
        )
    }
}
