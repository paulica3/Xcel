import SwiftUI

extension Color {
    static let neonGreen = Color(red: 0.224, green: 1.0, blue: 0.078)
    static let arenaBlack = Color(white: 0.04)
}

struct HomeView: View {
    let series: Series?
    @State private var showHistory = false
    @State private var showEntry = false

    var todayGame: Game? { series?.games.first { $0.isToday } }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                scoreboard
                Spacer()
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
    }

    private var header: some View {
        HStack {
            Text("XCEL")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.neonGreen)
            Spacer()
            Button { showHistory = true } label: {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(white: 0.4))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var scoreboard: some View {
        if let series {
            VStack(spacing: 12) {
                if let game = todayGame {
                    Text("GAME \(game.gameNumber) OF 7")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.35))
                        .kerning(2.5)
                }

                HStack(alignment: .center, spacing: 28) {
                    scoreColumn(value: series.wins, label: "W", color: .neonGreen)
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
        case .win: return .neonGreen
        case .loss: return Color(white: 0.25)
        case .pending: return game.isToday ? Color(white: 0.55) : Color(white: 0.13)
        }
    }

    @ViewBuilder
    private var ctaSection: some View {
        if let game = todayGame {
            Button { showEntry = true } label: {
                ctaLabel(for: game)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(ctaBackground(for: game))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(game.verdict != .pending)
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }

    @ViewBuilder
    private func ctaLabel(for game: Game) -> some View {
        switch game.verdict {
        case .pending:
            Text(game.morningIntention.isEmpty ? "Set intention — Game \(game.gameNumber)" : "Log Game \(game.gameNumber)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
        case .win:
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                Text("Game \(game.gameNumber) — W")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.neonGreen)
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
        game.verdict == .pending ? .neonGreen : Color(white: 0.1)
    }

    private func statusLine(for series: Series) -> String {
        let remaining = 7 - series.judgedCount
        switch series.seriesResult {
        case .won: return "Series W · \(series.wins)–\(series.losses)"
        case .lost: return "Series L · \(series.wins)–\(series.losses)"
        case .inProgress:
            guard series.judgedCount > 0 else { return "7 games. 1 week. Let's go." }
            let games = remaining == 1 ? "1 game left" : "\(remaining) games left"
            if series.wins > series.losses { return "Up \(series.wins)–\(series.losses) · \(games)" }
            if series.losses > series.wins { return "Down \(series.wins)–\(series.losses) · \(games)" }
            return "Tied \(series.wins)–\(series.losses) · \(games)"
        }
    }
}
