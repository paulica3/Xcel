import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    var currentSeries: Series? {
        let monday = Series.mondayOf(Date())
        return allSeries.first { Calendar.current.isDate($0.weekStart, inSameDayAs: monday) }
    }

    var body: some View {
        NavigationStack {
            HomeView(series: currentSeries, stats: CareerStats.compute(from: allSeries))
        }
        .onAppear {
            ensureCurrentSeries()
            processMissedGames()
            settings.setUpNotifications()
        }
        .fullScreenCover(isPresented: .constant(!settings.hasOnboarded)) {
            OnboardingView()
        }
    }

    private func ensureCurrentSeries() {
        guard currentSeries == nil else { return }
        let monday = Series.mondayOf(Date())
        let series = Series(weekStart: monday)
        modelContext.insert(series)

        for offset in 0..<7 {
            let gameDate = Calendar.current.date(byAdding: .day, value: offset, to: monday)!
            let game = Game(date: gameDate, gameNumber: offset + 1)
            series.games.append(game)
            modelContext.insert(game)
        }
        try? modelContext.save()
    }

    private func processMissedGames() {
        guard let series = currentSeries else { return }
        var changed = false
        for game in series.games where game.isMissed(seriesCreatedAt: series.createdAt) {
            game.verdict = .loss
            game.verdictOneLiner = "Didn't show up. Automatic L."
            changed = true
        }
        if changed { try? modelContext.save() }
    }
}
