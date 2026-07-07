import Foundation

// Aggregate stats over a player's walkout song history. Nothing here is
// persisted - like BoxScoreAverages/CareerStats, it's cheap to recompute on
// demand from the Game rows that already store songTitle/songArtist/
// songAppleMusicID.
struct SongStat: Identifiable {
    let id: String   // songAppleMusicID
    let title: String
    let artist: String
    let playCount: Int
    let wins: Int
    let losses: Int

    // Below this many plays, a win rate is just noise (2 plays, 2 wins reads
    // as a false "100%"). Mirrors AwardsService's minGames-style gating.
    static let minPlaysForWinRate = 3
    var hasReliableWinRate: Bool { wins + losses >= Self.minPlaysForWinRate }
    var winRate: Double {
        let decided = wins + losses
        return decided == 0 ? 0 : Double(wins) / Double(decided)
    }
}

enum MusicStats {
    // Most-played walkout song within one series - "song of the series".
    // Ties broken by whichever was played first that week.
    static func seriesSong(from games: [Game]) -> SongStat? {
        tally(games: games.sorted { $0.date < $1.date }).first
    }

    // All-time most-played walkout songs, across every judged game with a
    // song attached. `limit` caps how many rows the caller shows.
    static func topSongs(from allSeries: [Series], limit: Int = 5) -> [SongStat] {
        let games = allSeries.flatMap { $0.games }.sorted { $0.date < $1.date }
        return Array(tally(games: games).prefix(limit))
    }

    // Groups games by song, counting plays and win/loss record on days that
    // song was played. Sorted most-played first; only judged, non-excused
    // days count toward wins/losses (same spirit as CareerStats).
    private static func tally(games: [Game]) -> [SongStat] {
        var order: [String] = []   // first-seen order, for stable tie-breaking
        var titles: [String: String] = [:]
        var artists: [String: String] = [:]
        var plays: [String: Int] = [:]
        var wins: [String: Int] = [:]
        var losses: [String: Int] = [:]

        for game in games where game.hasSong {
            let id = game.songAppleMusicID
            if order.contains(id) == false { order.append(id) }
            titles[id] = game.songTitle
            artists[id] = game.songArtist
            plays[id, default: 0] += 1
            guard !game.excused else { continue }
            if game.verdict == .win { wins[id, default: 0] += 1 }
            if game.verdict == .loss { losses[id, default: 0] += 1 }
        }

        return order
            .map { id in
                SongStat(id: id, title: titles[id] ?? "", artist: artists[id] ?? "",
                          playCount: plays[id] ?? 0, wins: wins[id] ?? 0, losses: losses[id] ?? 0)
            }
            .sorted { $0.playCount > $1.playCount }
    }
}
