import SwiftUI
import SwiftData

struct Trophy: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let unlocked: Bool
}

// All-time achievements earned across every series.
struct TrophyCaseView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    private var accent: Color { settings.accent.color }
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var trophies: [Trophy] {
        let real = allSeries.filter { !$0.isWarmup }
        let stats = CareerStats.compute(from: allSeries)
        let seriesWon = real.filter { $0.seriesResult == .won }.count
        let comebacks = real.filter { $0.wasComeback }.count
        let sweeps = real.filter { $0.seriesResult == .won && $0.wins == 4 && $0.losses == 0 }.count
        let totalGames = stats.wins + stats.losses

        // Best win streak ever across all judged, non-excused games.
        let judged = real.flatMap { $0.games }
            .filter { $0.verdict != .pending && !$0.excused }
            .sorted { $0.date < $1.date }
        var best = 0, run = 0
        for g in judged {
            if g.verdict == .win { run += 1; best = max(best, run) } else { run = 0 }
        }

        return [
            Trophy(icon: "figure.basketball", title: "First Blood", detail: "Win your first game", unlocked: stats.wins >= 1),
            Trophy(icon: "trophy.fill", title: "Series Win", detail: "Take a full series", unlocked: seriesWon >= 1),
            Trophy(icon: "wind", title: "Clean Sweep", detail: "Win a series 4–0", unlocked: sweeps >= 1),
            Trophy(icon: "flame.fill", title: "Comeback King", detail: "Win down 2+ games", unlocked: comebacks >= 1),
            Trophy(icon: "bolt.fill", title: "Hot Hand", detail: "3 wins in a row", unlocked: best >= 3),
            Trophy(icon: "crown.fill", title: "Unstoppable", detail: "10 wins in a row", unlocked: best >= 10),
            Trophy(icon: "shield.lefthalf.filled", title: "Veteran", detail: "Play 25 games", unlocked: totalGames >= 25),
            Trophy(icon: "star.circle.fill", title: "Champion", detail: "Win 5 series", unlocked: seriesWon >= 5),
        ]
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    let unlocked = trophies.filter(\.unlocked).count
                    Text("\(unlocked) of \(trophies.count) unlocked")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(trophies) { badge($0) }
                    }
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("THE CASE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Trophy case")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .padding(.top, 8)
    }

    private func badge(_ t: Trophy) -> some View {
        VStack(spacing: 10) {
            Image(systemName: t.unlocked ? t.icon : "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(t.unlocked ? accent : Color(white: 0.25))
                .frame(height: 36)
                .shadow(color: t.unlocked ? accent.opacity(0.5) : .clear, radius: 10)
            Text(t.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(t.unlocked ? .white : Color(white: 0.4))
            Text(t.detail)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(t.unlocked ? accent.opacity(0.3) : .clear, lineWidth: 1)
        )
        .opacity(t.unlocked ? 1 : 0.7)
    }
}
