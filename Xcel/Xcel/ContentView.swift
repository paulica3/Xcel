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
            HomeView(series: currentSeries,
                     stats: CareerStats.compute(from: allSeries),
                     postseason: Postseason.compute(from: allSeries))
        }
        .onAppear {
            ensureCurrentSeries()
            processMissedGames()
            settings.setUpNotifications()
            refreshCheckups()
        }
        .fullScreenCover(isPresented: .constant(!settings.hasOnboarded)) {
            OnboardingView()
        }
    }

    private func ensureCurrentSeries() {
        guard currentSeries == nil else { return }
        let monday = Series.mondayOf(Date())

        // The user's first-ever week is a warm-up if they joined after Monday -
        // they can't play the full series, so it's reps until the next Monday.
        let isFirstEver = allSeries.isEmpty
        let joinedMidWeek = !Calendar.current.isDate(Date(), inSameDayAs: monday)
            && Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: monday)
        let series = Series(weekStart: monday, isWarmup: isFirstEver && joinedMidWeek)
        modelContext.insert(series)

        for offset in 0..<7 {
            let gameDate = Calendar.current.date(byAdding: .day, value: offset, to: monday)!
            let game = Game(date: gameDate, gameNumber: offset + 1)
            series.games.append(game)
            modelContext.insert(game)
        }
        try? modelContext.save()
    }

    // Refresh the state-driven notifications (4pm check-up + high-stakes alerts)
    // with the current series score on each app open.
    private func refreshCheckups() {
        let series = currentSeries
        let wins = series?.wins ?? 0
        let losses = series?.losses ?? 0
        NotificationManager.scheduleCheckups(
            enabled: settings.notificationsEnabled,
            wins: wins, losses: losses
        )
        NotificationManager.scheduleStakes(
            enabled: settings.notificationsEnabled && settings.stakesNotificationsEnabled
                && !(series?.isWarmup ?? false),
            wins: wins, losses: losses
        )
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
