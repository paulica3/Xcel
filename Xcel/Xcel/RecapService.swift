import Foundation
import SwiftUI
import SwiftData
import FoundationModels

struct SeriesRecap {
    var headline: String
    var body: String
}

// Self-contained recap card: shows the saved recap, or generates + persists it
// the first time an eligible finished series is viewed. Reused on the series
// scoreboard and in series history.
struct SeriesRecapCard: View {
    let series: Series
    let accent: Color
    @Environment(\.modelContext) private var modelContext
    @State private var generating = false

    var body: some View {
        Group {
            if series.hasRecap {
                VStack(alignment: .leading, spacing: 10) {
                    Text("WEEKLY RECAP")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(accent)
                    if !series.recapHeadline.isEmpty {
                        Text(series.recapHeadline)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Text(series.recapBody)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    ShareCardButton(content: ShareCardContent(
                        tag: "THE SERIES",
                        big: "\(series.wins)–\(series.losses)",
                        bigIsWin: series.seriesResult == .won,
                        headline: series.recapHeadline.isEmpty ? "Another week in the books." : series.recapHeadline,
                        sub: series.seriesResult == .won ? (series.wasComeback ? "Series won · comeback" : "Series won") : "Series wrapped"
                    ), accent: accent)
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.25), lineWidth: 1))
            } else if generating {
                HStack(spacing: 10) {
                    ProgressView().tint(accent)
                    Text("Writing the weekly recap…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
        }
        .task { await loadIfNeeded() }
    }

    private func loadIfNeeded() async {
        guard series.recapEligible, !series.hasRecap, !generating else { return }
        generating = true
        let recap = await RecapService.generate(for: series)
        series.recapHeadline = recap.headline
        series.recapBody = recap.body
        try? modelContext.save()
        generating = false
    }
}

// Broadcast-style wrap-up for a finished 7-game series.
enum RecapService {
    static func generate(for series: Series) async -> SeriesRecap {
        let games = series.games
            .filter { $0.verdict != .pending }
            .sorted { $0.gameNumber < $1.gameNumber }

        if let ai = try? await analyzeWithAI(series: series, games: games) {
            return ai
        }
        return heuristic(series: series, games: games)
    }

    // MARK: - AI

    private static func analyzeWithAI(series: Series, games: [Game]) async throws -> SeriesRecap {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw JudgeError.modelUnavailable }

        let instructions = """
        You are a sports broadcaster delivering the post-series wrap-up of someone's week.
        Each week is a best-of-seven playoff series; each day is a game they won or lost based on
        whether they followed through on their plan. Capture the arc of the week - momentum swings,
        the turning point, how it ended - in a punchy, energetic broadcast voice. Motivating and real,
        never generic. Reference actual days and what happened.

        Respond ONLY with valid JSON, nothing else:
        {"headline":"short punchy series headline","body":"3-4 sentence broadcast recap of the week"}
        """

        var prompt = "Final series result: \(series.wins)–\(series.losses)"
        switch series.seriesResult {
        case .won: prompt += series.wasComeback ? " (WON - comeback from 2+ down).\n" : " (series WON).\n"
        case .lost: prompt += " (series LOST).\n"
        case .inProgress: prompt += " (week ended, unfinished).\n"
        }
        prompt += "\nGame log:\n"
        let df = DateFormatter(); df.dateFormat = "EEE"
        for g in games {
            let mark = g.verdict == .win ? "W" : "L"
            let done = g.checklist.filter { $0.isDone }.count
            prompt += "Game \(g.gameNumber) (\(df.string(from: g.date))) [\(mark)] - \(done)/\(g.checklist.count) tasks done"
            if !g.verdictOneLiner.isEmpty { prompt += " - \"\(g.verdictOneLiner)\"" }
            prompt += "\n"
        }

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let headline = json["headline"] as? String,
              let body = json["body"] as? String else {
            throw JudgeError.parseFailure(response.content)
        }
        return SeriesRecap(headline: headline, body: body)
    }

    // MARK: - Heuristic fallback

    private static func heuristic(series: Series, games: [Game]) -> SeriesRecap {
        let w = series.wins, l = series.losses
        let headline: String
        switch series.seriesResult {
        case .won:
            headline = series.wasComeback ? "Comeback for the ages - \(w)–\(l)." : "Series in the bag - \(w)–\(l)."
        case .lost:
            headline = "They took the series \(w)–\(l). Next week's a new one."
        case .inProgress:
            headline = "Week's a wrap - \(w)–\(l)."
        }

        // Find the longest win streak and any turning point.
        var bestRun = 0, run = 0
        for g in games {
            if g.verdict == .win { run += 1; bestRun = max(bestRun, run) } else { run = 0 }
        }

        var body = "You went \(w)–\(l) across \(games.count) games. "
        if series.wasComeback {
            body += "Down and nearly out, you reeled off the wins when it mattered and stole the series - the kind of week you remember. "
        } else if series.seriesResult == .won {
            body += "You controlled it and closed it out. "
        } else if series.seriesResult == .lost {
            body += "It got away this week, but the tape shows where it slipped - fixable. "
        }
        if bestRun >= 2 { body += "Your best stretch was \(bestRun) straight wins. " }
        body += series.seriesResult == .won ? "Run it back." : "Reset and come out swinging Monday."

        return SeriesRecap(headline: headline, body: body)
    }
}
