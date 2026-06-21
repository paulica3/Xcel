import SwiftUI

struct SeriesView: View {
    let series: Series
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showHistory = false
    @State private var showEntry = false
    @State private var showResult = false

    private var accent: Color { settings.accent.color }
    private var todayGame: Game? { series.games.first { $0.isToday } }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        scoreboard
                            .padding(.top, 32)
                        weekLog
                            .padding(.top, 36)
                    }
                    .padding(.bottom, 24)
                }
                ctaSection
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showHistory) { HistoryView() }
        .sheet(isPresented: $showEntry) {
            if let game = todayGame {
                NavigationStack {
                    EntryView(game: game, onComplete: { showEntry = false })
                }
            }
        }
        .sheet(isPresented: $showResult) {
            if let game = todayGame {
                NavigationStack {
                    GameResultView(game: game)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))
            }
            Spacer()
            Text("THE SERIES")
                .font(.system(size: 13, weight: .black))
                .kerning(2)
                .foregroundStyle(accent)
            Spacer()
            Button { showHistory = true } label: {
                Image(systemName: "clock.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(Color(white: 0.4))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var scoreboard: some View {
        VStack(spacing: 12) {
            if series.isWarmup {
                Text("WARM-UP WEEK")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(accent)
                    .kerning(2.5)
            } else if let game = todayGame {
                Text("GAME \(game.gameNumber) OF 7")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
                    .kerning(2.5)
            }

            HStack(alignment: .center, spacing: 28) {
                scoreColumn(value: series.wins, label: "W", color: accent)
                Text("–")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(Color(white: 0.25))
                scoreColumn(value: series.losses, label: "L", color: Color(white: 0.4))
            }
            .padding(.vertical, 8)

            Text(statusLine(for: series))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.38))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            gameDots(series: series)
                .padding(.top, 8)
        }
    }

    private func scoreColumn(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 88, weight: .black))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color.opacity(0.55))
                .kerning(2)
        }
    }

    private func gameDots(series: Series) -> some View {
        let sorted = series.games.sorted { $0.gameNumber < $1.gameNumber }
        return HStack(spacing: 6) {
            ForEach(sorted) { game in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(dotColor(for: game))
            }
        }
    }

    private func dotColor(for game: Game) -> Color {
        switch game.verdict {
        case .win: return accent
        case .loss: return Color(white: 0.25)
        case .pending: return game.isToday ? Color(white: 0.55) : Color(white: 0.13)
        }
    }

    // MARK: This week's game log — past days you've logged, tap to review.

    private var loggedGames: [Game] {
        series.games
            .filter { $0.verdict != .pending }
            .sorted { $0.gameNumber > $1.gameNumber }
    }

    @ViewBuilder
    private var weekLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS WEEK")
                .font(.system(size: 11, weight: .bold))
                .kerning(2.5)
                .foregroundStyle(Color(white: 0.35))
                .padding(.horizontal, 4)

            if loggedGames.isEmpty {
                Text("No games logged yet. Win Game \(todayGame?.gameNumber ?? 1) tonight.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.3))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
            } else {
                ForEach(loggedGames) { game in
                    NavigationLink {
                        GameResultView(game: game)
                    } label: {
                        logRow(game)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func logRow(_ game: Game) -> some View {
        let isWin = game.verdict == .win
        return HStack(spacing: 14) {
            Text(isWin ? "W" : "L")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(isWin ? accent : Color(white: 0.4))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("Game \(game.gameNumber) · \(dayLabel(game.date))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                if !game.verdictOneLiner.isEmpty {
                    Text(game.verdictOneLiner)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    @ViewBuilder
    private var ctaSection: some View {
        if let game = todayGame {
            Button {
                if game.verdict == .pending { showEntry = true } else { showResult = true }
            } label: {
                ctaLabel(for: game)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(ctaBackground(for: game))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        } else {
            Text("No game today. Series runs Mon–Sun.")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.3))
                .padding(.bottom, 52)
        }
    }

    @ViewBuilder
    private func ctaLabel(for game: Game) -> some View {
        switch game.verdict {
        case .pending:
            Text(game.morningCompleted ? "Log Game \(game.gameNumber)" : "Set the plan — Game \(game.gameNumber)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
        case .win:
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                Text("Game \(game.gameNumber) — W")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(accent)
        case .loss:
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                Text("Game \(game.gameNumber) — L")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color(white: 0.45))
        }
    }

    private func ctaBackground(for game: Game) -> Color {
        game.verdict == .pending ? accent : Color(white: 0.1)
    }

    private func statusLine(for series: Series) -> String {
        let remaining = series.gamesRemaining
        let games = remaining == 1 ? "1 game left" : "\(remaining) games left"
        if series.isWarmup {
            return "Reps only — your real series starts Monday. \(games)."
        }
        switch series.seriesResult {
        case .won: return "Series W · \(series.wins)–\(series.losses)"
        case .lost: return "Series L · \(series.wins)–\(series.losses)"
        case .inProgress:
            guard series.judgedCount > 0 else {
                let g = remaining == 1 ? "1 game" : "\(remaining) games"
                return "\(g) this week. Let's go."
            }
            if series.userFacingElimination { return "Down \(series.wins)–\(series.losses) · WIN OR GO HOME" }
            if series.losses - series.wins >= 2 { return "Down \(series.wins)–\(series.losses) · home court advantage in play" }
            if series.wins > series.losses { return "Up \(series.wins)–\(series.losses) · \(games)" }
            if series.losses > series.wins { return "Down \(series.wins)–\(series.losses) · \(games)" }
            return "Tied \(series.wins)–\(series.losses) · \(games)"
        }
    }
}
